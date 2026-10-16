"""Frozen DOM impact methods, actual Session.Run cues and complete Page.Render draws."""
import hashlib
import json
import math
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
FROZEN=ROOT/'.tmp/outgame-cached-1792126975801'
paths=['scripts/intro/IntroImpact.lua','scripts/intro/IntroSession.lua','scripts/ui/IntroPage.lua','scripts/ui/IntroGateMotion.lua',
       'assets/Intro/Intro.json','assets/UI/SourceFontMetrics.json','assets/UI/SourceIcons.json']
hashes=lambda paths:{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths}
initial_hashes=hashes(paths)
gate=(ROOT/'tools/migration/check-intro-gate-offline.py').read_text(encoding='utf-8')
scope={'__file__':str(ROOT/'tools/migration/check-intro-gate-offline.py')}
exec(compile(gate[:gate.index('\ncases=[]')],'<gate native adapters>','exec'),scope)
lua,plain,source=scope['lua'],scope['plain'],scope['source']
checks=[]

def check(ok,label):
    assert ok,label
    checks.append(label)

def near(a,b,label,tolerance=1e-7):
    check(math.isclose(a,b,abs_tol=tolerance),label)

def convert(value,runtime=lua):
    if isinstance(value,dict):return runtime.table_from({k:convert(v,runtime)for k,v in value.items()})
    if isinstance(value,list):return runtime.table_from([convert(v,runtime)for v in value])
    return value

gate_impacts=[r for r in source['trace']if r['kind']=='animate' and r.get('key')=='root']
contract_impacts=[r for r in source['contractTrace']if r['kind']=='animate' and r.get('key')=='root']
flash=next(r for r in source['contractTrace']if r['kind']=='animate' and r.get('key')=='flash')
check(len(gate_impacts)==2 and len(contract_impacts)==1,'source executes exactly two gate and one stamp root impact')
check(not any(r.get('key')=='flash'for r in source['trace']),'source gate does not flash')
check(flash['background']=='#ff3a2a' and flash['frames']==[{'opacity':.25},{'opacity':0}],'source stamp flash color and keyframes')
check(flash['options']=={'duration':200,'easing':'ease-out'},'source flash duration and easing')
events=[dict(contract_impacts[0],impact='stamp',shot='stamp',cueAge=.2),
        dict(gate_impacts[0],impact='gate-close',shot='gate',cueAge=.46),
        dict(gate_impacts[1],impact='gate-unlock',shot='gate',cueAge=3.28)]
for event in events:
    event['xy']=[[float(v)for v in re.findall(r'\* ([\deE+\-.]+)\)',r['translate'])]for r in event['frames']]
    check(len(event['xy'])==11 and all(len(p)==2 for p in event['xy']),'source actual helper emits eleven paired frames '+event['impact'])
    near(event['time']-(.3 if event['impact']=='stamp'else 0),event['cueAge'],'source actual cue '+event['impact'])

# Actual Run/Update scheduler: record calls around the real production Terminal method.
timing=(ROOT/'tools/migration/check-intro-timing.lua').read_text(encoding='utf-8')
timing=timing.replace('local I;local shots={};','local I;local impacts={};local shots={};',1)
timing=timing.replace(' I.active=true;', ''' local Impact=require 'intro.IntroImpact';local Terminal=Impact.Terminal
 Impact.Terminal=function(self,kind,random)Terminal(self,kind,random);impacts[#impacts+1]={kind=kind,at=self.time,shot=self.shot,age=self.age}end
 I.active=true;''',1)
timing=timing.replace('skipped=I.skipRequested}','skipped=I.skipRequested,impacts=impacts}',1)
data=json.loads((ROOT/'assets/Intro/Intro.json').read_text(encoding='utf-8'))
from lupa.lua54 import LuaRuntime

def run_session(session_path,impact_source=None):
    runtime=LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().TIMING_DATA=convert(data,runtime)
    if impact_source:
        runtime.execute("package.path='scripts/?.lua;'..package.path;package.loaded['core.Coord']={}")
        runtime.globals().IMPACT_SOURCE=impact_source
        runtime.execute("package.loaded['intro.IntroImpact']=assert(load(IMPACT_SOURCE))()")
    task=timing.replace("local Session=require 'intro.IntroSession'",'local Session=assert(loadfile('+json.dumps(session_path.as_posix())+'))()')
    return plain(runtime.execute(task)(True,5.04,4.13,None,'contract'))

def check_run(result):
    actual=result['impacts']
    check(len(actual)==3,'actual Session.Run invokes all three terminal impacts')
    for event,row in zip(events,actual):
        check(row['kind']==event['impact'] and row['shot']==event['shot'],'actual cue shot ownership '+event['impact'])
        near(row['age'],event['cueAge'],'actual cue within source scheduler frame '+event['impact'],.05)
        sound=next(r for r in result['sounds']if r.get('shot')==row['shot'] and abs(r['t']-row['at'])<1e-8 and r['id']==('clang'if row['kind']=='gate-close'else 'stamp'))
        check(sound is not None,'actual effect shares exact emitted sound clock '+event['impact'])

result=run_session(ROOT/'scripts/intro/IntroSession.lua')
check_run(result)
negative=[]
try:check_run(run_session(FROZEN/'scripts/intro/IntroSession.lua'))
except AssertionError as error:
    check(str(error)=='actual Session.Run invokes all three terminal impacts','old 82d session fails for missing cue wiring')
    negative.append({'case':'actual frozen 82d Session.Run','failure':str(error)})
else:raise AssertionError('Old 82d Session unexpectedly supplied impacts')

lua.execute('''
local D=require 'ui.SourceDraw';local UI=package.loaded['urhox-libs/UI']
function UI.GetScale()return UI_SCALE end
graphics.GetDPR=function()return DPR end
local nativeSave,nativeRestore=nvgSave,nvgRestore
local transform={1,0,0,1,0,0};local stack={};local color=0
DRAWS={}
function ResetTransform()assert(#stack==0);transform={1,0,0,1,0,0};DRAWS={}end
function nvgSave(vg)
 stack[#stack+1]={table.unpack(transform)};stack[#stack].color=color;nativeSave(vg)
end
function nvgRestore(vg)
 transform=assert(table.remove(stack));color=transform.color;nativeRestore(vg)
end
function nvgTranslate(_,x,y)
 transform[5]=transform[5]+transform[1]*x+transform[3]*y
 transform[6]=transform[6]+transform[2]*x+transform[4]*y
end
function nvgScale(_,x,y)
 transform[1]=transform[1]*x;transform[2]=transform[2]*x
 transform[3]=transform[3]*y;transform[4]=transform[4]*y
end
function nvgRotate(_,r)
 local a,b,c,d=transform[1],transform[2],transform[3],transform[4]
 local co,si=math.cos(r),math.sin(r)
 transform[1]=a*co+c*si;transform[2]=b*co+d*si
 transform[3]=-a*si+c*co;transform[4]=-b*si+d*co
end
function nvgFillColor(_,value)color=value end
local function Record(name)
 DRAWS[#DRAWS+1]={name=name,x=transform[5],y=transform[6],color=color,alpha=ALPHA}
end
for _,name in ipairs({'nvgFill','nvgStroke','nvgText'})do
 local original=_G[name];_G[name]=function(...)Record(name);return original(...)end
end
function RootRestored()return #stack==0 and transform[1]==1 and transform[4]==1 and transform[5]==0 and transform[6]==0 end
function DrawImpact(event,w,h,scale,dpr,age,enabled,pagePath,impactSource,flag)
 if impactSource then package.loaded['intro.IntroImpact']=assert(load(impactSource))() end
 assert(loadfile(pagePath))()
 UI_SCALE=scale;DPR=dpr
 local p=NewPage(w,h);p.owner.active=true
 p.portrait.Draw=function()Record('portrait')end
 p.owner.shot=event.shot;p.owner.time=100+event.cueAge
 local index=0;local Impact=require 'intro.IntroImpact'
 if enabled then
  assert(Impact.Terminal,'actual frozen 82d impact has no terminal event')
  Impact.Terminal(p.owner,event.impact,function()index=index+1;return assert(event.randoms[index])end)
  assert(index==22,'Exactly eleven paired terminal frames')
 end
 if flag then p.owner[flag]=true end
 ResetTransform();math.randomseed(75)
 RenderPage(p,event.shot,event.cueAge+age,nil,false)
 assert(RootRestored(),'Root transform restored after complete Page.Render')
 return {draws=DRAWS,impact=p.owner.terminalImpact}
end
''')
current_impact=(ROOT/'scripts/intro/IntroImpact.lua').read_text(encoding='utf-8')
page_path=(ROOT/'scripts/ui/IntroPage.lua').as_posix()

def ease_out(t):
    if t<=0:return 0
    if t>=1:return 1
    lo,hi=0,1
    for _ in range(40):
        v=(lo+hi)/2
        if 3*(1-v)*v*v*.58+v**3<t:lo=v
        else:hi=v
    v=(lo+hi)/2
    return 3*(1-v)*v*v+v**3

draw_cases=[]
def draw_case(event,view,age,production=None,page=page_path):
    w,h,scale,dpr=view
    actual=plain(lua.globals().DrawImpact(convert(event),w,h,scale,dpr,age,True,page,production or current_impact,None))
    baseline=plain(lua.globals().DrawImpact(convert(event),w,h,scale,dpr,age,False,page,current_impact,None))
    duration=event['options']['duration']/1000
    x,y=0,0
    k=min(w/1920,h/1080);u=h/k/100
    if age<duration:
        v=age/duration*10;index=min(9,math.floor(v));q=v-index
        a,b=event['xy'][index:index+2]
        x=(a[0]+(b[0]-a[0])*q)*u*k;y=(a[1]+(b[1]-a[1])*q)*u*k
    paints=actual['draws'];base=baseline['draws']
    has_flash=event['impact']=='stamp' and age<.2
    check(len(paints)==len(base)+int(has_flash),'actual Page flash coverage '+event['impact'])
    for a,b in zip(paints,base):
        check(a['name']==b['name'],'actual full Page draw order preserved')
        near(a['x']-b['x'],x,'every actual page paint inherits source root X')
        near(a['y']-b['y'],y,'every actual page paint inherits source root Y')
    if has_flash:
        last=paints[-1]
        near(last['color'],255*16777216+58*65536+42*256+255*.25*(1-ease_out(age/.2)),'actual late red flash uses source CSS ease-out',2e-5)
        check(last['name']=='nvgFill','flash draws after actual contract/stamp content')
    for actual_frame,expected in zip(actual['impact']['frames'],event['xy']):
        for a,b in zip(actual_frame,expected):near(a,b,'actual source randomized eleven-keyframe coordinates')
    return {'impact':event['impact'],'viewport':view,'age':age,'paints':len(paints)}

for event in events:
    duration=event['options']['duration']/1000
    for view in [(1920,1080,1,1),(2400,1080,1,2),(1440,1080,1,1),(840,378,2,2)]:
        for age in [0,.019,.057,.1,.199,.2,duration-.001,duration+.001]:
            draw_cases.append(draw_case(event,view,age))

for old,kind in [(FROZEN/'scripts/ui/IntroPage.lua','Page.Render red flash'),(FROZEN/'scripts/intro/IntroImpact.lua','IntroImpact terminal helper')]:
    try:
        draw_case(events[0],(1920,1080,1,1),.057,
                  old.read_text(encoding='utf-8')if kind.startswith('IntroImpact')else current_impact,
                  old.as_posix()if kind.startswith('Page')else page_path)
    except Exception as error:
        check('actual Page flash coverage'in str(error)or'actual frozen 82d impact has no terminal event'in str(error),'old 82d fails relevant effect omission')
        negative.append({'case':'actual frozen 82d '+kind,'failure':str(error).split('\n')[0]})
    else:raise AssertionError('Old 82d unexpectedly passed '+kind)

# State guards execute the production helper, including a skipped advertisement followed by reality.
lua.globals().IMPACT_SOURCE=current_impact
lua.execute("package.loaded['intro.IntroImpact']=assert(load(IMPACT_SOURCE))()")
lua.execute('''
function GuardTerminal()
 local M=require 'intro.IntroImpact';local I={active=true,shot='stamp',time=10,skipRequested=true}
 M.Terminal(I,'stamp',function()return .25 end);I.time=10.05
 assert(M.Shake(I,10)~=0,'Valid reality impact survives skipped ad')
 local x,y,r,t=M.CameraPlan(I);assert(x==0 and y==0 and r==0 and t==0,'Terminal impact never creates camera trauma')
 for _,flag in ipairs({'disposed','failed','finishing'})do
  I[flag]=true;x,y=M.Shake(I,10);assert(x==0 and y==0,'Suppressed terminal shake '..flag)
  ResetTransform();M.Flash(1,I,1920,1080);assert(#DRAWS==0,'Suppressed terminal flash '..flag);I[flag]=nil
 end
 I.active=false;x,y=M.Shake(I,10);assert(x==0 and y==0,'Inactive terminal suppressed');I.active=true
 I.shot='gate';x,y=M.Shake(I,10);assert(x==0 and y==0,'Wrong shot suppresses terminal')
 I.shot='stamp';I.time=9;x,y=M.Shake(I,10);assert(x==0 and y==0,'Negative event age suppressed')
 I.time=11;x,y=M.Shake(I,10);assert(x==0 and y==0,'Expired root shake suppressed')
 ResetTransform();M.Flash(1,I,1920,1080);assert(#DRAWS==0,'Expired flash suppressed')
 local Session=require 'intro.IntroSession';I.host={};I.log={};I.payslipImpact={}
 Session.Mark(I,'contract');assert(I.terminalImpact==nil and I.payslipImpact==nil,'Mark clears effect ownership')
 Session.Mark(I,'stamp');assert(I.terminalImpact==nil,'Reentry cannot replay terminal')
 M.Terminal(I,'stamp');I.gate={Cancel=function()end};I.page={Close=function()end}
 input={};MM_ABSOLUTE=1;Session.Dispose(I);assert(I.terminalImpact==nil,'Dispose releases terminal frames')
 return 14
end
''')
guards=lua.globals().GuardTerminal()
mutations=[]
for before,after,label,event in [('amp,duration=1.3,.38','amp,duration=.65,.38','half stamp amplitude',events[0]),
 ('duration=.9,.3','duration=.9,.4','gate-close duration',events[1]),
 ('255,58,42','255,255,255','wrong flash color',events[0]),
 ('Ease(age/.2,0,0,.58,1)','Ease(age/.2,0,0,1,1)','linear flash easing',events[0])]:
    check(before in current_impact,'mutation target exists '+label)
    try:draw_case(event,(1920,1080,1,1),.057,current_impact.replace(before,after,1))
    except AssertionError as error:
        check(any(t in str(error)for t in ['inherits source root','flash uses source CSS']),'mutation fails relevant source comparison '+label)
        mutations.append({'case':label,'failure':str(error)})
    else:raise AssertionError('Mutation unexpectedly passed '+label)

inputs=['tools/migration/check-intro-terminal-impact.py','tools/migration/source-intro-gate.mjs',
        'tools/migration/check-intro-timing.lua','tools/migration/check-intro-gate-offline.py',
        'tools/migration/profile-intro-contract-offline.py']
assert hashes(paths)==initial_hashes,'Production changed during terminal impact check'
report={'result':'PASS','checks':len(checks)+guards,'productionHashes':hashes(paths),'testInputs':hashes(inputs),
 'sourceHashes':source['sourceHashes'],'actualSessionImpacts':result['impacts'],'drawCases':draw_cases,
 'negativeControls':negative,'mutationControls':mutations,
 'boundary':'Frozen full actGate and contract tail execute with their actual flash/shakeDom implementations, virtual waits and DOM/audio adapters. Actual Lua Session.Run/Update, IntroImpact, complete Page.Render/Contract/Comms/Gate and source paint/text modules execute. Native NanoVG is an affine transform/paint recorder; all actual paints retain the same source root translation and the red flash draws last. Four logical viewports/scale/DPR combinations, 96 render cases, cancellation/reentry, skipped-ad reality and no camera trauma covered. Session source cues match to a 50ms scheduler tolerance; impact and real Sfx execute at exactly the same Lua clock. No claim of GPU pixels, sound/listening, native frame timing, mobile or natural-playback acceptance.'}
out=ROOT/'docs/migration/evidence/intro-terminal-impact-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':report['checks'],'drawCases':len(draw_cases),'negativeControls':len(negative),'mutations':len(mutations),'evidence':str(out)}))

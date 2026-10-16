"""Execute frozen gate JS and actual opening Page draw, without a renderer."""
import hashlib
import json
import math
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
profile=(ROOT/'tools/migration/profile-intro-contract-offline.py').read_text(encoding='utf-8')
scope={'__file__':str(ROOT/'tools/migration/profile-intro-contract-offline.py')}
exec(compile(profile[:profile.index('old, current = runtime(OLD)')],'<contract harness>','exec'),scope)
lua=scope['runtime'](ROOT/'scripts/ui/IntroPage.lua')
plain=scope['plain']
source=json.loads(subprocess.check_output(['node','tools/migration/source-intro-gate.mjs'],cwd=ROOT,text=True))
checks=[]
def check(value,label):
    assert value,label
    checks.append(label)

trace=source['trace']
rotation=next(row for row in trace if row['kind']=='animate' and row['key']=='gate .g-lock .g-disc')
pins=[row for row in trace if row['kind']=='class' and row.get('key','').startswith('gate .g-lock .g-bolt')]
check(len(pins)==6 and math.isclose(rotation['time']-pins[0]['time'],.48),'source six 80ms waits before rotation')
check(rotation['options']['duration']==420,'source disc animation lasts 420ms')
motion=lua.eval("package.loaded['ui.IntroGateMotion']")
for i,pin in enumerate(pins):
    check(abs(motion.Plan(pin['time']+1e-8)['bolts'][i+1])<1e-5,f'pin {i} starts at source cue')
check(motion.Plan(2.91)['rotation']==0,'disc does not overlap bolt sequence')
check(motion.Plan(2.93)['rotation']>0,'disc begins after 480ms sequence')
for t,expected in [(0,1),(.46,0),(3.58,0),(3.94,.06),(4.24,.06),(5.74,1.04)]:
    check(math.isclose(motion.Plan(t)['split'],expected,abs_tol=1e-6),f'source split endpoint {t}')
for row in [r for r in trace if r['kind']=='animate' and r['key']=='left']:
    easing=row['options']['easing'];params=[float(v) for v in easing[len('cubic-bezier('):-1].split(',')]
    start=row['time'];duration=row['options']['duration']/1000
    for fraction in [.1,.5,.9]:
        eased=motion.Ease(fraction,*params)
        expected=1-eased if start==0 else .06*eased if start<4 else .06+.98*eased
        check(math.isclose(motion.Plan(start+duration*fraction)['split'],expected,abs_tol=1e-6),f'actual source easing {start}/{fraction}')
check(not motion.Plan(3.579)['half'] and motion.Plan(3.58)['half'],'lock halves begin at original door-open cue')
check(motion.Plan(3.27)['seam']==0 and motion.Plan(3.5)['seam']>0,'seam begins at original unlock cue')
check(motion.Plan(5.44)['seam']==0,'seam fades over source 1200ms')
check(not motion.Plan(5.94)['visible'],'gate removed at source cue')
stamp=next(row for row in source['contractTrace']if row['kind']=='in')
check(stamp['duration']==260 and stamp['frames'][1]['offset']==.75,'frozen stamp animation keyframes executed')
check([row['ms']for row in source['contractTrace']if row['kind']=='out']==[300,500],'frozen contract and stamp exits execute together')
for fraction in [0,.1,.3,.5,.75,.9,1]:
    eased=motion.Ease(fraction,.5,0,.7,1)
    scale=3.2+(0.92-3.2)*eased/.75 if eased<.75 else .92+.08*(eased-.75)/.25
    state=motion.Stamp(fraction*.26)
    check(math.isclose(state['scale'],scale,abs_tol=1e-6),f'stamp original scale easing {fraction}')
    check(math.isclose(state['alpha'],min(1,eased/.75),abs_tol=1e-6),f'stamp original alpha easing {fraction}')

lua.execute('''
local UI=package.loaded['urhox-libs/UI'];function UI.GetViewportSize()return VIEW_W,VIEW_H end
function UI.GetScale()return 1 end
graphics={GetDPR=function()return 1 end}
NVG_CW=1
local function Record(name,...)
 CALLS[name]=(CALLS[name]or 0)+1
 if RECORD then TRACE[#TRACE+1]={name,...}end
end
ALPHA=1;ALPHAS={};PAINTS={}
function nvgSave()DEPTH=DEPTH+1;ALPHAS[DEPTH]=ALPHA;Record('nvgSave')end
function nvgRestore()assert(DEPTH>0);ALPHA=ALPHAS[DEPTH];ALPHAS[DEPTH]=nil;DEPTH=DEPTH-1;Record('nvgRestore')end
function nvgGlobalAlpha(_,alpha)ALPHA=alpha;Record('nvgGlobalAlpha',alpha)end
for _,name in ipairs({'nvgFill','nvgStroke','nvgText'})do _G[name]=function(...)PAINTS[#PAINTS+1]={name,ALPHA};Record(name,...)end end
for _,name in ipairs({'nvgRotate','nvgArc'})do _G[name]=function(...)Record(name,...)end end
function NewPage(w,h)
 VIEW_W=w;VIEW_H=h
 local p=MakePage(w,h,false)
 p.owner.active=true;p.owner.stage='reality';p.owner.name='TEST';p.owner.host={state={}};p.owner.data=DATA
 p.owner.audio.Duration=function()return 8 end
 p.inputClip={SetStyle=function()end}
 p.nameField.SetVisible=function()end
 p.nameField.SetOpacity=function(self,alpha)self.alpha=alpha end
 p.portrait={materials={},Prepare=function()end,Queue=function()end,Draw=function()PAINTS[#PAINTS+1]={'portrait',ALPHA}end}
 return p
end
function RenderPage(p,shot,t,fade,contractExit,wallElapsed)
 p.owner.shot=shot;p.owner.age=t;p.owner.time=100+t;p.owner.signed=shot~='comms'
 p.owner.contractExitAt=contractExit and 100 or nil
 p.owner.finishing=fade~=nil;p.owner.fadeOutDuration=.7;p.owner.fadeOutAt=fade and p.owner.time-(1-fade)*.7 or nil
 p.owner.fadeOutElapsed=wallElapsed
 CALLS={};TRACE={};PAINTS={};RECORD=true
 p:Render(1);assert(DEPTH==0);assert(ALPHA==1)
 return PAINTS
end
''')
cases=[]
for w,h in [(1920,1080),(1440,1080),(2400,1080),(840,378)]:
    page=lua.globals().NewPage(w,h)
    for shot,t,exit_contract in [('contract',2,False),('stamp',.01,False),('stamp',.2,False),('stamp',1,False),
                                  ('gate',.01,True),('gate',.2,True),('gate',.4,True),('gate',.6,True),
                                  *[('gate',t,False) for t in [.2,.5,1,1.9,2.5,2.91,3.1,3.3,3.59,3.8,4.1,4.5,5.5,5.95]]]:
        paints=plain(lua.globals().RenderPage(page,shot,t,None,exit_contract))
        full=[row[1] for row in paints]
        traces=plain(lua.globals().TRACE)
        check(all(math.isfinite(value) for row in traces for value in row[1:] if isinstance(value,(int,float))),f'finite native commands {w}/{shot}/{t}')
        for alpha in [.5,0]:
            faded=plain(lua.globals().RenderPage(page,shot,t,alpha,exit_contract))
            check(len(faded)==len(paints),f'fade retains all draw layers {w}/{shot}/{t}/{alpha}')
            check(all(math.isclose(row[1],original*alpha,abs_tol=1e-8) for row,original in zip(faded,full)),f'every actual child paint multiplies root alpha {w}/{shot}/{t}/{alpha}')
            check(math.isclose(page['nameField']['alpha'],alpha,abs_tol=1e-8),f'UI name field fades {w}/{shot}/{t}/{alpha}')
        cases.append({'viewport':[w,h],'shot':shot,'age':t,'contractExit':exit_contract,'paintCount':len(paints)})
    # Both pressure bursts retain source counts and normalized coordinates.
    page=lua.globals().NewPage(w,h)
    lua.globals().RenderPage(page,'gate',3.28,None,False)
    check(len(page['gateSteam']['puffs'])==12,f'first source vent emits 6 particles at both outlets {w}')
    lua.globals().RenderPage(page,'gate',3.58,None,False)
    check(len(page['gateSteam']['puffs'])==28,f'second source vent adds 8 particles at both outlets {w}')
    for puff in page['gateSteam']['puffs'].values():
        check(20<=puff['r']<=50 and 1.2<=puff['life']<=2,f'original steam CSS radius/lifetime ranges {w}')
    page=lua.globals().NewPage(w,h)
    for frame in range(360):lua.globals().RenderPage(page,'gate',frame/60,None,False)
    check(page['gateSteam']['vented'][1] and page['gateSteam']['vented'][2],f'both vents emitted {w}')

# Actual render dispatch keeps C + portrait + red stamp, then overlaps gate.
lua.execute('''
LAYER={};local oldContract=capturedPage.Contract;local oldComms=capturedPage.Comms;local oldGate=capturedPage.Gate
capturedPage.Contract=function(self,...)LAYER[#LAYER+1]='contract';return oldContract(self,...)end
capturedPage.Comms=function(self,...)LAYER[#LAYER+1]='comms';return oldComms(self,...)end
capturedPage.Gate=function(self,...)LAYER[#LAYER+1]='gate';return oldGate(self,...)end
''')
for shot,t,exit_contract,expected in [('stamp',.4,False,['comms','contract']),('gate',.1,True,['comms','contract','gate']),
                                    ('gate',.35,True,['comms','gate']),('gate',.6,True,['gate']),('gate',.1,False,['gate'])]:
    lua.execute('LAYER={}')
    lua.globals().RenderPage(lua.globals().NewPage(1920,1080),shot,t,None,exit_contract)
    check(plain(lua.globals().LAYER)==expected,f'actual source exit layering {shot}/{t}/{exit_contract}')
lua.execute('''
LOCKS={};local Fx=require 'ui.IntroGateFx';local Lock=Fx.Lock
Fx.Lock=function(vg,I,x,y,u,plan,image,half)LOCKS[#LOCKS+1]={x=x,y=y,half=half};return Lock(vg,I,x,y,u,plan,image,half)end
''')
for t in [3.57,3.58,3.8,4.7]:
    lua.execute('LOCKS={}')
    lua.globals().RenderPage(lua.globals().NewPage(1920,1080),'gate',t,None,False)
    locks=plain(lua.globals().LOCKS)
    check(len(locks)==(1 if t<3.58 else 2),f'actual full lock replaced by two leaf locks {t}')
    if t>=3.58:
        split=motion.Plan(t)['split']
        check(math.isclose(locks[0]['x'],1920*.502*(1-split),abs_tol=1e-6),f'left half travels inside left clipped leaf {t}')
        check(math.isclose(locks[1]['x'],1920*(.498+.502*split),abs_tol=1e-6),f'right half travels inside right clipped leaf {t}')

# Traverse the other real Intro children through actual Page.Render dispatch.
def convert(value):
    if isinstance(value,dict):return lua.table_from({k:convert(v)for k,v in value.items()})
    if isinstance(value,list):return lua.table_from([convert(v)for v in value])
    return value
lua.globals().GLYPHS=convert(json.loads((ROOT/'assets/Intro/Fonts/TitleGlyphs.json').read_text(encoding='utf-8')))
lua.execute('''
local Read=package.loaded['core.ResourceData'].Read
package.loaded['core.ResourceData'].Read=function(path)if path=='Intro/Fonts/TitleGlyphs.json'then return GLYPHS end;return Read(path)end
package.loaded['ui.IntroTypography']={face='vox-title',Begin=function()end}
package.loaded['core.Coord']={Vec=function()return {}end}
package.loaded['ui.WorkshopPaint'].Image=function()PAINTS[#PAINTS+1]={'image',ALPHA}end
for _,name in ipairs({'nvgBezierTo','nvgPathWinding','nvgRoundedRect','nvgTransform','nvgGaussianBlur'})do _G[name]=function()end end
function nvgCreateImage()return 1 end
function nvgImagePatternTinted()return 1 end
function nvgBoxGradient()return 1 end
function nvgTextMetrics()return 10,-3 end
NVG_SOLID=1;NVG_HOLE=2;NVG_IMAGE_REPEATX=1;NVG_IMAGE_REPEATY=2
require 'ui.IntroPage'
''')
promo_cases=[]
for shot in ['logo','prosper','order','leave','no','familiar','galaxy','payslip','decide','decided',
             'sortie-countdown','sortie-brief','motto','disclaimer']:
    for age in [.12,.4,1,2.5]:
        page=lua.globals().NewPage(1920,1080)
        page['owner']['stage']='ad'
        page['owner']['caption']='原版字幕'
        page['owner']['log']=lua.table_from([])
        page['owner']['mine']=True
        page['owner']['voiceDuration']=8
        page['owner']['big']=''
        paints=plain(lua.globals().RenderPage(page,shot,age,None,False))
        faded=plain(lua.globals().RenderPage(page,shot,age,.37,False))
        check(len(faded)==len(paints),f'actual promo child count {shot}/{age}')
        check(all(math.isclose(row[1],base[1]*.37,abs_tol=1e-8)for row,base in zip(faded,paints)),f'actual promo child root alpha {shot}/{age}')
        promo_cases.append({'shot':shot,'age':age,'paintCount':len(paints)})

# Setter replacement semantics, nested groups, and unrelated contexts.
lua.execute('''
local A=require 'ui.IntroOpacity'
function AlphaExercise()
 local result={};A.Set(1,.3);result[#result+1]=ALPHA
 A.Push(1,.5);A.Set(1,.8);result[#result+1]=ALPHA
 A.Push(1,.4);A.Set(1,.7);result[#result+1]=ALPHA
 A.Pop(1);result[#result+1]=ALPHA;A.Pop(1);result[#result+1]=ALPHA
 A.Set(1,1);return result
end
''')
check(all(math.isclose(a,b) for a,b in zip(plain(lua.globals().AlphaExercise()),[.3,.4,.14,.4,.3])),'nested local alpha setter and native save/restore preserved')
opacity=lua.eval("package.loaded['ui.IntroOpacity']")
for elapsed,expected in [(0,1),(.35,.5),(.7,0),(2,0)]:
    owner=lua.table_from({'finishing':True,'time':1.001,'fadeOutAt':1,'fadeOutDuration':.7,'fadeOutElapsed':elapsed})
    check(math.isclose(opacity.Exit(owner),expected,abs_tol=1e-8),f'wall fade elapsed overrides clamped simulation time {elapsed}')
for shot,age in [('contract',2),('stamp',.2),('gate',3.6)]:
    page=lua.globals().NewPage(1920,1080)
    full=plain(lua.globals().RenderPage(page,shot,age,None,False))
    faded=plain(lua.globals().RenderPage(page,shot,age,1,False,.35))
    check(all(math.isclose(row[1],base[1]*.5,abs_tol=1e-8)for row,base in zip(faded,full)),f'actual Page uses wall progress despite unchanged simulation clock {shot}')
paths=['scripts/ui/IntroPage.lua','scripts/ui/IntroOpacity.lua','scripts/ui/IntroGateMotion.lua','scripts/ui/IntroGateFx.lua',
       'scripts/ui/IntroContractLayout.lua','scripts/ui/IntroContractMotion.lua','scripts/ui/IntroContractText.lua',
       'scripts/ui/IntroMotto.lua','scripts/ui/IntroTerminalFx.lua','scripts/intro/IntroSession.lua',
       'tools/migration/check-intro-gate-offline.py','tools/migration/source-intro-gate.mjs']
paths+=['scripts/ui/'+name+'.lua'for name in ['IntroPromo','IntroPromoMotion','IntroBrand','IntroComic','IntroComicText','IntroFamiliar','IntroFilm','IntroGalaxyText','IntroPayslip','IntroSortieKill','IntroSortieUi','IntroTitleCard']]
report={'result':'PASS','checks':len(checks),'cases':cases,'promoCases':promo_cases,'source':source,
        'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
        'boundary':'Frozen actGate JS executes with virtual waits and DOM/audio adapters. Actual Page.Render/Contract/Comms/Gate, GateFx, SourceDraw, text layout and frame modules execute in Lua 5.4; native NanoVG replaced by strict finite command and setter-alpha recorder, portrait surface doubled. Root fade verified on every emitted fill/stroke/text/portrait paint. This is per-element alpha multiplication, not CSS offscreen group pixel compositing. Random steam follows source ranges and frame updates, not source random pixel identity. No GPU, Web, screenshots, package, upload or visual acceptance.'}
out=ROOT/'docs/migration/evidence/intro-gate-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':len(checks),'cases':len(cases),'report':str(out)},ensure_ascii=False))

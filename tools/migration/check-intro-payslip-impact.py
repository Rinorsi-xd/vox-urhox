"""Actual source impact, actual Session cue/camera and Page/Promo root transform."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference=json.loads(subprocess.check_output(['node','tools/migration/source-intro-payslip-impact.mjs'],encoding='utf-8'))
frozen=ROOT/'.tmp/outgame-cached-1792113063203'
paths=['scripts/intro/IntroImpact.lua','scripts/intro/IntroSession.lua','scripts/ui/IntroPage.lua','scripts/ui/IntroPromo.lua','scripts/core/Coord.lua']
hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}

def plain(v):
    if hasattr(v,'items'):
        d=dict(v.items())
        return [plain(d[k]) for k in sorted(d)] if d and all(isinstance(k,int) for k in d) else {k:plain(x) for k,x in d.items()}
    return v

def execute(session_path,page_path,impact_source=None):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(v):
        if isinstance(v,dict):return lua.table_from({k:table(x) for k,x in v.items()})
        if isinstance(v,list):return lua.table_from([table(x) for x in v])
        return v
    lua.globals().REF=table(reference)
    lua.globals().SESSION_PATH=session_path.as_posix()
    lua.globals().PAGE_PATH=page_path.as_posix()
    lua.globals().IMPACT_SOURCE=impact_source
    return plain(lua.execute(r'''
package.path='scripts/?.lua;'..package.path
print=function()end
local noop=function()end
local checks=0;local function check(ok,label)assert(ok,label);checks=checks+1 end
local function near(a,b,label)check(math.abs(a-b)<1e-8,label)end
local function vector(a,b,label)for n=1,#b do near(a[n],b[n],label..'/'..n)end end
local vec={__add=function(a,b)return Vector3(a.x+b.x,a.y+b.y,a.z+b.z)end}
Vector3=setmetatable({FORWARD={x=0,y=0,z=1}},{__call=function(_,x,y,z)return setmetatable({x=x,y=y,z=z},vec)end})
local rotation={__mul=function(a,b)return Quaternion(a.angle+b.angle,Vector3.FORWARD)end}
Quaternion=function(angle,axis)check(axis==Vector3.FORWARD,'Trauma roll uses local forward axis');return setmetatable({angle=angle},rotation)end
local UI={Widget={Extend=function()capturedPage={};capturedPage.__index=capturedPage;return capturedPage end},
 GetViewportSize=function()return VIEW_W,VIEW_H end,GetScale=function()return UI_SCALE end}
package.loaded['urhox-libs/UI']=UI
for _,name in ipairs({'ui.IntroFrame','ui.WorkshopPaint','urhox-libs/UI/Core/ImageCache',
 'ui.IntroContractLayout','ui.IntroGateMotion','ui.IntroGateFx','ui.IntroContractMotion','ui.IntroContractText'})do package.loaded[name]={}end
local transform={sx=1,sy=1,x=0,y=0};local stack={};local events={}
local function record(name)events[#events+1]={name=name,x=transform.x,y=transform.y}end
function nvgSave()stack[#stack+1]={sx=transform.sx,sy=transform.sy,x=transform.x,y=transform.y}end
function nvgRestore()transform=assert(table.remove(stack),'Unbalanced restore')end
function nvgScale(_,x,y)transform.sx=transform.sx*x;transform.sy=transform.sy*y end
function nvgTranslate(_,x,y)transform.x=transform.x+x*transform.sx;transform.y=transform.y+y*transform.sy end
nvgGlobalAlpha=noop;nvgStrokeWidth=noop;nvgStrokeColor=noop;nvgStroke=noop
nvgRGBA=function(...)return{...}end
package.loaded['ui.SourceDraw']={Begin=noop,Width=function(_,text,size)return utf8.len(text)*size*.6 end,
 Text=function(_,text)if text=='跳过广告'then record('skip')end end,Rect=noop,Path=noop}
package.loaded['ui.SourceParagraph']={New=function()return{Measure=function()return{height=20}end,Draw=function()record('caption')end}end}
package.loaded['ui.IntroTypography']={}
package.loaded['ui.IntroTitleCard']={}
package.loaded['ui.IntroFilm']={Under=function()record('film-under')end,Over=function()record('bars')end}
package.loaded['ui.IntroPayslip']={Draw=function()record('paper')end,DrawForeground=function()record('lock-laser')end}
package.loaded['ui.IntroPromoFx']={Draw=function()record('flash')end}
package.loaded['ui.IntroWipe']={Draw=function()record('wipe')end}
graphics={GetDPR=function()return DPR end}
local Impact=IMPACT_SOURCE and assert(load(IMPACT_SOURCE))() or require 'intro.IntroImpact'
package.loaded['intro.IntroImpact']=Impact
local Session=assert(loadfile(SESSION_PATH))()
assert(loadfile(PAGE_PATH))()
local rows={}
for _,case in ipairs(REF.cases)do
 local I=setmetatable({active=true,stage='ad',shot='payslip',time=case.impactAt,age=case.hitAt+.09-1e-7,
  voiceDuration=case.duration,cueState={},log={},audio={Sfx=noop}},Session)
 local randomIndex=0;local oldRandom=math.random
 math.random=function()randomIndex=randomIndex+1;return assert(REF.randoms[randomIndex])end
 I:UpdateAdCues();check(I.payslipImpact==nil,'No impact before hit+.09')
 I.age=case.hitAt+.09;I:UpdateAdCues();math.random=oldRandom
 check(I.payslipImpact~=nil,'Actual Session triggers impact at hit+.09')
 near(I.payslipImpact.at,case.impactAt,'Impact actual clock');check(randomIndex==22,'Exactly 11 paired root keyframes')
 local impact=I.payslipImpact;I:UpdateAdCues();check(I.payslipImpact==impact,'Cue is one-shot')
 for n,frame in ipairs(case.shake.frames)do vector(impact.frames[n],frame,'Actual source random keyframe')end
 local camera={node={position=Vector3(-10,20,30),rotation=Quaternion(0,Vector3.FORWARD)},fov=44}
 I.host={GetCamera=function()return camera end,CameraShot=function(_,_,_,c)
  c.node.position=Vector3(-10,20,30);c.node.rotation=Quaternion(0,Vector3.FORWARD)
 end}
 for _,frame in ipairs(case.cameraFrames)do
  I.time=frame.time;I.age=I.time-case.markAt
  local x,y,roll,trauma=Impact.CameraPlan(I)
  vector({x,y,0},frame.position,'Actual frozen camera waveform');near(roll,frame.roll,'Source local roll')
  near(trauma,frame.traumaBefore,'Source trauma before decay')
  I:Camera()
  vector({-(camera.node.position.x+10),camera.node.position.y-20,camera.node.position.z-30},frame.position,'Actual Session camera applies reflected source offset')
  near(-camera.node.rotation.angle*math.pi/180,frame.roll,'Actual Session reflected local roll')
  near(I.payslipImpact.trauma,frame.traumaAfter,'Source applies before 1.4 per second decay')
  check(camera.fov==44,'Impact retains payslip FOV')
 end
 for _,view in ipairs({{1600,900,1,1},{2400,1080,1,2},{1440,1080,1,1},{960,540,2,2}})do
  VIEW_W,VIEW_H,UI_SCALE,DPR=table.unpack(view)
  local k=math.min(VIEW_W/1920,VIEW_H/1080);local u=VIEW_H/k/100
  for _,age in ipairs({0,.019,.038,.057,.19,.379,.38,.42,.5})do
   I.time=impact.at+age;I.age=I.time-case.markAt
   local expectedX,expectedY=0,0
   if age<.38 then
    local p=age/.38*10;local index=math.min(10,math.floor(p)+1);local q=p-(index-1)
    local a,b=case.shake.frames[index],case.shake.frames[index+1]
    expectedX=(a[1]+(b[1]-a[1])*q)*u;expectedY=(a[2]+(b[2]-a[2])*q)*u
   end
   local x,y=Impact.Shake(I,u);near(x,expectedX,'Source linear root X');near(y,expectedY,'Source linear root Y')
   I.caption='caption';I.data={};I.downloaded=true
   local page=setmetatable({owner=I,nameField={SetOpacity=noop},pointers={}},capturedPage)
   events={};page:Render(1)
   check(#stack==0 and transform.x==0 and transform.y==0 and transform.sx==1,'Page root restores render state')
   local expected={'film-under','paper','caption','bars','lock-laser','flash','skip','wipe'}
   check(#events==#expected,'Actual Page/Promo layer coverage')
   for index,event in ipairs(events)do
    check(event.name==expected[index],'Actual Promo ordering preserved')
    near(event.x,expectedX*k,'Whole-page root X includes '..event.name)
    near(event.y,expectedY*k,'Whole-page root Y includes '..event.name)
   end
   local r=page.skipRect;near(r.y,(VIEW_H/k*.024+expectedY)*k,'Skip hitbox tracks root Y')
   near(r.x+r.w,(VIEW_W/k*.974+expectedX)*k,'Skip hitbox tracks root X')
  end
 end
 I.time=impact.at+.1
 for _,flag in ipairs({'skipRequested','failed','finishing'})do
  I[flag]=true;vector({Impact.Shake(I,10)},{0,0},'Suppressed root effect '..flag)
  local x,y,r,t=Impact.CameraPlan(I);vector({x,y,r,t},{0,0,0,0},'Suppressed camera effect '..flag);I[flag]=nil
 end
 I:Mark('decide');check(I.payslipImpact==nil,'Next shot clears both impact owners')
 I:Mark('payslip');check(I.payslipImpact==nil,'Reentry cannot replay previous impact')
 rows[#rows+1]={duration=case.duration,impactAge=case.hitAt+.09,cameraFrames=#case.cameraFrames,viewports=4,rootAges=9}
end
return{checks=checks,cases=rows}
'''))

negative=[]
for kind,session,page in [
    ('frozen 5b8c cue',frozen/'scripts/intro/IntroSession.lua',ROOT/'scripts/ui/IntroPage.lua'),
    ('frozen 5b8c root transform',ROOT/'scripts/intro/IntroSession.lua',frozen/'scripts/ui/IntroPage.lua'),
]:
    try:execute(session,page)
    except Exception as error:
        assert 'Actual Session triggers impact' in str(error) or 'Whole-page root' in str(error),str(error)
        negative.append({'case':kind,'failure':str(error).split('\n')[0]})
    else:raise AssertionError('Frozen omission unexpectedly passed: '+kind)
result=execute(ROOT/'scripts/intro/IntroSession.lua',ROOT/'scripts/ui/IntroPage.lua')
mutations=[]
current=(ROOT/'scripts/intro/IntroImpact.lua').read_text(encoding='utf-8')
for before,after,label in [('1.6*(1-i/10)','0.8*(1-i/10)','halved root amplitude'),
                          ('age>=.38','age>=.5','extended root duration'),
                          ('Quaternion(-roll*180','Quaternion(roll*180','wrong reflected roll')]:
    assert before in current
    try:execute(ROOT/'scripts/intro/IntroSession.lua',ROOT/'scripts/ui/IntroPage.lua',current.replace(before,after,1))
    except Exception as error:
        assert any(text in str(error) for text in ['Actual source random keyframe','Source linear root','Actual Session reflected local roll']),str(error)
        mutations.append({'case':label,'failure':str(error).split('\n')[0]})
    else:raise AssertionError('Mutation unexpectedly passed: '+label)

# Execute one full actual Ad coroutine solely to inspect its two wipe arguments.
lua=LuaRuntime(unpack_returned_tuples=True)
def table(v):
    if isinstance(v,dict):return lua.table_from({k:table(x) for k,x in v.items()})
    if isinstance(v,list):return lua.table_from([table(x) for x in v])
    return v
lua.globals().TIMING_DATA=table(json.loads((ROOT/'assets/Intro/Intro.json').read_text(encoding='utf-8')))
harness=(ROOT/'tools/migration/check-intro-timing.lua').read_text(encoding='utf-8')
harness=harness.replace('local I;local shots={};','local I;local wipes={};local shots={};',1)
harness=harness.replace(' I.active=true;',' local original=I.Wipe;I.Wipe=function(self,color)wipes[#wipes+1]=color or "default";return original(self,color)end\n I.active=true;',1)
harness=harness.replace('skipped=I.skipRequested}','skipped=I.skipRequested,wipes=wipes}',1)
timing=lua.execute(harness)(True,5.04,4.13,None)
wipes=list(timing['wipes'].values())
assert wipes==['default','#2a0705'],wipes
assert all(c['wipeMarkup']=='<i style="background:#2a0705"></i>' for c in reference['cases'])
assert hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},'Production changed during check'
report={'result':'PASS',**result,'baseline':reference['baseline'],'sourceHashes':reference['sourceHashes'],
 'productionHashes':hashes,'negativeControls':negative,'mutationControls':mutations,'actualAdWipes':wipes,
 'boundary':reference['boundary']+' Actual Lua IntroSession.UpdateAdCues/Camera/Mark, IntroImpact and IntroPage.Render/IntroPromo.Draw execute. Camera vectors/quaternions are adapters; unrelated paint layers record their inherited transform. Captions, bars, foreground, skip button and wipe all inherit root translation; skip bounds follow it. Includes three voice durations, four viewport/scale/DPR combinations, exact cue boundary, one-shot trigger, cancellation/reentry, expired shake and residual camera decay. No GPU, build, raster, listening or natural-playback acceptance.'}
out=ROOT/'docs/migration/evidence/intro-payslip-impact-offline.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':result['checks'],'negativeControls':len(negative),'mutations':len(mutations),'evidence':str(out)}))

"""Compare actual frozen story-camera tasks and gate cue with actual Lua session."""
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

reference=json.loads(subprocess.check_output(['node','tools/migration/source-intro-story-camera.mjs'],encoding='utf-8'))
frozen=ROOT/'.tmp/outgame-cached-1792113063203/scripts/intro/IntroSession.lua'
assert hashlib.sha256(frozen.read_bytes()).hexdigest()=='c897536f3dd67695313dcb9a29b795a4a0f257a2e31bb91c92c6ba341019514d'
data=json.loads((ROOT/'assets/Intro/Intro.json').read_text(encoding='utf-8'))
LUA=r'''
package.path='scripts/?.lua;'..package.path
local noop=function()end
print=noop
Vector3=function(x,y,z)return{x=x,y=y,z=z}end
input={};MM_ABSOLUTE=1
package.loaded['urhox-libs/UI']={GetFocus=noop,ClearFocus=noop,SetRoot=noop,PushOverlay=noop}
package.loaded['core.ResourceData']={Read=function()return DATA end}
package.loaded['app.ResourceGate']={New=function()return {Start=noop,Cancel=noop}end}
package.loaded['ui.IntroPage']={New=function()return {imageWarmup={ready=true},ShowContract=noop}end}
package.loaded['intro.IntroImpact']={Payslip=noop,Camera=noop,Terminal=noop}
package.loaded['audio.IntroAudio']={New=function()return {Sfx=function()return {}end,StopMusic=noop,Music=noop,StopSfx=noop,
 Update=noop,StopVoice=noop,Voice=function()return 0 end}end}
local Session=assert(load(SESSION_SOURCE))()
local checks=0;local function check(value,label)checks=checks+1;assert(value,label)end
local function near(a,b,label)check(math.abs(a-b)<1e-8,label)end
local function vector(v,expected,label)near(-v.x,expected[1],label..'/x');near(v.y,expected[2],label..'/y');near(v.z,expected[3],label..'/z')end
local camera={node={LookAt=function(self,p)self.look=p end}}
local frames={}
local I=Session.New({},{GetCamera=function()return camera end})
I.active=true;I.time=17;I.storyCameraAt=17
for _,frame in ipairs(REFERENCE.frames)do
 I.time=17+frame.age;I:Mark(frame.shot)
 if frame.startGate then I.gateCameraAt=I.time end
 I:Camera()
 vector(camera.node.position,frame.position,'source continuous camera '..frame.shot..'/'..frame.age)
 vector(camera.node.look,frame.look,'source camera look '..frame.shot..'/'..frame.age)
 near(camera.fov,frame.fov,'source camera FOV')
 frames[#frames+1]={shot=frame.shot,age=frame.age,position=camera.node.position}
end
local runs={}
for _,part in ipairs({'contract','gate','normal'})do
 local s=Session.New({},{GetCamera=function()return camera end});s.active=true;s.ready=true;s.clicked=true;s.audioReady=true;s.sceneReady=true
 s.part=part;s.Vivi=noop;s.Ad=noop;s.Finish=function(self)self.complete=true end;s.choosing=false
 local shots={};s.host.Shot=function(id,self)shots[id]=self.time end
 s.thread=coroutine.create(function()s:Run()end)
 local dt=1/1000;local cursor=0;local poses=0
 for n=1,30000 do
  if s.shot=='contract' and s.age>=3 then s.signed=true end
  if s.choosing then s.choice=1 end
  s:Update(dt,true);s:Camera()
  check(not s.failed,s.error or 'actual coroutine failed')
  if s.shot=='contract' or s.shot=='stamp' or s.shot=='gate' and not s.gateCameraAt then
   local origin=shots.comms or shots.gate
   check(s.storyCameraAt==origin,'Run registers shared camera once at original scene entry')
   poses=poses+1
   local age=s.time-origin
   near(-camera.node.position.x,-13+math.sin(age*.07)*2,'Run story camera retains shared task age')
  end
  if s.complete then break end
 end
 check(s.complete==true,'complete actual '..part..' coroutine')
 check(s.gateCameraAt~=nil,'gate camera task registered')
 check(math.abs(s.gateCameraAt-shots.gate-REFERENCE.gateCameraAt)<.025,'actual gate camera begins at source split cue')
 local frozenTime=s.time;s:Update(.5,false);near(s.time,frozenTime,'unfocused opening preserves camera clock')
 runs[#runs+1]={part=part,gateCameraAge=s.gateCameraAt-shots.gate,storyCameraAt=s.storyCameraAt,sourceEntry=shots.comms or shots.gate,poses=poses}
end
-- A new start must not inherit either camera origin from a cancelled run.
I.active=false;I.storyCameraAt=-99;I.gateCameraAt=-99;I:Start('gate')
check(I.storyCameraAt==nil and I.gateCameraAt==nil,'Start clears prior opening camera origins')
return {checks=checks,runs=runs,frames=frames}
'''

def run(source):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def convert(value):
        if isinstance(value,dict):return lua.table_from({k:convert(v)for k,v in value.items()})
        if isinstance(value,list):return lua.table_from([convert(v)for v in value])
        return value
    def plain(value):
        if hasattr(value,'items'):
            rows=dict(value.items())
            if rows and all(isinstance(k,int)for k in rows):return [plain(rows[k])for k in sorted(rows)]
            return {k:plain(v)for k,v in rows.items()}
        return value
    lua.globals().SESSION_SOURCE=source
    lua.globals().DATA=convert(data)
    lua.globals().REFERENCE=convert(reference)
    return plain(lua.execute(LUA))

current=(ROOT/'scripts/intro/IntroSession.lua').read_text(encoding='utf-8')
negative=[]
for name,source,expected in [
    ('frozen 5b8c',frozen.read_text(encoding='utf-8'),'source continuous camera'),
    ('shot-age reset',current.replace("local age=self.time-(self.storyCameraAt or self.time)","local age=self.age"),'source continuous camera'),
    ('camera starts 300ms late',current.replace("self:Wait(.36);self.gateCameraAt=self.time;self:Wait(.3)","self:Wait(.36);self:Wait(.3);self.gateCameraAt=self.time"),'actual gate camera begins at source split cue'),
]:
    try:run(source)
    except Exception as error:
        assert expected in str(error),(name,str(error))
        negative.append({'name':name,'sha256':hashlib.sha256(source.encode()).hexdigest(),'failure':str(error).split('\n')[0]})
    else:raise AssertionError('Negative control passed: '+name)
result=run(current)
report={'result':'PASS',**result,'baseline':reference['baseline'],'sourceHashes':reference['sourceHashes'],
 'sourceGateCameraAge':reference['gateCameraAt'],'production':{'scripts/intro/IntroSession.lua':hashlib.sha256((ROOT/'scripts/intro/IntroSession.lua').read_bytes()).hexdigest()},
 'negativeControls':negative,'boundary':reference['boundary']+' Actual Lua Session.Camera/Mark/Run/Update/Start; complete contract, gate-only and normal (Ad/Vivi adapters) runs, pause and fresh-start reset. No UI layout, natural dialogue playback, GPU or package acceptance.'}
out=ROOT/'docs/migration/evidence/intro-story-camera-offline.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':result['checks'],'frames':len(result['frames']),'runs':result['runs'],'negativeControls':len(negative),'evidence':str(out)}))

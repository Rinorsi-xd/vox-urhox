"""Execute frozen source camera and actual Lua shots/host; frozen 5b8c is negative control."""
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

reference=json.loads(subprocess.check_output(['node','tools/migration/source-intro-payslip-camera.mjs'],encoding='utf-8'))
frozen=ROOT/'.tmp/outgame-cached-1792113063203'
paths=['scripts/intro/IntroShots.lua','scripts/app/OpeningHost.lua']
hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
old_hashes={p:hashlib.sha256((frozen/p).read_bytes()).hexdigest() for p in paths}
assert old_hashes[paths[0]]=='722e6f97e8e977c95e1bb1bda7e6fe94f6bc1f5267ef6d42f255ac3179c067a3'
assert old_hashes[paths[1]]=='b934a31693668c74573d034de08847758381b4adc5d7f29262c6d40a93db2335'

def plain(v):
    if hasattr(v,'items'):
        d=dict(v.items())
        return [plain(d[k]) for k in sorted(d)] if d and all(isinstance(k,int) for k in d) else {k:plain(x) for k,x in d.items()}
    return v

def run(host_path,shots_path,shots_source=None):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(v):
        if isinstance(v,dict):return lua.table_from({k:table(x) for k,x in v.items()})
        if isinstance(v,list):return lua.table_from([table(x) for x in v])
        return v
    lua.globals().REFERENCE=table(reference)
    lua.globals().HOST_PATH=host_path.as_posix()
    lua.globals().SHOTS_PATH=shots_path.as_posix()
    lua.globals().SHOTS_SOURCE=shots_source
    return plain(lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local noop=function()end
package.loaded['construction.Blueprint']={}
package.loaded['app.SceneLoader']={New=function()return{Update=noop,Cancel=noop}end}
Vector3=function(x,y,z)return{x=x,y=y,z=z}end
local Shots=assert(SHOTS_SOURCE and load(SHOTS_SOURCE) or loadfile(SHOTS_PATH))();package.loaded['intro.IntroShots']=Shots
local Host=assert(loadfile(HOST_PATH))()
local checks=0;local function check(ok,label)assert(ok,label);checks=checks+1 end
local function near(a,b,label)check(math.abs(a-b)<1e-8,label)end
local function vector(a,b,label)for n=1,3 do near(a[n],b[n],label..'/'..n)end end
local results={}
for _,case in ipairs(REFERENCE.cases)do
 local rays,grounds={},{};local calls=0;local environment=0
 local cart={pos={31,4,-169},vehicle={body={name='cart-body'}},Position=function(self)return self.pos end}
 local camera={node={position={x=777,y=888,z=999},LookAt=function(self,p)self.look=p end},fov=61}
 local host=Host.New({car={SetVisible=noop},graphicsSettings={SetSceneVisible=noop}})
 host.state.hallActor={SetVisible=noop,Dispose=noop};host.state.activeScene='crater';host.state.cameraLift=9
 host.state.session={combat={cart=case.kind~='fallback' and cart or nil},
  environment={Update=function()environment=environment+1 end}}
 host.state.world={GroundAt=function(_,x,z)grounds[#grounds+1]={x,z};return x*.07-z*.03 end,
  space={Raycast=function(_,origin,direction,length,ignored)
   calls=calls+1;rays[#rays+1]={origin=origin,direction=direction,length=length,ignored=ignored and ignored.name}
   if case.kind=='three-blocks' then return calls<=3 and {dist=1} or nil end
   if case.kind=='all-blocked' then return{dist=1}end
   if case.kind=='near-end' then return{dist=length-.59}end
   if case.kind=='at-margin' then return calls==1 and {dist=length-.6}or nil end
   if case.kind=='actor' then return{dist=1,owner={ref={}}}end
  end}}
 local I={host=host,ready=true,playing=false,time=17}
 host.Shot('payslip',I)
 check(I.payslipShot~=nil,'Payslip entry initializes camera: '..case.kind)
 check(#grounds==#case.grounds,'One-time ground sample count')
 for i,p in ipairs(grounds)do vector({p[1],0,p[2]},{case.grounds[i][1],0,case.grounds[i][2]},'Source terrain sample')end
 check(#rays==#case.rays,'Source clearCam ray count '..case.kind)
 for i,ray in ipairs(rays)do local expected=case.rays[i]
  vector(ray.origin,expected.origin,'Source ray origin');vector(ray.direction,expected.direction,'Source normalized direction')
  near(ray.length,expected.length,'Source ray length');check(ray.ignored==expected.ignored,'Original cart body excluded')
 end
 local entry=I.payslipShot.at;local frames={}
 -- Replacing the combat target must not replace the target captured at entry.
 host.state.session.combat.cart={Position=function()return{900,900,900}end}
 for _,frame in ipairs(case.frames)do
  local age=frame.age;cart.pos={31+age*3,4+age*.2,-169+age}
  if age>=2.5 then cart.vehicle=nil end
  host.CameraShot('payslip',age,I,camera)
  local p=camera.node.position;local look=camera.node.look
  vector({-p.x,p.y,p.z},frame.position,'Actual host source camera position '..case.kind..'/'..age)
  vector({-look.x,look.y,look.z},frame.look,'Actual host source camera look '..case.kind..'/'..age)
  near(camera.fov,frame.fov,'Source FOV44');check(I.payslipShot.at==entry,'Base camera retained')
  frames[#frames+1]={age=age,position={-p.x,p.y,p.z},look={-look.x,look.y,look.z},fov=camera.fov}
 end
 check(#rays==#case.rays and #grounds==#case.grounds,'No per-frame raycast or terrain resample')
 check(host.state.cameraLift==9,'Payslip does not inherit or alter smoothed montage lift')
 check(environment==#case.frames,'Actual host updates crater environment')
 host.Shot('decide',I);check(I.payslipShot==nil,'Leaving payslip releases captured unit')
 if case.kind~='fallback'then
  host.state.session.combat.cart=cart;cart.pos={41,8,-155};cart.vehicle={body={name='cart-body'}}
  host.Shot('payslip',I);check(I.payslipShot.at~=entry,'Reentry replaces camera base')
  host.CameraShot('payslip',0,I,camera);near(-camera.node.position.x,49,'Reentry camera uses fresh cart position')
 end
 host.state.craterRetired=true;host.Dispose(I)
 check(I.payslipShot==nil,'Dispose releases captured payslip unit')
 host.Dispose(I);check(I.payslipShot==nil,'Repeated dispose retains released camera state')
 results[#results+1]={kind=case.kind,rayCount=#case.rays,frames=frames}
end
return{checks=checks,cases=results}
'''))

negative=[]
try:
    run(frozen/paths[1],frozen/paths[0])
except Exception as error:
    assert 'Payslip entry initializes camera' in str(error),str(error)
    negative.append({'case':'frozen 5b8c host and shots','failure':str(error).split('\n')[0]})
else:raise AssertionError('Frozen missing payslip camera unexpectedly passed')
result=run(ROOT/paths[1],ROOT/paths[0])
mutations=[]
current=(ROOT/paths[0]).read_text(encoding='utf-8')
for before,after,label in [
    ('shot.at[1]-t*2','shot.at[1]-t*.2','wrong drift speed'),
    ('p[2]+1.5,p[3]},44','p[2]+1,p[3]},44','wrong live look height'),
    ('p[2]+1.5,p[3]},44','p[2]+1.5,p[3]},50','wrong FOV'),
]:
    assert before in current,label
    try:run(ROOT/paths[1],ROOT/paths[0],current.replace(before,after,1))
    except Exception as error:
        assert 'Actual host source camera' in str(error) or 'Source FOV44' in str(error),str(error)
        mutations.append({'case':label,'failure':str(error).split('\n')[0]})
    else:raise AssertionError('Mutation unexpectedly passed: '+label)
assert hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
assert old_hashes=={p:hashlib.sha256((frozen/p).read_bytes()).hexdigest() for p in paths}
report={'result':'PASS',**result,'baseline':reference['baseline'],'sourceHashes':reference['sourceHashes'],
 'productionHashes':hashes,'mutationControls':mutations,'frozenNegativeControl':{'manifest':'manifest-5b8cf21c.json','hashes':old_hashes,'failures':negative},
 'boundary':reference['boundary']+' Actual Lua OpeningHost.Shot/CameraShot, IntroShots and core.Coord use controlled engine adapters. Covers cart retention, missing/dead cart, terrain sample, 0/3/20 lifts, strict 0.6m margin, actor exclusion, FOV, seconds-based drift, reentry, scene exit and independent montage lift. No GPU, build, CURRENT_EXECUTION edits or acceptance of 5b8c.'}
out=ROOT/'docs/migration/evidence/intro-payslip-camera-offline.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':result['checks'],'negativeControls':len(negative),'mutations':len(mutations),'evidence':str(out)}))

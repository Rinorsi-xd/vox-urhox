"""Offline actual EffectBatch recorder checks; no Native, browser or FPS claims."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s,n)local f,e=load(s,n);assert(f,e);return true end')
for name in ['ads-pixel-batch.lua', 'ads-pixel-observer.lua']:
    compile_lua((ROOT / 'tools/migration' / name).read_text(encoding='utf-8'), name)
lua.execute(r'''
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
package.preload['core.Coord']=function()return {Vec=function(x,y,z)return{x,y,z}end}end
TRIANGLE_LIST='TRIANGLE_LIST'
function Color(...)return {...}end
function Vector2(...)return {...}end
function Vector3(...)return {...}end
function Vector4(...)return {...}end
function Variant(value)return value end
Material={new=function()return{SetSurfaceShader=function()return true end,SetShaderParameter=function(self,key,value)self[key]=value end}end}
mesh={enabled=false,vertices={},commits=0}
function mesh:BeginGeometry()self.vertices={}end
function mesh:DefineVertex(value)self.vertices[#self.vertices+1]={position=copy(value)}end
function mesh:DefineNormal(value)self.vertices[#self.vertices].normal=copy(value)end
function mesh:DefineColor(value)self.vertices[#self.vertices].color=copy(value)end
function mesh:DefineTexCoord(value)self.vertices[#self.vertices].uv=copy(value)end
function mesh:DefineTangent(value)self.vertices[#self.vertices].tangent=copy(value)end
function mesh:Commit()self.commits=self.commits+1;self.uploaded=copy(self.vertices)end
root={CreateChild=function()return{CreateComponent=function()return mesh end}end}
''')
lua.globals().Batch = lua.execute((ROOT / 'scripts/render/EffectBatch.lua').read_text(encoding='utf-8'))
lua.globals().Recorder = lua.execute((ROOT / 'tools/migration/ads-pixel-batch.lua').read_text(encoding='utf-8'))
lua.execute(r'''
local b=Batch.New(root,'Glow',4)
local positions={{0,0,10},{1,0,10},{2,0,10},{3,0,10}}
local tags={[positions[2]]={owner='ownPersistent',kind='spark'},[positions[3]]={owner='outsideOwnPersistent',kind='mote'},[positions[4]]={owner='outsideOwnPersistent',kind='overflow'}}
local r=Recorder.New(b,function(p)return tags[p]end)
b:Begin({0,0,0},2.75)
for i=1,3 do b:Disc(positions[i],.1,{7,4.2,1.2},.8,{1,0,0},{0,1,0},nil,1)end
b:Segment({0,1,10},{0,1,20},.2,{2,3,4},1.5,.3,0,1,true,.9)
b:Disc(positions[4],.1,{1,1,1},1,{1,0,0},{0,1,0})
b:Finish()
assert(b.count==4)
local frame=r:Snapshot();local baseline=mesh.uploaded
assert(#frame.entries==4 and frame.entries[1].tag==false and frame.entries[4].tag==false)
assert(frame.entries[2].tag.owner=='ownPersistent'and frame.entries[3].tag.owner=='outsideOwnPersistent')
local random=math.random;local calls=0
math.random=function(...)calls=calls+1;return random(...)end
local a=r:Replay(frame);assert(a.original==4 and a.removed==0 and equal(mesh.uploaded,baseline))
local motion=r:Replay(frame,function(e)return e.tag and e.tag.owner=='outsideOwnPersistent'end)
assert(motion.removed==1 and motion.retained==3 and #mesh.uploaded==18)
for i=1,12 do assert(equal(mesh.uploaded[i],baseline[i]))end
for i=13,18 do assert(equal(mesh.uploaded[i],baseline[i+6]))end
local equipment=r:Replay(frame,function(e)return e.tag~=false end)
assert(equipment.removed==2 and equipment.retained==2 and #mesh.uploaded==12)
for i=1,6 do assert(equal(mesh.uploaded[i],baseline[i]))end
for i=7,12 do assert(equal(mesh.uploaded[i],baseline[i+12]))end
local again=r:Replay(frame);assert(equal(mesh.uploaded,baseline)and b.material.clock==2.75)
assert(#r.frame.entries==4 and #frame.entries==4,'Replay cannot overwrite recorded original')
local empty=r:Replay(frame,function()return true end);assert(empty.retained==0 and not mesh.enabled)
r:Replay(frame);assert(mesh.enabled and equal(mesh.uploaded,baseline))
assert(calls==0,'Geometry replay cannot call RNG')
local altered={entries=frame.entries,camera=frame.camera,time=frame.time}
altered.entries[1].points[1][1]=999
assert(r.frame.entries[1].points[1][1]~=999,'Snapshots own point memory')
''')
combined = '\n'.join([
    (ROOT / 'scripts/main.lua').read_text(encoding='utf-8'),
    (ROOT / 'tools/migration/scope-fx-isolated-observer.lua').read_text(encoding='utf-8'),
    'do\nlocal AdsPixelBatch=(function()\n',
    (ROOT / 'tools/migration/ads-pixel-batch.lua').read_text(encoding='utf-8'),
    '\nend)()\n',
    (ROOT / 'tools/migration/ads-pixel-observer.lua').read_text(encoding='utf-8'),
    '\nend\n',
])
compile_lua(combined, 'combined-ads-pixel-entry')
lua.execute(r'''
keys={};input={GetKeyPress=function(self,key)return keys[key]==true end}
KEY_F8='F8';KEY_F9='F9';KEY_0='0';KEY_7='7';KEY_8='8';KEY_9='9'
cjson={encode=function(value)
 if type(value)=='table'then lastReport=value;return '{}'end
 if type(value)=='string'then return string.format('%q',value)end
 return tostring(value)
end}
print=function()end
local camera={worldPosition={x=0,y=2,z=0},worldRotation={w=1,x=0,y=0,z=0}}
local settings={fov=35}
local effects={time=5,particles={},smoke={},beams={},flares={},rings={},flashes={},zaps={},trails={},batches={}}
for _,name in ipairs({'Glow','Smoke','Streak'})do effects.batches[name]=Batch.New(root,name,20)end
function effects:EquipmentEmit(kind,p)self.particles[#self.particles+1]={pos=p,vel={0,0,0},age=0,size=.05,life=.2}end
local vehicleView={weaponEffects={visible=false}}
vehicleView.root={GetComponents=function()return{{enabledEffective=false}}end}
function vehicleView.weaponEffects:Update()effects:EquipmentEmit('spark',{1,0,10})end
local weaponView={Update=function()effects:EquipmentEmit('spark',{2,0,10})end}
package.preload['render.WeaponView']=function()return weaponView end
local trial={effects=effects,view={view=vehicleView},camera={GetNode=function()return camera end,GetCamera=function()return settings end},
 world={time=5,stats={shots=1}},vehicle={body={center=function()return{x=0,y=1,z=0}end}},
 practice={player={current={p={0,1,0},q={0,0,0,1}}}},weapons={energy=99},firstPerson=true,scope=true}
app={trial=trial}
updates=0;posts=0;presented=0
function HandleUpdate()
 updates=updates+1
 -- Reproduce the real production F8 collision found in run d.
 if keys.F8 then trial.firstPerson=false;trial.scope=false end
 if updates~=2 then return end
 vehicleView.weaponEffects:Update();weaponView.Update(vehicleView)
 for _,batch in pairs(effects.batches)do batch:Begin({0,2,0},5)end
 for _,particle in ipairs(effects.particles)do effects.batches.Glow:Disc(particle.pos,.1,{1,1,1},1,{1,0,0},{0,1,0})end
 for _,batch in pairs(effects.batches)do batch:Finish()end
end
function HandlePostUpdate()posts=posts+1;if keys.F8 then trial.firstPerson=false;trial.scope=false end end
function HandleFramePresented()presented=presented+1 end
AdsPixelBatch=Recorder
''')
lua.execute((ROOT / 'tools/migration/ads-pixel-observer.lua').read_text(encoding='utf-8'))
lua.execute(r'''
HandleUpdate();HandlePostUpdate();HandleUpdate();HandlePostUpdate()
assert(updates==2 and posts==2 and app.trial.firstPerson)
keys.F8=true;HandleUpdate();HandlePostUpdate();keys.F8=false
assert(updates==2 and posts==2,'F8 must not reach either production callback')
assert(lastReport.frozen and lastReport.scope.firstPerson and lastReport.scope.scope)
assert(lastReport.replay.Glow.retained==2 and lastReport.replay.Glow.removed==0)
local digest=lastReport.referenceDigest
keys['8']=true;HandleUpdate();keys['8']=false
assert(lastReport.frozen and lastReport.digest==digest and lastReport.replay.Glow.removed==1)
assert(lastReport.tagged.Glow['outsideOwnPersistent:ownMotion:spark']==1)
keys['9']=true;HandleUpdate();keys['9']=false
assert(lastReport.digest==digest and lastReport.replay.Glow.removed==2)
keys['0']=true;HandleUpdate();keys['0']=false
assert(lastReport.digest==digest and lastReport.replay.Glow.retained==2)
HandleFramePresented();assert(presented==0 and updates==2 and posts==2)
assert(lastReport.randomDelta==0 and lastReport.randomSeedDelta==0)
keys.F8=true;HandleUpdate();keys.F8=false
HandleUpdate();HandlePostUpdate();HandleFramePresented()
assert(updates==3 and posts==3 and presented==1,'Normal callbacks resume after QA release')
app.trial.firstPerson=false;app.trial.scope=false;keys.F8=true;HandleUpdate();keys.F8=false
local okay,message=pcall(HandlePostUpdate)
assert(not okay and tostring(message):find('Freeze only after actual ADS',1,true),'Actual ADS gate must still reject unscoped state')
''')
print('PASS actual EffectBatch attributes, tagged-only filters, overflow exclusion, baseline restore, empty visibility, alias safety, no RNG and combined Lua syntax. No rendered/runtime acceptance.')
print('PASS actual observer F8 interception prevents production debug pause, preserves true ADS, freezes Update/PostUpdate/FramePresented, checks exact own-motion tags and resumes callbacks. No hardware.')

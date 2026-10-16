"""Run the QA observer against real spawn/view Lua methods with CPU adapters."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

PROBE = ROOT / 'tools/migration/probe-outgame-web.lua'
INPUTS = [PROBE, ROOT / 'scripts/render/CombatView.lua', ROOT / 'scripts/render/DriveView.lua',
          ROOT / 'scripts/render/VehicleView.lua', ROOT / 'scripts/app/TrialSession.lua']
RUNNER = ROOT / 'tools/migration/check-story-natural-web.cjs'

ASSEMBLY_SETUP = r'''
modules={};cjson={null={}};TRIANGLE_LIST=0;LINE_LIST=1
require=function(name)return assert(modules[name],name)end
function LoadModule(text,name)local value=assert(load(text,name))();modules[name]=value;return value end
function Vector3(x,y,z)return {x=x,y=y,z=z}end
Vector4={};Quaternion=setmetatable({IDENTITY={w=1,x=0,y=0,z=0}},{__call=function(_,a)return {angle=a}end})
Vector3=setmetatable({ZERO={x=0,y=0,z=0}},{__call=function(_,x,y,z)return {x=x,y=y,z=z}end})
function Vector2(x,y)return {x=x,y=y}end
function Variant(x)return x end
resources={};released={};commits=0;projects=0;nodes={};materials={}
cache={Exists=function()return true end,GetResource=function(_,kind,name)
 resources[name]=resources[name] or {SetSRGB=function()end,name=name};return resources[name]end,
 ReleaseResource=function(_,kind,name)released[name]=(released[name] or 0)+1 end}
function Node()
 local n={children={},enabled=true};nodes[#nodes+1]=n
 function n:CreateChild(name)local c=Node();c.name=name;self.children[#self.children+1]=c;return c end
 function n:SetScale(s)self.scale=s end
 function n:Dispose()self.disposed=true;for _,c in ipairs(self.children)do c:Dispose()end end
 function n:CreateComponent()
  local g={};function g:BeginGeometry()self.vertices={}end
  function g:DefineVertex(v)self.vertices[#self.vertices+1]={p=v}end
  function g:DefineNormal(v)self.vertices[#self.vertices].n=v end
  function g:DefineColor(v)self.vertices[#self.vertices].c=v end
  function g:DefineTexCoord(v)self.vertices[#self.vertices].uv=v end
  function g:Commit()commits=commits+1 end
  function g:SetMaterial(m)self.material=m end;return g
 end;return n
end
Material={new=function()local m={params={}};materials[#materials+1]=m
 function m:SetSurfaceShader(s)self.shader=s;return true end
 function m:SetShaderParameter(k,v)self.params[k]=v end
 function m:SetSurfaceTexture(k,v)self.texture=v end
 function m:Dispose()self.disposed=true end;return m end}
modules.Config={CELL=.5,HexLinear=function(c,a)return {hex=c,alpha=a}end}
modules['core.ResourceData']={Read=function(path)return ReadData(path)end}
modules['core.Coord']={Vec=function(x,y,z)return Vector3(-x,y,z)end,CellPos=function(x,y,z)return Vector3(-x,y,z)end,RotQuat=function(r)return {rot=r}end}
modules['core.Math3']={};modules['drive.VehicleSpec']={GEOMETRY={rotations={}}}
modules['parts.Materials']={Joined=function(slot,xray)return slot..tostring(xray)end,JoinedOutline=function()return 'outline'end}
modules['parts.PartAssets']={Get=function()return {whole={layers={}}}end,Release=function(list)for _,name in ipairs(list)do cache:ReleaseResource('Model',name)end end}
modules['render.PartRig']={Build=function(node,data,part,vis)
 vis.rig={};vis.shellSlots={};vis.materialSlots={};vis.data=data
 vis.models={{instanceColor=false,model=cache:GetResource('Model','fixture-model')}};vis.resources={'fixture-model'}
end}
modules['render.ShellMaterials']={Release=function()end}
modules['app.ResourceGate']={New=function()return {Start=function(_,paths,done)done(true)end,Cancel=function()end}end}
modules['render.LiveryModel']={Fixed=function(p)return p.g~=nil end,Skip=function()return false end}
local function Motion()return {Update=function()end,Reset=function()end}end
modules['render.ActuatorView']={New=Motion};modules['render.LegView']={New=Motion};modules['render.MechView']={New=Motion}
modules['render.EquipmentEffects']={New=function()local e={Bind=function()end,Update=function()end};function e:Dispose()self.disposed=true end;return e end}
function Canon(v)
 if type(v)~='table'then return tostring(v)end
 local out={};for k,item in pairs(v)do if type(item)~='function'then out[#out+1]=tostring(k)..'='..Canon(item)end end
 table.sort(out);return '{'..table.concat(out,';')..'}'
end
function Snapshot(view)
 local out={joined={},rotors={},livery={},parts={}}
 local function Meshes(source,target)for key,mesh in pairs(source)do target[key]={vertices=mesh.geometry.vertices,material=mesh.geometry.material,shadow=mesh.geometry.castShadows}end end
 Meshes(view.joined.meshes,out.joined)
 for owner,mesh in pairs(view.rotorJoined or {})do out.rotors[owner]={};Meshes(mesh.meshes,out.rotors[owner])end
 for i,mesh in ipairs(view.livery.meshes)do out.livery[i]={owner=mesh.owner,key=mesh.key,vertices=mesh.geometry.vertices,params=mesh.material.params,texture=mesh.texturePath,order=mesh.material.renderOrder}end
 for id,vis in pairs(view.visuals)do out.parts[id]={position=vis.node.position,rotation=vis.node.rotation,resources=vis.resources,color=vis.models[1]and vis.models[1].instanceColor}end
 return Canon(out)
end
function Fixture(rotor)
 local parts={{id=1,type='cube',pos={0,0,0},rot=0,g=1,color=0x123456},
  {id=2,type='cube',pos={1,0,0},rot=0,g=1,color=0x654321},
  {id=3,type='core',pos={100,0,0},rot=0,color=0x556677}}
 local bp={livery={{s='burst',p={.5,1,0},n={0,1,0},r=.3,w=4,c={0x123456,0xabcdef}}},List=function()return parts end}
 local vehicle={native={position=Vector3.ZERO,rotation=Quaternion.IDENTITY},wheels={},spec={rotorOf=rotor and {[2]=1}or {},wings={}},rotors={}}
 return bp,vehicle
end
'''


def assembly_equivalence():
    def run(view_source, drive_source, rotor, mode='drive'):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(ASSEMBLY_SETUP)
        null = lua.globals().cjson.null
        def convert(value):
            if value is None:
                return null
            if isinstance(value, dict):
                return lua.table_from({k: convert(v) for k, v in value.items()})
            if isinstance(value, list):
                return lua.table_from([convert(v) for v in value])
            return value
        lua.globals().ReadData = lambda name: convert(json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8')))
        for name in ['core.Rotations', 'parts.Defs', 'construction.Rotors', 'render.JoinedSurface',
                     'render.JoinedMesh', 'construction.LiveryData', 'render.LiveryProjection',
                     'render.LiveryLayer', 'render.RotorView']:
            lua.globals().LoadModule((ROOT / 'scripts' / (name.replace('.', '/') + '.lua')).read_text(encoding='utf-8'), name)
        lua.execute("local p=require('render.LiveryProjection');local project=p.Project;function p.Project(...)projects=projects+1;return project(...)end")
        lua.globals().View = lua.globals().LoadModule(view_source, 'render.VehicleView')
        lua.globals().Drive = lua.globals().LoadModule(drive_source, 'render.DriveView')
        lua.execute('function Drive:Update()end')
        lua.globals().withRotor = rotor
        lua.globals().mode = mode
        return dict(lua.execute(r'''
local bp,vehicle=Fixture(withRotor);local drive,view;local yielded=false
if mode=='empty'then bp.livery={}end
local function Retain(v)drive=v;view=v.view end
if mode=='editor'then view=View.New(Node());view:Rebuild(bp)
elseif mode=='cancel' or mode=='final-cancel' or mode=='error'then
 local co=coroutine.create(function()Drive.New(Node(),bp,vehicle,function(p)
  if mode=='error'then error('injected checkpoint error')end
  if mode~='final-cancel' or p==.9 then coroutine.yield('retained')end end,Retain)end)
 local ok,why=coroutine.resume(co);assert(drive and view)
 if mode~='error'then assert(ok and why=='retained');assert(coroutine.close(co))else assert(not ok and tostring(why):find('injected checkpoint error'))end
 drive:Dispose();assert(view.root.disposed and drive.equipment.disposed);drive:Dispose()
 return {disposed=true,commits=commits,projects=projects}
elseif mode=='yield'then
 local co=coroutine.create(function()Drive.New(Node(),bp,vehicle,function(p)
  if p==.9 then yielded=true;coroutine.yield('before-bind')end end,Retain)end)
 assert(coroutine.resume(co));assert(yielded);local pendingCommits=commits
 assert(coroutine.resume(co));assert(coroutine.status(co)=='dead')
 return {snapshot=Snapshot(view),commits=commits,projects=projects,pendingCommits=pendingCommits}
else drive=Drive.New(Node(),bp,vehicle,nil,Retain);view=drive.view end
local snapshot=Snapshot(view);local color=view.visuals[3].models[1].instanceColor
assert(view.visuals[3].models[1].model==resources['fixture-model'])
assert(color.hex==0x556677 and #view.livery.meshes==(mode=='empty' and 0 or withRotor and mode~='editor' and 2 or 1))
local totalCommits,totalProjects=commits,projects
if drive then drive:Dispose()else view:Dispose()end
assert(view.root.disposed and released['fixture-model']==1)
for _,material in ipairs(materials)do assert(material.disposed)end
return {snapshot=snapshot,commits=totalCommits,projects=totalProjects,disposed=true}
''').items())
    view = INPUTS[3].read_text(encoding='utf-8')
    drive = INPUTS[2].read_text(encoding='utf-8')
    old_view = subprocess.run(['git', 'show', '48ef15f2:scripts/render/VehicleView.lua'], cwd=ROOT, capture_output=True, text=True, encoding='utf-8', check=True).stdout
    old_drive = subprocess.run(['git', 'show', '48ef15f2:scripts/render/DriveView.lua'], cwd=ROOT, capture_output=True, text=True, encoding='utf-8', check=True).stdout
    # Frozen actual 188b result identity, also exactly present in Git main.
    assert hashlib.sha256(old_view.encode()).hexdigest() == 'cad959af7ae69a319cfef87ff66f5ab797e3a158743ae4378dbfa3ca31ca99cf'
    assert hashlib.sha256(old_drive.encode()).hexdigest() == '93e2e2605797b25d3434e62161762434e63fc960bb63b9fad0289244ad9965af'
    checks, cases = [], []
    for rotor in [False, True]:
        old, new = run(old_view, old_drive, rotor), run(view, drive, rotor)
        assert new['snapshot'] == old['snapshot'], 'Final geometry/normal/color/UV/material/owner/resource differs'
        assert new['commits'] < old['commits'] and new['projects'] <= old['projects'], 'Old duplicate submission was not removed'
        checks.append('Actual old-main vs current final geometry, normals, paint, UV, material, rotor ownership and resource identity: rotor=' + str(rotor))
        cases.append({'rotor': rotor, 'oldCommits': old['commits'], 'newCommits': new['commits'], 'oldProjections': old['projects'], 'newProjections': new['projects']})
        old_editor, new_editor = run(old_view, old_drive, rotor, 'editor'), run(view, drive, rotor, 'editor')
        assert old_editor == new_editor
        checks.append('Default editor Rebuild unchanged: rotor=' + str(rotor))
        for mode in ['cancel', 'final-cancel', 'error']:
            assert run(view, drive, rotor, mode)['disposed']
            checks.append('Actual retained constructor ' + mode + ' disposes partial owner: rotor=' + str(rotor))
        yielded = run(view, drive, rotor, 'yield')
        assert yielded['snapshot'] == new['snapshot'] and yielded['commits'] == new['commits'] and yielded['pendingCommits'] == 0
        checks.append('Actual final rebuild checkpoint yields before single full bind submission: rotor=' + str(rotor))
        empty_old, empty_new = run(old_view, old_drive, rotor, 'empty'), run(view, drive, rotor, 'empty')
        assert empty_old['snapshot'] == empty_new['snapshot'] and empty_new['projects'] == 0 and empty_new['commits'] < empty_old['commits']
        checks.append('Empty livery stays empty and final joined geometry is exact: rotor=' + str(rotor))
    return {'checks': checks, 'cases': cases, 'negativeControl': 'Real 48ef15f2 / 188b production modules submit more geometry; exact final state remains equal',
            'boundary': 'Actual Rebuild, Bind, RotorView, JoinedMesh/Surface, LiveryLayer/Projection under native-object adapters and real exported shape/catalog data. PartRig/nonjoined attachment adapter retains model identity. No GPU/visual/performance claim.'}

RUNNER_CHECKS = r'''
const assert=require('node:assert/strict'),fs=require('node:fs');
const source=fs.readFileSync(process.argv[1],'utf8');
const {observeSpawnDiagnostic:observe}=require(process.argv[1]);
const checks=[];function check(ok,name){assert(ok,name);checks.push(name);}
const ack={result:'OBSERVED'},state={story:{enemies:0,time:1},performance:{battleTiming:{enabled:true,epoch:1},updateTiming:{'battle.Trial.Tick':{calls:1},other:{calls:7}}}};
const run={result:'WAITING_ZERO',durationWallMs:12000};
assert.throws(()=>observe(run,state,0,{result:'REQUESTED'}));checks.push('Reject requested but unacknowledged F15');
state.performance.battleTiming.enabled=false;assert.throws(()=>observe(run,state,0,ack));checks.push('Reject disabled detailed observer');
state.performance.battleTiming.enabled=true;
check(observe(run,state,100,ack)===false&&run.result==='WAITING_SPAWN','Actual zero sample arms diagnostic');
state.story.enemies=3;state.story.time=2;state.performance.updateTiming['battle.Trial.Tick'].calls=2;
check(observe(run,state,1000,ack)===false&&run.result==='SAMPLING','Actual zero-to-three transition begins window');
state.performance.updateTiming['battle.Trial.Tick'].calls=99;
check(run.zero.timings['battle.Trial.Tick'].calls===1&&run.firstSpawn.timings['battle.Trial.Tick'].calls===2,'Timing snapshots are frozen values');
check(!('other'in run.firstSpawn.timings),'Detailed snapshot excludes unrelated outer timing');
check(!observe(run,state,12999,ack),'Do not exit before twelve wall-clock seconds');
check(observe(run,state,13000,ack)&&run.result==='CAPTURED'&&run.elapsedWallMs===12000,'Capture exact twelve-second boundary');
const noZero={result:'WAITING_ZERO'};observe(noZero,state,0,ack);
check(!observe(noZero,state,15000,ack)&&!noZero.firstSpawn,'Starting with live enemies cannot masquerade as first spawn');
state.story.enemies=0;observe(noZero,state,16000,ack);state.story.enemies=2;
check(!observe(noZero,state,17000,ack)&&noZero.firstSpawn.wall===17000,'Later true zero-to-positive transition can arm after initial positive');
const begin=source.indexOf('   if(spawnDiagnostic){\n    const previousResult='),end=source.indexOf('\n   if(convoyCheck)',begin);
assert(begin>=0&&end>begin);
const actualInline=source.slice(begin,end);
const AsyncFunction=Object.getPrototypeOf(async function(){}).constructor;
(async()=>{
 const events=[],report={spawnDiagnostic:{result:'WAITING_ZERO'},battleTiming:ack,result:'RUNNING'};
 const apply=new AsyncFunction('spawnDiagnostic','report','state','observeSpawnDiagnostic','persist','check','keys','fire','shot',
  'while(true){'+actualInline+'\nbreak;}');
 const execute=()=>apply(true,report,state,observe,()=>events.push('persist'),(ok,name)=>check(ok,name),
  async()=>events.push('keys-release'),async value=>{assert.equal(value,false);events.push('fire-release');},async name=>events.push(name));
 state.story.enemies=0;await execute();state.story.enemies=3;await execute();
 report.spawnDiagnostic.firstSpawn.wall-=12001;await execute();
 check(report.result==='PASS'&&report.spawnDiagnostic.result==='CAPTURED','Actual inline mode reports diagnostic capture');
 check(events.slice(-3).join(',')==='keys-release,fire-release,first-spawn-window','Actual inline exit releases input before diagnostic screenshot');
 check(checks.every(name=>!name.includes('complete mission reached')),'Diagnostic does not add whole-mission completion check');
 check(source.includes("assert(!spawnDiagnostic||battleTimingCheck&&!entryOnly&&!logOnly&&!convoyCheck"),'Actual runner rejects incompatible entry/acceptance modes');
 check(source.includes("check(!spawnDiagnostic,'Diagnostic window cannot be replaced by whole-mission completion')"),'Actual full-mission shortcut explicitly rejects diagnostic substitution');
 check(source.includes("check(state.performance.arrayBytes===0,'natural attempt return releases terrain arrays')"),'Existing shared normal-return terrain release assertion remains');
 process.stdout.write(JSON.stringify({checks}));
})().catch(error=>{console.error(error);process.exitCode=1;});
'''

SETUP = r'''
wall=0;checks={};messages={};modules={};Time={GetSystemTime=function()return wall end}
print=function(value)messages[#messages+1]=value end
require=function(name)return assert(modules[name],name)end
function Check(value,label)assert(value,label);checks[#checks+1]=label end
function Cost(ms)wall=wall+ms end
function LoadModule(text,name)local value=assert(load(text,name))();modules[name]=value;return value end
function Stub(ms)return function(self,token,...)Cost(ms);return token,nil,'third',false end end
modules.Config={CELL=.5};modules['parts.Defs']={};modules['parts.PartAssets']={}
modules['render.PartRig']={};modules['render.JoinedSurface']={};modules['core.Coord']={}
modules['core.Rotations']={};modules['drive.VehicleSpec']={};modules['core.Math3']={}
modules['render.ActuatorView']={};modules['render.LegView']={};modules['render.WeaponView']={}
modules['render.EquipmentEffects']={New=function()Cost(3);return {}end}
modules['render.PartHitFlash']={New=function()return {Consume=Stub(2)}end}
hostile=setmetatable({}, {__pairs=function()error('observer traversed parts')end,
 __len=function()error('observer measured parts')end,__index=function()error('observer indexed parts')end})
function NewUnit(name)
 local unit={name=name,alive=true,parts=hostile,vehicle={Step=Stub(2),StepRotors=Stub(3)},
  weapons={Step=Stub(4)},Flush=Stub(1),bp={List=function()Cost(1);return {'a','b','c'}end}}
 unit.vehicle.mechControl={Step=Stub(1)};return unit
end
'''

CHECKS = r'''
local driveClass,viewClass=Drive,View
local originalNew,originalRebuild=Drive.New,View.Rebuild
local player=NewUnit('player');local enemies={NewUnit('one'),NewUnit('two'),NewUnit('three')}
local playerDrive=setmetatable({view=setmetatable({},View)},Drive)
local combatView=Combat.New({})
local combat={player=player,entries={{unit=player}},BeforeStep=function(self,dt)
 for _,entry in ipairs(self.entries)do
  if entry.driver then entry.driver:Step(dt)end
  entry.unit.vehicle:StepRotors(dt);entry.unit.vehicle:Step(dt);entry.unit.weapons:Step(dt)
 end
end,AfterStep=Stub(1),Update=Stub(1)}
for _,unit in ipairs(enemies)do combat.entries[#combat.entries+1]={unit=unit,driver={Step=Stub(6)}}end
local world={units={player,table.unpack(enemies)},viewEvents={},debris={events={}},fx={},Step=Stub(2),space={Step=Stub(1)}}
local trial={world=world,combat=combat,combatView=combatView,view=playerDrive,
 feedbackAudio={Consume=Stub(1)},restoreFlash={Consume=Stub(1)},hud={overlay={Consume=Stub(1)}},effects={Consume=Stub(2)},
 ConsumeWorldEvents=ConsumeWorldEvents}
local app={trial=trial}
local inherited=trial.ConsumeWorldEvents
local initialDriver=combat.entries[2].driver.Step
Check(not BATTLE.state().enabled,'Detailed observer defaults off')
BATTLE.ensure(app)
Check(Drive.New==originalNew and View.Rebuild==originalRebuild,'Default off leaves real constructor/rebuild classes untouched')
Check(trial.ConsumeWorldEvents==inherited and combat.entries[2].driver.Step==initialDriver,'Default off leaves actual instance chain untouched')
BATTLE.set(true);BATTLE.ensure(app)
Check(Drive.New~=originalNew and View.Rebuild~=originalRebuild,'F15 observer binds actual used metatables before first spawn')
Check(trial.ConsumeWorldEvents~=inherited,'Actual ConsumeWorldEvents bound before spawn')
local newWrapper,rebuildWrapper=Drive.New,View.Rebuild
for i=1,3 do world.viewEvents[i]={type='unitSpawn',unit=enemies[i]}end
trial:ConsumeWorldEvents()
for _,label in ipairs({'battle.Trial.ConsumeWorldEvents','battle.CombatView.Consume'})do
 Check(TIMING[label] and TIMING[label].calls==1,'First spawn actual parent captured: '..label)
end
Check(TIMING['battle.DriveView.New'].calls==3,'All three actual constructors captured in their first spawn frame')
Check(TIMING['battle.VehicleView.Rebuild'].calls==3,'All three actual rebuilds captured in their first spawn frame')
Check(TIMING['battle.VehicleView.Rebuild'].totalMs==54,'Actual deferred Rebuild loops retain controlled CPU cost before Bind surface submission')
Check(TIMING['battle.DriveView.New'].totalMs==93,'Actual DriveView.New includes its nested rebuild cost')
Check(TIMING['battle.CombatView.Consume'].totalMs==95,'Actual CombatView.Consume includes all first-spawn assembly')
Check(TIMING['battle.Trial.ConsumeWorldEvents'].totalMs==103,'Actual Trial event chain retains feedback/save/effect order and cost')
for _,unit in ipairs(enemies)do
 local drive=combatView.units[unit]
 Check(getmetatable(drive)==Drive and drive.vehicle==unit.vehicle,'Original real constructor self and vehicle retained: '..unit.name)
 Check(drive.view.bpBuilt==unit.bp and drive.view.added==3,'Original Rebuild executed all authored blueprint entries: '..unit.name)
end
Check(#world.viewEvents==0 and #world.fx==0,'Actual event ownership consumes and clears original arrays')
BATTLE.ensure(app)
Check(Drive.New==newWrapper and View.Rebuild==rebuildWrapper,'Repeated ensure never stacks class wrappers')
combat:BeforeStep(.016)
for _,label in ipairs({'battle.Player.Vehicle.StepRotors','battle.Player.Weapons.Step',
 'battle.Unit2.Driver.Step','battle.Unit2.Vehicle.StepRotors','battle.Unit2.Weapons.Step',
 'battle.Unit3.Driver.Step','battle.Unit4.Driver.Step','battle.Combat.BeforeStep'})do
 Check(TIMING[label] and TIMING[label].calls==1,'Actual control entry dispatch counted: '..label)
end
Check(TIMING['battle.Combat.BeforeStep'].totalMs==54,'Actual control parent remains inclusive of original driver/rotor/weapon calls')
local a,b,c,d=combat.entries[2].driver:Step('token')
Check(a=='token' and b==nil and c=='third' and d==false,'Driver wrapper preserves self, nil, false and four return slots')
Check(TIMING['battle.Unit2.Driver.Step'].maxMs==6,'Controlled driver CPU duration remains separate')
for i=1,3 do
 local unit=NewUnit('extra'..i);world.units[#world.units+1]=unit
 combat.entries[#combat.entries+1]={unit=unit,driver={Step=Stub(6)}}
end
local unsampled=combat.entries[6];local unsampledDriver=unsampled.driver.Step
local unsampledRotor,unsampledWeapons=unsampled.unit.vehicle.StepRotors,unsampled.unit.weapons.Step
BATTLE.ensure(app)
Check(BATTLE.state().sampledUnits==5,'Additional driver/weapon/rotor wrappers retain five-unit limit')
Check(unsampled.driver.Step==unsampledDriver and unsampled.unit.vehicle.StepRotors==unsampledRotor and
 unsampled.unit.weapons.Step==unsampledWeapons,'Sixth unit driver/rotor/weapon methods remain untouched')
local oldDriver=combat.entries[2].driver;local oldStep=oldDriver.Step
combat.entries[2].driver={Step=Stub(7)};local nextDriver=combat.entries[2].driver
BATTLE.ensure(app)
Check(oldDriver.Step==initialDriver and oldDriver.Step~=oldStep,'Replaced driver restores its own original method')
nextDriver:Step(.016);Check(TIMING['battle.Unit2.Driver.Step'].lastMs==7,'Replacement driver binds on next observer update')
local externalNew=function(...)return 'external',nil,'third',false end
Drive.New=externalNew;BATTLE.set(false)
Check(Drive.New==externalNew,'Disable preserves later externally replaced shared constructor')
Check(View.Rebuild==originalRebuild and trial.ConsumeWorldEvents==inherited,'Disable restores shared rebuild and instance event method')
Check(combat.entries[2].driver.Step~=oldStep,'Disable does not restore detached driver over replacement owner')
Drive.New=originalNew;BATTLE.set(true);BATTLE.ensure(app)
Check(Drive.New~=originalNew,'Re-enable binds real constructor again')
local checkpointCalls=0
local co=coroutine.create(function()
 local u=NewUnit('yielding');world.viewEvents={{type='unitSpawn',unit=u}}
 combatView:Consume(world,function()checkpointCalls=checkpointCalls+1;if checkpointCalls==1 then coroutine.yield('checkpoint')end end)
end)
local ok,why=coroutine.resume(co)
Check(ok and why=='checkpoint','Actual constructor/rebuild retain yieldable checkpoint semantics')
trial.disposed=true;BATTLE.ensure(app)
Check(Drive.New==originalNew and View.Rebuild==originalRebuild and BATTLE.state().boundMethods==0,'Disposed owner restores both shared classes while checkpoint suspended')
ok,why=coroutine.resume(co)
Check(ok and coroutine.status(co)=='dead' and checkpointCalls==6,'Suspended actual constructor completes original checkpoints after teardown')
Check(next(package.loaded)==nil,'No engine/module cache discovery or eager require added by observer')
Check(#messages==0,'Nested diagnostic calls remain quiet')
return {checks=checks,timing=TIMING}
'''


def execute(source):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(SETUP)
    lua.globals().View = lua.globals().LoadModule(INPUTS[3].read_text(encoding='utf-8'), 'render.VehicleView')
    lua.execute('''function View:init()Cost(2);self.added=0;self.joined={Update=Stub(2)};
 self.livery={Set=Stub(1),Update=Stub(2)}end
function View:Clear()Cost(1)end
function View:AddPart(part)Cost(5);self.added=self.added+1 end
local real=View.Rebuild
-- Preserve the actual Rebuild body; only retain its received blueprint for assertions.
function View:Rebuild(bp,checkpoint,deferSurfaces)self.bpBuilt=bp;return real(self,bp,checkpoint,deferSurfaces)end
''')
    lua.globals().Drive = lua.globals().LoadModule(INPUTS[2].read_text(encoding='utf-8'), 'render.DriveView')
    lua.execute('function Drive:Bind(bp,vehicle)Cost(4);self.vehicle=vehicle;self.view.joined:Update();self.view.livery:Update() end;function Drive:SavePose()Cost(1)end')
    lua.globals().Combat = lua.globals().LoadModule(INPUTS[1].read_text(encoding='utf-8'), 'render.CombatView')
    trial = INPUTS[4].read_text(encoding='utf-8')
    method = trial[trial.index('function M:ConsumeWorldEvents()'):trial.index('function M:Tick(', trial.index('function M:ConsumeWorldEvents()'))]
    lua.execute('M={};' + method + ';ConsumeWorldEvents=M.ConsumeWorldEvents')
    header = source[:source.index('VOX_SKIP_TUTORIAL=true')]
    lua.execute(header + '\nBATTLE={state=BattleTimingState,ensure=EnsureBattleTiming,set=SetBattleTiming};TIMING=updateTiming;package.loaded={}\n')
    result = lua.execute(CHECKS)
    return {'checks': list(result.checks.values()), 'timing': {label: dict(value) for label, value in result.timing.items()}}


def main():
    source = PROBE.read_text(encoding='utf-8')
    result = execute(source)
    previous = subprocess.run(['git', 'show', '48ef15f2:tools/migration/probe-outgame-web.lua'], cwd=ROOT,
                              capture_output=True, text=True, encoding='utf-8', check=True).stdout
    rejected = []
    candidates = [('real-main-48ef15f2', previous)]
    for label, before, after in [
        ('missing-consume', "Bind(trial,'ConsumeWorldEvents','battle.Trial.ConsumeWorldEvents')", ''),
        ('missing-constructor', "Bind(trial.view and getmetatable(trial.view),'New','battle.DriveView.New')", ''),
        ('missing-rebuild', "Bind(trial.view and trial.view.view and getmetatable(trial.view.view),'Rebuild','battle.VehicleView.Rebuild')", ''),
        ('missing-driver', "Bind(entry.driver,'Step',label..'.Driver.Step')", ''),
        ('missing-weapons', "Bind(unit.weapons,'Step',label..'.Weapons.Step')", ''),
        ('missing-rotors', "Bind(vehicle,'StepRotors',label..'.Vehicle.StepRotors')", ''),
        ('clobber-external-class', 'if binding.object[binding.method]==binding.wrapped then binding.object[binding.method]=binding.original end', 'binding.object[binding.method]=binding.original'),
    ]:
        assert before in source, label
        candidates.append((label, source.replace(before, after)))
    for label, candidate in candidates:
        try:
            execute(candidate)
        except Exception as error:
            rejected.append({'name': label, 'failure': str(error).splitlines()[0]})
        else:
            raise AssertionError('Negative control passed: ' + label)
    runner = subprocess.run(['node', '-e', RUNNER_CHECKS, str(RUNNER)], cwd=ROOT,
                            capture_output=True, text=True, encoding='utf-8', check=True)
    runner_result = json.loads(runner.stdout)
    subprocess.run(['node', '--check', str(RUNNER)], capture_output=True, text=True, check=True)
    report = {'result': 'PASS', **result, 'runner': runner_result, 'negativeControls': rejected, 'assembly': assembly_equivalence(),
              'inputs': {str(path.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(path.read_bytes()).hexdigest()
                         for path in [*INPUTS, RUNNER, Path(__file__), ROOT / 'scripts/render/RotorView.lua',
                                      ROOT / 'scripts/render/JoinedMesh.lua', ROOT / 'scripts/render/JoinedSurface.lua',
                                      ROOT / 'scripts/render/LiveryLayer.lua', ROOT / 'scripts/render/LiveryProjection.lua',
                                      ROOT / 'assets/Parts/JoinedShapes.json', ROOT / 'assets/Parts/Catalog.json', ROOT / 'assets/Livery/Catalog.json']},
              'boundary': 'Actual QA header and actual production ConsumeWorldEvents/CombatView.Consume/DriveView.New/VehicleView.Rebuild in Lua 5.4 with CPU scene/geometry/physics adapters. Deterministic inclusive wall cost only. Actual final JoinedMesh/Livery projection equivalence against frozen 188b production modules. No browser/GPU run or performance claim. Parts are only enumerated by the original Rebuild under test; observer unit.parts are hostile. Other instance wrappers discover new objects next update.'}
    output = ROOT / 'docs/migration/evidence/battle-spawn-timing-offline.json'
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    print(json.dumps({'result': 'PASS', 'checks': len(result['checks']), 'runnerChecks': len(runner_result['checks']), 'negativeControls': len(rejected), 'output': str(output)}))


if __name__ == '__main__':
    main()

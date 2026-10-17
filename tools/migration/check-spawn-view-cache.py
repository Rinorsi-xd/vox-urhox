"""Actual prebuilt visual ownership and same-frame spawn equivalence, CPU only."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

spec = importlib.util.spec_from_file_location('spawn_fixture', ROOT / 'tools/migration/check-battle-spawn-timing.py')
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)

SETUP = r'''
checks={};modelGets=0;rigBuilds=0;rebuilds=0;wall=0
function Check(value,label)assert(value,label);checks[#checks+1]=label end
Time={GetSystemTime=function()return wall end}
local vectors={};vectors.__index=vectors
function vectors.__sub(a,b)return Vector3(a.x-b.x,a.y-b.y,a.z-b.z)end
function vectors.__add(a,b)return Vector3(a.x+b.x,a.y+b.y,a.z+b.z)end
function vectors.__mul(a,b)return Vector3(a.x*b,a.y*b,a.z*b)end
Vector3=setmetatable({ZERO=setmetatable({x=0,y=0,z=0},vectors),UP={x=0,y=1,z=0},RIGHT={x=1,y=0,z=0},FORWARD={x=0,y=0,z=1}},
 {__call=function(_,x,y,z)return setmetatable({x=x,y=y,z=z},vectors)end})
Vector4=setmetatable({ZERO={x=0,y=0,z=0,w=0}},{__call=function(_,x,y,z,w)return {x=x,y=y,z=z,w=w}end})
function Color(r,g,b,a)return {r=r,g=g,b=b,a=a or 1}end
local previousResource=cache.GetResource
function cache:GetResource(kind,name)
 local value=previousResource(self,kind,name)
 if kind=='Model'then
  modelGets=modelGets+1
  value.boundingBox=value.boundingBox or {min=Vector3(-1,-1,-1),max=Vector3(1,1,1)}
  function value:SetBoundingBox(box)self.boundingBox=box end
 end
 return value
end
function BoundingBox(a,b)return {min=a.min or a,max=a.max or b}end
local baseNode=Node
function Node()
 local n=baseNode();n.components={};n.position=Vector3.ZERO;n.rotation=Quaternion.IDENTITY;n.scale=1
 function n:CreateChild(name)local child=Node();child.name=name;child.parent=self;self.children[#self.children+1]=child;return child end
 function n:SetParent(parent)
  if self.parent then for i,c in ipairs(self.parent.children)do if c==self then table.remove(self.parent.children,i);break end end end
  self.parent=parent;parent.children[#parent.children+1]=self
 end
 local component=n.CreateComponent
 function n:CreateComponent(kind)
  local g=component(self);g.kind=kind;g.materials={};self.components[#self.components+1]=g
  function g:SetMaterial(index,material)if material==nil then self.material=index else self.materials[index]=material end end
  local commit=g.Commit
  function g:Commit()if failCommit then error('injected native Commit failure')end;return commit(self)end
  return g
 end
 function n:Dispose()
  if self.disposed then return end;self.disposed=true
  for _,child in ipairs(self.children)do child:Dispose()end
 end
 return n
end
local materialNew=Material.new
Material.new=function(...)
 local m=materialNew(...)
 function m:Clone()local out=Material:new();for k,v in pairs(self.params)do out.params[k]=v end;return out end
 return m
end
modules['parts.Materials'].Get=function(slot,instanced)return slot..':'..tostring(instanced)end
modules['parts.Materials'].New=function(shader)local m=Material:new();m:SetSurfaceShader(shader);return m end
modules['parts.Materials'].DynamicEmission=function(slot)return 'emission:'..slot end
modules['render.WeaponView']={}
modules['render.PartHitFlash']={New=function()return {Consume=function()end,Dispose=function()end}end}
-- Device selection is outside this assembly-only fixture; fail if it is used.
modules['controls.TouchMode']=setmetatable({},{__index=function(_,key)error('Unexpected touch policy access: '..key)end})
modules['urhox-libs.Platform.PlatformUtils']={IsDesktopPlatform=function()return true end}
function GetArguments()return {}end
local nativeRequire=require
require=function(name)
 if modules[name] then return modules[name]end
 local source=ReadModule(name)
 local value=assert(load(source,'@scripts/'..name:gsub('%.','/')..'.lua'))()
 modules[name]=value;return value
end
for _,name in ipairs({'core.Math3','parts.PartAssets','render.PartRig','render.ShellMaterials'})do modules[name]=nil end
local Assets=require 'parts.PartAssets';local Rig=require 'render.PartRig';local build=Rig.Build
function Rig.Build(...)rigBuilds=rigBuilds+1;wall=wall+1;return build(...)end
View=require 'render.VehicleView';local rebuild=View.Rebuild
function View:Rebuild(...)rebuilds=rebuilds+1;return rebuild(self,...)end
Drive=require 'render.DriveView';function Drive:Update()end
Cache=require 'render.SpawnViewCache';Combat=require 'render.CombatView';BP=require 'construction.Blueprint'
function Source()
 return {v=1,sizeVersion=1,name='fixture',parts={
  {'cube',0,0,0,0,0x123456,cjson.null,1}, {'cube',1,0,0,0,0x654321,cjson.null,1},
  {'core',100,0,0,0,0x556677}, {'steer3',200,0,0,0,0x777777},
  {'track2',300,0,0,0,0x555555}, {'mg3',400,0,0,0,0x223344}},
  livery={{s='burst',p={.5,1,0},n={0,1,0},r=.3,w=4,c={0x123456,0xabcdef}}}}
end
function Specification(bp,rotor)
 local ids={};for _,p in ipairs(bp:List())do ids[#ids+1]=p.id end
 return {ok=true,partIds=ids,rotorOf=rotor and {[2]=1}or {},wings={},legs={},mechLegs={}}
end
function Vehicle(bp,rotor)
 return {native={position=Vector3.ZERO,rotation=Quaternion.IDENTITY},wheels={},spec=Specification(bp,rotor),rotors={}}
end
function Tree(node)
 local out={name=node.name,position=node.position,rotation=node.rotation,scale=node.scale,enabled=node.enabled,components={},children={}}
 for i,g in ipairs(node.components)do
  local slots={};for k,m in pairs(g.materials)do slots[k]=type(m)=='table'and {shader=m.shader,params=m.params}or m end
  out.components[i]={kind=g.kind,model=g.model and g.model.name,materials=slots,color=g.instanceColor,custom=g.instanceCustomData,shadow=g.castShadows}
 end
 for i,child in ipairs(node.children)do if not child.disposed then out.children[i]=Tree(child)end end
 return out
end
function FullSnapshot(view)
 return Snapshot(view)..Canon(Tree(view.root))
end
function AssertFreed(scene)
 for _,node in ipairs(nodes)do if node~=scene then Check(node.disposed,'All owned native nodes released')end end
 for _,material in ipairs(materials)do Check(material.disposed,'All private material handles released')end
end
'''

CASES = r'''
local source=Source();local bp=BP.New():Load(source);local scene=Node();local spec=Specification(bp,withRotor)
local cache=Cache.New(scene,{limit=8})
local checkpoints,lastProgress=0,0
Check(cache:Prepare(source,spec,3,function(p)assert(p>=lastProgress);lastProgress=p;checkpoints=checkpoints+1 end)==3,'Three exact complete assemblies prepared')
Check(cache.count==3 and checkpoints>3,'Preparation calls per-part loading checkpoints')
Check(lastProgress==1,'Actual multi-copy progress is monotonic and reaches one')
Check(cache:Prepare(source,spec,3)==0,'Requested peak copies does not duplicate existing pool')
for _,entry in ipairs(cache.entries[next(cache.entries)])do Check(not entry.root.enabled,'Cached assemblies cannot draw')end
local beforeGets,beforeRigs,beforeRebuilds=modelGets,rigBuilds,rebuilds
local units={};local world={viewEvents={},debris={events={}}}
local combat=Combat.New(scene,cache)
for i=1,3 do
 local fresh=BP.New():Load(source);local unit={alive=true,bp=fresh,vehicle=Vehicle(fresh,withRotor)}
 units[i]=unit;world.viewEvents[i]={type='unitSpawn',unit=unit}
end
combat:Consume(world)
Check(cache.count==0 and cache.hits==3,'Actual CombatView takes all three assemblies in original event batch')
Check(modelGets==beforeGets and rigBuilds==beforeRigs and rebuilds==beforeRebuilds,'Actual first spawn performs no native model request, PartRig.Build or VehicleView.Rebuild')
Check(#world.viewEvents==0,'Original event batch is consumed synchronously')
local snapshots={}
for i,unit in ipairs(units)do
 local drive=combat.units[unit];Check(drive and drive.vehicle==unit.vehicle,'Same-frame live native vehicle is bound')
 Check(drive.view.root.parent==scene and drive.view.root.enabled,'Complete car is visible at original spawn pose')
 for _,part in ipairs(unit.bp:List())do Check(drive.view.visuals[part.id].part==part,'Real damage part identity replaces template reference')end
 Check(drive.view.livery.list==unit.bp.livery,'Live livery ownership replaces prepared blueprint')
 snapshots[i]=FullSnapshot(drive.view)
end
Check(combat.units[units[1]].view.visuals[6].weaponMotion~=combat.units[units[2]].view.visuals[6].weaponMotion,'Weapon motion and private materials are never shared across cars')
local active=combat.units[units[1]].view.root
cache:Dispose();cache:Dispose();Check(not active.disposed,'Cache unload never disposes transferred live car')
combat:Dispose();AssertFreed(scene)
return {checks=checks,snapshots=snapshots,preparationRigs=beforeRigs,spawnRigs=rigBuilds-beforeRigs,spawnModels=modelGets-beforeGets}
'''

LIFECYCLE = r'''
local source=Source();local bp=BP.New():Load(source);local spec=Specification(bp);local scene=Node();local cache=Cache.New(scene,{limit=case=='limit'and 99 or 8})
if case=='limit'then
 local previous=0
 Check(cache:Prepare(source,spec,99,function(p)assert(p>=previous);previous=p end)==8 and cache.count==8,'Global cache budget is hard limited to eight')
 Check(previous==1,'Partial-budget preparation progress still reaches one')
 Check(cache:Prepare(source,spec,99)==0,'Budget does not grow on repeat preparation')
elseif case=='signature'then
 cache:Prepare(source,spec,1)
 local changes={
  function(p)p.parts[1].color=p.parts[1].color+1 end,
  function(p)p.parts[1].shellColor=0x102030 end,
  function(p)p.parts[1].g=2 end,
  function(p)p.parts[1].rot=1 end,
  function(p)p.parts[1].pos[1]=3 end,
  function(p)p.parts[1].type='slope'end,
  function(p)p.livery[1].c[1]=0x000001 end,
  function(p)p.livery[1].w=9 end,
  function(p)local part=p.parts[1];p.parts[1]=nil;p.parts[9]=part;part.id=9 end,
 }
 for _,change in ipairs(changes)do local other=BP.New():Load(source);change(other);Check(cache:Take(other)==nil,'Any visual signature mutation takes original path')end
 local named=BP.New():Load(source);named.name='renamed';local view=cache:Take(named);Check(view~=nil,'Unrelated display name does not invalidate identical visuals');view:Dispose()
elseif case=='prune'then
 spec.partIds={1,2,3,4,6};cache:Prepare(source,spec,1)
 Check(cache:Take(bp)==nil,'Unpruned blueprint cannot consume filtered template')
 bp:Remove(5);local view=cache:Take(bp);Check(view and not view.visuals[5],'Pruning preserves exact original IDs and kept parts');view:Dispose()
elseif case=='cancel'then
 local co=coroutine.create(function()cache:Prepare(source,spec,2,function()coroutine.yield()end)end)
 Check(coroutine.resume(co),'Loading coroutine can suspend during actual Rebuild')
 local pending=cache.pending;Check(pending and pending.view and cache.count==1,'Half-built candidate retained before first checkpoint')
 cache:Dispose();Check(pending.root.disposed and pending.view==nil,'Cancel releases partially assembled candidate')
 Check(coroutine.close(co),'Canceled construction coroutine closes')
elseif case=='cancel-resume'then
 local co=coroutine.create(function()cache:Prepare(source,spec,2,function()coroutine.yield()end)end)
 assert(coroutine.resume(co));cache:Dispose();local ok,err=coroutine.resume(co)
 Check(not ok and tostring(err):find('preparation canceled'),'Resuming canceled construction cannot touch freed nodes')
elseif case=='prepare-error'then
 local ok,err=pcall(function()cache:Prepare(source,spec,2,function()error('checkpoint failure')end)end)
 Check(not ok and tostring(err):find('checkpoint failure'),'Loading exception is preserved')
 Check(cache.pending==nil and cache.count==0,'Failed candidate is removed from cache ownership')
elseif case=='bind-error'then
 cache:Prepare(source,spec,1);local view=cache:Take(bp);failCommit=true
 local retained;local ok,err=pcall(function()Drive.New(scene,bp,Vehicle(bp,true),nil,function(v)retained=v end,view)end)
 Check(not ok and tostring(err):find('native Commit failure'),'Original native Commit failure propagates')
 Check(retained and retained.disposed and view.root.disposed,'Taken candidate releases all ownership when Bind fails')
 retained:Dispose();failCommit=false
elseif case=='rig-error'then
 local original=cache.GetResource
 local resource=modules['parts.PartAssets'].Model
 modules['parts.PartAssets'].Model=function(layer)
  local value=resource(layer);if modelGets>=3 then error('part model failure')end;return value
 end
 local ok,err=pcall(function()cache:Prepare(source,spec,1)end)
 Check(not ok and tostring(err):find('part model failure'),'Native rig construction error propagates')
 Check(cache.count==0 and cache.pending==nil,'Partial rig and cache candidate retire after failure')
elseif case=='fallback'then
 local unit={alive=true,bp=bp,vehicle=Vehicle(bp)};local world={viewEvents={{type='unitSpawn',unit=unit}},debris={events={}}}
 local combat=Combat.New(scene,cache);combat:Consume(world)
 Check(cache.misses==1 and rigBuilds>0 and rebuilds==1,'Missing template executes unchanged complete synchronous constructor')
 combat:Dispose()
end
cache:Dispose();Check(cache.count==0 and cache:Take(bp)==nil,'Disposed cache remains empty and unavailable');AssertFreed(scene)
return checks
'''


def runtime(cache_source=None, overrides=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(fixture.ASSEMBLY_SETUP)
    null = lua.globals().cjson.null

    def convert(value):
        if value is None:
            return null
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value

    lua.globals().ReadData = lambda path: convert(json.loads((ROOT / 'assets' / path).read_text(encoding='utf-8')))

    def module(name):
        if overrides and name in overrides:
            return overrides[name]
        if name == 'render.SpawnViewCache' and cache_source:
            return cache_source
        return (ROOT / 'scripts' / (name.replace('.', '/') + '.lua')).read_text(encoding='utf-8')

    lua.globals().ReadModule = module
    lua.execute(SETUP)
    return lua


MISSION = r'''
local scene=Node();local source=Source();local blueprint=BP.New():Load(source)
blueprint.Stats=function()return {fitTier={id=2}}end
local builds=0;local physical=modules['drive.VehicleSpec']
physical.Build=function(bp,checkpoint)
 builds=builds+1;if checkpoint then checkpoint()end;return Specification(bp)
end
local levels=require('story.MissionData');local arena=require('combat.ArenaData')
modules['combat.CarUnit']={New=function(_,source,opts)
 local unit={alive=true,bp=BP.New():Load(source),spec={bounds={min={0,0,0},max={1,1,1}}},pos={0,0,0},spawnAt=opts.spawn,
  vehicle={Place=function()end},SavePose=function(self)self.current={}end,Dispose=function()end}
 return unit
end}
modules['combat.EnemyDriver']={}
local function Owner()return {Dispose=function()end}end
modules['story.MissionRules']={New=function()return {time=0}end}
modules['ui.MissionObjective']={New=Owner};modules['ui.MissionChoiceState']={New=Owner}
modules['story.MissionTimers']={New=Owner};modules['audio.StoryComms']={New=Owner};modules['audio.StoryRadio']={New=Owner}
modules['render.MissionView']={New=function()
 return {AlarmOff=function()end,AddIntel=function()end,AddSite=function()end,Collector=function()end,Dispose=function()end}
end}
modules['render.SalvageExplosion']={New=function(_,_,options)
 local result=Owner();if options.retain then options.retain(result)end
 if options.checkpoint then options.checkpoint(1)end;return result
end}
for _,name in ipairs({'parts.Dependencies','combat.StoryBoss','ui.Epilogue','render.StoryStomp',
 'combat.DrillRaiderDriver','combat.DriverActions','drive.RotorMotion','story.EnemyRules','combat.PlayerViewSync'})do
 local dependency=name
 modules[name]=setmetatable({},{__index=function(_,key)error('Unexpected non-preparation dependency: '..dependency..'.'..key)end})
end
local Mission=require 'story.Mission'
local level={steps={
 {enemies={{source=source},{source=source},{role='heavy'}},role='assault'},
 {guards={{source=source},{source=source}},counter={{role='heavy'},{role='heavy'}}},
 {beats={{spawn={{role='sniper'},{role='sniper'}}},{spawn={{source=source},{source=source},{source=source},{source=source}}}}},
}}
local mission=setmetatable({session={scene=scene},tier=1,level=level,entries={},world={units={}}},Mission)
if missionCase=='ordered'then
 local previous=0;local yielded=0;local co=coroutine.create(function()
  mission:PrepareSpawnSpecs(function(p)Check(p>=previous,'Actual Mission preparation progress never goes backwards');previous=p;yielded=yielded+1;coroutine.yield()end,true)
 end)
 while coroutine.status(co)~='dead'do local ok,err=coroutine.resume(co);assert(ok,err)end
 Check(yielded>8 and previous==1,'Actual Mission callback can yield across cache and physical preparation')
 Check(mission.spawnViewCache.count==8,'Actual Mission preparation respects global eight-car budget')
 local copy=BP.New():Load(source);for i=1,4 do local view=mission.spawnViewCache:Take(copy);Check(view~=nil,'Later source peak preserves first-source priority');view:Dispose()end
 local heavy=BP.New():Load(arena.prefabs['red:1:heavy:0'])
 for i=1,2 do local view=mission.spawnViewCache:Take(heavy);Check(view~=nil,'Actual guard/counter peak reserves two heavy assemblies');view:Dispose()end
 local sniper=BP.New():Load(arena.prefabs['red:1:sniper:0'])
 for i=1,2 do local view=mission.spawnViewCache:Take(sniper);Check(view~=nil,'Actual beat source reserves remaining two assemblies');view:Dispose()end
elseif missionCase=='no-checkpoint'then
 mission:PrepareSpawnSpecs(nil,true);Check(mission.spawnSpecCache and not mission.spawnViewCache,'No loading checkpoint leaves original physical-only construction')
elseif missionCase=='opt-out'then
 mission:PrepareSpawnSpecs(function()end,false);Check(not mission.spawnViewCache,'Non-explicit visual preparation remains disabled')
elseif missionCase=='cancel'then
 local co=coroutine.create(function()
  mission:PrepareSpawnSpecs(function()if mission.spawnViewCache then coroutine.yield()end end,true)
 end)
 assert(coroutine.resume(co));local cache=mission.spawnViewCache
 Check(cache and cache.pending,'Actual Mission owns half-built visual before loading yields')
 mission:Dispose();Check(cache.disposed and cache.count==0 and not mission.spawnViewCache,'Actual Mission.Dispose releases unfinished cache')
 assert(coroutine.close(co))
elseif missionCase=='new'then
 local session={scene=scene,map={storyLevel=4},world={units={},layout={nav={}}},touch=false,effects={}}
 local retained;local ticks=0;local co=coroutine.create(function()
  Mission.New(session,blueprint,{prepareViews=true,retain=function(value)retained=value end,
   checkpoint=function()ticks=ticks+1;coroutine.yield()end})
 end)
 while coroutine.status(co)~='dead'do local ok,err=coroutine.resume(co);assert(ok,err)end
 Check(retained and retained.spawnViewCache and retained.spawnViewCache.count>0,'Actual Mission.New connects explicit visual preparation with loading checkpoint')
 Check(ticks>1,'Actual Mission.New remains yieldable through view construction')
 retained:Dispose()
end
mission:Dispose();AssertFreed(scene);return checks
'''


def main():
    checks = []
    comparisons = []
    for rotor in [False, True]:
        lua = runtime()
        lua.globals().withRotor = rotor
        cached = lua.execute(CASES)
        checks.extend(cached.checks.values())
        snapshot = ROOT / '.tmp/outgame-cached-1792139145715'
        identity = json.loads((snapshot / 'identity.json').read_text(encoding='utf-8'))['identity']
        old_names = ['render.DriveView', 'render.VehicleView', 'render.PartRig']
        old_sources = {name: (snapshot / 'scripts' / (name.replace('.', '/') + '.lua')).read_text(encoding='utf-8') for name in old_names}
        for name in old_names:
            assert hashlib.sha256(old_sources[name].encode()).hexdigest() == identity['scripts'][name.replace('.', '/') + '.lua']
        comparison = runtime(overrides=old_sources)
        comparison.globals().withRotor = rotor
        original = comparison.execute(r'''
local source=Source();local bp=BP.New():Load(source);local scene=Node()
local drive=Drive.New(scene,bp,Vehicle(bp,withRotor));local result=FullSnapshot(drive.view)
drive:Dispose();AssertFreed(scene);return result
''')
        assert all(snapshot == original for snapshot in cached.snapshots.values()), 'Final authored rig, geometry, material, livery or node state differs'
        comparisons.append({'rotor': rotor, 'copies': 3, 'preparationRigBuilds': cached.preparationRigs,
                            'spawnRigBuilds': cached.spawnRigs, 'spawnNativeModels': cached.spawnModels, 'exactVisualState': True})
    cases = ['limit', 'signature', 'prune', 'cancel', 'cancel-resume', 'prepare-error', 'bind-error', 'rig-error', 'fallback']
    for name in cases:
        lua = runtime()
        lua.globals().case = name
        checks.extend(lua.execute(LIFECYCLE).values())
    mission_cases = ['ordered', 'no-checkpoint', 'opt-out', 'cancel', 'new']
    for name in mission_cases:
        lua = runtime()
        lua.globals().missionCase = name
        checks.extend(lua.execute(MISSION).values())
    rejected = []
    for label, module, before, after, script, case in [
        ('missing-live-consumption', 'render.CombatView', 'self.spawnCache and self.spawnCache:Take(e.unit.bp)', 'nil', CASES, None),
        ('missing-live-part-adoption', 'render.DriveView', 'vis.part=p;', '', CASES, None),
        ('missing-partial-release', 'render.SpawnViewCache', 'if self.pending then Retire(self.pending);self.pending=nil end', 'self.pending=nil', LIFECYCLE, 'cancel'),
        ('missing-hard-budget', 'render.SpawnViewCache', 'math.min(8,math.floor(options.limit or 8))', 'math.floor(options.limit or 8)', LIFECYCLE, 'limit'),
        ('missing-color-signature', 'render.SpawnViewCache', 'p.rot,p.color,p.shellColor', 'p.rot,0,p.shellColor', LIFECYCLE, 'signature'),
    ]:
        path = ROOT / 'scripts' / (module.replace('.', '/') + '.lua')
        source = path.read_text(encoding='utf-8')
        assert before in source, label
        lua = runtime(overrides={module: source.replace(before, after)})
        lua.globals().case = case
        lua.globals().withRotor = False
        try:
            lua.execute(script)
        except Exception as error:
            rejected.append({'name': label, 'failure': str(error).splitlines()[0]})
        else:
            raise AssertionError('Negative control passed: ' + label)
    inputs = ['scripts/render/SpawnViewCache.lua', 'scripts/render/CombatView.lua', 'scripts/render/DriveView.lua',
              'scripts/render/VehicleView.lua', 'scripts/render/PartRig.lua', 'scripts/render/RotorView.lua',
              'scripts/render/WeaponPresentation.lua', 'scripts/render/WeaponMotion.lua',
              'scripts/render/JoinedMesh.lua', 'scripts/render/JoinedSurface.lua', 'scripts/render/LiveryLayer.lua',
              'scripts/render/LiveryProjection.lua', 'scripts/construction/Blueprint.lua', 'scripts/construction/BlueprintMigration.lua',
              'scripts/story/Mission.lua','scripts/app/TrialSession.lua',
              'tools/migration/check-spawn-view-cache.py', 'tools/migration/check-battle-spawn-timing.py']
    report = {'result': 'PASS', 'checks': checks, 'comparisons': comparisons, 'lifecycleCases': cases,'missionCases':mission_cases,'negativeControls':rejected,
              'inputs': {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in inputs},
              'boundary': 'Actual Lua SpawnViewCache, CombatView, DriveView Bind, VehicleView, PartRig, PartAssets, WeaponMotion/Presentation, RotorView, Blueprint and final joined/livery projection execute. Native objects/material API and actuator/update backends are controlled. Exact complete visual state equals the ordinary constructor; no delayed unit or gameplay change. No GPU shader coverage, first-spawn Web latency, memory budget or mobile acceptance.'}
    output = ROOT / 'docs/migration/evidence/spawn-view-cache-offline.json'
    output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'result': 'PASS', 'checks': len(checks), 'comparisons': comparisons, 'lifecycleCases': len(cases), 'negativeControls':len(rejected)}))


if __name__ == '__main__':
    main()

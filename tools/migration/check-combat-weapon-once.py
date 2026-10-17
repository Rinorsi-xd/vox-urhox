"""Actual Lua consumers and authored rigs; native drawing is a counted test double."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

parser = argparse.ArgumentParser()
parser.add_argument('--benchmark', action='store_true')
parser.add_argument('--output', type=Path)
args = parser.parse_args()
lua = LuaRuntime(unpack_returned_tuples=True)


def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value


sources = {}
for name in ('VehicleView', 'CombatView', 'WeaponView', 'WeaponPresentation', 'WeaponMotion'):
    sources[name] = (ROOT / f'scripts/render/{name}.lua').read_text(encoding='utf-8')
assert 'skipWings,skipWeapons)' in sources['VehicleView']
assert 'vis.weaponMotion and not skipWeapons' in sources['VehicleView']
assert sources['CombatView'].count('true,unit.weapons~=nil)') == 1
profiles = json.loads((ROOT / 'assets/Parts/WeaponMotion.json').read_text(encoding='utf-8'))
rigs = {k: json.loads((ROOT / f'assets/Parts/Rigs/{k}.json').read_text(encoding='utf-8'))
        for k in profiles if k.startswith(('mg', 'laser', 'missile', 'sniper'))}
lua.globals().PROFILES = table(profiles)
lua.globals().RIGS = table(rigs)
lua.globals().SOURCES = table(sources)
lua.globals().BENCHMARK = args.benchmark
lua.execute("package.path='scripts/?.lua;?.lua;'..package.path")
result = lua.execute(r'''
local packages={
 'render.JoinedMesh','render.LiveryLayer','render.WingRig','render.ShellMaterials',
 'render.BuildXray','render.WeaponEffects','parts.Defs','parts.PartAssets',
 'render.JoinedSurface','render.RotorDisc','render.DriveView','render.PartHitFlash','parts.Materials'}
for _,name in ipairs(packages)do package.loaded[name]={}end
package.loaded['core.Coord']={Vec=function(...)return {...}end}
package.loaded['core.ResourceData']={Read=function(path)assert(path=='Parts/WeaponMotion.json');return PROFILES end}
package.loaded.Config={CELL=1}
package.loaded['parts.Defs']={DATA={materials={}}}
package.loaded['render.PartRig']={SetWeapon=function(vis)vis.turretCalls=vis.turretCalls+1 end}
local Motion=assert(load(SOURCES.WeaponMotion,'@scripts/render/WeaponMotion.lua'))()
package.loaded['render.WeaponMotion']=Motion
local Presentation=assert(load(SOURCES.WeaponPresentation,'@scripts/render/WeaponPresentation.lua'))()
Presentation.Apply=function(vis)vis.applyCalls=vis.applyCalls+1 end
package.loaded['render.WeaponPresentation']=Presentation
local Weapon=assert(load(SOURCES.WeaponView,'@scripts/render/WeaponView.lua'))()
package.loaded['render.WeaponView']=Weapon
local View=assert(load(SOURCES.VehicleView,'@scripts/render/VehicleView.lua'))()
package.loaded['render.VehicleView']=View
local Combat=assert(load(SOURCES.CombatView,'@scripts/render/CombatView.lua'))()
local oldSource,n=SOURCES.CombatView:gsub('true,unit%.weapons~=nil%)','true)')
assert(n==1,'exact previous consumer reconstruction')
local OldCombat=assert(load(oldSource,'@before/CombatView.lua'))()
local checks,cases,negative=0,0,0
local function equal(a,b,path)
 checks=checks+1;assert(type(a)==type(b),path..' type')
 if type(a)=='table'then
  for k,v in pairs(a)do equal(v,b[k],path..'.'..tostring(k))end
  for k in pairs(b)do assert(a[k]~=nil,path..' extra')end
 elseif type(a)=='number'then assert(string.pack('d',a)==string.pack('d',b),path..' numeric bits')
 else assert(a==b,path..' value')end
end
local excluded={data=true,parts=true,random=true}
local function snapshot(m)
 local out={};for k,v in pairs(m)do if not excluded[k]then out[k]=v end end;return out
end
local function make(kind,seed,armed)
 local counter={n=0,seed=seed}
 local function random()counter.n=counter.n+1;counter.seed=(counter.seed*48271)%2147483647;return counter.seed/2147483647 end
 local motion=Motion.New(kind,RIGS[kind],PROFILES[kind],random)
 local vis={weaponMotion=motion,rig={head={}},turretCalls=0,applyCalls=0}
 local counts={joined=0,livery=0,pose=0,idleFx=0,hit=0}
 local view=setmetatable({visuals={[1]=vis},joined={Update=function()counts.joined=counts.joined+1 end},
  livery={Update=function()counts.livery=counts.livery+1 end}},View)
 view.UpdateWeaponEffects=function()counts.idleFx=counts.idleFx+1 end
 local drive={view=view,Update=function()counts.pose=counts.pose+1 end}
 local w={id=1,charge=1,windup=0,spin=0,spinRate=0,spinAngle=0,prevYaw=0,yaw=0,prevPitch=0,pitch=0,
  barrel=1,shotAt=0,open=0,lock=0,tubes={true,true},mphase='ready',reload=1}
 local system={groups={{weapons={w}}},drill={Latched=function()return false end},offline=false}
 local unit={weapons=armed and system or nil}
 local combat=setmetatable({units={[unit]=drive},pieces={},hitFlash={Update=function()counts.hit=counts.hit+1 end}},Combat)
 return {motion=motion,vis=vis,view=view,drive=drive,unit=unit,combat=combat,w=w,system=system,rng=counter,counts=counts}
end
local function state(x,frame)
 local w=x.w;w.charge=(frame%45)/44;w.windup=(frame%17)/16;w.spin=(frame%31)/30
 w.spinRate=w.spin*25;w.spinAngle=frame*.2;w.shotAt=frame//7;w.barrel=frame%2+1
 w.open=(frame%23)/22;w.lock=(frame%19)/18;w.mphase=frame%40<20 and 'reload' or 'ready';w.reload=(frame%20)/19
 w.readyAt=frame%40==20 and frame/60 or -9;w.tubes={frame%13<8,frame%11<7};x.system.offline=frame%80>=60
end
local function reference(x,frame,dt,time,armed)
 state(x,frame)
 if armed then x.motion:SetState(x.w,time,x.system)end
 x.motion:Update(time,dt)
end
local function candidate(x,frame,dt,time,mode)
 state(x,frame)
 if mode=='hall'then x.view:UpdateIdle(dt,time)
 else x.combat:Update(.5,dt,{time=time})end
end
local modes={'armed','unarmed','hall'}
local dts={0,1/120,1/60,1/30,.1}
local kinds={};for k in pairs(RIGS)do kinds[#kinds+1]=k end;table.sort(kinds)
for _,kind in ipairs(kinds)do for _,dt in ipairs(dts)do for _,mode in ipairs(modes)do
 local a,b=make(kind,1729,mode=='armed'),make(kind,1729,mode=='armed')
 for frame=1,96 do
  local time=frame*dt
  reference(a,frame,dt,time,mode=='armed');candidate(b,frame,dt,time,mode)
  equal(snapshot(a.motion),snapshot(b.motion),kind..'.'..mode..'.'..frame)
  assert(a.rng.n==b.rng.n and a.rng.seed==b.rng.seed,'exact single-pass RNG sequence')
  assert(b.vis.applyCalls==frame,'one material/pose application')
  assert(b.vis.turretCalls==(mode=='armed'and frame or 0),'single armed turret call')
  assert(b.counts.joined==frame and b.counts.livery==frame,'idle surfaces retained')
  if mode~='hall'then assert(b.counts.pose==frame and b.counts.idleFx==frame and b.counts.hit==frame,'other combat consumers retained')end
 end;cases=cases+1
end end end
for _,kind in ipairs(kinds)do
 local a,b=make(kind,1729,true),make(kind,1729,true);setmetatable(b.combat,OldCombat)
 for frame=1,96 do reference(a,frame,1/60,frame/60,true);candidate(b,frame,1/60,frame/60,'armed')end
 assert(b.vis.applyCalls==192 and b.vis.turretCalls==96,'previous consumer advances twice')
 assert(a.motion.flowPhase~=b.motion.flowPhase,'negative control detects double integration');negative=negative+1
end
local benchmark={}
if BENCHMARK then
 -- Lupa CPU microbenchmark only: actual Motion/consumer code, counted drawing
 -- doubles, normal GC. This is not a Web/Native rendered FPS measurement.
 local function run(label)
  collectgarbage('restart');collectgarbage('collect');assert(collectgarbage('isrunning'))
  local xs={};for car=1,8 do for _,kind in ipairs(kinds)do local x=make(kind,1729+car,true)
   if label=='A'then setmetatable(x.combat,OldCombat)end;xs[#xs+1]=x end end
  for frame=1,60 do for _,x in ipairs(xs)do candidate(x,frame,1/60,frame/60,'armed')end end
  local t=os.clock()
  for frame=61,420 do for _,x in ipairs(xs)do candidate(x,frame,1/60,frame/60,'armed')end end
  local seconds=os.clock()-t;local rng,applications,turrets=0,0,0
  for _,x in ipairs(xs)do rng=rng+x.rng.n;applications=applications+x.vis.applyCalls;turrets=turrets+x.vis.turretCalls end
  return {variant=label,seconds=seconds,frames=360,weapons=#xs,rngCalls=rng,applications=applications,turrets=turrets,normalGc=collectgarbage('isrunning')}
 end
 for i,label in ipairs({'A','B','B','A'})do benchmark[i]=run(label)end
end
return {cases=cases,checks=checks,negative=negative,kinds=kinds,benchmark=benchmark}
''')


def python(value):
    if hasattr(value, 'items'):
        items = list(value.items())
        if items and all(isinstance(k, int) for k, _ in items):
            return [python(value[k]) for k in range(1, len(items) + 1)]
        return {k: python(v) for k, v in items}
    return value


baseline = 'b276064942ae09c0227ec28d4cfda1d5ff006455'
h5_paths = ('three/src/drive/carVisual.js', 'three/src/build/vehicleView.js')
h5 = {}
for path in h5_paths:
    source = subprocess.check_output(['git', '-c', 'safe.directory=D:/Rino_Project/Vox', 'show', f'{baseline}:{path}'], cwd='D:/Rino_Project/Vox')
    h5[path] = {'sha256': hashlib.sha256(source).hexdigest()}
    text = source.decode('utf-8')
    if path.endswith('carVisual.js'):
        assert text.count('for ( const t of this.turretObjs ) t.rig?.setState( t.w, time, this.weapons );') == 1
        assert text.count('this.view.update( time );') == 1
        h5[path]['consumer'] = 'setState once, main VehicleView.update once, then _turrets'
    else:
        assert text.count('for ( const r of this.rigs.values() ) r.update( t, dt );') == 1
        h5[path]['consumer'] = 'each rig.update once per VehicleView.update'
report = {'status': 'PASS_ACTUAL_LUA_CONSUMERS', **python(result), 'h5Commit': baseline, 'h5': h5,
          'sourceSha256': {k: hashlib.sha256(v.encode()).hexdigest() for k, v in sources.items()},
          'boundary': 'Actual Lua consumers, WeaponMotion, authored profiles/rigs, exact one-pass state and RNG; native pose/material/geometry calls are counted doubles. H5 call structure verified at frozen commit, not numerical H5/Lua cross-engine equality. Optional Lupa CPU microbenchmark is not Web/Native/mobile FPS.'}
serialized = json.dumps(report, indent=2, ensure_ascii=False)
if args.output:
    with args.output.open('x', encoding='utf-8') as output:
        output.write(serialized + '\n')
print(serialized)

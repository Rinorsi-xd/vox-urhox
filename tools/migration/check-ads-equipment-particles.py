"""Check proposed ADS ownership filtering using actual Lua modules, offline only."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().READ_SOURCE = lambda path: (ROOT / path).read_text(encoding='utf-8-sig')
result = lua.execute(r'''
local noop=function()end
local function Vec3(x,y,z)return {x=x,y=y,z=z}end
Vector3=setmetatable({RIGHT=Vec3(1,0,0),UP=Vec3(0,1,0)},{__call=function(_,...)return Vec3(...)end})
local mods={}
local function Node()return {CreateChild=function()return Node()end,Dispose=noop}end
local function Service()return {Clear=noop,Update=noop,Dispose=noop}end
local draw,owners,activeOwn,filterOwn,groundCalls
local function Copy(x,seen)
 if type(x)~='table'then return x end
 seen=seen or {};if seen[x]then return seen[x]end
 local out={};seen[x]=out
 for k,v in pairs(x)do if k~='sourceView'then out[k]=Copy(v,seen)end end
 return out
end
local function Record(name,pos,...)
 if filterOwn and name=='Glow.Disc' and owners[pos]==activeOwn then return end
 draw[#draw+1]={name,Copy(pos),Copy({...})}
end
mods['render.EffectBatch']={New=function(_,kind)
 return {mesh={},Begin=noop,Finish=noop,Dispose=noop,
 Disc=function(_,pos,...)Record(kind..'.Disc',pos,...)end,
 Segment=function(_,pos,...)Record(kind..'.Segment',pos,...)end}
end}
mods['render.CombatLight']={New=Service}
mods['render.ChipEffects']={New=Service}
mods['render.MissileEffects']={New=Service}
mods['render.MissileView']={New=Service}
mods['render.DrillEffects']={}
mods['render.Quality']={current={name='desktop',weaponArcSegments=2400,weaponSwirlSegments=4}}
mods['Config']={}
mods['render.CombatSourceFx']={Color=function(v)return {v,v,v}end}
mods['core.Rotations']={}
mods['render.PartRig']={SetWeapon=noop}
mods['render.WeaponPresentation']={Update=noop,Apply=noop}
require=function(name)
 if mods[name]then return mods[name]end
 local path='scripts/'..name:gsub('%.','/')..'.lua'
 mods[name]=assert(load(READ_SOURCE(path),path))();return mods[name]
end
local function Once(source,old,new)
 local from,to=source:find(old,1,true);assert(from,'missing transform '..old)
 assert(not source:find(old,to+1,true),'nonunique transform')
 return source:sub(1,from-1)..new..source:sub(to+1)
end
local candidateSource=READ_SOURCE('scripts/render/CombatEffects.lua')
local baselineSource=Once(candidateSource,'function M:EquipmentEmit(kind,p,sourceView)','function M:EquipmentEmit(kind,p)')
baselineSource=Once(baselineSource,',grav=3,sourceView=sourceView}',',grav=3}')
baselineSource=Once(baselineSource,',grav=-.3,sourceView=sourceView}',',grav=-.3}')
baselineSource=Once(baselineSource,'if self.firstPerson and self.ownView and e.sourceView==self.ownView then return end','')
local candidateView=READ_SOURCE('scripts/render/WeaponView.lua')
local viewSource=Once(candidateView,'effects:EquipmentEmit(e.kind,{-p.x,p.y,p.z},vehicleView)','effects:EquipmentEmit(e.kind,{-p.x,p.y,p.z})')
local old=assert(load(baselineSource,'CombatEffectsBaseline'))()
local new=assert(load(candidateSource,'CombatEffectsCandidate'))()
local oldView=assert(load(viewSource,'WeaponViewBaseline'))()
local newView=assert(load(candidateView,'WeaponViewCandidate'))()
local rotation=setmetatable({},{__mul=function(_,v)return v end})
local camera={worldPosition=Vec3(0,1,0),worldRotation=rotation}
local checks=0
local function Equal(a,b,path)
 assert(type(a)==type(b),path..':type')
 if type(a)~='table'then checks=checks+1;assert(a==b,path..':value');return end
 for k,v in pairs(a)do Equal(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..':extra')end
end
local function Run(module,view,candidate,cap,scenario)
 math.randomseed(17102026+cap*29+scenario)
 draw={};owners={};groundCalls=0;filterOwn=false
 local own,enemy={},{}
 local weapons={groups={},projectiles={}}
 local f=module.New(Node(),function()groundCalls=groundCalls+1;return .1 end)
 f.maxParticles=cap;f.maxSmoke=cap
 local frames={};local hidden=0;local emitted=0
 local function Emit(kind,owner)
  local before=#f.particles
  f:EquipmentEmit(kind,{1+emitted*.001,-.5,2},owner);emitted=emitted+1
  if #f.particles>before and (kind=='spark' or kind=='mote')then
   local p=f.particles[#f.particles];owners[p.pos]=owner
   if candidate then assert(p.sourceView==owner,'ownership tag')end
  end
 end
 for frame=1,180 do
  if frame<=20 or frame>=45 and frame<=50 then
   for _,kind in ipairs({'spark','mote','fizzle','boot'})do
    Emit(kind,own);Emit(kind,enemy);Emit(kind,nil)
   end
  end
  local ads=scenario==1 or scenario==4 or scenario==2 and frame>=8 and frame<=38 or scenario==3 and frame%2==0
  activeOwn=own;local selectedOwn=own;if scenario==4 then selectedOwn=nil end
  f:SetFirstPerson(ads,weapons,selectedOwn)
  filterOwn=not candidate and ads and scenario~=4
  draw={};local beforeGround=groundCalls
  if ads and scenario~=4 then for _,p in ipairs(f.particles)do if owners[p.pos]==own then hidden=hidden+1 end end end
  f:Update(frame%13==0 and .11 or 1/60,{},camera)
  frames[frame]={particles=Copy(f.particles),smoke=Copy(f.smoke),flashes=Copy(f.flashes),draw=draw,
   ground=groundCalls-beforeGround,time=f.time}
 end
 assert(#f.particles==0 and #f.smoke==0,'expiration')
 -- Actual WeaponView must supply exactly its input system as the third argument.
 local rig={LocalToWorld=function(_,p)return p end}
 local sys={groups={{weapons={{id=1,prevYaw=0,yaw=0,prevPitch=0,pitch=0}}}}}
 local seen={}
 local vehicleView={visuals={[1]={rig={head=rig},weaponMotion={emits={{kind='spark',p={1,2,3}},{kind='mote',p={4,5,6}}}}}}}
 view.Update(vehicleView,sys,1,.1,1,
  {EquipmentEmit=function(_,kind,p,source)seen[#seen+1]={kind=kind,p=p,source=source==vehicleView}end})
 assert(#seen==2 and seen[1].kind=='spark' and seen[2].kind=='mote')
 assert(seen[1].source==candidate and seen[2].source==candidate,'actual WeaponView ownership forwarding')
 local tail={};for i=1,32 do tail[i]=math.random()end
 f:Dispose();assert(f.ownView==nil and f.ownWeapons==nil and not f.firstPerson,'dispose owner cleanup')
 return {frames=frames,tail=tail,groundCalls=groundCalls,hidden=hidden},seen
end
local cases={}
for _,cap in ipairs({0,1,8,1000})do for scenario=0,4 do
 local a=Run(old,oldView,false,cap,scenario);local b=Run(new,newView,true,cap,scenario)
 Equal(a,b,'cap'..cap..'/scenario'..scenario)
 cases[#cases+1]={cap=cap,scenario=scenario,frames=#a.frames,hidden=a.hidden,groundCalls=a.groundCalls}
end end
local swirlSource=READ_SOURCE('scripts/render/WeaponEffects.lua')
local beforeSwirl=Once(swirlSource,"World(head,m:Muzzle(-.2-Random(item)*.4)),self.view)","World(head,m:Muzzle(-.2-Random(item)*.4)))")
local function Swirl(source,expectOwner)
 local module=assert(load(source,'WeaponEffectsActual'))()
 local ownView={};local f=module.New(ownView);f.time=.2
 local calls,randomCalls=0,0
 f.Batch=function()return {Quad=function()calls=calls+1 end}end
 local seen={};f.emitter={EquipmentEmit=function(_,kind,p,owner)
  seen[#seen+1]={kind=kind,p=p};assert((owner==ownView)==expectOwner,'Swirl exact view identity')
 end}
 local item={random=function()randomCalls=randomCalls+1;return .1 end}
 local m={big=true,kind='mg',spinV=1,tier=5,scale={1,1,1},Muzzle=function(_,z)return {0,0,z}end}
 local head={LocalToWorld=function(_,p)return p end}
 f:Swirl(item,.1,m,head)
 assert(#seen==1 and calls==4 and randomCalls==2,'actual Swirl emission/draw/RNG')
 return {seen=seen,calls=calls,randomCalls=randomCalls}
end
Equal(Swirl(beforeSwirl,false),Swirl(swirlSource,true),'Swirl pass-through')
return {status='PASS',checks=checks,cases=cases,actualEffects=candidateSource,actualView=candidateView,
 reconstructedBaselineEffects=baselineSource,reconstructedBaselineView=viewSource}
''')

def plain(value):
    if hasattr(value, 'items'):
        entries = list(value.items())
        if all(isinstance(k, int) for k, _ in entries):
            return [plain(value[i]) for i in range(1, len(entries) + 1)]
        return {k: plain(v) for k, v in entries}
    return value

report = plain(result)
for key in ('actualEffects', 'actualView', 'reconstructedBaselineEffects', 'reconstructedBaselineView'):
    report[key + 'Sha256'] = hashlib.sha256(report.pop(key).encode()).hexdigest()
for name in ('CombatEffects', 'WeaponView', 'WeaponEffects'):
    report[name + 'ActualFileSha256'] = hashlib.sha256((ROOT / f'scripts/render/{name}.lua').read_bytes()).hexdigest()
trial = (ROOT / 'scripts/app/TrialSession.lua').read_text(encoding='utf-8-sig')
assert trial.count('self.effects:SetFirstPerson(') == 3
assert trial.count('self.weapons,self.view.view)') == 2
assert 'self.weaponEffects=WeaponEffects.New(self)' in (ROOT / 'scripts/render/VehicleView.lua').read_text(encoding='utf-8-sig')
report['sourceChainChecks'] = 'Both active TrialSession SetFirstPerson calls pass the exact self.view.view; VehicleView constructs WeaponEffects with self; actual WeaponView and Swirl methods assert exact owner identity. Death call clears first-person mode.'
report['boundary'] = 'Actual current CombatEffects, WeaponView and WeaponEffects.Swirl against isolated reconstructed prior owner-free methods. Graphics/service adapters, exact lifecycle/state/RNG and filtered draw-call equivalence. No production edit by this check, native pixels, measured speedup, full combat or mobile FPS acceptance.'
target = ROOT / 'docs/migration/evidence/ads-equipment-particles-offline-2026-10-17.json'
target.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))

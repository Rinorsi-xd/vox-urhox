"""Compare actual CombatEffects with a narrow in-memory ADS draw candidate.

This does not modify production source or establish visual acceptance.
"""
from pathlib import Path
import argparse
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

parser = argparse.ArgumentParser()
parser.add_argument('--baseline-scripts', type=Path, default=ROOT / 'scripts')
parser.add_argument('--candidate-scripts', type=Path)
args = parser.parse_args()
baseline = (args.baseline_scripts / 'render/CombatEffects.lua').read_text(encoding='utf-8')
candidate = baseline
changes = [
    ('function M:EquipmentEmit(kind,p)', 'function M:EquipmentEmit(kind,p,sourceView)'),
    ('size=.03+math.random()*.02,life=.15+math.random()*.15,age=0,drag=3,grav=3}',
     'size=.03+math.random()*.02,life=.15+math.random()*.15,age=0,drag=3,grav=3,sourceView=sourceView}'),
    ('size=.04,life=.5+math.random()*.4,age=0,drag=1.5,grav=-.3}',
     'size=.04,life=.5+math.random()*.4,age=0,drag=1.5,grav=-.3,sourceView=sourceView}'),
    ('function M:SetFirstPerson(active,ownWeapons)', 'function M:SetFirstPerson(active,ownWeapons,ownView)'),
    ('self.ownWeapons=self.firstPerson and ownWeapons or nil', 'self.ownWeapons=self.firstPerson and ownWeapons or nil\n    self.ownView=self.firstPerson and ownView or nil'),
    ('e.size=e.size+(e.grow or 0)*dt;local t=e.age/e.life\n            if smoke then',
     'e.size=e.size+(e.grow or 0)*dt;local t=e.age/e.life\n'
     '            if self.firstPerson and self.ownView and e.sourceView==self.ownView then return end\n'
     '            if smoke then'),
]
if args.candidate_scripts:
    candidate = (args.candidate_scripts / 'render/CombatEffects.lua').read_text(encoding='utf-8')
else:
    for before, after in changes:
        assert candidate.count(before) == 1, before
        candidate = candidate.replace(before, after)

setup = r'''
for _,name in ipairs({'render.CombatLight','render.MissileEffects','render.MissileView','render.DrillEffects',
 'render.EffectBatch','render.Quality','render.ChipEffects','render.CombatSourceFx'})do package.loaded[name]={}end
local function Copy(v)
 if type(v)~='table'then return v end
 local r={};for k,x in pairs(v)do if k~='sourceView'then r[k]=Copy(x)end end;return r
end
function Scenario(M)
 math.randomseed(1017)
 local own,enemy={projectiles={}},{projectiles={}}
 local ownView,enemyView={name='ownView'},{name='enemyView'}
 local s=setmetatable({time=0,disposed=false,particles={},smoke={},beams={},flares={},rings={},flashes={},zaps={},trails={},
  maxParticles=100,maxSmoke=100,batches={},chips={Update=function()end},missiles={Update=function()end},
  light={Update=function()end},groundAt=function()return 0 end},{__index=M})
 for _,name in ipairs({'Glow','Smoke','Streak','Ribbon','Ring'})do
  local b={draws={}}
  function b:Begin()self.draws={}end
  function b:Disc(p,size,color,alpha)
   local bucket;for _,item in ipairs(s.particles)do if item.pos==p then bucket=item.qaBucket;break end end
   self.draws[#self.draws+1]={pos=Copy(p),size=size,color=Copy(color),alpha=alpha,bucket=bucket}
  end
  function b:Finish()end
  s.batches[name]=b
 end
 local camera={worldPosition={x=0,y=2,z=0},worldRotation=setmetatable({},{__mul=function(_,v)return v end})}
 local stats={}
 local function Emit(owner,x)
  s:EquipmentEmit('spark',{x,.025,10},owner);s.particles[#s.particles].qaBucket=x
  s:EquipmentEmit('mote',{x,2,10},owner);s.particles[#s.particles].qaBucket=x
 end
 Emit(ownView,1);Emit(enemyView,2);Emit(nil,3)
 for step=1,80 do
  if step==2 then s:SetFirstPerson(true,own,ownView)end
  if step==5 then s:SetFirstPerson(false)end
  if step==6 then s:SetFirstPerson(true,nil)end
  if step==7 then s:SetFirstPerson(true,enemy,enemyView)end
  if step==8 then s:SetFirstPerson(false)end
  if step==10 then Emit(ownView,4);Emit(enemyView,5);Emit(nil,6)end
  if step==11 then s:SetFirstPerson(true,own,ownView)end
  s:Update(1/60,{},camera)
  local draws={};for _,row in ipairs(s.batches.Glow.draws)do draws[row.bucket]=true end
  stats[#stats+1]={particles=Copy(s.particles),smoke=Copy(s.smoke),draws=Copy(s.batches.Glow.draws),visible=draws}
 end
 return stats,math.random(),s
end
Vector3={RIGHT={x=1,y=0,z=0},UP={x=0,y=1,z=0}}
'''


def run(source):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(setup)
    lua.globals().package.loaded['core.Math3'] = lua.execute((ROOT / 'scripts/core/Math3.lua').read_text(encoding='utf-8'))
    module = lua.execute(source)
    rows, next_random, instance = lua.globals().Scenario(module)

    def plain(value):
        if hasattr(value, 'items'):
            return {key: plain(item) for key, item in value.items()}
        return value

    return plain(rows), next_random, len(instance.particles)


before, before_random, before_remaining = run(baseline)
after, after_random, after_remaining = run(candidate)
for step in range(1, 81):
    assert before[step]['particles'] == after[step]['particles'], f'Particle simulation changed at {step}'
    assert before[step]['smoke'] == after[step]['smoke'], f'Smoke simulation changed at {step}'
    if step in (1, 5, 6, 8, 9, 10):
        assert before[step]['draws'] == after[step]['draws'], f'Unscoped/nil ownership render changed at {step}'
    elif step == 7:
        assert 1 in after[step]['visible'] and 2 not in after[step]['visible'] and 3 in after[step]['visible']
    else:
        for x in (2, 3, 5, 6):
            assert (x in before[step]['visible']) == (x in after[step]['visible']), f'Enemy/world draw changed at {step}'
        assert 1 not in after[step]['visible'] and 4 not in after[step]['visible']
assert before_random == after_random, 'RNG stream changed'
assert before_remaining == after_remaining == 0, 'Expiry changed'
assert 1 in before[2]['visible'] and 1 not in after[2]['visible'], 'Pre-ADS own particle not hidden'
assert 1 in after[5]['visible'], 'Alive own particle not restored after release'
view_baseline = (args.baseline_scripts / 'render/WeaponView.lua').read_text(encoding='utf-8')
view_before = "effects:EquipmentEmit(e.kind,{-p.x,p.y,p.z})"
view_after = "effects:EquipmentEmit(e.kind,{-p.x,p.y,p.z},vehicleView)"
assert view_baseline.count(view_before) == 1
view_candidate = (args.candidate_scripts / 'render/WeaponView.lua').read_text(encoding='utf-8') if args.candidate_scripts else view_baseline.replace(view_before, view_after)
view_lua = LuaRuntime(unpack_returned_tuples=True)
view_lua.execute(r'''
package.loaded['render.PartRig']={SetWeapon=function()end}
package.loaded['render.WeaponPresentation']={Update=function()end,Apply=function()end}
package.loaded['core.Coord']={Vec=function(x,y,z)return{x=x,y=y,z=z}end}
function CheckForward(M,expected)
 local calls=0
 local node={LocalToWorld=function(self,p)return p end}
 local v={visuals={{rig={head=node},weaponMotion={emits={{kind='spark',p={1,2,3}}}}}}}
 local w={id=1,prevYaw=0,yaw=0,prevPitch=0,pitch=0,spinAngle=0}
 local system={groups={{weapons={w}}}}
 local effects={EquipmentEmit=function(self,kind,p,owner)
  calls=calls+1;assert(kind=='spark'and p[1]==-1 and p[2]==2 and p[3]==3)
  assert((owner==v)==expected,'Only actual VehicleView identity may cross source boundary')
 end}
 M.Update(v,system,1,1/60,1,effects);assert(calls==1)
 M.Update(v,system,1,1/60,1,nil);assert(calls==1,'No emitter remains supported')
end
''')
view_lua.globals().CheckForward(view_lua.execute(view_baseline), False)
view_lua.globals().CheckForward(view_lua.execute(view_candidate), True)
fx_baseline = (args.baseline_scripts / 'render/WeaponEffects.lua').read_text(encoding='utf-8')
fx_before = "self.emitter:EquipmentEmit('spark',World(head,m:Muzzle(-.2-Random(item)*.4)))"
fx_after = "self.emitter:EquipmentEmit('spark',World(head,m:Muzzle(-.2-Random(item)*.4)),self.view)"
assert fx_baseline.count(fx_before) == 1
fx_candidate = (args.candidate_scripts / 'render/WeaponEffects.lua').read_text(encoding='utf-8') if args.candidate_scripts else fx_baseline.replace(fx_before, fx_after)
fx_lua = LuaRuntime(unpack_returned_tuples=True)
fx_lua.globals().package.loaded['core.Math3'] = fx_lua.execute((ROOT / 'scripts/core/Math3.lua').read_text(encoding='utf-8'))
fx_lua.execute(r'''
package.loaded.Config={}
package.loaded['core.Coord']={Vec=function(x,y,z)return{x=x,y=y,z=z}end}
package.loaded['render.EffectBatch']={}
package.loaded['render.Quality']={current={weaponSwirlSegments=4}}
function CheckSwirl(M,expected)
 local view={name='actual own VehicleView'}
 local fx=M.New(view);fx.time=5
 local quads,calls,rng=0,0,0
 fx.batches.Swirl={Quad=function()quads=quads+1 end}
 local item={random=function()rng=rng+1;return .001 end}
 local head={LocalToWorld=function(self,p)return p end}
 local m={big=true,kind='mg',spinV=1,tier=5,scale={1,1,1},Muzzle=function(self,z)return{0,0,z}end}
 fx.emitter={EquipmentEmit=function(self,kind,p,owner)
  calls=calls+1;assert(kind=='spark'and p[1]==0 and p[2]==0)
  assert((owner==view)==expected,'Persistent Swirl must forward exact owning VehicleView')
 end}
 fx:Swirl(item,1/60,m,head)
 assert(quads==4 and calls==1 and rng==2,'Persistent geometry, RNG and emission count preserved')
 fx.emitter=nil;fx:Swirl(item,1/60,m,head)
 assert(quads==8 and calls==1 and rng==3,'Optional emitter behavior preserved')
end
''')
fx_lua.globals().CheckSwirl(fx_lua.execute(fx_baseline), False)
fx_lua.globals().CheckSwirl(fx_lua.execute(fx_candidate), True)
print('PASS in-memory candidate: actual CombatEffects emission/update for 80 frames, unchanged physics/age/expiry/RNG, scoped owner-only draw removal, preexisting particle hide, release restore, nil/source compatibility, enemy/world preservation. No production edits or rendered acceptance.')
print('PASS actual WeaponView candidate forwards exact VehicleView identity; transformed positions, call counts and optional emitter behavior preserved.')
print('PASS actual persistent WeaponEffects.Swirl forwards exact owning VehicleView; source positions, quad count, emission count, private RNG and optional emitter behavior preserved.')

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path('.tmp/nav-python-deps').resolve()))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
HandleUpdate=function()end;HandlePostUpdate=function()end
local v={Add=function(a,b)return{a[1]+b[1],a[2]+b[2],a[3]+b[3]}end,
 Scale=function(a,k)return{a[1]*k,a[2]*k,a[3]*k}end,
 Normalize=function(a)local n=math.sqrt(a[1]^2+a[2]^2+a[3]^2);return{a[1]/n,a[2]/n,a[3]/n}end}
require=function(name)if name=='core.Math3'then return v elseif name=='render.CombatSourceFx'then return{Color=function()return{1,1,1}end}else return{}end end
Vector3={FORWARD={x=0,y=0,z=1}}
''')
combat = pathlib.Path('scripts/render/CombatEffects.lua').read_text(encoding='utf8')
lua.globals().Combat = lua.execute(combat)
observer = pathlib.Path('tools/migration/scope-fx-isolated-observer.lua').read_text(encoding='utf8')
prefix, suffix = observer.rsplit('\nend', 1)
lua.execute(prefix + '''
TEST_SCOPE={Attach=AttachEmissionObserver,Snapshot=EmissionSnapshot,tags=particleTags,positions=positionTags}
''' + '\nend' + suffix)
lua.execute('''
local function Batch()
 return{count=0,limit=10,mesh={enabled=true},Disc=function(self)if self.count<self.limit then self.count=self.count+1 end;return'original-disc',nil,7 end}
end
local function Effects()
 return setmetatable({particles={},smoke={},flashes={},maxParticles=100,maxSmoke=100,batches={Glow=Batch(),Smoke=Batch()}},{__index=Combat})
end
local function Trial(e,update)
 return{firstPerson=true,effects=e,view={view={weaponEffects={visible=false,Update=update}}},
 camera={GetNode=function()return{worldPosition={x=0,y=0,z=0},worldRotation=setmetatable({},{__mul=function(_,v)return v end})}end}}
end
local function Signature(e)
 local out={}
 for _,name in ipairs({'particles','smoke'})do for _,p in ipairs(e[name])do out[#out+1]=table.concat({name,p.pos[1],p.pos[2],p.pos[3],p.vel[1],p.vel[2],p.vel[3],p.life,p.size},',')end end
 return table.concat(out,'|')
end
local raw=Effects();math.randomseed(47);raw:EquipmentEmit('spark',{0,0,.3});raw:EquipmentEmit('fizzle',{1,0,1})
local expected=Signature(raw);local expectedRandom=math.random()
local e=Effects();local calls=0
local t=Trial(e,function(self,fail)
 calls=calls+1;if fail then error('original failure')end
 e:EquipmentEmit('spark',{0,0,.3});return'original-update',nil,9
end)
TEST_SCOPE.Attach(t);local wrapper=t.view.view.weaponEffects.Update
TEST_SCOPE.Attach(t);assert(t.view.view.weaponEffects.Update==wrapper,'Attach must be idempotent')
math.randomseed(47)
local a,b,c=t.view.view.weaponEffects:Update();assert(a=='original-update'and b==nil and c==9 and calls==1)
e:EquipmentEmit('fizzle',{1,0,1})
assert(Signature(e)==expected and math.random()==expectedRandom,'Actual EquipmentEmit RNG/order/objects changed')
local s=TEST_SCOPE.Snapshot(t)
assert(s.totals['scoped:ownPersistent:spark'].particlesAdded==1)
assert(s.totals['scoped:outsideOwnPersistent:fizzle'].particlesAdded==10)
assert(s.totals['scoped:outsideOwnPersistent:fizzle'].smokeAdded==2)
assert(s.live['particles:ownPersistent:spark'].nearHalfMeter==1)
local p=e.particles[1];p.pos[3]=-.2
local d,f,g=e.batches.Glow:Disc(p.pos);assert(d=='original-disc'and f==nil and g==7)
local row=TEST_SCOPE.Snapshot(t).draws['scoped:ownPersistent:spark:Glow']
assert(row.calls==1 and row.accepted==1 and row.nearHalfMeter==1 and row.behindCamera==1)
e.batches.Glow.limit=e.batches.Glow.count;e.batches.Glow:Disc(p.pos)
row=TEST_SCOPE.Snapshot(t).draws['scoped:ownPersistent:spark:Glow'];assert(row.calls==2 and row.accepted==1 and row.acceptedNearHalfMeter==1 and row.acceptedBehindCamera==1,'Cap rejected draw must not count accepted')
assert(not pcall(function()t.view.view.weaponEffects:Update(true)end),'Original error must propagate')
local unrelated={pos={0,0,.1}};e.particles[#e.particles+1]=unrelated
e.maxParticles=#e.particles;e:EquipmentEmit('spark',{0,0,.1})
s=TEST_SCOPE.Snapshot(t)
assert(s.totals['scoped:outsideOwnPersistent:spark'].particlesAdded==0,'Cap rejected particle must not be tagged')
assert(TEST_SCOPE.tags[unrelated]==nil,'Preexisting non-equipment particles must not be misattributed')
assert(s.totals['scoped:outsideOwnPersistent:spark'].calls==1,'Owner context must restore after error')
for _=1,10 do e:EquipmentEmit('mote',{0,0,1})end
assert(#TEST_SCOPE.Snapshot(t).latest==6,'Recent detail must be bounded')
assert(getmetatable(TEST_SCOPE.tags).__mode=='k'and getmetatable(TEST_SCOPE.positions).__mode=='k','Ownership maps must use weak keys')
e.particles={};e.smoke={};p=nil;raw=nil;unrelated=nil;collectgarbage('collect')
assert(next(TEST_SCOPE.tags)==nil and next(TEST_SCOPE.positions)==nil,'Metadata must not retain particles/positions')
''')
print('PASS: actual Lua observer and production EquipmentEmit; RNG/order, returns, error restoration, cap rejection, unrelated objects, draws, distance, bounded details, weak keys. Offline adapters; no Runtime/FPS acceptance.')

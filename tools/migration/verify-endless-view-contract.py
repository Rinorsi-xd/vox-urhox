"""Exercise real endless/objective geometry integration without native rendering."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
lua = LuaRuntime(unpack_returned_tuples=True)
result = lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(value,label) assert(value,label);checks=checks+1 end
local mt={}
local function Vec(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},mt) end
mt.__add=function(a,b)return Vec(a.x+b.x,a.y+b.y,a.z+b.z)end
mt.__sub=function(a,b)return Vec(a.x-b.x,a.y-b.y,a.z-b.z)end
mt.__mul=function(a,b)return Vec(a.x*b,a.y*b,a.z*b)end
Vector3=setmetatable({UP=Vec(0,1,0),DOWN=Vec(0,-1,0)},{__call=function(_,...)return Vec(...)end})
Vector2={ZERO={x=0,y=0}}
function Quaternion(...) return {...} end
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a} end
function Variant(v) return v end
TRIANGLE_LIST=0
cache={GetResource=function(_,kind,name)return {kind=kind,name=name}end}
Material={new=function()
 local m={}
 function m:SetSurfaceShader(name) self.shader=name;return true end
 function m:SetTechnique() end
 function m:SetShaderParameter() end
 function m:Dispose() self.disposed=true end
 return m
end}
package.preload['core.Coord']=function()return {Vec=function(x,y,z)return Vec(-x,y,z)end}end
package.preload['endless.Data']=function()return {config={clearPickupDuration=.4,pickupDuration=.2}}end
package.preload['parts.Defs']=function()return {PARTS={gun={cat='weapon'}}}end
package.preload['construction.Blueprint']=function()return {New=function()return {Add=function()end}end}end
package.preload['render.VehicleView']=function()return {New=function(pivot)
 local v={root=pivot:CreateChild('Part'),visuals={}}
 function v:Rebuild()end
 function v:Dispose()self.disposed=true end
 return v
end}end
local function Node(name)
 local n={name=name,children={},position=Vec(),worldPosition=Vec(),scale=1}
 function n:CreateChild(name)local c=Node(name);self.children[#self.children+1]=c;return c end
 function n:SetScale(v)self.scale=v end
 function n:CreateComponent()
  local mesh={vertices={},commits=0}
  function mesh:BeginGeometry()self.vertices={}end
  function mesh:DefineVertex(v)self.vertices[#self.vertices+1]=v end
  function mesh:DefineNormal()end
  function mesh:DefineTexCoord()end
  function mesh:DefineColor()end
  function mesh:SetMaterial(v)self.material=v end
  function mesh:Commit()self.commits=self.commits+1 end
  self.mesh=mesh;return mesh
 end
 function n:Dispose()self.disposed=true end
 return n
end
local Endless=require 'endless.View'
local Objective=require 'render.ObjectiveView'
local scene=Node('Scene')
local v=Endless.New(scene)
Check(v.geometry.mesh~=nil,'constructor initializes actual geometry mesh')
Check(v.geometry.origin[1]==0 and v.geometry.origin[2]==0 and v.geometry.origin[3]==0,'constructor origin')
Check(v.geometry.route==nil,'endless has no payload route')
Check(v.geometry.mesh.enabled==false,'initial empty effects hidden')
Check(v.geometry.materials[1].shader=='Shaders/BLGL/Combat/Objective.shader','shared depth-tested shader')
local player={pos={3,2,4}}
local session={world={time=0,GroundAt=function()return 2 end},entries={},player=player,session={},run={shield={hp=100,max=100}}}
v:Update(session,.1)
Check(not v.geometry.mesh.enabled,'empty update hides effects')
v:Warn('spawn',{10,2,20});v:Update(session,.1)
Check(v.geometry.mesh.enabled,'warning visible')
Check(#v.geometry.mesh.vertices==96,'actual sixteen-sided warning beam')
Check(math.abs(v.geometry.mesh.vertices[1].x+13)<1e-9,'warning transformed once from game coordinates')
v:ClearWarning('spawn');v:Update(session,.1)
Check(not v.geometry.mesh.enabled,'cleared warning hidden')
session.entries={{unit=player},{unit={alive=true,endless={elite=true},spec={bounds={radius=4}},Position=function()return {12,3,14}end}}}
v:Update(session,.1)
Check(v.geometry.mesh.enabled and #v.geometry.mesh.vertices==576,'live elite actual ring')
session.entries[2].unit.alive=false;v:Update(session,.1)
Check(not v.geometry.mesh.enabled,'dead elite no ring')
v:Event{type='drop',drop={id='credits',credits=8,pos={10,0,20}}}
local coin=v.drops.credits
Check(#coin.pivot.children==3,'real three-coin stack')
for _,node in ipairs(coin.pivot.children)do Check(#node.mesh.vertices==72,'real coin has closed six-sided mesh')end
v:Update(session,.1)
Check(v.geometry.mesh.enabled and #v.geometry.mesh.vertices==96,'uncollected drop beam')
Check(coin.root.position.x==-10 and coin.root.position.y==2.1 and coin.root.position.z==20,'drop on scalar ground height')
Check(coin.pivot.position.y==1.1,'source bob offset')
v:Event{type='dropCollected',drop={id='credits'},reason='pickup'}
Check(coin.duration==.2,'normal collection duration')
session.world.time=.1;v:Update(session,.1)
Check(math.abs(coin.root.position.x-(-8.25))<1e-9,'quadratic collection position')
Check(math.abs(coin.root.scale-.575)<1e-9,'collection scale')
session.world.time=.2;v:Update(session,.1)
Check(v.drops.credits==nil and coin.root.disposed,'finished coin released')
v:Event{type='drop',drop={id='part',type='gun',pos={0,1,0}}}
local part=v.drops.part
session.world.GroundAt=function()return {h=5}end
v:Update(session,.1)
Check(part.root.position.y==5.1,'drop accepts height-record ground contract')
v:Event{type='dropCollected',drop={id='part'},reason='waveClear'}
Check(part.duration==.4,'wave-clear collection duration')
session.world.time=.600001;v:Update(session,.4)
Check(v.drops.part==nil and part.root.disposed and part.visual.disposed,'part visual released after collection')
local shield={node={},down=0,raised=0,updates=0}
function shield:SetHP(hp)self.hp=hp;self.updates=self.updates+1 end
function shield:Down()self.down=self.down+1 end
function shield:Raise()self.raised=self.raised+1 end
local enemy={node={enabled=true}}
session.session.environment={effects={shields={shield,enemy}}}
v:Update(session,.1)
Check(shield.hp==1 and shield.updates==1 and not enemy.node.enabled,'base shield initialized and enemy shield disabled')
v:Update(session,.1);Check(shield.updates==1,'unchanged shield avoids repeated writes')
session.run.shield.hp=0;v:Update(session,.1);v:Update(session,.1)
Check(shield.down==1 and shield.hp==0,'shield breaks once')
session.run.shield.hp=50;v:Update(session,.1)
Check(shield.raised==1 and shield.hp==.5,'shield restored once')
v:Event{type='drop',drop={id='pending',type='gun',pos={0,0,0}}}
local pending=v.drops.pending;local geom=v.geometry;local effectsRoot=v.root;local coinMat=v.coinMaterial
v:Dispose();v:Dispose()
Check(pending.visual.disposed and effectsRoot.disposed and geom.root.disposed,'all roots and pending visual disposed')
Check(geom.materials[1].disposed and geom.materials[2].disposed and coinMat.disposed,'geometry and coin materials disposed')
Check(v.geometry==nil and v.root==nil and next(v.drops)==nil,'owned handles cleared')
local escort={id='escort',path={{0,0,0},{3,4,0},{6,8,0}},cum={0,3,6},length=6,tuning={checkpoints={.5}}}
function escort:At()return {pos={2,1,0}}end
local route=Objective.New({scene=Node('Escort')},escort)
Check(route.route==true,'actual escort route preserved')
route:Update(.1,{s=0,idle=0,pushing=0,contested=false})
Check(#route.batches.PayloadHalo.mesh.vertices==768,'escort halo preserved')
route:Dispose();Check(route.root.disposed,'escort ownership released')
return checks
''')

paths = ['scripts/endless/View.lua', 'scripts/endless/Coin.lua',
         'scripts/render/ObjectiveView.lua', 'scripts/render/ObjectiveRoute.lua']
arena = LuaRuntime(unpack_returned_tuples=True)
arena_regression = dict(arena.execute("return dofile('tools/migration/check-objective-geometry.lua')"))
assert arena_regression['result'] == 'PASS', arena_regression
report = {
    'pass': True,
    'checks': result + arena_regression['checks'],
    'endlessIntegrationChecks': result,
    'arenaGeometryRegression': arena_regression,
    'production': {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in paths},
    'fixtures': {'tools/migration/check-objective-geometry.lua': hashlib.sha256((ROOT / 'tools/migration/check-objective-geometry.lua').read_bytes()).hexdigest()},
    'boundary': 'Actual Lua Endless.View, ObjectiveView, ObjectiveRoute and Coin with native node/material/vector adapters; the part VehicleView is a double. Covers construction, warning, elite, actual coin mesh, loot collection, shield transitions, cleanup and escort route/halo. No GPU, browser, build or native launch. Rendered pixels, natural waves and device performance remain OPEN.'
}
output = ROOT / 'docs/migration/evidence/endless-view-contract-offline.json'
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))

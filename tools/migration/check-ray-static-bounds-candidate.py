"""Bounded correctness checks only; actual Lua arithmetic, fixed body doubles."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

parser = argparse.ArgumentParser()
parser.add_argument('--fixture', type=Path, default=Path('.tmp/ray-static-bounds-4a3a-1017-a'))
parser.add_argument('--output', type=Path)
args = parser.parse_args()
fixture = ROOT / args.fixture
identity = json.loads((fixture / 'identity.json').read_text(encoding='utf-8'))
old = (fixture / 'VehicleRay.baseline.lua').read_text(encoding='utf-8')
candidate = (fixture / 'VehicleRay.candidate.lua').read_text(encoding='utf-8')
assert hashlib.sha256(old.encode()).hexdigest() == identity['baselineSha256']
assert hashlib.sha256(candidate.encode()).hexdigest() == identity['candidateSha256']
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;?.lua;'..package.path")
lua.globals().OLD_SOURCE = old
lua.globals().CANDIDATE_SOURCE = candidate
result = lua.execute(r'''
local V=require 'core.Math3'
local function Load(source)
 local s,n=source:gsub('return M%s*$','M.TestBounds=Bounds;return M');assert(n==1)
 return assert(load(s))()
end
local old,new=Load(OLD_SOURCE),Load(CANDIDATE_SOURCE)
local checks,cases=0,0
local function Eq(a,b,path)
 checks=checks+1;assert(type(a)==type(b),path..' type')
 if type(a)=='number'then assert(string.pack('d',a)==string.pack('d',b),path..' bits')
 elseif type(a)=='table'then
  for k,v in pairs(a)do Eq(v,b[k],path..'.'..tostring(k))end
  for k in pairs(b)do assert(a[k]~=nil,path..' extra')end
 else assert(a==b,path..' value')end
end
local function Copy(x)
 if type(x)~='table'then return x end
 local out={};for k,v in pairs(x)do out[k]=Copy(v)end;return out
end
local seed=1017
local function R(scale)
 seed=(seed*1664525+1013904223)&0xffffffff
 return (seed/4294967296*2-1)*(scale or 1)
end
local function Shape(id)
 local shape={center={R(10),R(5),R(10)},half={math.abs(R(2)),math.abs(R(2)),math.abs(R(2))},partId=id}
 if id%2==0 then local a=R(math.pi);shape.quat={x=0,y=math.sin(a/2),z=0,w=math.cos(a/2)}end
 return shape
end
local function Vehicle(spec,rotors)
 return {spec=spec or {boxes={Shape(1)},hulls={},sensors={}},rotors=rotors or {},wheels={},
  legHitboxes={items={}},mechHitboxes={items={}},
  body={translation=function()return {x=1,y=2,z=3}end,rotation=function()return {x=0,y=0,z=0,w=1}end}}
end
local function Check(a,b,label)
 Eq(old.TestBounds(a),new.TestBounds(b),label..'.bounds')
 local origin={R(30),R(20),R(30)};local direction=V.Normalize({R(),R(),R()})
 a.rayBounds=nil;b.rayBounds=nil
 local x,y=old.Cast(a,origin,direction,60),new.Cast(b,origin,direction,60)
 if x then x.body=nil end;if y then y.body=nil end
 Eq(x,y,label..'.cast');Eq(a.rayBounds,b.rayBounds,label..'.cache');cases=cases+1
end
for case=1,120 do
 local spec={boxes={},hulls={},sensors={}}
 for i=1,case%30 do local list=i%3==0 and spec.boxes or i%3==1 and spec.hulls or spec.sensors;list[#list+1]=Shape(i)end
 local a,b=Vehicle(Copy(spec)),Vehicle(Copy(spec))
 for i=1,case%4 do
  local wheel={center={R(15),R(5),R(15)},conn={R(15),R(5),R(15)},down={0,-1,0},drop=R(3),
   axle={1,0,0},radius=math.abs(R(2)),width=math.abs(R(2)),partId=100+i,track=i==4}
  a.wheels[i]=Copy(wheel);b.wheels[i]=Copy(wheel)
 end
 for frame=1,4 do
  local dynamic=Shape(200+frame);local dynamicMech=Shape(300+frame)
  a.legHitboxes.items={Copy(dynamic)};b.legHitboxes.items={Copy(dynamic)}
  a.mechHitboxes.items={Copy(dynamicMech)};b.mechHitboxes.items={Copy(dynamicMech)}
  for i,w in ipairs(a.wheels)do w.drop=R(4);b.wheels[i].drop=w.drop end
  local prior=b.rayStaticBounds;Check(a,b,'random-'..case..'-'..frame)
  if prior then assert(b.rayStaticBounds==prior,'Dynamic update reuses static extrema')end
 end
 -- In-place spec replacement is conservatively invalidated even though damage
 -- creates a fresh production Vehicle. List replacement/count changes are too.
 a.spec=Copy(spec);b.spec=Copy(spec);a.spec.boxes[#a.spec.boxes+1]=Shape(999);b.spec.boxes=Copy(a.spec.boxes)
 Check(a,b,'spec-replace-'..case)
 a.spec.sensors={Shape(1000)};b.spec.sensors=Copy(a.spec.sensors);Check(a,b,'list-replace-'..case)
 a.spec.hulls[#a.spec.hulls+1]=Shape(1001);b.spec.hulls[#b.spec.hulls+1]=Copy(a.spec.hulls[#a.spec.hulls]);Check(a,b,'list-count-'..case)
end
-- Rotor presence may change after the static cache has been populated; the
-- exact original path must still observe moved spec shapes immediately.
for i=1,30 do
 local a,b=Vehicle(),Vehicle();b.spec=Copy(a.spec);Check(a,b,'before-rotor-'..i)
 a.rotors={{angle=i}};b.rotors={{angle=i}}
 a.spec.boxes[1].center={100+i,2,3};b.spec.boxes[1].center=Copy(a.spec.boxes[1].center)
 Check(a,b,'rotor-fallback-'..i)
 a.rotors={};b.rotors={};Check(a,b,'rotor-removed-'..i)
end
for _,special in ipairs({0.0,-0.0,math.huge,-math.huge,0/0,1e-300,-1e300})do
 for _,where in ipairs({'center','half'})do
  local spec={boxes={{center={0,0,0},half={0,0,0},partId=1}},hulls={},sensors={}}
  spec.boxes[1][where][1]=special
  local a,b=Vehicle(Copy(spec)),Vehicle(Copy(spec))
  Eq(old.TestBounds(a),new.TestBounds(b),'special.'..where)
  Eq(old.TestBounds(a),new.TestBounds(b),'special.cached.'..where);cases=cases+1
 end
end
local negative={}
local function Reject(label,pattern,replacement,exercise)
 local at=assert(CANDIDATE_SOURCE:find('-- Isolated candidate.',1,true))
 local prefix,body=CANDIDATE_SOURCE:sub(1,at-1),CANDIDATE_SOURCE:sub(at)
 local text,n=body:gsub(pattern,replacement,1);assert(n==1,'Mutation anchor '..label);text=prefix..text
 local mutant=Load(text);local ok=pcall(exercise,mutant);assert(not ok,'Negative control accepted: '..label)
 negative[#negative+1]=label
end
Reject('rotor-fallback','if not vehicle%.rotors or #vehicle%.rotors>0 then','if false then',function(mod)
 local a=Vehicle();mod.TestBounds(a);a.rotors={{}};a.spec.boxes[1].center={100,0,0}
 Eq(old.TestBounds(a),mod.TestBounds(a),'negative.rotor')
end)
Reject('static-invalidation','if not cached or cached%.spec~=spec or cached%.boxes~=spec%.boxes or cached%.hulls~=spec%.hulls%s+or cached%.sensors~=spec%.sensors or cached%.boxCount~=#spec%.boxes%s+or cached%.hullCount~=#spec%.hulls or cached%.sensorCount~=#spec%.sensors then','if not cached then',function(mod)
 local a=Vehicle();mod.TestBounds(a);a.spec={boxes={{center={100,0,0},half={1,1,1},partId=1}},hulls={},sensors={}}
 Eq(old.TestBounds(a),mod.TestBounds(a),'negative.spec')
end)
Reject('dynamic-legs','ipairs%({vehicle%.legHitboxes and vehicle%.legHitboxes%.items or {},vehicle%.mechHitboxes and vehicle%.mechHitboxes%.items or {}}%)do','ipairs({})do',function(mod)
 local a=Vehicle();a.legHitboxes.items={{center={100,0,0},half={1,1,1},partId=3}}
 Eq(old.TestBounds(a),mod.TestBounds(a),'negative.leg')
end)
Reject('dynamic-wheel-drop','Grow%(V%.Add%(w%.center,V%.Scale%(w%.down or {0,%-1,0},w%.drop%)%),half%);Grow%(w%.conn,half%)','Grow(w.conn,half)',function(mod)
 local a=Vehicle();a.wheels={{center={0,0,0},conn={0,0,0},drop=100,axle={1,0,0},radius=1,width=1,partId=2}}
 Eq(old.TestBounds(a),mod.TestBounds(a),'negative.wheel')
end)
return {status='PASS',cases=cases,checks=checks,negativeControls=table.concat(negative,','),
 rotorFallbackCases=30,specialValueCases=14,normalGC=collectgarbage('isrunning')}
''')
plain = dict(result.items())
plain['baselineSha256'] = identity['baselineSha256']
plain['candidateSha256'] = identity['candidateSha256']
plain['boundary'] = ('Actual Lua54 VehicleRay/Math3 against randomized shape/pose/body doubles, including dynamic leg/mech/wheel updates, '
                     'spec/list replacement and count invalidation, no-rotor cache reuse, rotor fallback, NaN/infinity/signed zero. '
                     'Normal automatic GC retained. No actual Native query replay, CPU benchmark, production adoption or FPS claim.')
encoded = json.dumps(plain, indent=2)
if args.output:
    with args.output.open('x', encoding='utf-8') as stream:
        stream.write(encoded + '\n')
print(encoded)

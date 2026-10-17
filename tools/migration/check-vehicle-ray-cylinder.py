"""Exact Lua 5.4 comparison of isolated Cylinder and full VehicleRay consumers."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source_path = ROOT / 'scripts/combat/VehicleRay.lua'
candidate_path = ROOT / 'tools/migration/vehicle-ray-cylinder-candidate.lua'
source = source_path.read_text(encoding='utf-8')
candidate = candidate_path.read_text(encoding='utf-8')
start = source.index('local function Cylinder(')
end = source.index('local function Bounds(', start)
original_function = source[start:end]
candidate_function = candidate[:candidate.rindex('return Cylinder')]
assert 'V.' not in candidate_function
assert source.count(original_function) == 1

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;?.lua;'..package.path")
lua.globals().ORIGINAL = original_function
lua.globals().CANDIDATE = candidate_function
lua.globals().ORIGINAL_MODULE = source
lua.globals().CANDIDATE_MODULE = source[:start]+candidate_function+source[end:]
result = lua.execute(r'''
local V=require 'core.Math3'
local baseline=assert(load('local V=require "core.Math3"\n'..ORIGINAL..'\nreturn Cylinder'))()
local candidate=assert(load(CANDIDATE..'\nreturn Cylinder'))()
local oldModule=assert(load(ORIGINAL_MODULE))()
local newModule=assert(load(CANDIDATE_MODULE))()
local checks,cases,hits,misses=0,0,0,0
local coverage={}
local function equal(a,b,where)
    checks=checks+1
    assert(type(a)==type(b),where..': type')
    if type(a)=='number' then
        assert(string.pack('d',a)==string.pack('d',b),where..': numeric bits '..tostring(a)..' / '..tostring(b))
    elseif type(a)=='table' then
        for k,v in pairs(a) do equal(v,b[k],where..'.'..tostring(k)) end
        for k in pairs(b) do assert(a[k]~=nil,where..': extra key '..tostring(k)) end
    else assert(a==b,where..': value') end
end
local function run(args,label)
    cases=cases+1
    local a=table.pack(baseline(table.unpack(args)))
    local b=table.pack(candidate(table.unpack(args)))
    equal(a,b,label)
    if a.n==0 then misses=misses+1 else hits=hits+1 end
    coverage[label]=(coverage[label] or 0)+1
end
local axis={1,0,0}
local boundaries={
    {{0,0,0},{1,0,0},axis,1,.5,10},
    {{.5,1,0},{0,1,0},axis,1,.5,10},
    {{0,2,0},{0,-1,0},axis,1,.5,1},
    {{0,2,0},{0,-1,0},axis,1,.5,1-2^-52},
    {{-2,0,0},{1,0,0},axis,1,.5,10},
    {{2,0,0},{-1,0,0},axis,1,.5,10},
    {{0,2,1},{0,-1,0},axis,1,.5,10},
    {{0,2,1+2^-50},{0,-1,0},axis,1,.5,10},
    {{0,2,0},{0,0,0},axis,1,.5,10},
    {{0,0,0},{0,0,0},axis,0,0,0},
    {{2,0,0},{-1e-9,0,0},axis,1,.5,1e12},
    {{2,0,0},{-1.000000001e-9,0,0},axis,1,.5,1e12},
    {{0,2,0},{0,-1e-6,0},axis,1,.5,1e8},
    {{0,2,0},{0,-1.000000001e-6,0},axis,1,.5,1e8},
    {{0,2,0},{0,-1,0},axis,1,.5,-1},
    {{0,0,0},{-0.0,0,-0.0},axis,1,.5,-1},
    {{2,0,0},{0,0,0},axis,1,.5,math.huge},
    {{0,2,0},{0,-1,0},axis,0,0,math.huge},
    {{-2,2,0},{1,-1,0},axis,1,1,10},
}
for i,args in ipairs(boundaries) do run(args,'boundary-'..i) end
math.randomseed(1017,845)
local function random(scale) return (math.random()*2-1)*scale end
for i=1,60000 do
    local scale=10^random(5)
    local a=i%4==0 and axis or V.Normalize({random(1),random(1),random(1)})
    local radius=math.random()*scale
    local half=math.random()*scale
    local origin={random(scale*4),random(scale*4),random(scale*4)}
    local dir=V.Normalize({random(1),random(1),random(1)})
    if i%7==0 then dir=V.Scale(a,i%2==0 and 1 or -1) end
    if i%11==0 then origin=V.Scale(a,random(half)) end
    run({origin,dir,a,radius,half,math.random()*scale*12},'random')
end
local consumerCases=0
local function body(p,q) return {translation=function() return p end,rotation=function() return q end} end
for i=1,5000 do
    local q={x=0,y=math.sin(i*.001),z=0,w=math.cos(i*.001)}
    local p={x=random(50),y=random(5),z=random(50)}
    local wheel={center={0,0,0},conn={0,0,0},down={0,-1,0},drop=.2,axle=axis,radius=1,width=1,partId=7}
    local function vehicle()
        return {body=body(p,q),spec={boxes={},hulls={},sensors={}},wheels={wheel}}
    end
    local origin={p.x+random(4),p.y+random(4),p.z+random(4)}
    local dir=V.Normalize({random(1),random(1),random(1)})
    local oldVehicle,newVehicle=vehicle(),vehicle()
    -- Body identity differs between fixtures; compare every other returned field.
    local a=oldModule.Cast(oldVehicle,origin,dir,15)
    local b=newModule.Cast(newVehicle,origin,dir,15)
    if a then assert(a.body==oldVehicle.body);a.body=nil end
    if b then assert(b.body==newVehicle.body);b.body=nil end
    equal(a,b,'consumer-'..i);consumerCases=consumerCases+1
end
local mixedConsumers=0
for _,direction in ipairs({{0,-1,0},{1,0,0},{-1,0,0}}) do
    for _,tracked in ipairs({false,true}) do
        local function vehicle()
            local box={center={0,0,0},half={.5,1,1},partId=3}
            local function wheel(id,track) return {center={0,0,0},conn={0,0,0},drop=0,axle=axis,radius=1,width=1,partId=id,track=track} end
            return {body=body({x=0,y=0,z=0},{x=0,y=0,z=0,w=1}),
                spec={boxes={box},hulls={},sensors={}},wheels={wheel(7,false),wheel(8,tracked)},
                legHitboxes={items={{center={0,0,0},half={.5,1,1},partId=4}}}}
        end
        local origin=V.Scale(direction,-2)
        local oldVehicle,newVehicle=vehicle(),vehicle()
        for _,length in ipairs({10, direction[2]~=0 and 1 or 1.5}) do
            local a=oldModule.Cast(oldVehicle,origin,direction,length)
            local b=newModule.Cast(newVehicle,origin,direction,length)
            assert(a and b and a.partId==(tracked and 7 or 8),'Actual consumer equal-distance wheel ordering')
            assert(a.body==oldVehicle.body and b.body==newVehicle.body)
            a.body=nil;b.body=nil;equal(a,b,'mixed-consumer')
            mixedConsumers=mixedConsumers+1
        end
    end
end
local controls={
    {'inside-normal',CANDIDATE:gsub('dir%[1%]%*%-1,dir%[2%]%*%-1,dir%[3%]%*%-1','dir[1],dir[2],dir[3]',1),1},
    {'cap-normal',CANDIDATE:gsub('axis%[1%]%*sign,axis%[2%]%*sign,axis%[3%]%*sign','axis[1]*-sign,axis[2]*-sign,axis[3]*-sign',1),5},
    {'exclusive-max',CANDIDATE:gsub('if best<=maxDist','if best<maxDist',1),3},
    {'skip-first-root',CANDIDATE:gsub('local t=index==1 and first or second','local t=second',1),3},
    {'cap-wins-tie',CANDIDATE:gsub('t>=0 and t<best and x%*x','t>=0 and t<=best and x*x',1),19},
}
local rejected={}
for _,control in ipairs(controls) do
    local mutant=assert(load(control[2]..'\nreturn Cylinder'))()
    local args=boundaries[control[3]]
    local ok=pcall(equal,table.pack(baseline(table.unpack(args))),table.pack(mutant(table.unpack(args))),control[1])
    assert(not ok,'Negative control escaped: '..control[1]);rejected[#rejected+1]=control[1]
end
return {status='PASS',cases=cases,consumerCases=consumerCases,mixedConsumers=mixedConsumers,checks=checks,hits=hits,misses=misses,negativeControls=rejected}
''')

def convert(value):
    if hasattr(value, 'items'):
        entries = list(value.items())
        if entries and all(isinstance(k, int) for k, _ in entries):
            return [convert(value[i]) for i in range(1, len(entries)+1)]
        return {str(k): convert(v) for k, v in entries}
    return value

report = convert(result)
report['sha256'] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in [source_path, candidate_path, ROOT/'scripts/core/Math3.lua']}
report['boundary'] = 'Offline behavior equivalence only; no CPU/FPS or target-device claim.'
destination = ROOT/'docs/migration/evidence/vehicle-ray-cylinder-candidate-offline.json'
destination.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, indent=2))

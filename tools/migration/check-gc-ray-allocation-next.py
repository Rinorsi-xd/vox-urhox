"""Actual Lua ray and allocation observer; native body poses are fixed doubles."""
import hashlib
import json
import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path)
parser.add_argument('--prepared', type=Path)
args = parser.parse_args()
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
sources = {name: (ROOT / relative).read_text(encoding='utf-8') for name, relative in {
    'Math': 'scripts/core/Math3.lua', 'Ray': 'scripts/combat/VehicleRay.lua',
    'Factory': 'tools/migration/qa-single-step-allocation.lua',
    'Routes': 'tools/migration/gc-ray-allocation-routes.lua',
}.items()}
lua.globals().SOURCES = lua.table_from(sources)
result = lua.execute(r'''
local function Load(source,env)return assert(load(source,'@actual-source','t',env or _ENV))()end
local Factory=Load(SOURCES.Factory);local Routes=Load(SOURCES.Routes)
local function Modules()
 local math3=Load(SOURCES.Math)
 local env=setmetatable({require=function(name)assert(name=='core.Math3');return math3 end},{__index=_ENV})
 return {math=math3,ray=Load(SOURCES.Ray,env)}
end
local old,new=Modules(),Modules();local original=new.ray.Cast;local mathOriginal=new.math.Rotate
local probe=Factory.New{gc=collectgarbage,clock=function()return math.floor(os.clock()*1000)end,capacity=8,deadlineMs=250}
local observer=Routes.Install(probe,new.ray,new.math)
local checks,cases=0,0
local function Equal(a,b,path)
 checks=checks+1;assert(type(a)==type(b),path..' type')
 if type(a)=='table'then
  for k,v in pairs(a)do Equal(v,b[k],path..'.'..tostring(k))end
  for k in pairs(b)do assert(a[k]~=nil,path..' extra')end
 elseif type(a)=='number'then assert(string.pack('d',a)==string.pack('d',b),path..' bits')
 else assert(a==b,path..' value')end
end
local function Vehicle()
 return {body={translation=function()return {x=2,y=3,z=-4}end,rotation=function()return {x=0,y=0,z=0,w=1}end},
 spec={boxes={{center={0,0,0},half={1,1,1},partId='hull'}},hulls={},sensors={}},
 wheels={{center={1,0,1},conn={1,0,1},down={0,-1,0},drop=.2,axle={1,0,0},radius=.7,width=.4,partId='wheel'}},
 legHitboxes={items={{center={-1,0,1},half={.2,.6,.2},quat={x=0,y=0,z=.1,w=math.sqrt(.99)},partId='leg'}}}}
end
local a,b=Vehicle(),Vehicle();local randomState=0x1234
local function R()
 randomState=(1664525*randomState+1013904223)&0xffffffff
 return randomState/4294967296
end
for i=1,4000 do
 if i%7==0 then a.rayBounds=nil;b.rayBounds=nil end
 local o,d={2+(R()-.5)*12,3+(R()-.5)*6,-4+(R()-.5)*12},{R()-.5,R()-.5,R()-.5}
 d=old.math.Normalize(d);local length=R()*25
 local left,right=old.ray.Cast(a,o,d,length),new.ray.Cast(b,o,d,length)
 if left then left.body=nil end;if right then right.body=nil end
 Equal(left,right,'ray.'..i);Equal(a.rayBounds,b.rayBounds,'bounds.'..i);cases=cases+1
end
local finalRandom=randomState
for sample=1,8 do
 probe:Capture(sample,function()
  for i=1,20 do
   if i==1 then b.rayBounds=nil end
   new.ray.Cast(b,{2,3,-10},{0,0,1},20)
  end
 end)
end
assert(randomState==finalRandom,'Observer consumes no RNG')
local report=probe:Report();local rows={};for _,row in ipairs(report.totals)do rows[row.name]=row end
assert(rows['gcRay.Cast'].calls==160)
assert(rows['gcRay.coldBounds'].calls==8 and rows['gcRay.cachedBounds'].calls==152)
assert(rows['gcRay.math.Rotate'].calls>0 and rows['gcRay.math.Sub'].calls>0)
for _,f in ipairs(report.frames)do
 local total=0;for _,row in ipairs(f.rows)do assert(row.errors==0);total=total+row.selfKiB end
 assert(math.abs(total-f.measuredKiB)<1e-6,'Exclusive allocation conservation')
 assert(f.complete and f.restored and f.error==false,'Complete samples only')
end
probe:Restore();probe:Restore()
assert(observer.Restored()and observer.Depth()==0)
assert(new.ray.Cast==original and new.math.Rotate==mathOriginal,'Exact function restore')
local outside=Factory.New{gc=collectgarbage,clock=function()return 0 end,capacity=1}
local outsideObserver=Routes.Install(outside,new.ray,new.math)
outside:Capture(1,function()for i=1,10 do new.math.Add({1,2,3},{4,5,6})end end)
for _,row in ipairs(outside:Report().totals)do assert(row.calls==0,'Exclude math outside ray')end
outside:Restore();assert(outsideObserver.Restored())
local failure=Factory.New{gc=collectgarbage,clock=function()return 0 end,capacity=1}
local bad={Cast=function()error('intentional ray failure')end};local badOriginal=bad.Cast
local errorObserver=Routes.Install(failure,bad,new.math)
local ok,err=pcall(function()failure:Capture(1,function()bad.Cast({})end)end)
assert(not ok and tostring(err):find('intentional ray failure',1,true))
assert(errorObserver.Depth()==0 and collectgarbage('isrunning'),'Error unwind and GC restore')
failure:Restore();assert(errorObserver.Restored()and bad.Cast==badOriginal,'Error function restore')
return {status='PASS',cases=cases,checks=checks,cold=rows['gcRay.coldBounds'].calls,
 warm=rows['gcRay.cachedBounds'].calls,rayCalls=rows['gcRay.Cast'].calls,restored=true,
 errorsRestored=true,outsideMathExcluded=true,rngUntouched=true}
''')
plain = dict(result.items())
plain['sourceSha256'] = {name: hashlib.sha256(value.encode()).hexdigest() for name, value in sources.items()}
plain['boundary'] = ('Actual Lua54 VehicleRay, Math3, allocation factory and routing observer. Native body pose uses fixed doubles. '
                     'No Runtime, browser, hardware, production edits, CPU benchmark or FPS acceptance. '
                     'Stopped GC is used only for eight bounded allocation-observer checks.')
if args.prepared:
    paired = json.loads((args.prepared / 'paired-identity.json').read_text(encoding='utf-8'))
    production = []
    for output in paired['outputs']:
        target = Path(output['target'])
        identity = json.loads((target / 'identity.json').read_text(encoding='utf-8'))
        for relative, expected in identity['sourceHashes'].items():
            actual = (target / relative).read_bytes()
            assert hashlib.sha256(actual).hexdigest() == expected, relative
        for relative in ('scripts/vehicle-allocation-probe.lua', 'scripts/qa-single-step-allocation.lua'):
            lua.globals().COMPILE_SOURCE = (target / relative).read_text(encoding='utf-8')
            lua.execute('assert(load(COMPILE_SOURCE))')
        production.append({relative: digest for relative, digest in identity['sourceHashes'].items()
                           if relative not in {'scripts/vehicle-allocation-probe.lua',
                                               'scripts/qa-single-step-allocation.lua',
                                               'scripts/gc-ray-allocation-routes.lua'}})
    assert production[0] == production[1]
    plain['preparedPair'] = {'status': 'READY_NOT_RUN', 'identicalProductionInputs': len(production[0]),
                             'identicalProductionLuaModules': sum(key.endswith('.lua') for key in production[0]),
                             'qaEntriesCompile': True, 'sourceHashesVerified': True}
encoded = json.dumps(plain, indent=2)
if args.output:
    with args.output.open('x', encoding='utf-8') as stream:
        stream.write(encoded + '\n')
print(encoded)

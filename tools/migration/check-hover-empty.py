"""Execute actual Lua HoverControl before/candidate; no Runtime or timing claim."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source = (ROOT / '.tmp/vehicle-ray-normal-fd97-A/scripts/drive/HoverControl.lua').read_text(encoding='utf-8')
candidate = subprocess.check_output([
    'node', '-e', 'const fs=require("fs");process.stdout.write(require("./tools/migration/hover-empty-candidate.cjs").candidate(fs.readFileSync(".tmp/vehicle-ray-normal-fd97-A/scripts/drive/HoverControl.lua","utf8")));'
], cwd=ROOT, text=True, encoding='utf-8')
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().BEFORE = source
lua.globals().AFTER = candidate
lua.execute("package.path='scripts/?.lua;?.lua;'..package.path;package.loaded['drive.TerrainObstacles']={SUPPORT_MASK=19};package.loaded['drive.Capabilities']={}")
result = lua.execute(r'''
local old=assert(load(BEFORE))();local new=assert(load(AFTER))()
local checks,cases,nonempty,empty=0,0,0,0
local function equal(a,b,label)
    checks=checks+1;assert(type(a)==type(b),label..' type')
    if type(a)=='number' then
        if a~=a then assert(b~=b,label..' NaN') else assert(string.pack('d',a)==string.pack('d',b),label..' numeric bits')end
    elseif type(a)=='table' then
        for k,v in pairs(a)do equal(v,b[k],label..'.'..tostring(k))end
        for k in pairs(b)do assert(a[k]~=nil,label..' extra '..tostring(k))end
    else assert(a==b,label..' value')end
end
local function copy(t)if type(t)~='table'then return t end;local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out end
local function run(module,hovers,mass,scale,contact)
    local calls={rotation=0,translation=0,ray=0,velocity=0,force=0};local trace={}
    local body={}
    function body.rotation()calls.rotation=calls.rotation+1;return {x=0,y=.1,z=0,w=math.sqrt(.99)}end
    function body.translation()calls.translation=calls.translation+1;return {x=-3,y=2,z=7}end
    function body.velocityAtPoint(p)calls.velocity=calls.velocity+1;trace[#trace+1]={'velocity',copy(p)};return {x=.4,y=-.2,z=.6}end
    function body.addForceAtPoint(f,p,wake)calls.force=calls.force+1;trace[#trace+1]={'force',copy(f),copy(p),wake}end
    local space={}
    function space:Raycast(p,d,length,b,ignore,flag,mask)
        calls.ray=calls.ray+1;assert(b==body and ignore==nil and flag==false and mask==19)
        trace[#trace+1]={'ray',copy(p),copy(d),length}
        if calls.ray%3==0 then return nil end
        return {dist=1.1,normal={0,1,0},body={velocityAtPoint=function(q)
            trace[#trace+1]={'groundVelocity',copy(q)};return {x=0,y=.05,z=0}
        end}}
    end
    local previous={obsolete=true};local v={body=body,space=space,spec={hovers=copy(hovers)},mass=mass,
        hoverStates=previous,hoverHeightScale=scale,hoverShares={one=.6,two=.4}}
    local a=module.Step(v,contact);local firstStates=v.hoverStates
    assert(a~=previous and firstStates~=previous and next(previous)=='obsolete','Fresh state, old table untouched')
    local b=module.Step(v,contact)
    assert(a~=b and firstStates~=v.hoverStates,'Fresh output/state on every call')
    return {output=a,nextOutput=b,states=v.hoverStates,trace=trace},calls
end
local configurations={{},{{partId='one',works=false,pos={1,0,1},dir={0,1,0},height=2,load=300}},
    {{partId='one',works=true,pos={1,0,1},dir={0,1,0},height=2,load=300,emits={{pos={1,0,1}}}},
     {partId='two',works=true,pos={-1,0,1},dir={0,1,0},height=2.5,load=400,emits={{pos={-1,0,1}},{pos={0,0,1}}}}}}
for _,hovers in ipairs(configurations)do
 for _,mass in ipairs({500,1e-12,1e20,0.0,-0.0,-500,math.huge,-math.huge,0/0})do
  for _,scale in ipairs({false,.6,1,1.7,-0.0,math.huge})do
   for _,contact in ipairs({false,0,500,10000})do
    local actualContact=contact or nil
    local a,ac=run(old,hovers,mass,scale,actualContact);local b,bc=run(new,hovers,mass,scale,actualContact)
    equal(a,b,'exact states/results/force-ray sequence');cases=cases+1
    if #hovers==0 then
        empty=empty+1;assert(ac.rotation==2 and ac.translation==2 and bc.rotation==0 and bc.translation==0)
        assert(ac.ray==0 and bc.ray==0 and ac.force==0 and bc.force==0)
    else nonempty=nonempty+1;equal(ac,bc,'nonempty call counts')end
   end
  end
 end
end
-- Actual Body.Wrap read-scope caches native pose, even though each wrapper getter
-- still creates a fresh Lua result. A skipped wrapper is not skipped native IO.
Vector3={ZERO={x=0,y=0,z=0}}
package.loaded['core.Coord']={Vec=function(x,y,z)return {x=-x,y=y,z=z}end}
local Body=assert(loadfile('.tmp/vehicle-ray-normal-fd97-A/scripts/physics/Body.lua'))()
local scoped={}
for index,module in ipairs({old,new})do
    local values={mass=0,position={x=2,y=3,z=4},rotation={x=0,y=0,z=0,w=1}}
    local reads={};local native=setmetatable({node={}},{__index=function(_,key)
        reads[key]=(reads[key]or 0)+1;return values[key]
    end})
    local body=Body.Wrap(native);local getterCalls={rotation=0,translation=0}
    for _,key in ipairs({'rotation','translation'})do
        local original=body[key];body[key]=function()getterCalls[key]=getterCalls[key]+1;return original()end
    end
    local guard <close> = body.beginReadScope()
    body.rotation();body.translation();reads.position=0;reads.rotation=0
    getterCalls.rotation=0;getterCalls.translation=0
    local result=module.Step({body=body,mass=500,spec={hovers={}},hoverHeightScale=1},0)
    scoped[index]={wrapperRotation=getterCalls.rotation,wrapperTranslation=getterCalls.translation,
        nativePosition=reads.position,nativeRotation=reads.rotation,result=result}
end
equal(scoped[1].result,scoped[2].result,'Actual Body read-scope results')
assert(scoped[1].wrapperRotation==1 and scoped[1].wrapperTranslation==1)
assert(scoped[2].wrapperRotation==0 and scoped[2].wrapperTranslation==0)
assert(scoped[1].nativePosition==0 and scoped[1].nativeRotation==0)
assert(scoped[2].nativePosition==0 and scoped[2].nativeRotation==0)
return {cases=cases,checks=checks,empty=empty,nonempty=nonempty,scoped=scoped}
''')
print(json.dumps({'status': 'PASS_EXACT_LUA_BEHAVIOR', 'cases': result['cases'],
                  'checks': result['checks'], 'empty': result['empty'], 'nonempty': result['nonempty'],
                  'productionChanged': False,
                  'actualBodyPrewarmedScope': {
                      'beforeWrapperPoseCalls': 2, 'afterWrapperPoseCalls': 0,
                      'beforeNativePoseReads': 0, 'afterNativePoseReads': 0},
                  'boundary': 'Exact results/state/trace and fresh table identity; nonempty getter/force/ray counts unchanged. Empty path skips two Lua Body wrapper getters per call, not necessarily native reads inside Body read scope. No CPU gain or FPS claim.'}))

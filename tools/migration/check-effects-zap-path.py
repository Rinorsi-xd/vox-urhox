"""Compare complete real Effects.Update/Batch submissions, no renderer timing."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

candidate = ROOT / '.tmp/perf-effects-zap-path-1017/CombatEffects-candidate.lua'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().READ_SOURCE = lambda name: (ROOT / name).read_text(encoding='utf-8-sig')
lua.globals().CANDIDATE = candidate.read_text(encoding='utf-8-sig')
result = lua.execute(r'''
local noop=function()end
local originalRequire=require
local function F32(x)return string.unpack('f',string.pack('f',x))end
local function Vec3(x,y,z)return {x=F32(x),y=F32(y),z=F32(z)}end
Vector3=setmetatable({RIGHT=Vec3(1,0,0),UP=Vec3(0,1,0)},{__call=function(_,...)return Vec3(...)end})
Vector2=function(x,y)return {x=F32(x),y=F32(y)}end
Vector4=function(x,y,z,w)return {x=F32(x),y=F32(y),z=F32(z),w=F32(w)}end
Color=function(r,g,b,a)return {r=F32(r),g=F32(g),b=F32(b),a=F32(a)}end
Variant=function(v)return v end;TRIANGLE_LIST=0
local hash,calls
local function Record(name,...)
 calls=calls+1
 local function Bytes(s)for i=1,#s do hash=(hash~s:byte(i))*0x100000001b3 end end
 Bytes(name)
 for i=1,select('#',...)do local x=select(i,...);assert(type(x)=='number');Bytes(string.pack('<d',x))end
end
local function Mesh()
 return {BeginGeometry=function(_,i,p)Record('begin',i,p)end,
 DefineVertex=function(_,v)Record('p',v.x,v.y,v.z)end,
 DefineNormal=function(_,v)Record('n',v.x,v.y,v.z)end,
 DefineColor=function(_,v)Record('c',v.r,v.g,v.b,v.a)end,
 DefineTexCoord=function(_,v)Record('u',v.x,v.y)end,
 DefineTangent=function(_,v)Record('t',v.x,v.y,v.z,v.w)end,
 Commit=function()Record('commit')end}
end
Material={new=function()return {SetSurfaceShader=function()return true end,SetShaderParameter=noop,Dispose=noop}end}
local function Node()
 return {CreateChild=function()return Node()end,CreateComponent=function()return Mesh()end,Dispose=noop}
end
local mods={['core.Rotations']={},['render.Quality']={current={name='desktop',weaponArcSegments=2400}}}
require=function(name)
 if mods[name] then return mods[name]end
 local real={['core.Math3']='scripts/core/Math3.lua',['core.Coord']='scripts/core/Coord.lua',
 ['render.EffectBatch']='scripts/render/EffectBatch.lua'}
 if real[name]then mods[name]=assert(load(READ_SOURCE(real[name]),real[name]))();return mods[name]end
 return {}
end
local Batch=require 'render.EffectBatch'
local baseSource=READ_SOURCE('scripts/render/CombatEffects.lua')
local old=assert(load(baseSource,'EffectsBaseline'))();local new=assert(load(CANDIDATE,'EffectsCandidate'))()
local rotation=setmetatable({},{__mul=function(_,v)return Vec3(v.x,v.y,v.z)end})
local camera={worldPosition=Vec3(8,7,-12),worldRotation=rotation}
local function Run(module,count,limit,variant)
 math.randomseed(17102026+count*31+variant)
 local f=setmetatable({root=Node(),time=0,batches={},beams={},flares={},rings={},particles={},smoke={},flashes={},zaps={},trails={},
 chips={Update=noop},missiles={Update=noop},light={Update=noop},groundAt=function()return 0 end},module)
 for _,kind in ipairs({'Ribbon','Streak','Glow','Ring','Smoke'})do f.batches[kind]=Batch.New(Node(),kind,limit)end
 f.batches.Arc=Batch.New(Node(),'Ribbon',limit)
 local frames={}
 for frame=1,48 do
  if frame%11==1 then for i=1,count do if #f.zaps<64 then
   local a={i*1.13-8,3.2+i*.17,11.2+i*.27}
   local b=variant==1 and {table.unpack(a)} or variant==2 and {a[1],a[2]+5,a[3]} or {a[1]+3.7,a[2]-.23,a[3]+5.9}
   f.zaps[#f.zaps+1]={a=a,b=b,age=0,life=.06+(i%9)*.017,width=.03+i*.002}
  end end end
  hash=0xcbf29ce484222325;calls=0
  f:Update(frame%7==0 and .05 or 1/60,{},camera)
  local state={};for _,e in ipairs(f.zaps)do state[#state+1]={e.age,e.life,e.width,table.unpack(e.a)}end
  local batches={};for _,name in ipairs({'Ribbon','Streak','Glow','Ring','Smoke','Arc'})do
   local b=f.batches[name];if b then batches[#batches+1]={name,b.count,b.mesh.enabled}end
  end
  frames[frame]={digest=string.format('%016x',hash),calls=calls,zapCount=#f.zaps,state=state,batches=batches}
 end
 local tail={};for i=1,32 do tail[i]=math.random()end
 return {frames=frames,randomTail=tail}
end
local checks=0;local cases={}
local function Equal(a,b,path)
 assert(type(a)==type(b),path..':type')
 if type(a)~='table'then checks=checks+1;assert(a==b,path..':value');return end
 for k,v in pairs(a)do Equal(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..':extra')end
end
for _,count in ipairs({0,1,8,64})do for _,limit in ipairs({0,1,2400})do for variant=0,2 do
 local a=Run(old,count,limit,variant);local b=Run(new,count,limit,variant)
 Equal(a,b,'count'..count..'/limit'..limit..'/variant'..variant)
 cases[#cases+1]={count=count,limit=limit,variant=variant,frames=#a.frames}
end end end
return {checks=checks,cases=cases,status='PASS'}
''')
def plain(value):
    if hasattr(value, 'items'):
        entries = list(value.items())
        if all(isinstance(k, int) for k, _ in entries):
            return [plain(value[i]) for i in range(1, len(entries) + 1)]
        return {k: plain(v) for k, v in entries}
    return value

report = plain(result)
report['baselineSha256'] = hashlib.sha256((ROOT / 'scripts/render/CombatEffects.lua').read_bytes()).hexdigest()
report['candidateSha256'] = hashlib.sha256(candidate.read_bytes()).hexdigest()
report['boundary'] = 'Real complete CombatEffects.Update and EffectBatch, float32 native-value and draw-call adapters. Per-frame complete vertex-attribute/order hash, state, batch visibility and RNG tails; 36 cases. No actual native geometry/GPU, CPU improvement, full combat or target-device FPS acceptance.'
target = ROOT / '.tmp/perf-effects-zap-path-1017/offline-equivalence.json'
target.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: v for k, v in report.items() if k != 'cases'}))

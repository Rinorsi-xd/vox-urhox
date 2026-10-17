"""Offline actual Effects.Update outputs and section guard lifecycle; no timing run."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

fixture = ROOT / '.tmp/monitor-combat-effects-2a97-a'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().READ = lambda p: (ROOT / p).read_text(encoding='utf-8-sig')
lua.globals().BASE = READ_BASE = (ROOT / 'scripts/render/CombatEffects.lua').read_text(encoding='utf-8-sig')
lua.globals().DERIVED = (fixture / 'scripts/render/CombatEffects.lua').read_text(encoding='utf-8-sig')
lua.globals().OBSERVER = (ROOT / 'tools/migration/monitor-combat-effects-observer.lua').read_text(encoding='utf-8-sig')
result = lua.execute(r'''
local noop=function()end
local modules={['render.CombatLight']={},['render.MissileEffects']={},['render.MissileView']={},
 ['render.DrillEffects']={},['render.EffectBatch']={},['render.Quality']={current={name='desktop'}},
 ['render.ChipEffects']={},['render.CombatSourceFx']={Bolt=noop}}
require=function(name)
 if modules[name]then return modules[name]end
 if name=='core.Math3' then modules[name]=assert(load(READ('scripts/core/Math3.lua')))();return modules[name]end
 error('Unexpected require '..name)
end
local old=assert(load(BASE,'EffectsBaseline'))();local new=assert(load(DERIVED,'EffectsDerived'))()
local rows,scopes,events={},{},{}
local function clone(value)
 if type(value)~='table'then return value end
 local result={};for k,v in pairs(value)do result[k]=clone(v)end;return result
end
local function record(kind,...)
 local values={kind};for i=1,select('#',...)do values[#values+1]=clone(select(i,...))end
 rows[#rows+1]=values
end
Vector3={RIGHT={x=1,y=0,z=0},UP={x=0,y=1,z=0}}
local rotation=setmetatable({},{__mul=function(_,v)return v end})
local camera={worldPosition={x=8,y=7,z=9},worldRotation=rotation}
local function batch()
 return {Begin=function(_,...)record('begin',...)end,Segment=function(_,...)record('segment',...)end,
 Disc=function(_,...)record('disc',...)end,Finish=function()record('finish')end}
end
local function Make(module)
 local fx=setmetatable({time=0,maxHelix=64,particles={},smoke={},beams={},flares={},trails={},zaps={},rings={},flashes={},
 chips={Update=function(_,dt)record('chips',dt)end},missiles={Update=function(_,dt,projectiles)record('missiles',dt,projectiles)end},
 light={Update=function(_,dt)record('light',dt)end},groundAt=function(x,z)return .2*x-.1*z end,batches={}},module)
 for _,kind in ipairs({'Ribbon','Streak','Glow','Ring','Smoke','Arc'})do fx.batches[kind]=batch()end
 fx.particles={{pos={1,3,2},vel={.2,-.5,.1},color={3,2,1},size=.1,life=.8,age=0,drag=2,grav=9,grow=.02},
  {pos={2,-3,1},vel={1,-2,3},color={1,2,3},size=.2,life=.04,age=0,drag=1,grav=2}}
 fx.smoke={{pos={-1,2,1},vel={1,2,3},color={.2,.2,.2},size=1,life=1.2,age=0,drag=.4,grav=0,grow=.3}}
 fx.beams={{from={0,2,0},to={0,2,5},dir={0,0,1},tier=4,kind='sniper',len=5,age=0,grow=.035,life=.5,phase=.4,hitDone=true}}
 fx.flares={{base={1,2,3},tip={2,3,4},width=.2,color={1,2,3},life=.1,age=0}}
 fx.trails={{from={0,2,0},to={0,2,5},dir={0,0,1},len=5,age=0,life=.75,next=0}}
 fx.zaps={{a={1,2,3},b={4,5,6},width=.04,life=.2,age=0}}
 fx.rings={{pos={0,2,0},dir={0,1,0},r0=.1,r1=2,life=.3,delay=.02,age=0,color={1,2,3},alpha=.8,thick=.2}}
 fx.flashes={{pos={1,2,3},size=1,life=.1,age=0,color={1,2,3}}}
 return fx
end
local stack={};local tokens={};local started,ended=0,0
performance={enabled=true,recording=true}
function performance:Begin(label)
 local depth=#stack+1;local token=tokens[depth]or {};tokens[depth]=token
 assert(not token.active);token.label=label;token.active=true;stack[depth]=token;started=started+1
 events[#events+1]={'begin',label};return token
end
function performance:End(token)
 assert(stack[#stack]==token and token.active,'Scope close mismatch')
 token.active=false;stack[#stack]=nil;ended=ended+1;events[#events+1]={'end',token.label}
end
function performance:Wrap(module,key,label)assert(type(module[key])=='function')end
app={trial={vehicle={}}};GetTime=function()return {frameNumber=100}end
local pressed=false;input={GetKeyPress=function()local p=pressed;pressed=false;return p end};KEY_F9=1
local log={};cjson={encode=function(value)return tostring(value)end};print=function(value)log[#log+1]=value end
HandleUpdate=noop;HandleFramePresented=noop
assert(load(OBSERVER,'Observer'))()
local callback=_G.VOX_EFFECTS_SECTION_PROBE;assert(type(callback)=='function')
local checks=0
local function Equal(a,b,path)
 assert(type(a)==type(b),path..' type')
 if type(a)~='table' then checks=checks+1;assert(a==b,path..' value');return end
 for k,v in pairs(a)do Equal(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' extra')end
end
local function Run(module)
 math.randomseed(1017);local fx=Make(module);local frames={}
 for frame=1,24 do
  rows={};fx:Update(frame%7==0 and .05 or 1/60,{},camera)
  frames[frame]={calls=rows,particles=clone(fx.particles),smoke=clone(fx.smoke),beams=clone(fx.beams),
   flares=clone(fx.flares),trails=clone(fx.trails),zaps=clone(fx.zaps),rings=clone(fx.rings),flashes=clone(fx.flashes)}
  assert(#stack==0,'All scopes closed after actual Update')
 end
 local rng={};for i=1,16 do rng[i]=math.random()end
 return {frames=frames,rng=rng}
end
local a=Run(old);local b=Run(new);Equal(a,b,'ActualUpdate')
assert(started==24*13 and ended==started,'Exactly thirteen whole sections per Update')
local labels={};for _,entry in ipairs(events)do if entry[1]=='begin'then labels[entry[2]]=true end end
local count=0;for _ in pairs(labels)do count=count+1 end;assert(count==13)
performance.recording=false;local before=started;Run(new);assert(started==before,'No scopes while monitor is inactive')
performance.recording=true;local disposed=Make(new);disposed.disposed=true;disposed:Update(.01,{},camera);assert(started==before)
local failure={};local bad=Make(new);bad.light.Update=function()error(failure)end
local ok,err=pcall(bad.Update,bad,.01,{},camera);assert(not ok and err==failure,'Original error object preserved')
assert(#stack==0 and started==ended,'Exception closes last current section')
assert(_G.VOX_EFFECTS_SECTION_PROBE==nil,'Exception restores original global')
_G.VOX_EFFECTS_SECTION_PROBE=callback
for _,entry in ipairs({'render.EffectBatch','render.CombatLight','render.RotorView','render.ActuatorView','render.LegView','render.MechView','render.EquipmentEffects'})do
 modules[entry]=modules[entry]or {};modules[entry].Update=noop;modules[entry].Finish=noop
end
HandleUpdate();pressed=true;HandleUpdate();pressed=true;HandleUpdate();HandleFramePresented()
assert(_G.VOX_EFFECTS_SECTION_PROBE==nil,'Complete-frame stop restores global')
return {status='EFFECT_SECTION_OFFLINE_PASS',checks=checks,frames=24,sectionCount=count,
 errorIdentityPreserved=true,normalAndErrorScopeRestoration=true,completeFrameCallbackRestored=true}
''')
print(json.dumps(dict(result), indent=2))

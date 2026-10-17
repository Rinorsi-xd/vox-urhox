local beforeSusp,afterSusp,beforeSpace,afterSpace,scopeSource=...
package.path='scripts/?.lua;'..package.path
local Math=require 'core.Math3'
local ticks=0
Time={GetSystemTime=function()ticks=ticks+1;return ticks end}
local Probe=assert(load(scopeSource))();Probe.active=true
local callers={['suspension.Sample']=true,['leg.Cast']=true,['stability.Step']=true,['hover.Step']=true}
function Probe.Caller()for i=#Probe.stack,1,-1 do if callers[Probe.stack[i].name]then return Probe.stack[i].name end end;return 'other'end
local assertions=0
local function equal(a,b)
 assertions=assertions+1;assert(type(a)==type(b))
 if type(a)=='number'then assert(math.type(a)==math.type(b)and string.pack('d',a)==string.pack('d',b))
 elseif type(a)=='table'then for k,v in pairs(a)do equal(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
 else assert(a==b)end
end
local function copy(x)if type(x)~='table'then return x end;local t={};for k,v in pairs(x)do t[k]=copy(v)end;return t end
local modules={['core.Math3']=Math,['drive.TerrainObstacles']={SUPPORT_MASK=7},['construction.Rotors']={AxisQuat=function(axis,a)local s=math.sin(a/2);return {x=axis[1]*s,y=axis[2]*s,z=axis[3]*s,w=math.cos(a/2)}end},
 ['core.Coord']={Vec=function(x,y,z)return {x=-x,y=y,z=z}end},['physics.Body']={Wrap=function(n)return n.wrapper end}}
local env=setmetatable({require=function(n)return assert(modules[n],n)end,_G={G1_WEB_CPU_SUPPORT_SCOPE=Probe},
 Ray=function(p,d)return {p=p,d=d}end},{__index=_G})
local function module(source)return assert(load(source,'support fixture','t',env))()end
local a,b,sa,sb=module(beforeSusp),module(afterSusp),module(beforeSpace),module(afterSpace)
local function suspension(mod,scenario)
 local log={};local velocity={x=2,y=-.5,z=4}
 local function record(name,...)log[#log+1]={name,...}end
 local body={rotation=function()return {x=0,y=math.sin(.2),z=0,w=math.cos(.2)}end,
  applyImpulseAtPoint=function(value,point,active)record('impulse',copy(value),copy(point),active);velocity={x=velocity.x+value.x*.001,y=velocity.y+value.y*.001,z=velocity.z+value.z*.001}end,
  velocityAtPoint=function(p)record('velocity',copy(p));return copy(velocity)end,
  impulseDenominator=function(p,d)record('denominator',copy(p),copy(d));return 1.25 end,
  center=function()record('center');return {x=.3,y=.2,z=-.1}end}
 local ground={velocityAtPoint=function(p)record('groundVelocity',copy(p));return {x=.2,y=0,z=-.1}end,
  impulseDenominator=function(p,d)record('groundDenominator',copy(p),copy(d));return .25 end}
 local vehicle={body=body,wheels={}};local states={}
 for i=1,({0,1,4,16})[scenario%4+1]do
  vehicle.wheels[i]={contactAxle={-1,0,0},maxForce=700,friction=1.8,radius=.4,rotor=scenario%3==0 and i%2==0 or nil,down={0,-1,0}}
  states[i]={grounded=scenario%5~=0 and i%3~=0,normal={0,1,0},force=200+i,point={i*.2,.1,i*.3},hard={i*.2,.4,i*.3},
   steer=.2,engine=scenario%2==0 and 10 or 0,brake=2,side=.8,spin=0,deltaSpin=.3,groundBody=scenario%2==0 and ground or nil}
 end
 local self=setmetatable({vehicle=vehicle,states=states},mod)
 for i=1,3 do Probe.Enter('suspension.Apply');self:Apply(1/60);Probe.Leave()end
 for _,state in ipairs(states)do state.groundBody=nil end
 return {states=states,log=log,velocity=velocity}
end
for scenario=1,32 do equal(suspension(a,scenario),suspension(b,scenario));Probe.AssertClosed()end
local function ray(mod,scenario,caller)
 local wrapped={tag='wrapped'};local own={tag='registered'};local owner={type='ground'}
 local bodies={},{};local hits={};local nodes={}
 for i=1,6 do
  local native={node={GetID=function()return i end},mass=i%2,trigger=i==1,kinematic=i==3,wrapper=wrapped}
  nodes[i]=native;hits[i]={body=native,distance=i*.3,position={x=i,y=i+1,z=i+2},normal={x=.25,y=.5,z=.75}}
  if i%2==0 then bodies[i]={body=own,owner=owner}end
 end
 if scenario%7==0 then hits={}end
 if scenario%11==0 then hits[1]={distance=0}end
 local log={};local self=setmetatable({bodies=bodies,world={Raycast=function(_,value,length,mask)
  log[#log+1]={ray=copy(value),length=length,mask=mask};return hits
 end}},mod)
 local excluded=scenario%3==0 and {native=nodes[2]}or nil
 Probe.Enter(caller);Probe.Enter('physics.Raycast')
 local hit=self:Raycast({-2,0,1},{0,-1,0},10,excluded,scenario%5==0 and 'ground'or nil,scenario%2==0,scenario%4==0 and 0 or nil)
 Probe.Leave();Probe.Leave();Probe.AssertClosed()
 return {hit=hit and {dist=hit.dist,point=hit.point,normal=hit.normal,body=hit.body.tag,owner=hit.owner,collider=hit.collider}or false,log=log}
end
for scenario=1,80 do for _,caller in ipairs({'suspension.Sample','leg.Cast','stability.Step','hover.Step','vehicle.Step'})do equal(ray(sa,scenario,caller),ray(sb,scenario,caller))end end
for _,phase in ipairs({'apply.support','apply.contact','apply.impulses'})do assert(Probe.rows[phase].calls==96)end
for _,caller in ipairs({'suspension.Sample','leg.Cast','stability.Step','hover.Step','other'})do
 for _,phase in ipairs({'construct','native','filter'})do assert(Probe.rows['ray.'..caller..'.'..phase].calls==80)end
end
local selfTotal,rootTotal=0,0
for name,row in pairs(Probe.rows)do assert(row.selfMs>=0 and row.selfMs<=row.ms);selfTotal=selfTotal+row.selfMs
 if name=='suspension.Apply'or callers[name]or name=='vehicle.Step'then rootTotal=rootTotal+row.ms end
end
assert(selfTotal==rootTotal,'Nested scope self conservation')
return {status='PASS',assertions=assertions,suspensionCases=32,rayCases=400,scopeSelfConserves=true,
 boundary='Real full module arithmetic/call ordering against dependency adapters, fake clock only. No Bullet/Web timing.'}

package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local V=require 'core.Math3'
local ticks=0
Time={GetSystemTime=function()ticks=ticks+1;return ticks end}
local Scope=assert(load(SCOPE_SOURCE,'@perf-drive-sections-scope.lua'))()
_G.VOX_DRIVE_SCOPE=Scope;Scope.active=true
local checks=0
local function Equal(a,b,path)
 if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));checks=checks+1;return end
 assert(type(b)=='table',path..' type')
 for key,value in pairs(a) do Equal(value,b[key],path..'.'..tostring(key)) end
 for key in pairs(b) do assert(a[key]~=nil,path..' extra '..tostring(key)) end
end
local function Copy(a)
 if type(a)~='table' then return a end
 local out={};for key,value in pairs(a) do out[key]=Copy(value) end;return out
end
local function GaitRun(source,profile)
 local Gait=assert(load(source,'@drive/LegGait.lua'))();local log={};local c={list={}}
 for side=-1,1,2 do for z=-2,2,2 do
  c.list[#c.list+1]={leg={pos={side*.8,1.2,z},toe={side*1.8,0,z},out={side,0,0},height=1.2,reach=3,stepHeight=.8},group=#c.list%2,jumpGlow=.5}
 end end
 local step=0;local casts=0
 function c:Cast(p,d,distance)
  casts=casts+1;log[#log+1]={'ray',Copy(p),Copy(d),distance}
  if profile==3 and (casts%11==0 or step%100>80) then return nil end
  local best=nil
  if d[2]<-1e-9 then local t=-p[2]/d[2];if t>=0 and t<=distance then best={point=V.Add(p,V.Scale(d,t)),normal={0,1,0},distance=t,collider=1} end end
  if profile==2 and math.abs(d[1])>1e-9 then local t=(5-p[1])/d[1];if t>=0 and t<=distance and (not best or t<best.distance) then best={point=V.Add(p,V.Scale(d,t)),normal={-1,0,0},distance=t,collider=2} end end
  return best
 end
 function c:Reachable(s,foot,q,p)
  log[#log+1]={'reachable',Copy(foot)}
  return V.Length(V.Sub(foot,V.Add(p,V.RotateUnit(q,s.leg.pos))))<3.2
 end
 function c:Clear(s,foot,q,p,from)
  log[#log+1]={'clear',Copy(foot),from or 0};return profile~=3 or casts%4~=0
 end
 function c:Target(s,foot,q,p)return V.Sub(V.RotateUnit(V.Inverse(q),V.Sub(foot,p)),s.leg.pos)end
 Gait.Setup(c)
 local snapshots={}
 for index=1,240 do
  step=index;local speed=index%90<60 and 2 or .05
  local body={linvel=function()return {x=profile==2 and 1 or 0,y=index%80>65 and -2 or 0,z=speed}end,
   angvel=function()return {x=0,y=.05,z=0}end,velocityAtPoint=function(point)return {x=.05*point.z,y=0,z=speed-.05*point.x}end}
  local a=index*.0008;local q={x=0,y=math.sin(a),z=0,w=math.cos(a)};local p={profile==2 and index*.01 or 0,0,index*.006}
  for _,s in ipairs(c.list)do s.support=index%5~=0 and {} or nil end
  Gait.Step(c,1/60,{q=q,p=p,up={0,1,0},surf={0,1,0},body=body,supported=index%80<65})
  Scope.AssertClosed()
  local states={};for _,s in ipairs(c.list)do states[#states+1]=Copy({foot=s.foot,previous=s.previous,target=s.target,mode=s.mode,sw=s.sw,contact=s.contact,cycle=s.cycle,bladeAngle=s.bladeAngle,jumpGlow=s.jumpGlow})end
  snapshots[#snapshots+1]={states=states,phase=c.phase,phaseAcc=c.phaseAcc,cadence=c.cadence,settle=c.settle,parked=c.parked}
 end
 return {snapshots=snapshots,log=log,casts=casts}
end
for profile=1,3 do Equal(GaitRun(GAIT_BASE,profile),GaitRun(GAIT_PROBE,profile),'gait'..profile) end
local function ContactRun(source,variant)
 local Contact=assert(load(source,'@drive/ContactControl.lua'))();local log={};local snapshots={};local frameIndex=0
 local n=variant%3==0 and 0 or variant%3==1 and 4 or 10
 local vehicle={mass=1200,supRear=2,supFront=1.8,cgH=1.2,capabilities={wheelShare=.8},nRear=n/2,steer=0,aLong=0,vPrev=0,aLat=0,
  tracked=variant%2==0,hoverMode=variant%5==0,legMode=variant%7==0,inertiaY=3000,halfTrack=1.3,rMin=4,com={0,0,0},wheels={},steerWheels={},trackWheels={},
  spec={motion={accelFactor=.9,topSpeed=24},thrusters=variant%4==0 and {{dir={0,1,0}}} or {},wings=variant%6==0 and {{}} or {}}}
 local wheelState={};for i=1,n do
  local w={index=i,partId=i,center={i%2==0 and 1 or -1,0,i<=n/2 and 1.5 or -1.5},rear=i>n/2,steer=i<=n/2,track=vehicle.tracked,steerAngle=.6,rearFade=i>n/2,rest=.6,share=1/n}
  vehicle.wheels[i]=w;wheelState[i]={engine=0,brake=0,steer=0}
  if w.steer then vehicle.steerWheels[#vehicle.steerWheels+1]=w end
  if w.track then vehicle.trackWheels[#vehicle.trackWheels+1]=w end
 end
 local vc={};vehicle.vc=vc
 local function Grounded(i)return (i+frameIndex)%5~=0 end
 local function Get(name,fn)vc[name]=function(i)log[#log+1]={name,i};return fn(i)end end
 local function Set(name,key)vc[name]=function(i,value)log[#log+1]={name,i,value};wheelState[i][key]=value end end
 Get('wheelIsInContact',Grounded);Get('wheelSuspensionForce',function(i)return 1000+i*10 end)
 Get('wheelSuspensionLength',function(i)return .16+.02*math.sin((i+frameIndex)/4)end)
 Get('wheelHardPoint',function(i)return {x=i,y=0,z=0}end)
 Get('wheelContactNormal',function()return {x=0,y=1,z=0}end)
 Get('wheelEngineForce',function(i)return wheelState[i].engine end);Get('wheelBrake',function(i)return wheelState[i].brake end)
 Set('setWheelEngineForce','engine');Set('setWheelBrake','brake');Set('setWheelSteering','steer');Set('setWheelSideFrictionStiffness','friction')
 local body={angvel=function()return {x=.03,y=.06,z=.01}end};vehicle.body=body
 for _,key in ipairs({'addForce','addTorque','addForceAtPoint'})do body[key]=function(...)log[#log+1]={key,Copy({...})}end end
 for index=1,32 do
  frameIndex=index;local speed=(index-16)*1.3
  local result=Contact.Step(vehicle,{throttle=index%3-1,steer=math.sin(index/8),handbrake=index%7==0},1/60,
   {up={0,1,0},fwd={0,0,1},vel={1.2,0,speed},speed=speed,q={x=0,y=0,z=0,w=1}})
  Scope.AssertClosed();snapshots[#snapshots+1]=Copy({result=result,steer=vehicle.steer,aLong=vehicle.aLong,aLat=vehicle.aLat,contacts=vehicle.contactStates,wheels=wheelState})
 end
 return {log=log,snapshots=snapshots}
end
for variant=1,14 do Equal(ContactRun(CONTACT_BASE,variant),ContactRun(CONTACT_PROBE,variant),'contact'..variant) end
for _,name in ipairs({'gait.air','gait.kinematics','gait.phase','gait.stance','gait.swing','gait.free','gait.plant','gait.finish',
 'contact.inputs','contact.loads','contact.steering','contact.wheelCommands','contact.handling','contact.damping','contact.bottomout','contact.telemetry'})do
 assert(Scope.rows[name] and Scope.rows[name].calls>0,'Uncovered probe section '..name)
end
return {checks=checks,sections=Scope.rows}

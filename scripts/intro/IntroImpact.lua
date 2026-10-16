-- Payslip's root translation and own camera trauma share the actual hit cue.
local Coord=require 'core.Coord'
local M={}
function M.Terminal(I,kind,random)
 local amp,duration=1.3,.38
 if kind=='gate-close' then amp,duration=.9,.3
 elseif kind=='gate-unlock' then amp,duration=.6,.26
 elseif kind~='stamp' then return end
 random=random or math.random
 local frames={}
 for i=0,10 do
  local a=amp*(1-i/10)
  frames[i+1]={(random()*2-1)*a,(random()*2-1)*a}
 end
 I.terminalImpact={at=I.time,shot=I.shot,kind=kind,duration=duration,frames=frames}
end
local function TerminalAge(I)
 local impact=I.terminalImpact
 if not impact or I.shot~=impact.shot or not I.active or I.disposed or I.failed or I.finishing then return nil end
 local age=I.time-impact.at
 if age<0 then return nil end
 return age
end
function M.Flash(vg,I,w,h)
 local age=TerminalAge(I)
 if not age or I.terminalImpact.kind~='stamp' or age>=.2 then return end
 local alpha=.25*(1-require('ui.IntroGateMotion').Ease(age/.2,0,0,.58,1))
 require('ui.SourceDraw').Rect(vg,0,0,w,h,{255,58,42,255*alpha})
end
function M.Payslip(I,random)
 random=random or math.random
 local frames={}
 for i=0,10 do
  local a=1.6*(1-i/10)
  frames[i+1]={(random()*2-1)*a,(random()*2-1)*a}
 end
 I.payslipImpact={at=I.time,frames=frames,trauma=.8,cameraAt=I.time}
end
local function Age(I)
 local impact=I.payslipImpact
 if not impact or I.shot~='payslip' or I.skipRequested or I.failed or I.finishing then return nil end
 local age=I.time-impact.at
 if age<0 then return nil end
 return age
end
function M.Shake(I,u)
 local terminalAge=TerminalAge(I)
 if terminalAge and terminalAge<I.terminalImpact.duration then
  local impact=I.terminalImpact
  local p=terminalAge/impact.duration*10;local index=math.min(10,math.floor(p)+1);local k=p-(index-1)
  local a,b=impact.frames[index],impact.frames[index+1]
  return (a[1]+(b[1]-a[1])*k)*u,(a[2]+(b[2]-a[2])*k)*u
 end
 local age=Age(I)
 if not age or age>=.38 then return 0,0 end
 local p=age/.38*10;local index=math.min(10,math.floor(p)+1);local k=p-(index-1)
 local a,b=I.payslipImpact.frames[index],I.payslipImpact.frames[index+1]
 return (a[1]+(b[1]-a[1])*k)*u,(a[2]+(b[2]-a[2])*k)*u
end
function M.CameraPlan(I)
 local age=Age(I)
 if not age then return 0,0,0,0 end
 local trauma=I.payslipImpact.trauma
 if trauma<=.001 then return 0,0,0,trauma end
 local k,tt=trauma^2,I.time*26
 return (math.sin(tt)*.6+math.sin(tt*2.3+1)*.4)*.35*k,
  (math.sin(tt*1.13+4)*.6+math.sin(tt*2.9)*.4)*.28*k,
  math.sin(tt*.8+7)*.035*k,trauma
end
function M.Camera(I,camera)
 if not Age(I) then return end
 local x,y,roll,trauma=M.CameraPlan(I)
 if trauma>.001 then
  local node=camera.node
  node.position=node.position+Coord.Vec(x,y,0)
  -- Reflection of source-local +Z rotation reverses the angle.
  node.rotation=node.rotation*Quaternion(-roll*180/math.pi,Vector3.FORWARD)
 end
 local impact=I.payslipImpact
 impact.trauma=math.max(0,trauma-math.max(0,I.time-impact.cameraAt)*1.4);impact.cameraAt=I.time
end
return M

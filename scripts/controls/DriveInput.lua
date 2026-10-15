-- PC keyboard state and pointer-sampled fire share the simulation command.
local M={};M.__index=M
function M.New() return setmetatable({held={},lookX=0,lookY=0},M) end
function M:Clear() self.held={};self.lookX=0;self.lookY=0;self.lookPointer=nil;self.touchThrottle=0;self.touchSteer=0;self.rotorStep=false end
function M:Look(dx,dy) self.lookX=self.lookX+dx;self.lookY=self.lookY+dy end
function M:TakeLook()
    local x,y=self.lookX,self.lookY;self.lookX=0;self.lookY=0;return x,y
end
function M:Read()
    if not input.focus then self:Clear();return {throttle=0,steer=0} end
    local function Held(name,key) return self.held[name] or input:GetKeyDown(key) end
    local function Axis(positive,negative) return (positive and 1 or 0)-(negative and 1 or 0) end
    local rotorStep=input:GetKeyPress(KEY_F) or self.rotorStep==true;self.rotorStep=false
    local space=Held('jump',KEY_SPACE)==true or Held('brake',KEY_SPACE)==true
    local shift=Held('descend',KEY_SHIFT)==true or self.held.boost==true
    return {throttle=math.max(-1,math.min(1,Axis(Held("forward",KEY_W) or input:GetKeyDown(KEY_UP),Held("reverse",KEY_S) or input:GetKeyDown(KEY_DOWN))+(self.touchThrottle or 0))),
        steer=math.max(-1,math.min(1,Axis(Held("left",KEY_A) or input:GetKeyDown(KEY_LEFT),Held("right",KEY_D) or input:GetKeyDown(KEY_RIGHT))+(self.touchSteer or 0))),
        handbrake=Held("brake",KEY_SPACE),jump=Held("jump",KEY_SPACE)==true,climb=Axis(Held("climb",KEY_SPACE),Held("descend",KEY_SHIFT)),
        strafe=Axis(Held("strafeLeft",KEY_Q),Held("strafeRight",KEY_E)),cutLift=Held("cutLift",KEY_X),
        firing=self.held.fire==true,rotorStep=rotorStep,space=space,shift=shift}
end
-- Source controls.js chooses actions from the surviving vehicle capabilities.
function M:Command(command,vehicle,aimYaw,aimPitch)
    local leg=vehicle.legMode;local walker=vehicle.legControl or vehicle.mechControl
    local space=command.space;local wings=vehicle.spec.wings and #vehicle.spec.wings>0
    local jetClimb=space and (not leg or (walker and walker.airTime and walker.airTime>0 and walker.airTime<.25)
        or (not (walker and walker.airTime and walker.airTime>0) and (vehicle.telemetry.legContacts or 0)==0 and walker and walker.groundedTime==0))
    command.climb=(jetClimb and 1 or 0)-(command.shift and not (leg and vehicle.mechControl) and 1 or 0)
    command.jump=leg and space==true;command.handbrake=space==true and not leg and not wings
    command.boost=leg and vehicle.mechControl~=nil and command.shift==true
    command.aimYaw=aimYaw;command.aimPitch=aimPitch
    local function Face(target,gain,damping)
        local err=target-vehicle:Yaw();local e=err-2*math.pi*math.floor(err/(2*math.pi)+.5)
        return e,math.max(-1,math.min(1,e*gain-vehicle.body.angvel().y*damping))
    end
    if (leg or vehicle.hoverMode) and (command.throttle~=0 or command.steer~=0 or command.strafe~=0) then
        command.strafe=math.max(-1,math.min(1,command.strafe+command.steer))
        local e,steer=Face(aimYaw,3.2,.22);command.steer=math.abs(e)<.015 and 0 or steer
    end
    if self.planePoint and wings then
        local q=vehicle.body.rotation();local nose=math.asin(math.max(-1,math.min(1,2*(q.y*q.z-q.w*q.x))))
        local e,steer=Face(aimYaw,2.4,.3);local pitch=aimPitch-nose
        command.strafe=math.max(-1,math.min(1,command.strafe+(self.touchSteer or 0)))
        command.steer=math.abs(e)<.02 and 0 or steer;command.climb=math.abs(pitch)<.02 and 0 or math.max(-1,math.min(1,pitch*3))
    end
    return command
end
return M

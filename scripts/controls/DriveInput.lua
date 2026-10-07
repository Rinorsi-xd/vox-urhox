-- PC keyboard state and pointer-sampled fire share the simulation command.
local M={};M.__index=M
function M.New() return setmetatable({held={},lookX=0,lookY=0},M) end
function M:Clear() self.held={};self.lookX=0;self.lookY=0;self.lookPointer=nil;self.touchThrottle=0;self.touchSteer=0 end
function M:Look(dx,dy) self.lookX=self.lookX+dx;self.lookY=self.lookY+dy end
function M:TakeLook()
    local x,y=self.lookX,self.lookY;self.lookX=0;self.lookY=0;return x,y
end
function M:Read()
    if not input.focus then self:Clear();return {throttle=0,steer=0} end
    local function Held(name,key) return self.held[name] or input:GetKeyDown(key) end
    local function Axis(positive,negative) return (positive and 1 or 0)-(negative and 1 or 0) end
    return {throttle=(self.touchThrottle or 0)~=0 and self.touchThrottle or Axis(Held("forward",KEY_W),Held("reverse",KEY_S)),steer=(self.touchSteer or 0)~=0 and self.touchSteer or Axis(Held("left",KEY_A),Held("right",KEY_D)),
        handbrake=Held("brake",KEY_SPACE),jump=Held("jump",KEY_SPACE)==true,climb=Axis(Held("climb",KEY_SPACE),Held("descend",KEY_SHIFT)),
        strafe=Axis(Held("strafeLeft",KEY_Q),Held("strafeRight",KEY_E)),cutLift=Held("cutLift",KEY_X),
        firing=self.held.fire==true}
end
return M

-- Source CameraRig.fp in right-handed metres. Native input/camera are adapters.
local Math=require 'core.Math3'
local M={};M.__index=M
function M.New(pos,forward,limit)
    return setmetatable({pos={table.unpack(pos)},vel={0,0,0},yaw=math.atan(-forward[1],-forward[3]),pitch=math.asin(Math.Clamp(forward[2],-1,1)),limit=limit},M)
end
function M:Forward()
    local cp=math.cos(self.pitch)
    return {-math.sin(self.yaw)*cp,math.sin(self.pitch),-math.cos(self.yaw)*cp}
end
function M:Step(dt,c)
    self.yaw=self.yaw-(c.dx or 0)*.0022
    self.pitch=Math.Clamp(self.pitch-(c.dy or 0)*.0022,-1.52,1.52)
    local sy,cy=math.sin(self.yaw),math.cos(self.yaw)
    local f,r=c.forward or 0,c.right or 0
    local want={-sy*f+cy*r,c.up or 0,-cy*f-sy*r}
    want=Math.Scale(Math.Normalize(want),(c.fast and 11 or 4.5)*(c.speed or 1))
    self.vel=Math.Mix(self.vel,want,1-math.exp(-dt*10))
    local p=Math.Add(self.pos,Math.Scale(self.vel,dt));local b=self.limit
    self.pos={Math.Clamp(p[1],-b.x,b.x),Math.Clamp(p[2],b.y0,b.y1),Math.Clamp(p[3],b.z0,b.z1)}
end
function M:Stop() self.vel={0,0,0} end
return M

-- Frozen shared/drive/chaseCam.js. All state stays in H5 source coordinates.
local Math=require 'core.Math3'
local M={};M.__index=M
local DEG=180/math.pi
function M.New() local self=setmetatable({},M);self:init();return self end
function M:init() self.zoom=1;self.target={0,0,0};self.radius=0;self.dist=8;self.curDist=8;self.minY=.35 end
function M:Reset(pos,radius)
    self.radius=radius;self.dist=Math.Clamp(radius*2.3+3,6,80);self.curDist=self.dist
    self.target={pos[1],pos[2]+radius*.35+.6,pos[3]}
    return (.12+.43*Math.Clamp((radius-8)/16,0,1))*DEG
end
function M:Zoom(delta) self.zoom=Math.Clamp(self.zoom*1.0012^delta,.5,2.2) end
function M.Look(yaw,pitch,dx,dy,sensitivity,flight)
    local lo,hi=flight and -1.25 or -.42,flight and 1.25 or .8
    return yaw+dx*.0024*sensitivity*DEG,Math.Clamp(pitch+dy*.002*sensitivity*DEG,lo*DEG,hi*DEG)
end
function M:Pose(dt,pos,yaw,pitch,cast,eye)
    local t=self.target;local kx,ky=1-math.exp(-dt*20),1-math.exp(-dt*9)
    t[1]=t[1]+(pos[1]-t[1])*kx;t[3]=t[3]+(pos[3]-t[3])*kx
    t[2]=t[2]+(pos[2]+self.radius*.35+.6-t[2])*ky
    local y,p=-yaw/DEG,-pitch/DEG;local cp=math.cos(p)
    local forward={math.sin(y)*cp,math.sin(p),math.cos(y)*cp}
    if eye then return {eye=eye,forward=forward,target=t} end
    local d=self.dist*self.zoom;local off={-forward[1]*d,-forward[2]*d+d*.085+.3,-forward[3]*d}
    local want=Math.Length(off);local dir=Math.Scale(off,1/want)
    -- Camera boom: target o ---- ray ---- surface | .4 m clearance | camera.
    -- A hit shortens immediately; negative terrain never clamps to world zero.
    local hit=cast(t,dir,want+.4)
    local distance=hit and math.max(1.2,hit-.4) or want
    self.curDist=distance<self.curDist and distance or self.curDist+(distance-self.curDist)*math.min(1,dt*2.5)
    local raise=math.max(0,self.minY-(t[2]+dir[2]*self.curDist))
    return {target={t[1],t[2]+raise,t[3]},forward=forward,dir=dir,distance=self.curDist,
        boomPitch=math.atan(dir[2],math.sqrt(dir[1]^2+dir[3]^2))*DEG,hit=hit}
end
return M

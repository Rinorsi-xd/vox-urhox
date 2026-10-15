-- Frozen H5 testDrive.js _beginReset/_tickReset/_safeSpot (2026-10-14).
local Coord=require 'core.Coord'
local M={};M.__index=M
local DEG=180/math.pi
local SLOPE=math.cos(25/DEG)
local RADII={0,5,9,14,20,28,38}
local terrainOwners={ground=true,obstacle=true,sign=true}

function M.New(session)
    local self=setmetatable({},M);self.session=session;self.safeHist={};self.disposed=false
    session.resetChan=nil;session.resetReady=0
    return self
end
function M:Alive()
    local s=self.session;local player=s.combat and s.combat.player
    return not self.disposed and s.vehicle and (not player or player.alive)
end
function M:Begin()
    if not self:Alive() then return false end
    local s=self.session
    if s.resetChan then s.resetChan=nil;return false end
    local now=Time:GetSystemTime()
    if now<(s.resetReady or 0) then
        if s.app and s.app.toasts then s.app.toasts:Push('重置冷却中（'..math.ceil((s.resetReady-now)/1000)..' 秒）','info',1200) end
        return false
    end
    s.resetChan={t=0,dur=1.2};return true
end

-- Query cross-section (meters); it is disabled and never enters Bullet's solver.
--                 full car OBB (yaw follows source, native X is mirrored)
--                 +--------------------+  ground+.4+fullHeight
--                 | collision anywhere |  => reject, including thin walls
--                 +--------------------+  ground+.4
--  downward ray   v  <=25 degree floor  => accept only unowned map geometry
--  floor ---------------------------------------------------------------
-- Sensors and own chassis are excluded. AABB/corner rays cannot replace this
-- full volume test: they miss centre walls and reject rotated narrow passages.
function M:Query(bounds)
    if not self.queryNode then
        local node=self.session.scene:CreateChild('SafeResetQuery');self.queryNode=node
        local shape=node:CreateComponent('CollisionShape');self.queryShape=shape
        shape:SetBox(Vector3.ONE);shape.margin=0
        local body=node:CreateComponent('RigidBody');self.queryBody=body
        body.trigger=true;body.collisionLayer=0;body.collisionMask=0xffff
        body.collisionEventMode=COLLISION_NEVER;body.enabled=false
    end
    local lo,hi=bounds.min,bounds.max
    local x,y,z=hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3]
    local size=self.querySize
    if not size or x~=size[1] or y~=size[2] or z~=size[3] then
        self.queryShape:SetBox(Vector3(x,y,z));self.queryShape.margin=0;self.querySize={x,y,z}
    end
    return self.queryBody
end
function M:Fits(x,z,yaw,current)
    local s=self.session;local v=s.vehicle;local bounds=v.spec.bounds
    local hit=s.world:CastRay({x,current.y+60,z},{0,-1,0},160,v.body)
    if not hit or hit.normal[2]<SLOPE or hit.owner and not terrainOwners[hit.owner.type] then return nil end
    local lo,hi=bounds.min,bounds.max;local midX,midZ=(hi[1]+lo[1])/2,(hi[3]+lo[3])/2
    local c,sn=math.cos(yaw),math.sin(yaw);local ground=hit.point[2]
    local query=self:Query(bounds)
    query.position=Coord.Vec(x+midX*c+midZ*sn,ground+.4+(hi[2]-lo[2])/2,z-midX*sn+midZ*c)
    query.rotation=Quaternion(-yaw*DEG,Vector3.UP)
    for _,body in ipairs(s.world.space.world:GetRigidBodies(query)) do
        if body~=v.native and body~=query and not body.trigger then return nil end
    end
    return {pos={x,ground+.25,z},yaw=yaw}
end
function M:SafeSpot()
    local s=self.session;local v=s.vehicle;local p=v.body.translation();local yaw=v:Yaw();local now=s.world.time
    for i=#self.safeHist,1,-1 do
        local h=self.safeHist[i];local dx,dz=h.pos[1]-p.x,h.pos[3]-p.z;local distance=math.sqrt(dx*dx+dz*dz)
        if now-h.t>=1.5 and distance>=2.5 and distance<=60 then
            local spot=self:Fits(h.pos[1],h.pos[3],h.yaw,p);if spot then return spot end
        end
    end
    for _,radius in ipairs(RADII) do
        for k=0,(radius==0 and 0 or 11) do
            local angle=k/12*math.pi*2
            local spot=self:Fits(p.x+math.sin(angle)*radius,p.z+math.cos(angle)*radius,yaw,p)
            if spot then return spot end
        end
    end
    return {pos={p.x,p.y+v.spec.bounds.radius,p.z},yaw=yaw}
end
function M:Update(dt)
    local s=self.session
    if not self:Alive() then s.resetChan=nil;return end
    local v=s.vehicle;local q=v.body.rotation();local p=v.body.translation();local tel=v.telemetry or {}
    local upY=1-2*(q.x*q.x+q.z*q.z);local t=s.world.time;local last=self.safeHist[#self.safeHist]
    local supported=(tel.contact or 0)>0 or (tel.hovers or 0)>0 or (tel.legContacts or 0)>0 or (tel.airspeed or 0)>15
    local distance=last and math.sqrt((p.x-last.pos[1])^2+(p.z-last.pos[3])^2) or math.huge
    if upY>.87 and supported and (not last or t-last.t>.5) and distance>1.5 then
        self.safeHist[#self.safeHist+1]={t=t,pos={p.x,p.y+v.spec.bounds.min[2],p.z},yaw=v:Yaw()}
        if #self.safeHist>24 then table.remove(self.safeHist,1) end
    end
    local ch=s.resetChan;if not ch then return end
    ch.t=ch.t+dt;if ch.t<ch.dur then return end
    s.resetChan=nil;s.resetReady=Time:GetSystemTime()+4000
    local spot=self:SafeSpot()
    if s.weapons and s.weapons.drill then s.weapons.drill:Cancel() end
    s:ApplyResetSpot(spot)
end
function M:Clear() self.session.resetChan=nil end
function M:ForgetHistory() self.safeHist={} end
function M:Dispose()
    if self.disposed then return end;self:Clear();self.disposed=true;self.safeHist={}
    if self.queryNode then self.queryNode:Dispose();self.queryNode=nil;self.queryBody=nil;self.queryShape=nil end
end
return M

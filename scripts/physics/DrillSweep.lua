-- Blade slices sweep forward, including their shoulders:
--   rear [=======]---> tip       own chassis is excluded
--   road ____________           upward supporting contact is ignored
-- Native convex casts supply exact physical hull contacts. Massless articulated
-- sensors use pooled query-only boxes on isolated layer 0x4000.
local V=require 'core.Math3'
local Coord=require 'core.Coord'
local M={};M.__index=M
local BALLS={{.06,.07},{.4,.19},{.8,.35},{1.2,.51},{1.6,.67}}
local function Vec(v) return Coord.Vec(table.unpack(v)) end
local function Quat(q) return Quaternion(q.w,q.x,-q.y,-q.z) end
function M.New(world)
    local self=setmetatable({},M);self:init(world);return self
end
function M:init(world)
    self.world=world;self.root=world.scene:CreateChild('DrillQueries');self.probes={};self.sensors={};self.lookup={};self.casts=0
end
function M:Probe(i,half,radius)
    local p=self.probes[i]
    if not p then
        local n=self.root:CreateChild('BladeSlice');p={shape=n:CreateComponent('CollisionShape'),key=''};self.probes[i]=p
    end
    local key=radius and 'r'..radius or table.concat(half,',')
    if key~=p.key then
        if radius then p.shape:SetSphere(radius*2) else p.shape:SetBox(Vector3(half[1]*2,half[2]*2,half[3]*2)) end
        p.shape.margin=.001;p.key=key
    end
    return p.shape
end
function M:Sensors(excluded)
    local count=0;self.lookup={}
    for _,unit in ipairs(self.world.units) do if unit.alive and unit.vehicle.body~=excluded then
        local v=unit.vehicle;local p=V.Array(v.body.translation());local q=v.body.rotation()
        for _,list in ipairs({v.spec.sensors,v.legHitboxes and v.legHitboxes:Items() or {},v.mechHitboxes and v.mechHitboxes.items or {}}) do for _,s in ipairs(list) do
            count=count+1;local slot=self.sensors[count]
            if not slot then
                local node=self.root:CreateChild('PartSensor');local shape=node:CreateComponent('CollisionShape')
                local body=node:CreateComponent('RigidBody');body.trigger=true;body.kinematic=true;body.collisionMask=0x4000;body.collisionLayer=0
                slot={node=node,shape=shape,body=body,key=''};self.sensors[count]=slot
            end
            local key=table.concat(s.half,',')
            if key~=slot.key then slot.shape:SetBox(Vector3(s.half[1]*2,s.half[2]*2,s.half[3]*2));slot.shape.margin=.001;slot.key=key end
            local pos=Vec(V.Add(p,V.RotateUnit(q,s.center)));local rot=Quat(s.quat and V.QMul(q,s.quat) or q)
            slot.node:SetTransform(pos,rot);slot.body:SetTransform(pos,rot);slot.body.collisionLayer=0x4000
            self.lookup[slot.node:GetID()]={body=v.body,owner={type='car',ref=unit,partId=s.partId}}
        end end
    end end
end
function M:Cast(tip,dir,distance,excluded,cutters)
    local changed={};local function Hide(body)
        if not changed[body] then changed[body]={layer=body.collisionLayer};body.collisionLayer=0 end
    end
    if excluded and excluded.isValid() then Hide(excluded.native) end
    local best=nil ---@type table|nil
    local ok,err=pcall(function()
        self:Sensors(excluded)
        local count=cutters and #cutters or #BALLS
        for i=1,count do
            local c=cutters and cutters[i];local pos=c and c.pos or V.Sub(tip,V.Scale(dir,BALLS[i][1]))
            local q=c and Quat(c.quat) or Quaternion.IDENTITY
            local radius=not c and BALLS[i][2] or nil
            local shape=self:Probe(i,c and c.half,radius)
            local limit=best and best.dist or distance
            -- Retry past supporting floors and unrelated triggers so they cannot
            -- hide a wall immediately behind them. Every layer restores on error.
            while true do
                self.casts=self.casts+1
                local h=self.world.space.world:ConvexCast(shape,Vec(pos),q,Vec(V.Add(pos,V.Scale(dir,limit))),q)
                if not h.body then break end
                local id=h.body.node:GetID();local entry=self.lookup[id] or self.world.space.bodies[id]
                local owner=entry and entry.owner;local normal={-h.normal.x,h.normal.y,h.normal.z}
                local support=cutters and (not owner or ({ground=true,obstacle=true,terrain=true})[owner.type]) and normal[2]>.7 and V.Dot(normal,dir)>-.1
                if support or h.body.trigger and not self.lookup[id] then Hide(h.body)
                else
                    local body=entry and entry.body
                    best={dist=h.distance,point={-h.position.x,h.position.y,h.position.z},normal=normal,
                        body=body,collider=body,owner=owner,dir=dir};break
                end
            end
        end
    end)
    for body,state in pairs(changed) do body.collisionLayer=state.layer end
    for _,slot in ipairs(self.sensors) do slot.body.collisionLayer=0 end
    if not ok then error(err) end
    return best
end
function M:Dispose() self.root:Dispose();self.sensors={};self.probes={};self.lookup={};self.world=nil end
return M

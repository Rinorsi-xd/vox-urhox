local Coord=require "core.Coord"
local Body=require "physics.Body"
---@class PhysicsSpace
---@field scene Scene
---@field world PhysicsWorld
local Space={}
Space.__index=Space
function Space.New(scene)
    local self=setmetatable({},Space);self:init(scene);return self
end
function Space:init(scene)
    self.scene=scene
    self.world=scene:GetComponent("PhysicsWorld") or scene:CreateComponent("PhysicsWorld")
    self.world.updateEnabled=false;self.world.interpolation=false;self.world.fps=60;self.world.maxSubSteps=1
    self.world.gravity=Vector3(0,-9.81,0);self.world.numIterations=12
    self.bodies={};self.vehicleOwners=0;self.stepIndex=0
end
function Space:Register(native,owner)
    local wrapper=Body.Wrap(native)
    local id=native.node:GetID();local previous=self.bodies[id]
    if previous and previous.owner and previous.owner.type=='vehicle' then self.vehicleOwners=self.vehicleOwners-1 end
    self.bodies[id]={body=wrapper,owner=owner}
    if owner and owner.type=='vehicle' then self.vehicleOwners=self.vehicleOwners+1 end
    return wrapper
end
function Space:SetOwner(native,owner)
    local entry=assert(self.bodies[native.node:GetID()],'Physics body is not registered')
    if entry.owner and entry.owner.type=='vehicle' then self.vehicleOwners=self.vehicleOwners-1 end
    entry.owner=owner
    if owner and owner.type=='vehicle' then self.vehicleOwners=self.vehicleOwners+1 end
end
function Space:Unregister(native)
    local entry=self.bodies[native.node:GetID()]
    if entry then
        if entry.owner and entry.owner.type=='vehicle' then self.vehicleOwners=self.vehicleOwners-1 end
        entry.body.invalidate()
    end
    self.bodies[native.node:GetID()]=nil
end
-- Reused per call: Ray(Vector3,Vector3) built three userdata objects per ray.
local rayScratch,originScratch,directionScratch=Ray(),Vector3(),Vector3()
function Space:Raycast(origin,direction,length,excluded,skipOwnerType,fixedOnly,collisionMask)
    originScratch.x=-origin[1];originScratch.y=origin[2];originScratch.z=origin[3]
    directionScratch.x=-direction[1];directionScratch.y=direction[2];directionScratch.z=direction[3]
    local ray=rayScratch;ray:Define(originScratch,directionScratch)
    local results=self.world:Raycast(ray,length,collisionMask or 0xffff)
    for _,hit in ipairs(results) do
        local native=hit.body
        if native and (not excluded or native~=excluded.native) and not native.trigger
            and (not fixedOnly or (native.mass==0 and not native.kinematic)) then
            local id=native.node:GetID();local entry=self.bodies[id]
            if not (skipOwnerType and entry and entry.owner and entry.owner.type==skipOwnerType) then
            local p,n=hit.position,hit.normal
            return {dist=hit.distance,point={-p.x,p.y,p.z},normal={-n.x,n.y,n.z},
                body=entry and entry.body or Body.Wrap(native),owner=entry and entry.owner or nil,collider=id}
            end
        end
    end
    return nil
end
function Space:Step(dt)
    self.stepIndex=self.stepIndex+1
    self.world:Update(dt)
    -- Combat replaces vehicle ownership with car ownership; in that case the
    -- old full static-body scan cannot call PostStep. Keep its order otherwise.
    if self.vehicleOwners==0 then return end
    for _,entry in pairs(self.bodies) do
        local owner=entry.owner
        if owner and owner.type=='vehicle' and owner.ref then owner.ref:PostStep() end
    end
end
function Space:Dispose()
    if self.disposed then return end;self.disposed=true
    for _,entry in pairs(self.bodies) do entry.body.invalidate() end
    self.bodies={};self.vehicleOwners=0;self.scene=nil;self.world=nil
end
return Space

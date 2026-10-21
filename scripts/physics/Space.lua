local Coord=require "core.Coord"
local Body=require "physics.Body"
local PhysicsStats=require "diagnostics.PhysicsStats"
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
    self.staticQueries={};self.staticQueryCount=0;self.staticQueryHits=0;self.staticQueryMisses=0
end
-- Fixed-only support rays ignore every moving body. Invalidate when static
-- geometry changes, including direct native shape/layer/transform edits.
function Space:InvalidateStaticQueries() self.staticQueries={};self.staticQueryCount=0 end
function Space:Register(native,owner)
    local wrapper=Body.Wrap(native,function() self:InvalidateStaticQueries() end)
    if native.mass==0 and not native.kinematic then self:InvalidateStaticQueries() end
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
    if native.mass==0 and not native.kinematic then self:InvalidateStaticQueries() end
    if owner and owner.type=='vehicle' then self.vehicleOwners=self.vehicleOwners+1 end
end
function Space:Unregister(native)
    if native.mass==0 and not native.kinematic then self:InvalidateStaticQueries() end
    local entry=self.bodies[native.node:GetID()]
    if entry then
        if entry.owner and entry.owner.type=='vehicle' then self.vehicleOwners=self.vehicleOwners-1 end
        entry.body.invalidate()
    end
    self.bodies[native.node:GetID()]=nil
end
-- Reused per call: Ray(Vector3,Vector3) built three userdata objects per ray.
local rayScratch,originScratch,directionScratch=Ray(),Vector3(),Vector3()
local function CopyHit(hit)
    if not hit then return nil end
    return {dist=hit.dist,point={table.unpack(hit.point)},normal={table.unpack(hit.normal)},
        body=hit.body,owner=hit.owner,collider=hit.collider}
end
local function Remember(space,key,hit)
    if not key then return hit end
    -- Bound both hit and miss storage; moving rays must not retain the
    -- entire travelled path or retired native bodies.
    if space.staticQueryCount>=512 then space:InvalidateStaticQueries() end
    space.staticQueries[key]=hit or false;space.staticQueryCount=space.staticQueryCount+1
    return CopyHit(hit)
end
function Space:Raycast(origin,direction,length,excluded,skipOwnerType,fixedOnly,collisionMask)
    local key
    if fixedOnly then
        key=string.pack('dddddddI4',origin[1],origin[2],origin[3],direction[1],direction[2],direction[3],length,collisionMask or 0xffff)
            ..':'..(excluded and excluded.native.node:GetID() or 0)..':'..(skipOwnerType and 's'..skipOwnerType or 'n')
        local previous=self.staticQueries[key]
        if previous~=nil then self.staticQueryHits=self.staticQueryHits+1;return CopyHit(previous) end
        self.staticQueryMisses=self.staticQueryMisses+1
    end
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
            return Remember(self,key,{dist=hit.distance,point={-p.x,p.y,p.z},normal={-n.x,n.y,n.z},
                body=entry and entry.body or Body.Wrap(native),owner=entry and entry.owner or nil,collider=id})
            end
        end
    end
    return Remember(self,key,nil)
end
function Space:Step(dt)
    self.stepIndex=self.stepIndex+1
    -- 性能监控开启时每秒抽一步做物理统计（见 diagnostics.PhysicsStats），否则照常单步
    if not PhysicsStats.Step(self,dt) then self.world:Update(dt) end
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
    self.bodies={};self:InvalidateStaticQueries();self.vehicleOwners=0;self.scene=nil;self.world=nil
end
return Space

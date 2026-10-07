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
    self.bodies={}
end
function Space:Register(native,owner)
    local wrapper=Body.Wrap(native)
    self.bodies[native.node:GetID()]={body=wrapper,owner=owner}
    return wrapper
end
function Space:Unregister(native) self.bodies[native.node:GetID()]=nil end
function Space:Raycast(origin,direction,length,excluded,skipOwnerType,fixedOnly)
    local ray=Ray(Coord.Vec(table.unpack(origin)),Coord.Vec(table.unpack(direction)))
    local results=self.world:Raycast(ray,length)
    for _,hit in ipairs(results) do
        if hit.body and (not excluded or hit.body~=excluded.native) and not hit.body.trigger
            and (not fixedOnly or (hit.body.mass==0 and not hit.body.kinematic)) then
            local entry=self.bodies[hit.body.node:GetID()]
            if not (skipOwnerType and entry and entry.owner and entry.owner.type==skipOwnerType) then
            local p,n=hit.position,hit.normal
            return {dist=hit.distance,point={-p.x,p.y,p.z},normal={-n.x,n.y,n.z},
                body=entry and entry.body or Body.Wrap(hit.body),owner=entry and entry.owner or nil,collider=hit.body.node:GetID()}
            end
        end
    end
    return nil
end
function Space:Step(dt) self.world:Update(dt) end
return Space

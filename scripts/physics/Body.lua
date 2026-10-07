-- Polar vectors mirror X. Angular velocity/torque are axial vectors: mirror Y,Z.
-- Apply point forces as central force + cross(world lever,force), avoiding the
-- legacy RigidBody point-argument convention and handling rotated COM correctly.
local Coord=require "core.Coord"
local M={}
local function Polar(v) return Coord.Vec(v.x,v.y,v.z) end
local function Axial(v) return Vector3(v.x,-v.y,-v.z) end
local function Unpolar(v) return {x=-v.x,y=v.y,z=v.z} end
local function Unaxial(v) return {x=v.x,y=-v.y,z=-v.z} end
---@param native RigidBody
function M.Wrap(native)
    local function Center() return native.position+native.rotation*native.centerOfMass end
    -- Native Lua does not expose inertia. Measure the three impulse responses once,
    -- restore velocity immediately, and rotate this tensor with the body thereafter.
    local inverse={Vector3.ZERO,Vector3.ZERO,Vector3.ZERO}
    if native.mass>0 then
        local saved=native.angularVelocity;local q=native.rotation
        for i,axis in ipairs({Vector3.RIGHT,Vector3.UP,Vector3.FORWARD}) do
            native.angularVelocity=Vector3.ZERO;native:ApplyTorqueImpulse(q*axis)
            inverse[i]=q:Inverse()*native.angularVelocity
        end
        native.angularVelocity=saved
    end
    local function InvInertia(value)
        local q=native.rotation;local v=q:Inverse()*value
        return q*(inverse[1]*v.x+inverse[2]*v.y+inverse[3]*v.z)
    end
    return {
        native=native,
        translation=function() return Unpolar(native.position) end,
        rotation=function() local q=native.rotation;return {x=q.x,y=-q.y,z=-q.z,w=q.w} end,
        linvel=function() return Unpolar(native.linearVelocity) end,
        angvel=function() return Unaxial(native.angularVelocity) end,
        localCom=function() return Unpolar(native.centerOfMass) end,
        center=function() return Unpolar(Center()) end,
        impulseDenominator=function(point,direction)
            if native.mass<=0 then return 0 end
            local r=Polar(point)-Center();local n=Polar(direction)
            return 1/native.mass+n:DotProduct(InvInertia(r:CrossProduct(n)):CrossProduct(r))
        end,
        velocityAtPoint=function(point)
            local arm=Polar(point)-Center()
            return Unpolar(native.linearVelocity+native.angularVelocity:CrossProduct(arm))
        end,
        addForce=function(force) native:ApplyForce(Polar(force)) end,
        applyImpulse=function(impulse) native:ApplyImpulse(Polar(impulse)) end,
        addTorque=function(torque) native:ApplyTorque(Axial(torque)) end,
        addForceAtPoint=function(force,point)
            local f=Polar(force);native:ApplyForce(f);native:ApplyTorque((Polar(point)-Center()):CrossProduct(f))
        end,
        applyImpulseAtPoint=function(impulse,point)
            local j=Polar(impulse);native:ApplyImpulse(j);native:ApplyTorqueImpulse((Polar(point)-Center()):CrossProduct(j))
        end,
        resetForces=function() native:ResetForces() end,
        setTranslation=function(p) native.position=Polar(p) end,
        setRotation=function(q) native.rotation=Quaternion(q.w,q.x,-q.y,-q.z) end,
        setLinvel=function(v) native.linearVelocity=Polar(v) end,
        setAngvel=function(v) native.angularVelocity=Axial(v) end,
    }
end
return M

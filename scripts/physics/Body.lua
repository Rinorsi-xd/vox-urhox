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
    local valid=true
    -- A vehicle's controllers run synchronously before PhysicsWorld.Update.
    -- Cache reads only inside that interval; impulses still invalidate velocity.
    local scoped=false
    ---@type Vector3|nil
    local pose=nil
    ---@type Quaternion|nil
    local orientation=nil
    ---@type Vector3|nil
    local localCenter=nil
    ---@type Vector3|nil
    local worldCenter=nil
    ---@type Quaternion|nil
    local inverseRotation=nil
    ---@type number|nil
    local bodyMass=nil
    ---@type Vector3|nil
    local linear=nil
    ---@type Vector3|nil
    local angular=nil
    local function ClearReads()
        pose=nil;orientation=nil;localCenter=nil;worldCenter=nil;inverseRotation=nil;bodyMass=nil;linear=nil;angular=nil
    end
    local function EndReadScope() scoped=false;ClearReads() end
    local readGuard=setmetatable({},{__close=EndReadScope})
    local function ReadPosition() if not scoped then return native.position end;if not pose then pose=native.position end;return pose end
    local function ReadRotation() if not scoped then return native.rotation end;if not orientation then orientation=native.rotation end;return orientation end
    local function ReadLocalCenter() if not scoped then return native.centerOfMass end;if not localCenter then localCenter=native.centerOfMass end;return localCenter end
    local function ReadMass() if not scoped then return native.mass end;if not bodyMass then bodyMass=native.mass end;return bodyMass end
    local function ReadLinear() if not scoped then return native.linearVelocity end;if not linear then linear=native.linearVelocity end;return linear end
    local function ReadAngular() if not scoped then return native.angularVelocity end;if not angular then angular=native.angularVelocity end;return angular end
    local function Position(p)
        local v=Polar(p);native.position=v
        if native.kinematic then native.node.position=v end
        pose=nil;worldCenter=nil
    end
    local function Rotation(q)
        local v=Quaternion(q.w,q.x,-q.y,-q.z);native.rotation=v
        if native.kinematic then native.node.rotation=v end
        orientation=nil;worldCenter=nil;inverseRotation=nil
    end
    local function Center()
        if not scoped then return native.position+native.rotation*native.centerOfMass end
        if not worldCenter then worldCenter=ReadPosition()+ReadRotation()*ReadLocalCenter() end
        return worldCenter
    end
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
        local q=ReadRotation();local inv
        if scoped then inverseRotation=inverseRotation or q:Inverse();inv=inverseRotation else inv=q:Inverse() end
        local v=inv*value
        return q*(inverse[1]*v.x+inverse[2]*v.y+inverse[3]*v.z)
    end
    local wrapper={}
    wrapper={
        native=native,
        isValid=function() return valid end,
        invalidate=function() valid=false;scoped=false;ClearReads();native=nil;wrapper.native=nil end,
        beginReadScope=function() ClearReads();scoped=true;return readGuard end,
        endReadScope=EndReadScope,
        mass=ReadMass,
        bodyType=function() return native.kinematic end,
        setBodyType=function(kinematic) native.kinematic=kinematic;ClearReads() end,
        isCcdEnabled=function() return {radius=native.ccdRadius,threshold=native.ccdMotionThreshold} end,
        enableCcd=function(value)
            if type(value)=='table' then native.ccdRadius=value.radius;native.ccdMotionThreshold=value.threshold
            else native.ccdRadius=value and .15 or 0;native.ccdMotionThreshold=value and .1 or 0 end
        end,
        translation=function() return Unpolar(ReadPosition()) end,
        rotation=function() local q=ReadRotation();return {x=q.x,y=-q.y,z=-q.z,w=q.w} end,
        linvel=function() return Unpolar(ReadLinear()) end,
        angvel=function() return Unaxial(ReadAngular()) end,
        localCom=function() return Unpolar(ReadLocalCenter()) end,
        center=function() return Unpolar(Center()) end,
        impulseDenominator=function(point,direction)
            local mass=ReadMass();if mass<=0 then return 0 end
            local r=Polar(point)-Center();local n=Polar(direction)
            return 1/mass+n:DotProduct(InvInertia(r:CrossProduct(n)):CrossProduct(r))
        end,
        velocityAtPoint=function(point)
            local velocity=ReadLinear();local spin=ReadAngular()
            if spin.x==0 and spin.y==0 and spin.z==0 then return Unpolar(velocity) end
            local arm=Polar(point)-Center()
            return Unpolar(velocity+spin:CrossProduct(arm))
        end,
        addForce=function(force) native:ApplyForce(Polar(force)) end,
        applyImpulse=function(impulse) native:ApplyImpulse(Polar(impulse));linear=nil end,
        addTorque=function(torque) native:ApplyTorque(Axial(torque)) end,
        applyTorqueImpulse=function(torque) native:ApplyTorqueImpulse(Axial(torque));angular=nil end,
        addForceAtPoint=function(force,point)
            local f=Polar(force);native:ApplyForce(f);native:ApplyTorque((Polar(point)-Center()):CrossProduct(f))
        end,
        applyImpulseAtPoint=function(impulse,point)
            local j=Polar(impulse);native:ApplyImpulse(j);native:ApplyTorqueImpulse((Polar(point)-Center()):CrossProduct(j))
            linear=nil;angular=nil
        end,
        resetForces=function() native:ResetForces() end,
        resetTorques=function() native:ResetForces() end,
        setTranslation=Position,
        setRotation=Rotation,
        setNextKinematicTranslation=Position,
        setNextKinematicRotation=Rotation,
        setLinvel=function(v) native.linearVelocity=Polar(v);linear=nil end,
        setAngvel=function(v) native.angularVelocity=Axial(v);angular=nil end,
    }
    return wrapper
end
return M

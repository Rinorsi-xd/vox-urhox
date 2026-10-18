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
    -- Inside a read scope, forces and torques are summed in Lua (torque uses the
    -- centre at call time) and submitted once when the scope ends. Bullet only
    -- accumulates them until the world step, so the applied totals are the same.
    local pending=false
    local fx,fy,fz,tx,ty,tz=0.0,0.0,0.0,0.0,0.0,0.0
    local function FlushForces()
        if not pending then return end
        pending=false
        if native then
            if fx~=0 or fy~=0 or fz~=0 then native:ApplyForce(Vector3(fx,fy,fz)) end
            if tx~=0 or ty~=0 or tz~=0 then native:ApplyTorque(Vector3(tx,ty,tz)) end
        end
        fx,fy,fz,tx,ty,tz=0.0,0.0,0.0,0.0,0.0,0.0
    end
    local function EndReadScope() FlushForces();scoped=false;ClearReads() end
    local readGuard=setmetatable({},{__close=EndReadScope})
    local function ReadPosition() if not scoped then return native.position end;if not pose then pose=native.position end;return pose end
    local function ReadRotation() if not scoped then return native.rotation end;if not orientation then orientation=native.rotation end;return orientation end
    local function ReadLocalCenter() if not scoped then return native.centerOfMass end;if not localCenter then localCenter=native.centerOfMass end;return localCenter end
    local function ReadMass() if not scoped then return native.mass end;if not bodyMass then bodyMass=native.mass end;return bodyMass end
    local function ReadLinear() if not scoped then return native.linearVelocity end;if not linear then linear=native.linearVelocity end;return linear end
    local function ReadAngular() if not scoped then return native.angularVelocity end;if not angular then angular=native.angularVelocity end;return angular end
    -- Bumped by every pose write so callers may cache a pose between physics steps.
    local poseVersion=0
    local function Position(p)
        poseVersion=poseVersion+1
        local v=Polar(p);native.position=v
        if native.kinematic then native.node.position=v end
        pose=nil;worldCenter=nil
    end
    local function Rotation(q)
        poseVersion=poseVersion+1
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
    -- Invert the measured local tensor once. Flight controllers can request an
    -- angular acceleration without depending on Bullet's compound mass weights.
    local a,b,c=inverse[1].x,inverse[2].x,inverse[3].x
    local d,e,f=inverse[2].y,inverse[3].y,inverse[3].z
    local det=a*(d*f-e*e)-b*(b*f-c*e)+c*(b*e-c*d)
    local inertia=nil ---@type number[]|nil
    if det>0 then inertia={(d*f-e*e)/det,(c*e-b*f)/det,(b*e-c*d)/det,
        (a*f-c*c)/det,(b*c-a*e)/det,(a*d-b*b)/det} end
    local function FlightAcceleration(alpha)
        if not inertia then return end
        local q=ReadRotation();local v=q:Inverse()*Axial(alpha)
        local torque=Vector3(inertia[1]*v.x+inertia[2]*v.y+inertia[3]*v.z,
            inertia[2]*v.x+inertia[4]*v.y+inertia[5]*v.z,
            inertia[3]*v.x+inertia[5]*v.y+inertia[6]*v.z)
        native:ApplyTorque(q*torque)
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
        poseVersion=function() return poseVersion end,
        -- Direct native pose writes bypass setTranslation; they must call this.
        touchPose=function() poseVersion=poseVersion+1;pose=nil;orientation=nil;worldCenter=nil;inverseRotation=nil end,
        invalidate=function() pending=false;fx,fy,fz,tx,ty,tz=0.0,0.0,0.0,0.0,0.0,0.0;valid=false;scoped=false;ClearReads();native=nil;wrapper.native=nil end,
        beginReadScope=function() FlushForces();ClearReads();scoped=true;return readGuard end,
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
        predictedAngvel=function(dt)
            local total=Vector3(tx,ty,tz)
            return Unaxial(ReadAngular()+InvInertia(total)*dt)
        end,
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
        addForce=function(force)
            if not scoped then native:ApplyForce(Polar(force));return end
            fx=fx-force.x;fy=fy+force.y;fz=fz+force.z;pending=true
        end,
        applyImpulse=function(impulse) native:ApplyImpulse(Polar(impulse));linear=nil end,
        addTorque=function(torque)
            if not scoped then native:ApplyTorque(Axial(torque));return end
            tx=tx+torque.x;ty=ty-torque.y;tz=tz-torque.z;pending=true
        end,
        addFlightAngularAcceleration=inertia and FlightAcceleration or nil,
        applyTorqueImpulse=function(torque) native:ApplyTorqueImpulse(Axial(torque));angular=nil end,
        addForceAtPoint=function(force,point)
            if not scoped then
                local f=Polar(force);native:ApplyForce(f);native:ApplyTorque((Polar(point)-Center()):CrossProduct(f));return
            end
            local c=Center();local ax,ay,az=-force.x,force.y,force.z
            local rx,ry,rz=-point.x-c.x,point.y-c.y,point.z-c.z
            fx=fx+ax;fy=fy+ay;fz=fz+az
            tx=tx+(ry*az-rz*ay);ty=ty+(rz*ax-rx*az);tz=tz+(rx*ay-ry*ax);pending=true
        end,
        applyImpulseAtPoint=function(impulse,point)
            local j=Polar(impulse);native:ApplyImpulse(j);native:ApplyTorqueImpulse((Polar(point)-Center()):CrossProduct(j))
            linear=nil;angular=nil
        end,
        resetForces=function() pending=false;fx,fy,fz,tx,ty,tz=0.0,0.0,0.0,0.0,0.0,0.0;native:ResetForces() end,
        resetTorques=function() pending=false;fx,fy,fz,tx,ty,tz=0.0,0.0,0.0,0.0,0.0,0.0;native:ResetForces() end,
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

-- Source mass properties for wing forces only. Native pose and COM stay intact.
local V=require 'core.Math3'
local M={}
local Response={};Response.__index=Response
local function Inverse(a)
    local det=a[1]*(a[5]*a[9]-a[6]*a[8])-a[2]*(a[4]*a[9]-a[6]*a[7])+a[3]*(a[4]*a[8]-a[5]*a[7])
    local scale=math.max(a[1],a[5],a[9])
    if scale<=0 or det<=scale^3*1e-12 then return nil end
    return {(a[5]*a[9]-a[6]*a[8])/det,(a[3]*a[8]-a[2]*a[9])/det,(a[2]*a[6]-a[3]*a[5])/det,
        (a[6]*a[7]-a[4]*a[9])/det,(a[1]*a[9]-a[3]*a[7])/det,(a[3]*a[4]-a[1]*a[6])/det,
        (a[4]*a[8]-a[5]*a[7])/det,(a[2]*a[7]-a[1]*a[8])/det,(a[1]*a[5]-a[2]*a[4])/det}
end
local function Multiply(a,v)
    return {a[1]*v[1]+a[2]*v[2]+a[3]*v[3],a[4]*v[1]+a[5]*v[2]+a[6]*v[3],a[7]*v[1]+a[8]*v[2]+a[9]*v[3]}
end
function M.New(v)
    local spec=v.spec
    if not spec.wings or #spec.wings==0 or #(spec.rotors or {})>0 then return nil end
    local shapes={};local mass=0;local weighted={0,0,0}
    local function Add(center,diag,m,quat)
        if not m or m<=0 then return false end
        mass=mass+m
        for k=1,3 do weighted[k]=weighted[k]+center[k]*m end
        shapes[#shapes+1]={center=center,diag=diag,mass=m,quat=quat}
        return true
    end
    for _,list in ipairs({spec.boxes or {},spec.hulls or {}}) do for _,s in ipairs(list) do
        if s.shape or s.rotor or not s.half or not s.center then return nil end
        local h,m=s.half,s.mass
        if not m or m<=0 then return nil end
        if not Add(s.center,{m*(h[2]^2+h[3]^2)/3,m*(h[1]^2+h[3]^2)/3,m*(h[1]^2+h[2]^2)/3},m,s.quat) then return nil end
    end end
    for _,w in ipairs(v.wheels or {}) do if not w.track then
        if w.rotor or not w.conn then return nil end
        local m=w.mass;local radius,height=w.radius*.9,w.width*.45
        if not m or m<=0 then return nil end
        local axial=m*radius^2*.5;local transverse=m*(radius^2*.25+height^2/3)
        local diag=math.abs(w.axle[1])>.5 and {axial,transverse,transverse} or {transverse,transverse,axial}
        if not Add(w.conn,diag,m) then return nil end
    end end
    if mass<=0 or math.abs(mass-v.mass)>math.max(1,v.mass)*1e-4 then return nil end
    local com=V.Scale(weighted,1/mass);local tensor={0,0,0,0,0,0,0,0,0}
    -- Each solid: [own inertia at center] + m (|r|^2 identity - r r^T).
    -- Wheel solid is its suspension bump cylinder; hit sensors carry no mass.
    for _,s in ipairs(shapes) do
        local axes={{1,0,0},{0,1,0},{0,0,1}}
        if s.quat then for k=1,3 do axes[k]=V.Rotate(s.quat,axes[k]) end end
        local r=V.Sub(s.center,com);local r2=V.Dot(r,r)
        for i=1,3 do for j=1,3 do
            local own=0;for k=1,3 do own=own+s.diag[k]*axes[k][i]*axes[k][j] end
            local index=(i-1)*3+j
            tensor[index]=tensor[index]+own+s.mass*((i==j and r2 or 0)-r[i]*r[j])
        end end
    end
    local inverse=Inverse(tensor);if not inverse then return nil end
    local response=setmetatable({},Response);response:init(v,mass,com,tensor,inverse);return response
end
function Response:init(v,mass,com,tensor,inverse)
    self.vehicle=v;self.mass=mass;self.com=com;self.inertia=tensor;self.inverse=inverse
end
function Response:Torque(worldTorque)
    local q=self.vehicle.body.rotation()
    local localTorque=V.Rotate(V.Inverse(q),V.Array(worldTorque))
    return V.Vec(V.Rotate(q,Multiply(self.inverse,localTorque)))
end
function Response:ForceAt(worldForce,worldPoint)
    local body=self.vehicle.body;local p=body.translation();local q=body.rotation()
    local worldCom=V.Add(V.Array(p),V.Rotate(q,self.com))
    return self:Torque(V.Vec(V.Cross(V.Sub(V.Array(worldPoint),worldCom),V.Array(worldForce))))
end
return M

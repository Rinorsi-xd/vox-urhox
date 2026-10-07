-- Source actuator limits and box-constrained lift balancing; never set chassis pose.
local Math=require "core.Math3"
local C=Math.Clamp
local M={}
local function Vec(v) return {x=v[1],y=v[2],z=v[3]} end
local function Array(v) return {v.x,v.y,v.z} end
local function Falloff(speed,limit) return C(1-(math.max(0,speed)/math.max(.01,limit))^3,0,1) end
local function Tilted(t,angle)
    local pivot=t.pivot or t.pos;local r=Math.Sub(t.pos,pivot);local c,s=math.cos(angle),math.sin(angle)
    return {pivot[1]+r[1],pivot[2]+c*r[2]-s*r[3],pivot[3]+s*r[2]+c*r[3]}
end
function M.Step(v,cmd,dt,contact,supportForce)
    local body=v.body;local q=body.rotation();local p,lv,av=body.translation(),body.linvel(),body.angvel()
    local mg=v.mass*9.81;local ts=v.spec.thrusters;local lifts={}
    for _,t in ipairs(ts) do if t.dir[2]>.7 then lifts[#lifts+1]=t end end
    local climb,throttle,strafe,steer=C(cmd.climb or 0,-1,1),C(cmd.throttle or 0,-1,1),C(cmd.strafe or 0,-1,1),C(cmd.steer or 0,-1,1)
    v.thrusterOutputs={};v.thrusterDirections={}
    if cmd.cutLift or #lifts==0 then v.flightTarget=nil;v.landingTime=0
    elseif climb>0 and v.flightTarget==nil then v.flightTarget=p.y end
    if v.flightTarget~=nil then
        v.flightTarget=C(v.flightTarget+climb*3*dt,p.y-1.8,p.y+1.8)
        local hit=v.space:Raycast({p.x,p.y+v.spec.bounds.min[2]+.1,p.z},{0,-1,0},.35,body)
        v.landingTime=climb<0 and (contact>0 or hit) and math.abs(lv.y)<.7 and (v.landingTime or 0)+dt or 0
        if v.landingTime>.25 then v.flightTarget=nil end
    end
    local horizontalSpeed=math.sqrt(lv.x*lv.x+lv.z*lv.z)
    if #ts>0 and horizontalSpeed>0 then body.addForce({x=-v.mass*.002*horizontalSpeed*lv.x,y=0,z=-v.mass*.002*horizontalSpeed*lv.z},true) end
    local torque={0,0,0};local outputCount=0
    local function Apply(t,d,f,point)
        if f<.001 then return end
        point=point or t.pos
        local wd=Math.Rotate(q,d);local r=Math.Rotate(q,point)
        body.addForceAtPoint(Vec(Math.Scale(wd,f)),{x=p.x+r[1],y=p.y+r[2],z=p.z+r[3]},true)
        v.thrusterOutputs[t.partId]=f/t.thrust;v.thrusterDirections[t.partId]=d;outputCount=outputCount+1
        local tq=Math.Cross(Math.Sub(point,v.com),d)
        for k=1,3 do torque[k]=torque[k]+tq[k]*f end
    end
    for _,t in ipairs(ts) do if t.dir[2]<=.7 then
        local yaw=Math.Cross(Math.Sub(t.pos,v.com),t.dir)[2]
        local out=math.max(0,t.dir[3]*throttle,t.dir[1]*strafe)
        if math.abs(t.dir[1])>.7 and yaw*steer>.05 then
            out=math.max(out,math.abs(steer)*C((1.4-steer*Math.Unrotate(q,Array(av))[2])/.5,0,1))
        end
        if t.dir[2]<-.7 and v.flightTarget==nil then out=math.max(out,-climb) end
        local wd=Math.Rotate(q,t.dir);local speed=Math.Dot(Array(lv),wd)
        local governed=speed>0 and math.max(speed,math.sqrt(wd[1]^2+wd[3]^2)>.001 and horizontalSpeed or 0) or 0
        Apply(t,t.dir,t.thrust*out*Falloff(governed,t.speedLimit))
    end end
    local capacity=0
    for _,t in ipairs(lifts) do capacity=capacity+math.max(0,Math.Rotate(q,t.dir)[2])*t.thrust end
    local balanceError=0
    if v.flightTarget~=nil then
        local speedSum,thrustSum=0,0
        for _,t in ipairs(lifts) do speedSum=speedSum+t.thrust*t.speedLimit;thrustSum=thrustSum+t.thrust end
        local liftSpeed=speedSum/math.max(1,thrustSum)
        local wanted=12*math.pi/180*math.max(0,throttle)*Falloff(horizontalSpeed,liftSpeed)
        v.liftTilt=(v.liftTilt or 0)+(wanted-(v.liftTilt or 0))*(1-math.exp(-dt*8))
        local d={0,math.cos(v.liftTilt),math.sin(v.liftTilt)};local up=Math.Rotate(q,{0,1,0})
        for _,t in ipairs(lifts) do v.thrusterDirections[t.partId]=d end
        local desired=Math.Unrotate(q,{-up[3]*v.inertiaY*8-av.x*v.inertiaY*4,0,up[1]*v.inertiaY*8-av.z*v.inertiaY*4})
        local armScale=.5
        for _,t in ipairs(lifts) do armScale=math.max(armScale,math.sqrt((t.pos[1]-v.com[1])^2+(t.pos[3]-v.com[3])^2)) end
        local target={math.max(0,mg-math.min(mg,supportForce or 0)+v.mass*(4*(v.flightTarget-p.y)-3.6*lv.y))/mg,
            (desired[1]-torque[1])/(mg*armScale),(desired[3]-torque[3])/(mg*armScale)}
        local points,columns,outputs={},{},{}
        local vertical=Math.Rotate(q,d)[2]
        for i,t in ipairs(lifts) do
            points[i]=Tilted(t,v.liftTilt)
            local tq=Math.Cross(Math.Sub(points[i],v.com),d)
            columns[i]={vertical*t.thrust/mg,tq[1]*t.thrust/(mg*armScale),tq[3]*t.thrust/(mg*armScale)}
            outputs[i]=C(target[1]*mg/math.max(1,capacity),0,1)
        end
        local residual={table.unpack(target)}
        for k=1,3 do for i,column in ipairs(columns) do residual[k]=residual[k]-column[k]*outputs[i] end end
        for _=1,36 do for i,column in ipairs(columns) do
            local norm=Math.Dot(column,column)+1e-8
            local nextValue=C(outputs[i]+Math.Dot(column,residual)/norm,0,1);local delta=nextValue-outputs[i]
            outputs[i]=nextValue;for k=1,3 do residual[k]=residual[k]-delta*column[k] end
        end end
        balanceError=math.sqrt(residual[2]^2+residual[3]^2)
        for i,t in ipairs(lifts) do Apply(t,d,t.thrust*outputs[i],points[i]) end
    else
        v.liftTilt=(v.liftTilt or 0)*math.exp(-dt*8)
        for _,t in ipairs(lifts) do v.thrusterDirections[t.partId]={0,math.cos(v.liftTilt),math.sin(v.liftTilt)} end
    end
    return {altitude=p.y+v.spec.bounds.min[2],altitudeTarget=v.flightTarget and v.flightTarget+v.spec.bounds.min[2] or nil,
        liftRatio=capacity/mg,liftBalanceError=balanceError,flightHold=v.flightTarget~=nil,boosting=outputCount>0}
end
return M

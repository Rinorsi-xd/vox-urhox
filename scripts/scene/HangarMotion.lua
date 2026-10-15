-- Articulated nodes preserve the original H5 local pivots and animation equations.
local Mat=require "scene.HangarMaterials"
local Config=require "scene.HangarConfig"
local M={}
local function smooth(x) x=math.max(0,math.min(1,x));return x*x*(3-2*x) end
function M.Bind(h)
    h.arms={}
    for i=1,4 do
        local turret=h:Node("Arm"..i):GetChild("Turret")
        local upper=assert(turret:GetChild("Shoulder"))
        local fore=assert(upper:GetChild("Elbow"))
        local tool=assert(fore:GetChild("Wrist"))
        h.arms[i]={turret=turret,upper=upper,fore=fore,tool=tool,
            rest={turret.rotation,upper.rotation,fore.rotation,tool.rotation}}
    end
    h.drones={}
    for i=1,2 do
        local n=h:Node("Drone"..i)
        local phase=(i-1)*math.pi
        local pat=h.layout.drones.patrol
        -- The editable DronePatrol parent is the path anchor; this child follows it locally.
        h.drones[i]={node=n,pos=n.position,yaw=n.rotation:YawAngle()*math.pi/180,phase=phase,
            origin=Vector3(-math.sin(phase)*pat.r,pat.y+math.sin(phase)*1.5,math.cos(phase)*pat.r*1.25)}
    end
    h.bridge=h:Node("CraneBridge")
    h.trolley=assert(h.bridge:GetChild("CraneTrolley"))
    h.bridgeOrigin=h.bridge.position
    h.trolleyOrigin=h.trolley.position
    h.scan=h:Node("WelcomeScanner")
    h.scanMat=h.scan:GetComponent("StaticModel").material
    h.nicheRotations={}
    for i,n in ipairs(h.niches) do h.nicheRotations[i]=n.rotation end
end
function M.Update(h,dt,t)
    h.greet=math.max(0,h.greet-dt)
    local g=smooth((3.2-h.greet)/0.8)*smooth(h.greet)
    local restTime=Config.authoredPoseTime
    for i,a in ipairs(h.arms) do
        local k=i-1
        local yaw=0.42*math.sin(t*0.12+k*0.9)*(1-g)
        local sh=0.78+0.18*math.sin(t*0.23+k*1.7)
        local el=0.95+0.25*math.sin(t*0.31+k)
        local wr=0.55+0.35*math.sin(t*0.41+k*2.3)
        a.turret.rotation=a.rest[1]*Quaternion(-math.deg(yaw-0.42*math.sin(restTime*0.12+k*0.9)),Vector3.UP)
        a.upper.rotation=a.rest[2]*Quaternion(math.deg(sh+(0.1-sh)*g-(0.78+0.18*math.sin(restTime*0.23+k*1.7))),Vector3.RIGHT)
        a.fore.rotation=a.rest[3]*Quaternion(math.deg(el+(0.35-el)*g-(0.95+0.25*math.sin(restTime*0.31+k))),Vector3.RIGHT)
        a.tool.rotation=a.rest[4]*Quaternion(math.deg(wr+(-0.4+0.3*math.sin(t*6+k)-wr)*g-(0.55+0.35*math.sin(restTime*0.41+k*2.3))),Vector3.RIGHT)
    end
    local pat=h.layout.drones.patrol
    for _,d in ipairs(h.drones) do
        local angle=t*pat.speed+d.phase
        local goal=d.origin+Vector3(-(math.sin(angle)-math.sin(d.phase))*pat.r,
            (math.sin(t*0.4+d.phase)-math.sin(d.phase))*1.5,
            (math.cos(angle)-math.cos(d.phase))*pat.r*1.25)
        local prev=d.pos
        local p=prev+(goal-prev)*(1-math.exp(-dt*1.2))
        local vel=p-prev
        if vel:LengthSquared()>0.000001 then
            local want=math.atan(vel.x,vel.z)
            d.yaw=d.yaw+math.atan(math.sin(want-d.yaw),math.cos(want-d.yaw))*math.min(1,dt*2)
        end
        d.pos=p
        d.node.position=Vector3(p.x,p.y+math.sin(t*3+d.phase)*0.05,p.z)
        d.node.rotation=Quaternion(math.deg(math.min(0.35,vel:Length()/math.max(dt,0.001)*0.04)),math.deg(d.yaw),0)
    end
    local ph=(t/70)%1
    local k=ph<0.4 and smooth(ph/0.4) or ph<0.5 and 1 or ph<0.9 and 1-smooth((ph-0.5)/0.4) or 0
    local c=h.layout.crane
    local restK=smooth((restTime/70)/0.4)
    h.bridge.position=h.bridgeOrigin+Vector3(0,0,(c.range[2]-c.range[1])*(k-restK))
    h.trolley.position=h.trolleyOrigin+Vector3(-(math.sin(t*0.05)-math.sin(restTime*0.05))*6,0,0)
    for _,v in ipairs(h.holos) do
        local p=v.origin
        v.node.position=p+Vector3(0,(math.sin(t*0.7-p.x)-math.sin(restTime*0.7-p.x))*0.06,0)
    end
    for i,n in ipairs(h.niches) do n.rotation=h.nicheRotations[i]*Quaternion(-math.deg((t-restTime)*0.25),Vector3.UP) end
    h.scanTime=h.scanTime+dt
    local st=h.scanTime
    local fade=math.min(1,st/0.2)*(1-smooth((st-1.8)/0.4))
    h.scan.enabled=fade>0.001
    local b=h.scanBox
    local z=b.z1+(b.z0-b.z1)*smooth(st/1.8)
    h.scan.position=Vector3(-(b.x0+b.x1)/2,b.h/2,z)
    h.scan.scale=Vector3(b.x1-b.x0,b.h,1)
    Mat.Set(h.scanMat,"uStrength",fade)
    Mat.Set(h.padMat,"uScan",Vector3(z,math.max(math.abs(b.x0),math.abs(b.x1)),fade))
    Mat.Set(h.padMat,"uFlash",fade)
end
return M

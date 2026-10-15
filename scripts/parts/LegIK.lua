-- Port of shared/parts/legIK.js. Targets and lengths are in source part-local cells.
-- Solves contact targets; no time-based walking or fake ground contact.
local M={}
local function Clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function Hypot(x,y,z) return math.sqrt(x*x+y*y+(z or 0)^2) end
local function Wrap(x) return x-2*math.pi*math.floor(x/(2*math.pi)+0.5) end
local function Rotate(x,y,a) return x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a) end
function M.Solve(g,target,bladeAngle)
    bladeAngle=bladeAngle or 0
    local o=g.origins
    local h,s,e,k=o.hip,o.shoulderJoint,o.elbow,o.knee
    local yaw=-math.atan(target[3]-h[3],target[1]-h[1])
    local px,py=h[1]+Hypot(target[1]-h[1],target[3]-h[3]),target[2]
    local bx,by=o.toe[1]-k[1],o.toe[2]-k[2]
    local span=math.max(Hypot(k[1]-s[1],k[2]-s[2]),(g.lengths[1]+g.lengths[2])*0.94)
    local rx,ry=Rotate(bx,by,bladeAngle)
    local wx,wy=px-rx,py-ry
    local d0=Hypot(wx-s[1],wy-s[2])
    local width=math.max(0.001,(g.lengths[1]+g.lengths[2])*0.99-span)
    if d0>span then
        local soft=span+width*(1-math.exp(-(d0-span)/width))
        local dx,dy=px-s[1],py-s[2]
        local distance,L=Hypot(dx,dy),g.lengths[3]
        local phi,rest=math.atan(dy,dx),math.atan(by,bx)
        local delta=math.acos(Clamp((distance*distance+L*L-soft*soft)/(2*distance*L),-1,1))
        bladeAngle=Clamp(rest+bladeAngle,phi-delta,phi+delta)-rest
        rx,ry=Rotate(bx,by,bladeAngle);wx,wy=px-rx,py-ry
    end
    local vx,vy=wx-s[1],wy-s[2]
    local l1,l2=g.lengths[1],g.lengths[2]
    local d=Clamp(Hypot(vx,vy),math.abs(l1-l2)+1e-5,l1+l2-1e-5)
    local angle=math.atan(vy,vx)
    local a=angle+math.acos(Clamp((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1))
    local ex,ey=s[1]+l1*math.cos(a),s[2]+l1*math.sin(a)
    local kx,ky=s[1]+d*math.cos(angle),s[2]+d*math.sin(angle)
    local a2=math.atan(ky-ey,kx-ex)
    local first=a-math.atan(e[2]-s[2],e[1]-s[1])
    local second=a2-math.atan(k[2]-e[2],k[1]-e[1])
    local tx,ty,tz=h[1]+(kx+rx-h[1])*math.cos(yaw),ky+ry,h[3]-(kx+rx-h[1])*math.sin(yaw)
    local function To3(x,y) return {h[1]+(x-h[1])*math.cos(yaw),y,h[3]-(x-h[1])*math.sin(yaw)} end
    return {yaw=yaw,first=Wrap(first),second=Wrap(second-first),blade=Wrap(bladeAngle-second),
        error=Hypot(tx-target[1],ty-target[2],tz-target[3]),toe={tx,ty,tz},
        points={hip={table.unpack(h)},shoulderJoint=To3(s[1],s[2]),elbow=To3(ex,ey),knee=To3(kx,ky),toe={tx,ty,tz}}}
end
function M.Reachable(g,target,evaluation)
    if not target or target[1]<g.origins.hip[1]+.12 then return false end
    for _,value in ipairs(target) do if value~=value or math.abs(value)==math.huge then return false end end
    -- Optional caller-owned evaluation is tied to this exact target for one Step.
    local pose=evaluation and evaluation.pose or M.Solve(g,target);local rad=math.pi/180
    if evaluation then evaluation.pose=pose end
    return pose.error<.035 and math.abs(pose.yaw)<105*rad and pose.first> -105*rad and pose.first<125*rad
        and math.abs(pose.second)<155*rad and math.abs(pose.blade)<170*rad
end
return M

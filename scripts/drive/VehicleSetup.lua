local Math=require "core.Math3"
local Capabilities=require "drive.Capabilities"
local Contact=require "drive.ContactControl"
local M={}
-- Bullet uses a different compound COM from Rapier's per-shape mass weights.
-- Distribute the residual supported mass around the measured native COM instead
-- of creating a constant pitch/roll moment on an otherwise symmetric hover car.
-- Solve the smallest change from rated-load shares. If COM lies outside the
-- support polygon, retain those shares: missing actuators must still tip/fall.
function M.HoverShares(spec,com)
    local hs={};local total=0
    for _,h in ipairs(spec.hovers) do if h.works then hs[#hs+1]=h;total=total+h.load end end
    local result={};if total==0 then return result end
    local rows={{}};local dx,dz={},{}
    for i,h in ipairs(hs) do rows[1][i]=1;dx[i]=h.pos[1]-com[1];dz[i]=h.pos[3]-com[3];result[h.partId]=h.load/total end
    if #hs<2 then return result end
    if math.max(table.unpack(dx))-math.min(table.unpack(dx))>.05 then rows[#rows+1]=dx end
    if math.max(table.unpack(dz))-math.min(table.unpack(dz))>.05 then rows[#rows+1]=dz end
    local a,b={},{}
    for i,r in ipairs(rows) do
        a[i]={};b[i]=i==1 and 1 or 0
        for k,h in ipairs(hs) do b[i]=b[i]-r[k]*result[h.partId] end
        for j,s in ipairs(rows) do local sum=0;for k,value in ipairs(r) do sum=sum+value*s[k] end;a[i][j]=sum end
    end
    for i=1,#rows do
        local pivot=i;for j=i+1,#rows do if math.abs(a[j][i])>math.abs(a[pivot][i]) then pivot=j end end
        if math.abs(a[pivot][i])<1e-9 then return result end
        a[i],a[pivot]=a[pivot],a[i];b[i],b[pivot]=b[pivot],b[i]
        for j=i+1,#rows do local f=a[j][i]/a[i][i];for k=i,#rows do a[j][k]=a[j][k]-f*a[i][k] end;b[j]=b[j]-f*b[i] end
    end
    local lambda={}
    for i=#rows,1,-1 do local value=b[i];for j=i+1,#rows do value=value-a[i][j]*lambda[j] end;lambda[i]=value/a[i][i] end
    local candidate={}
    for i,h in ipairs(hs) do
        local value=result[h.partId];for j,r in ipairs(rows) do value=value+r[i]*lambda[j] end
        if value<0 then return result end
        candidate[h.partId]=value
    end
    return candidate
end
function M.StaticLoads(spec,totalLoad)
    local mass=0;local center={0,0,0};local shares={}
    for _,list in ipairs({spec.boxes,spec.hulls,spec.wheels}) do for _,b in ipairs(list) do
        mass=mass+b.mass
        for k=1,3 do center[k]=center[k]+b.center[k]*b.mass end
    end end
    for i,w in ipairs(spec.wheels) do shares[i]=w.load/totalLoad end
    if mass<=0 then return shares end
    center=Math.Scale(center,1/mass)
    local indices,dx,dz,ones={},{},{},{}
    for i,w in ipairs(spec.wheels) do if not w["end"] then
        indices[#indices+1]=i;dx[#dx+1]=w.center[1]-center[1];dz[#dz+1]=w.center[3]-center[3];ones[#ones+1]=1
    end end
    if #indices<2 then return shares end
    local function Spread(v) return math.max(table.unpack(v))-math.min(table.unpack(v))>.05 end
    local rows={ones};if Spread(dx) then rows[#rows+1]=dx end;if Spread(dz) then rows[#rows+1]=dz end
    local a,rhs={},{}
    for i,r in ipairs(rows) do
        a[i]={};rhs[i]=i==1 and 1 or 0
        for j,q in ipairs(rows) do local sum=0;for k,v in ipairs(r) do sum=sum+v*q[k] end;a[i][j]=sum end
    end
    for p=1,#rows do
        if math.abs(a[p][p])<1e-9 then return shares end
        for r=p+1,#rows do
            local f=a[r][p]/a[p][p]
            for k=p,#rows do a[r][k]=a[r][k]-f*a[p][k] end
            rhs[r]=rhs[r]-f*rhs[p]
        end
    end
    local lambda={}
    for p=#rows,1,-1 do
        local v=rhs[p];for k=p+1,#rows do v=v-a[p][k]*lambda[k] end
        lambda[p]=v/a[p][p]
    end
    for j,i in ipairs(indices) do
        local value=0;for k,r in ipairs(rows) do value=value+lambda[k]*r[j] end
        shares[i]=math.max(.15/#indices,value)
    end
    for i,w in ipairs(spec.wheels) do if w["end"] then shares[i]=.5 end end
    return shares
end
function M.Wheels(spec)
    local capabilities=Capabilities.Compute(spec)
    local shares=M.StaticLoads(spec,math.max(1,spec.motion.load))
    local roadSum=0;for i,w in ipairs(spec.wheels) do if not w["end"] then roadSum=roadSum+shares[i] end end
    if capabilities.hoverLoad>0 or capabilities.legLoad>0 then for i,w in ipairs(spec.wheels) do
        shares[i]=w["end"] and shares[i]*capabilities.wheelShare or shares[i]/math.max(1e-9,roadSum)*capabilities.wheelShare
    end end
    local bottom=math.huge
    for _,b in ipairs(spec.boxes) do bottom=math.min(bottom,b.center[2]-b.half[2]) end
    for _,h in ipairs(spec.hulls) do if not h.track then bottom=math.min(bottom,h.center[2]-Math.Length(h.half)) end end
    local wheels={}
    for i,w in ipairs(spec.wheels) do
        local rest=Math.Clamp(.28*w.radius+.06,.12,.5)
        local soft=w.track and .2 or Contact.FEEL.soft
        local sag=w["end"] and 0 or math.min(.9,soft*math.max(1,spec.motion.L))
        local drop=Math.Clamp((w.center[2]-w.radius)-bottom+.12,0,math.max(.15,w.radius*.4))
        local conn={w.center[1],w.center[2]-drop+rest*(1-sag),w.center[3]}
        local axle=math.abs(w.axle[1])>.5 and {-1,0,0} or {0,0,1}
        local alignment=Math.Dot(axle,w.axle);local sign=alignment<0 and -1 or 1
        local k=9.81*shares[i]/(soft*rest*math.max(1,spec.motion.L))
        local damping=2*math.sqrt(k*shares[i])
        local result={};for key,value in pairs(w) do result[key]=value end
        result.rest=rest;result.sag0=sag;result.drop=drop;result.spinSign=sign;result.index=i;result.share=shares[i]
        result.conn=conn;result.contactAxle=axle;result.stiffness=k;result.compression=damping*.5;result.relaxation=damping*Contact.FEEL.bounce
        result.down={0,-1,0}
        result.maxTravel=rest*.95;result.maxForce=w.load*9.81*6;result.friction=w.track and Contact.TUNING.trackGrip or Contact.TUNING.wheelGrip
        wheels[#wheels+1]=result
    end
    return wheels,capabilities
end
function M.Handling(vehicle,com)
    local wheels,spec=vehicle.wheels,vehicle.spec
    vehicle.com=com;vehicle.nRear=0;vehicle.steerWheels={};vehicle.trackWheels={}
    vehicle.hoverShares=M.HoverShares(spec,com)
    local frontSteer=false
    for _,w in ipairs(wheels) do
        w.rear=w.center[3]<com[3]-.1
        if w.rear then vehicle.nRear=vehicle.nRear+1 end
        if w.steer then vehicle.steerWheels[#vehicle.steerWheels+1]=w;if w.center[3]>=com[3]-.1 then frontSteer=true end end
        if w.track then vehicle.trackWheels[#vehicle.trackWheels+1]=w end
    end
    if vehicle.nRear==0 then for _,w in ipairs(wheels) do w.rear=true end;vehicle.nRear=#wheels end
    for _,w in ipairs(vehicle.steerWheels) do w.rearFade=frontSteer and w.center[3]<com[3]-.1 end
    vehicle.tracked=#vehicle.trackWheels>0
    local minZ,maxZ=math.huge,-math.huge
    local inertia,halfTrack,halfBase,supFront,supRear,bottom=0,.3,.3,.3,.3,math.huge
    for _,b in ipairs(spec.boxes) do inertia=inertia+b.mass*((b.center[1]-com[1])^2+(b.center[3]-com[3])^2+(b.half[1]^2+b.half[3]^2)/3) end
    for _,h in ipairs(spec.hulls) do inertia=inertia+h.mass*((h.center[1]-com[1])^2+(h.center[3]-com[3])^2) end
    for _,w in ipairs(wheels) do
        local x,z=w.center[1]-com[1],w.center[3]-com[3]
        inertia=inertia+w.mass*(x*x+z*z);halfTrack=math.max(halfTrack,math.abs(x));halfBase=math.max(halfBase,math.abs(z))
        supFront=math.max(supFront,z);supRear=math.max(supRear,-z)
        minZ=math.min(minZ,w.center[3]);maxZ=math.max(maxZ,w.center[3]);bottom=math.min(bottom,w.center[2]-w.drop-w.radius)
    end
    vehicle.wheelbase=#wheels>0 and maxZ-minZ or 0;vehicle.rMin=Math.Clamp(vehicle.wheelbase*.5+1,2.5,6)
    vehicle.inertiaY=math.max(inertia,vehicle.mass*.5);vehicle.halfTrack=halfTrack;vehicle.halfBase=halfBase
    vehicle.supFront=supFront;vehicle.supRear=supRear;vehicle.cgH=#wheels>0 and math.max(.2,com[2]-bottom) or .5
    vehicle.vPrev=0;vehicle.aLong=0;vehicle.aLat=0;vehicle.steer=0;vehicle.drifting=false
    vehicle.hoverMode=vehicle.capabilities.hoverMode;vehicle.legMode=vehicle.capabilities.legMode
end
return M

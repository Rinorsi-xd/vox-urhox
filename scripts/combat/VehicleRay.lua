-- Combat-only hit volumes from the same source spec as native chassis collision.
-- Native Raycast exposes body, not compound shape id; preserve source per-part
-- hull/wheel IDs and non-colliding track sensors with analytic ray intersections.
-- Suspension still uses native Space.Raycast and never collides with sensors.
local V=require "core.Math3"
local M={}
-- Slabs in shape-local space; offset avoids allocating a translated origin
-- for every axis-aligned part. Inside hits retain the source -direction normal.
-- Boundary contact is inclusive; parallel rays outside any slab miss.
-- Returns distance, normal axis (0 = inside: normal is -dir) and its sign.
-- Callers build the normal only for the final hit; no per-candidate tables.
local function Box(origin,dir,half,maxDist,offset)
    local near,far=0,maxDist;local normalAxis,normalSign=0,0
    for axis=1,3 do
        local at=origin[axis]-(offset and offset[axis] or 0)
        if math.abs(dir[axis])<1e-9 then if math.abs(at)>half[axis] then return end
        else
            local a=(-half[axis]-at)/dir[axis];local b=(half[axis]-at)/dir[axis]
            local sign=-1;if a>b then a,b=b,a;sign=1 end
            if a>near then near=a;normalAxis=axis;normalSign=sign end
            far=math.min(far,b);if near>far then return end
        end
    end
    return near,normalAxis,normalSign
end
-- Scalar form of the former V.Dot/Sub/Scale/Normalize expression, same order.
-- Origin is (ox,oy,oz) relative to the wheel centre; returns t,nx,ny,nz.
local function Cylinder(ox,oy,oz,dir,axis,radius,halfWidth,maxDist)
    local a1,a2,a3=axis[1],axis[2],axis[3];local d1,d2,d3=dir[1],dir[2],dir[3]
    local o=ox*a1+oy*a2+oz*a3;local d=d1*a1+d2*a2+d3*a3
    local rox,roy,roz=ox-a1*o,oy-a2*o,oz-a3*o
    local rdx,rdy,rdz=d1-a1*d,d2-a2*d,d3-a3*d
    local roro=rox*rox+roy*roy+roz*roz
    if math.abs(o)<=halfWidth and roro<=radius*radius then return 0,d1*-1,d2*-1,d3*-1 end
    local best=maxDist+1;local nx,ny,nz=0,0,0
    local a=rdx*rdx+rdy*rdy+rdz*rdz;local b=2*(rox*rdx+roy*rdy+roz*rdz);local c=roro-radius*radius
    local discriminant=b*b-4*a*c
    if a>1e-12 and discriminant>=0 then
        local root=math.sqrt(discriminant)
        for i=1,2 do
            local t=i==1 and (-b-root)/(2*a) or (-b+root)/(2*a)
            if t>=0 and t<best and math.abs(o+d*t)<=halfWidth then
                best=t
                local vx,vy,vz=rox+rdx*t,roy+rdy*t,roz+rdz*t
                local l=math.sqrt(vx*vx+vy*vy+vz*vz);local k=l>0 and 1/l or 1
                nx,ny,nz=vx*k,vy*k,vz*k
            end
        end
    end
    if math.abs(d)>1e-9 then for sign=-1,1,2 do
        local t=(sign*halfWidth-o)/d;local x,y,z=rox+rdx*t,roy+rdy*t,roz+rdz*t
        if t>=0 and t<best and x*x+y*y+z*z<=radius*radius then best=t;nx,ny,nz=a1*sign,a2*sign,a3*sign end
    end end
    if best<=maxDist then return best,nx,ny,nz end
end
-- Same operation order as V.Rotate(q,{vx,vy,vz}).
local function RotateXYZ(q,vx,vy,vz)
    local x,y,z,w=q.x,q.y,q.z,q.w
    local ix=w*vx+y*vz-z*vy
    local iy=w*vy+z*vx-x*vz
    local iz=w*vz+x*vy-y*vx
    local iw=-x*vx-y*vy-z*vz
    return ix*w-iw*x-iy*z+iz*y,iy*w-iw*y-iz*x+ix*z,iz*w-iw*z-ix*y+iy*x
end
local function Grow(lo,hi,center,half)
    for i=1,3 do lo[i]=math.min(lo[i],center[i]-half[i]);hi[i]=math.max(hi[i],center[i]+half[i]) end
end
local function GrowShapes(lo,hi,list)
    for _,s in ipairs(list) do
        local h=s.half
        if s.quat then
            local x=V.Rotate(s.quat,{h[1],0,0});local y=V.Rotate(s.quat,{0,h[2],0});local z=V.Rotate(s.quat,{0,0,h[3]})
            local c=s.center
            for i=1,3 do local e=math.abs(x[i])+math.abs(y[i])+math.abs(z[i]);lo[i]=math.min(lo[i],c[i]-e);hi[i]=math.max(hi[i],c[i]+e) end
        else Grow(lo,hi,s.center,h) end
    end
end
-- Chassis shapes and wheels move only through Vehicle:ApplyRotors, which clears
-- rayStaticBounds. Leg/mech hitboxes move every step and are folded in per rebuild.
local function StaticBounds(vehicle)
    local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
    for _,list in ipairs({vehicle.spec.boxes,vehicle.spec.hulls,vehicle.spec.sensors}) do GrowShapes(lo,hi,list) end
    for _,w in ipairs(vehicle.wheels) do if not w.track then
        local radius=math.max(w.radius,w.width*.5);local half={radius,radius,radius}
        Grow(lo,hi,V.Add(w.center,V.Scale(w.down or {0,-1,0},w.drop)),half);Grow(lo,hi,w.conn,half)
    end end
    return {lo=lo,hi=hi}
end
local function Bounds(vehicle)
    vehicle.rayStaticBounds=vehicle.rayStaticBounds or StaticBounds(vehicle)
    local base=vehicle.rayStaticBounds
    local lo,hi={base.lo[1],base.lo[2],base.lo[3]},{base.hi[1],base.hi[2],base.hi[3]}
    if vehicle.legHitboxes then GrowShapes(lo,hi,vehicle.legHitboxes:Items()) end
    if vehicle.mechHitboxes then GrowShapes(lo,hi,vehicle.mechHitboxes.items) end
    return {center=V.Scale(V.Add(lo,hi),.5),half=V.Scale(V.Sub(hi,lo),.5)}
end
-- Conservative sphere test against segment o+t*d, t in [0,limit]. Every shape
-- lies inside its sphere, so a rejected shape could not have produced a hit.
local function SegmentMissesSphere(o,d,dd,cx,cy,cz,r2,limit)
    local wx,wy,wz=cx-o[1],cy-o[2],cz-o[3]
    local t=dd>1e-18 and (wx*d[1]+wy*d[2]+wz*d[3])/dd or 0
    if t<0 then t=0 elseif t>limit then t=limit end
    local ex,ey,ez=wx-d[1]*t,wy-d[2]*t,wz-d[3]*t
    return ex*ex+ey*ey+ez*ez>r2*1.0001+1e-6
end
local scratchO,scratchD={0,0,0},{0,0,0}
-- Same operation order as V.Unrotate(q,{x,y,z}), without temporary tables.
local function UnrotateInto(q,vx,vy,vz,out)
    local x,y,z,w=-q.x,-q.y,-q.z,q.w
    local ix=w*vx+y*vz-z*vy
    local iy=w*vy+z*vx-x*vz
    local iz=w*vz+x*vy-y*vx
    local iw=-x*vx-y*vy-z*vz
    out[1]=ix*w-iw*x-iy*z+iz*y;out[2]=iy*w-iw*y-iz*x+ix*z;out[3]=iz*w-iw*z-ix*y+iy*x
    return out
end
-- Pose is read once per physics step per vehicle. Every wrapper pose write
-- bumps poseVersion and Space:Step bumps stepIndex, so a stale pose cannot match.
local function Pose(vehicle,body)
    local space=vehicle.space;local cache=vehicle.rayPose
    if space and body.poseVersion then
        local step,version=space.stepIndex,body.poseVersion()
        if cache and cache.body==body and cache.step==step and cache.version==version then return cache.p,cache.q end
        cache=cache or {};vehicle.rayPose=cache
        cache.body=body;cache.step=step;cache.version=version;cache.p=body.translation();cache.q=body.rotation()
        return cache.p,cache.q
    end
    return body.translation(),body.rotation()
end
local scratchL,scratchLD={0,0,0},{0,0,0}
-- Per-cast state shared by Scan; Cast is not re-entrant.
local castO,castD,castDD,limit
local bestDist,bestAxis,bestSign,bestNx,bestNy,bestNz,bestQuat,bestId
local function Scan(list)
    local o,d,dd=castO,castD,castDD
    for _,shape in ipairs(list) do
        local c,h=shape.center,shape.half
        if not SegmentMissesSphere(o,d,dd,c[1],c[2],c[3],h[1]*h[1]+h[2]*h[2]+h[3]*h[3],limit) then
            local quat=shape.quat;local distance,axis,sign
            if quat then
                local lo=UnrotateInto(quat,o[1]-c[1],o[2]-c[2],o[3]-c[3],scratchL)
                local ld=UnrotateInto(quat,d[1],d[2],d[3],scratchLD)
                distance,axis,sign=Box(lo,ld,h,limit)
                if distance and distance<=limit and axis==0 then bestNx,bestNy,bestNz=ld[1]*-1,ld[2]*-1,ld[3]*-1 end
            else
                distance,axis,sign=Box(o,d,h,limit,c)
                if distance and distance<=limit and axis==0 then bestNx,bestNy,bestNz=d[1]*-1,d[2]*-1,d[3]*-1 end
            end
            if distance and distance<=limit then
                limit=distance;bestDist=distance;bestAxis=axis;bestSign=sign;bestQuat=quat;bestId=shape.partId
            end
        end
    end
end
local function AcceptWheel(distance,nx,ny,nz,id)
    if distance and distance<=limit then
        limit=distance;bestDist=distance;bestAxis=-1;bestNx,bestNy,bestNz=nx,ny,nz;bestQuat=nil;bestId=id
    end
end
local DOWN={0,-1,0}
function M.Cast(vehicle,origin,direction,length)
    local body=vehicle.body;local p,q=Pose(vehicle,body)
    local o=UnrotateInto(q,origin[1]-p.x,origin[2]-p.y,origin[3]-p.z,scratchO)
    local d=UnrotateInto(q,direction[1],direction[2],direction[3],scratchD)
    vehicle.rayBounds=vehicle.rayBounds or Bounds(vehicle)
    local bounds=vehicle.rayBounds
    if not Box(o,d,bounds.half,length,bounds.center) then return end
    castO,castD,castDD,limit=o,d,d[1]*d[1]+d[2]*d[2]+d[3]*d[3],length;bestDist=nil;bestQuat=nil;bestId=nil
    local spec=vehicle.spec
    Scan(spec.boxes);Scan(spec.hulls);Scan(spec.sensors)
    if vehicle.legHitboxes then Scan(vehicle.legHitboxes:Items()) end
    if vehicle.mechHitboxes then Scan(vehicle.mechHitboxes.items) end
    local dd=castDD
    for _,w in ipairs(vehicle.wheels) do if not w.track then
        local down=w.down or DOWN;local wc,drop=w.center,w.drop
        local cx,cy,cz=wc[1]+down[1]*drop,wc[2]+down[2]*drop,wc[3]+down[3]*drop
        local radius,half=w.radius,w.width*.5
        if not SegmentMissesSphere(o,d,dd,cx,cy,cz,radius*radius+half*half,limit) then
            local distance,nx,ny,nz=Cylinder(o[1]-cx,o[2]-cy,o[3]-cz,d,w.axle,radius,half,limit)
            AcceptWheel(distance,nx,ny,nz,w.partId)
        end
        local conn=w.conn;local r2,h2=radius*.9,w.width*.45
        if not SegmentMissesSphere(o,d,dd,conn[1],conn[2],conn[3],r2*r2+h2*h2,limit) then
            local distance,nx,ny,nz=Cylinder(o[1]-conn[1],o[2]-conn[2],o[3]-conn[3],d,w.axle,r2,h2,limit)
            AcceptWheel(distance,nx,ny,nz,w.partId)
        end
    end end
    if not bestDist then return end
    local nx,ny,nz
    if bestAxis==-1 or bestAxis==0 then nx,ny,nz=bestNx,bestNy,bestNz
    else nx,ny,nz=0,0,0;if bestAxis==1 then nx=bestSign elseif bestAxis==2 then ny=bestSign else nz=bestSign end end
    if bestQuat then nx,ny,nz=RotateXYZ(bestQuat,nx,ny,nz) end
    nx,ny,nz=RotateXYZ(q,nx,ny,nz)
    local dist=bestDist;bestQuat=nil
    return {dist=dist,normal={nx,ny,nz},partId=bestId,
        point={origin[1]+direction[1]*dist,origin[2]+direction[2]*dist,origin[3]+direction[3]*dist},body=body}
end
return M

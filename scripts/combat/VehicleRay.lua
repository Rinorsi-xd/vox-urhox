-- Combat-only hit volumes from the same source spec as native chassis collision.
-- Native Raycast exposes body, not compound shape id; preserve source per-part
-- hull/wheel IDs and non-colliding track sensors with analytic ray intersections.
-- Suspension still uses native Space.Raycast and never collides with sensors.
local V=require "core.Math3"
local M={}
-- Slabs in shape-local space; offset avoids allocating a translated origin
-- for every axis-aligned part. Inside hits retain the source -direction normal.
-- Boundary contact is inclusive; parallel rays outside any slab miss.
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
    local normal=nil ---@type number[]|nil
    if normalAxis==0 then normal=V.Scale(dir,-1)
    else normal={0,0,0};normal[normalAxis]=normalSign end
    return near,normal
end
local function Cylinder(origin,dir,axis,radius,halfWidth,maxDist)
    local o=V.Dot(origin,axis);local d=V.Dot(dir,axis)
    local ro=V.Sub(origin,V.Scale(axis,o));local rd=V.Sub(dir,V.Scale(axis,d))
    if math.abs(o)<=halfWidth and V.Dot(ro,ro)<=radius*radius then return 0,V.Scale(dir,-1) end
    local best=maxDist+1;local normal={0,0,0};local a=V.Dot(rd,rd);local b=2*V.Dot(ro,rd);local c=V.Dot(ro,ro)-radius*radius
    local discriminant=b*b-4*a*c
    if a>1e-12 and discriminant>=0 then
        local root=math.sqrt(discriminant)
        for _,t in ipairs({(-b-root)/(2*a),(-b+root)/(2*a)}) do
            if t>=0 and t<best and math.abs(o+d*t)<=halfWidth then best=t;normal=V.Normalize(V.Add(ro,V.Scale(rd,t))) end
        end
    end
    if math.abs(d)>1e-9 then for _,sign in ipairs({-1,1}) do
        local t=(sign*halfWidth-o)/d;local radial=V.Add(ro,V.Scale(rd,t))
        if t>=0 and t<best and V.Dot(radial,radial)<=radius*radius then best=t;normal=V.Scale(axis,sign) end
    end end
    if best<=maxDist then return best,normal end
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
local noItems={}
function M.Cast(vehicle,origin,direction,length)
    local body=vehicle.body;local p=body.translation();local q=body.rotation()
    local o=UnrotateInto(q,origin[1]-p.x,origin[2]-p.y,origin[3]-p.z,scratchO)
    local d=UnrotateInto(q,direction[1],direction[2],direction[3],scratchD)
    vehicle.rayBounds=vehicle.rayBounds or Bounds(vehicle)
    local bounds=vehicle.rayBounds
    if not Box(o,d,bounds.half,length,bounds.center) then return end
    local best=nil ---@type table|nil
    local limit=length
    local dd=d[1]*d[1]+d[2]*d[2]+d[3]*d[3]
    local function Accept(distance,normal,id)
        if distance and distance<=limit then limit=distance;best={dist=distance,normal=V.Rotate(q,normal),partId=id} end
    end
    for _,list in ipairs({vehicle.spec.boxes,vehicle.spec.hulls,vehicle.spec.sensors,vehicle.legHitboxes and vehicle.legHitboxes:Items() or noItems,vehicle.mechHitboxes and vehicle.mechHitboxes.items or noItems}) do for _,shape in ipairs(list) do
        local c,h=shape.center,shape.half
        if not SegmentMissesSphere(o,d,dd,c[1],c[2],c[3],h[1]*h[1]+h[2]*h[2]+h[3]*h[3],limit) then
            local distance,normal
            if shape.quat then
                distance,normal=Box(V.Unrotate(shape.quat,V.Sub(o,shape.center)),V.Unrotate(shape.quat,d),shape.half,limit)
            else distance,normal=Box(o,d,shape.half,limit,shape.center) end
            if normal and shape.quat then normal=V.Rotate(shape.quat,normal) end
            Accept(distance,normal,shape.partId)
        end
    end end
    for _,w in ipairs(vehicle.wheels) do if not w.track then
        local down=w.down or {0,-1,0};local wc,drop=w.center,w.drop
        local cx,cy,cz=wc[1]+down[1]*drop,wc[2]+down[2]*drop,wc[3]+down[3]*drop
        local radius,half=w.radius,w.width*.5
        if not SegmentMissesSphere(o,d,dd,cx,cy,cz,radius*radius+half*half,limit) then
            local distance,normal=Cylinder(V.Sub(o,{cx,cy,cz}),d,w.axle,radius,half,limit)
            Accept(distance,normal,w.partId)
        end
        local conn=w.conn;local r2,h2=radius*.9,w.width*.45
        if not SegmentMissesSphere(o,d,dd,conn[1],conn[2],conn[3],r2*r2+h2*h2,limit) then
            local distance,normal=Cylinder(V.Sub(o,conn),d,w.axle,r2,h2,limit)
            Accept(distance,normal,w.partId)
        end
    end end
    if best then best.point=V.Add(origin,V.Scale(direction,best.dist));best.body=body end
    return best
end
return M

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
local function Bounds(vehicle)
    local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
    local function Grow(center,half)
        for i=1,3 do lo[i]=math.min(lo[i],center[i]-half[i]);hi[i]=math.max(hi[i],center[i]+half[i]) end
    end
    for _,list in ipairs({vehicle.spec.boxes,vehicle.spec.hulls,vehicle.spec.sensors,vehicle.legHitboxes and vehicle.legHitboxes.items or {},vehicle.mechHitboxes and vehicle.mechHitboxes.items or {}}) do for _,s in ipairs(list) do
        local half={table.unpack(s.half)}
        if s.quat then
            local x=V.Rotate(s.quat,{s.half[1],0,0});local y=V.Rotate(s.quat,{0,s.half[2],0});local z=V.Rotate(s.quat,{0,0,s.half[3]})
            for i=1,3 do half[i]=math.abs(x[i])+math.abs(y[i])+math.abs(z[i]) end
        end
        Grow(s.center,half)
    end end
    for _,w in ipairs(vehicle.wheels) do if not w.track then
        local radius=math.max(w.radius,w.width*.5);local half={radius,radius,radius}
        Grow(V.Add(w.center,V.Scale(w.down or {0,-1,0},w.drop)),half);Grow(w.conn,half)
    end end
    return {center=V.Scale(V.Add(lo,hi),.5),half=V.Scale(V.Sub(hi,lo),.5)}
end
function M.Cast(vehicle,origin,direction,length)
    local body=vehicle.body;local p=body.translation();local q=body.rotation()
    local o=V.Unrotate(q,V.Sub(origin,{p.x,p.y,p.z}));local d=V.Unrotate(q,direction)
    vehicle.rayBounds=vehicle.rayBounds or Bounds(vehicle)
    local bounds=vehicle.rayBounds
    if not Box(o,d,bounds.half,length,bounds.center) then return end
    local best=nil ---@type table|nil
    local limit=length
    local function Accept(distance,normal,id)
        if distance and distance<=limit then limit=distance;best={dist=distance,normal=V.Rotate(q,normal),partId=id} end
    end
    for _,list in ipairs({vehicle.spec.boxes,vehicle.spec.hulls,vehicle.spec.sensors,vehicle.legHitboxes and vehicle.legHitboxes.items or {},vehicle.mechHitboxes and vehicle.mechHitboxes.items or {}}) do for _,shape in ipairs(list) do
        local distance,normal
        if shape.quat then
            distance,normal=Box(V.Unrotate(shape.quat,V.Sub(o,shape.center)),V.Unrotate(shape.quat,d),shape.half,limit)
        else distance,normal=Box(o,d,shape.half,limit,shape.center) end
        if normal and shape.quat then normal=V.Rotate(shape.quat,normal) end
        Accept(distance,normal,shape.partId)
    end end
    for _,w in ipairs(vehicle.wheels) do if not w.track then
        local center=V.Add(w.center,V.Scale(w.down or {0,-1,0},w.drop))
        local distance,normal=Cylinder(V.Sub(o,center),d,w.axle,w.radius,w.width*.5,limit)
        Accept(distance,normal,w.partId)
        distance,normal=Cylinder(V.Sub(o,w.conn),d,w.axle,w.radius*.9,w.width*.45,limit)
        Accept(distance,normal,w.partId)
    end end
    if best then best.point=V.Add(origin,V.Scale(direction,best.dist));best.body=body end
    return best
end
return M

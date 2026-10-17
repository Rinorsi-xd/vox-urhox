-- Isolated candidate. V and OriginalBounds are supplied by the exact baseline.
local function Bounds(vehicle)
    -- Turntables mutate center/quat in these lists in place; preserve that path.
    if not vehicle.rotors or #vehicle.rotors>0 then vehicle.rayStaticBounds=nil;return OriginalBounds(vehicle) end
    local spec=vehicle.spec;local cached=vehicle.rayStaticBounds
    if not cached or cached.spec~=spec or cached.boxes~=spec.boxes or cached.hulls~=spec.hulls
        or cached.sensors~=spec.sensors or cached.boxCount~=#spec.boxes
        or cached.hullCount~=#spec.hulls or cached.sensorCount~=#spec.sensors then
        local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
        for _,list in ipairs({spec.boxes,spec.hulls,spec.sensors})do for _,s in ipairs(list)do
            local half={table.unpack(s.half)}
            if s.quat then
                local x=V.Rotate(s.quat,{s.half[1],0,0});local y=V.Rotate(s.quat,{0,s.half[2],0});local z=V.Rotate(s.quat,{0,0,s.half[3]})
                for i=1,3 do half[i]=math.abs(x[i])+math.abs(y[i])+math.abs(z[i]) end
            end
            for i=1,3 do lo[i]=math.min(lo[i],s.center[i]-half[i]);hi[i]=math.max(hi[i],s.center[i]+half[i]) end
        end end
        cached={spec=spec,boxes=spec.boxes,hulls=spec.hulls,sensors=spec.sensors,
            boxCount=#spec.boxes,hullCount=#spec.hulls,sensorCount=#spec.sensors,lo=lo,hi=hi}
        vehicle.rayStaticBounds=cached
    end
    local lo,hi={table.unpack(cached.lo)},{table.unpack(cached.hi)}
    local function Grow(center,half)
        for i=1,3 do lo[i]=math.min(lo[i],center[i]-half[i]);hi[i]=math.max(hi[i],center[i]+half[i]) end
    end
    for _,list in ipairs({vehicle.legHitboxes and vehicle.legHitboxes.items or {},vehicle.mechHitboxes and vehicle.mechHitboxes.items or {}})do for _,s in ipairs(list)do
        local half={table.unpack(s.half)}
        if s.quat then
            local x=V.Rotate(s.quat,{s.half[1],0,0});local y=V.Rotate(s.quat,{0,s.half[2],0});local z=V.Rotate(s.quat,{0,0,s.half[3]})
            for i=1,3 do half[i]=math.abs(x[i])+math.abs(y[i])+math.abs(z[i]) end
        end
        Grow(s.center,half)
    end end
    for _,w in ipairs(vehicle.wheels)do if not w.track then
        local radius=math.max(w.radius,w.width*.5);local half={radius,radius,radius}
        Grow(V.Add(w.center,V.Scale(w.down or {0,-1,0},w.drop)),half);Grow(w.conn,half)
    end end
    return {center=V.Scale(V.Add(lo,hi),.5),half=V.Scale(V.Sub(hi,lo),.5)}
end
return Bounds

-- Engine-independent body description, ported from shared/drive/vehicleSpec.js.
-- Geometry in source coordinates; engine adapters alone mirror X.
-- Collision design (body space):
--   [merged solid boxes] + [rotated thin/frame hulls] = chassis contact volume
--          |-- wheel/track suspension rays --|       = ground support
--   [track full bounds / moving leg links]           = hit sensors, no support
-- Thin antenna/flag add mass to their mount; inverted wheels become structure.
-- Only parts connected to the core drive. Debris uses all supplied parts.
local Config=require "Config"
local Defs=require "parts.Defs"
local Rot=require "core.Rotations"
local Assets=require "parts.PartAssets"
local Loadout=require "combat.WeaponLoadout"
local Math=require "core.Math3"
local Geometry=require("core.ResourceData").Read("Drive/Geometry.json")
local Mech=require 'parts.MechIK'
local M={GEOMETRY=Geometry}
local CELL=Config.CELL
local THIN={antenna=true,flag=true}
local IDENTITY={x=0,y=0,z=0,w=1}
local function Key(x,y,z) return x..","..y..","..z end
local function Origin(p) return {p.pos[1],p.pos[2]+0.5,p.pos[3]} end
local function ToBody(p,v) return Math.Scale(Math.Add(Origin(p),Rot.ApplyRot(p.rot,v)),CELL) end
local function QMul(a,b)
    return {x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,y=a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,
        z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w,w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z}
end
local function Box(p,b,mass)
    return {partId=p.id,center=ToBody(p,b.c),half=Math.Scale(b.h,CELL),quat=Geometry.rotations[p.rot+1],mass=mass}
end
local function FullTrack(g)
    local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
    for _,c in ipairs(g.cells) do for k=1,3 do lo[k]=math.min(lo[k],c[k]-.5);hi[k]=math.max(hi[k],c[k]+.5) end end
    local half=Math.Scale(Math.Sub(hi,lo),.5)
    for k=1,3 do half[k]=half[k]-.02 end
    return {c=Math.Scale(Math.Add(lo,hi),.5),h=half}
end
local function TrackShape(g)
    -- The hull is clipped at the lowest road axle: suspension supports below
    -- it, while the rounded/sloping ends contact rocks without a vertical wall.
    -- Inverted/sideways mounts retain the full box used by source debris.
    local axle=math.huge
    for _,w in ipairs(g.wheels) do if w.kind=='road' then axle=math.min(axle,w.c[3]) end end
    local out={};local c=g.hull.c
    for _,w in ipairs(g.wheels) do for i=0,15 do
        local a=i/16*math.pi*2;local r=w.r+g.thickness
        local x=w.c[1]+math.cos(a)*r;local z=math.max(axle,w.c[3]+math.sin(a)*r)
        for _,y in ipairs(g.lanes[1]) do
            -- Match the source Float32Array before the native convex hull.
            for _,v in ipairs({(x-c[1])*CELL,(y-c[2])*CELL,(z-c[3])*CELL}) do
                out[#out+1]=string.unpack('f',string.pack('f',v))
            end
        end
    end end
    return out
end
local function HoverBox(g)
    -- Mount-local collision along dominant lift axis, before rotating to body:
    --   installation face | solid hull | lift point ... hover gap ... ground
    -- Clip only the ground-facing side at lift.p; retain >= .1 cell thickness.
    -- Side mounts and inverted mounts use the same signed-axis rule. Do not
    -- merge their occupied cells again: that would restore the clipped volume.
    local box=FullTrack(g);local axis=1
    for k=2,3 do if math.abs(g.liftDir[k])>math.abs(g.liftDir[axis]) then axis=k end end
    local lo,hi=Math.Sub(box.c,box.h),Math.Add(box.c,box.h);local edge=g.lift.p[axis]
    if g.liftDir[axis]<0 then hi[axis]=math.max(lo[axis]+.1,math.min(hi[axis],edge))
    else lo[axis]=math.min(hi[axis]-.1,math.max(lo[axis],edge)) end
    return {c=Math.Scale(Math.Add(lo,hi),.5),h=Math.Scale(Math.Sub(hi,lo),.5)}
end
function M.HullBoxes(p)
    local def=Defs.PARTS[p.type];local boxes={}
    for _,h in ipairs(def.hull) do
        boxes[#boxes+1]={partId=p.id,center=ToBody(p,h.c),half=Math.Scale(h.h,CELL),
            quat=QMul(Geometry.rotations[p.rot+1],h.q or IDENTITY),mass=def.mass/#def.hull}
    end
    return boxes
end
local function Append(to,from) for _,v in ipairs(from) do to[#to+1]=v end end
local function AddMass(solid,c,mass)
    local key=Key(table.unpack(c))
    if not solid[key] then solid[key]={pos=c,mass=0} end
    solid[key].mass=solid[key].mass+mass
end
function M.MergeBoxes(cells,checkpoint)
    local left,order={},{}
    for key,c in pairs(cells) do left[key]=c.mass;order[#order+1]=c.pos end
    table.sort(order,function(a,b)
        if a[2]~=b[2] then return a[2]<b[2] end
        if a[3]~=b[3] then return a[3]<b[3] end
        return a[1]<b[1]
    end)
    local m0=0
    local function Has(x,y,z)
        local mass=left[Key(x,y,z)]
        return mass~=nil and mass<=m0*2 and mass*2>=m0
    end
    local boxes={}
    for _,c in ipairs(order) do
        if checkpoint then checkpoint() end
        local x0,y0,z0=table.unpack(c)
        local seed=left[Key(x0,y0,z0)]
        if seed~=nil then
            m0=seed
            local x1=x0;while Has(x1+1,y0,z0) do x1=x1+1 end
            local function Row(y,z) for x=x0,x1 do if not Has(x,y,z) then return false end end;return true end
            local z1=z0;while Row(y0,z1+1) do z1=z1+1 end
            local function Layer(y) for z=z0,z1 do if not Row(y,z) then return false end end;return true end
            local y1=y0;while Layer(y1+1) do y1=y1+1 end
            local mass=0
            for y=y0,y1 do for z=z0,z1 do for x=x0,x1 do
                local key=Key(x,y,z);mass=mass+left[key];left[key]=nil
            end;if checkpoint then checkpoint() end end end
            boxes[#boxes+1]={center={(x0+x1)/2*CELL,((y0+y1)/2+.5)*CELL,(z0+z1)/2*CELL},
                half={(x1-x0+1)*CELL/2,(y1-y0+1)*CELL/2,(z1-z0+1)*CELL/2},mass=mass}
        end
    end
    return boxes
end
function M.Debris(parts)
    local solid,wheels,hulls={},{},{};local mass=0
    for _,p in ipairs(parts) do
        local def=Defs.PARTS[p.type];mass=mass+def.mass
        local track,wheel=Geometry.tracks[p.type],Geometry.wheels[p.type]
        if track then hulls[#hulls+1]=Box(p,FullTrack(track),def.mass)
        elseif wheel then
            wheels[#wheels+1]={center=ToBody(p,{0,wheel.cy,0}),axle=Rot.ApplyRot(p.rot,{0,1,0}),radius=wheel.r*CELL,width=wheel.w*CELL,mass=def.mass}
        elseif def.hull then Append(hulls,M.HullBoxes(p))
        else
            local cells=THIN[p.type] and {p._cells[1]} or p._cells
            for _,c in ipairs(cells) do AddMass(solid,c,def.mass/#cells) end
        end
    end
    return {boxes=M.MergeBoxes(solid),hulls=hulls,wheels=wheels,mass=mass}
end
local function AddTrack(p,def,g,up,out)
    local upright=Rot.ApplyRot(p.rot,{0,0,1})[2]>.5
    if upright then
        local total,ground=0,math.huge
        for _,w in ipairs(g.wheels) do
            total=total+(w.kind=="road" and 1 or .3)
            if w.kind=="road" then ground=math.min(ground,w.c[3]-w.r-g.thickness) end
        end
        local lane=g.lanes[1]
        for _,w in ipairs(g.wheels) do
            local center=w.kind=="road" and w.c or {w.c[1],w.c[2],w.c[3]-(w.c[3]-w.r-g.thickness-ground)}
            out.wheels[#out.wheels+1]={partId=p.id,type=p.type,track=true,["end"]=w.kind~="road",center=ToBody(p,center),axle=up,
                radius=(w.r+g.thickness)*CELL,width=(lane[2]-lane[1])*CELL,mass=0,
                load=def.load*(w.kind=="road" and 1 or .3)/total,speed=def.speed/3.6,steer=false,steerAngle=0}
        end
    end
    local hull=Box(p,upright and g.hull or FullTrack(g),def.mass);hull.track=upright
    if upright then hull.shape=TrackShape(g) end
    out.hulls[#out.hulls+1]=hull;out.sensors[#out.sensors+1]=Box(p,FullTrack(g),0)
end
function M.BuildParts(parts,dropped,rotors,rotorOf,checkpoint)
    local out={ok=true,reason="",partIds={},dropped=dropped or 0,hulls={},sensors={},wheels={},hovers={},legs={},mechLegs={},wings={},thrusters={},weapons={}}
    out.rotors=rotors or {};out.rotorOf=rotorOf or {}
    local buckets={[0]={}};local mass=0
    for _,p in ipairs(parts) do
        if checkpoint then checkpoint() end
        local owner=out.rotorOf[p.id] or 0;buckets[owner]=buckets[owner] or {};local solid=buckets[owner]
        local def=Defs.PARTS[p.type];local up=Rot.ApplyRot(p.rot,{0,1,0})
        mass=mass+def.mass;out.partIds[#out.partIds+1]=p.id
        local leg,track,wheel=Geometry.legs[p.type],Geometry.tracks[p.type],Geometry.wheels[p.type]
        if def.leg then
            local reach=0;for _,length in ipairs(leg.lengths) do reach=reach+length end
            out.legs[#out.legs+1]={partId=p.id,type=p.type,rot=p.rot,origin=Math.Scale(Origin(p),CELL),pos=ToBody(p,{0,0,0}),toe=ToBody(p,leg.toe),
                load=def.load,speed=def.speed/3.6,stepHeight=def.stepHeight,jumpHeight=def.jumpHeight,works=up[2]>.99,
                height=-leg.toe[2]*CELL,reach=reach*CELL,out=Rot.ApplyRot(p.rot,{1,0,0})}
            out.hulls[#out.hulls+1]=Box(p,{c={0,0,0},h={.47,.47,.40}},def.mass)
        elseif def.mech then
            -- Full mass stays on mount/hip. Moving links are combat sensors only.
            local g=Mech.Data(p.type);local hipLow=g.joints.hip[2]+1.1;local sb=g.segmentBounds.mount
            out.mechLegs[#out.mechLegs+1]={partId=p.id,type=p.type,rot=p.rot,tier=g.tier,origin=Math.Scale(Origin(p),CELL),
                pos=ToBody(p,{0,0,0}),mount=ToBody(p,{0,-.5,0}),hip=ToBody(p,g.joints.hip),toeRest=ToBody(p,g.joints.toe),
                standHeight=g.standHeight*CELL,load=def.load,speed=def.speed/3.6,jumpHeight=def.jumpHeight,jet=def.jet,
                works=up[2]<-.99 and Rot.ApplyRot(p.rot,{0,0,1})[3]>.99}
            out.hulls[#out.hulls+1]=Box(p,{c={0,(hipLow-.5)/2,0},h={math.max(math.abs(sb.min[1]),sb.max[1],.5),
                (hipLow+.5)/2,math.max(math.abs(sb.min[3]),sb.max[3],.5)}},def.mass)
        elseif track then AddTrack(p,def,track,up,out)
        elseif wheel and math.abs(up[2])<.5 then
            out.wheels[#out.wheels+1]={partId=p.id,type=p.type,center=ToBody(p,{0,wheel.cy,0}),axle=up,radius=wheel.r*CELL,width=wheel.w*CELL,
                mass=def.mass,load=def.load,speed=def.speed/3.6,steer=def.steer==true,steerAngle=(def.steerAngle or 0)*math.pi/180}
        else
            if def.weapon then out.weapons[#out.weapons+1]=Loadout.Part(p) end
            if def.hover then
                local g=Assets.HoverInfo(p.type,p.rot);local dir=Rot.ApplyRot(p.rot,g.liftDir);local emits={}
                for _,e in ipairs(g.emits) do emits[#emits+1]={pos=ToBody(p,e.p),radius=e.radius*CELL} end
                out.hovers[#out.hovers+1]={partId=p.id,type=p.type,mount=g.mount,pos=ToBody(p,g.lift.p),dir=dir,load=def.load,height=g.height*Geometry.hoverHeightScale,
                    radius=g.lift.radius*CELL,speed=def.speed/3.6,works=dir[2]>=Geometry.hoverMinUp,emits=emits}
                out.hulls[#out.hulls+1]=Box(p,HoverBox(g),def.mass)
            end
            if def.thruster then
                local g=Geometry.thrusters[p.type];local area=0;local center={0,0,0}
                for _,n in ipairs(g.nozzles) do
                    area=area+n.radius^2
                    for k=1,3 do center[k]=center[k]+n.p[k]*n.radius^2 end
                end
                out.thrusters[#out.thrusters+1]={partId=p.id,type=p.type,pos=ToBody(p,Math.Scale(center,1/area)),pivot=ToBody(p,g.pivot),
                    dir=Rot.ApplyRot(p.rot,def.thrustDir),thrust=def.thrust,speedLimit=def.speedLimit/3.6}
            end
            if def.wing then
                local g=Assets.Get(p.type,p.rot).segments.info;local surfaces={}
                for _,sf in ipairs(g.surfaces) do surfaces[#surfaces+1]={name=sf.name,virtual=sf.virtual==true,pos=ToBody(p,sf.center),area=sf.area*CELL*CELL} end
                out.wings[#out.wings+1]={partId=p.id,type=p.type,kind=g.kind,tier=g.tier,lift=def.lift,pos=ToBody(p,g.lift.center),
                    area=g.lift.area*CELL*CELL,n=Rot.ApplyRot(p.rot,{1,0,0}),s=up,c=Rot.ApplyRot(p.rot,{0,0,1}),surfaces=surfaces}
            end
            if def.hull then Append(out.hulls,M.HullBoxes(p))
            elseif def.hover then -- The clipped hull above already carries collision and mass.
            elseif THIN[p.type] then AddMass(solid,p._cells[1],def.mass)
            else for _,c in ipairs(p._cells) do AddMass(solid,c,def.mass/#p._cells) end end
        end
    end
    out.boxes={}
    for owner=0,#out.rotors do for _,box in ipairs(M.MergeBoxes(buckets[owner] or {},checkpoint)) do
        if owner>0 then box.rotor=owner end;out.boxes[#out.boxes+1]=box
    end end
    for _,list in ipairs({out.hulls,out.sensors,out.wheels,out.hovers,out.thrusters,out.weapons,out.wings}) do
        for _,item in ipairs(list) do item.rotor=out.rotorOf[item.partId] end
    end
    local load,speed=0,0
    for _,list in ipairs({out.wheels,out.hovers,out.legs,out.mechLegs}) do for _,m in ipairs(list) do
        if m.works~=false then load=load+m.load;speed=speed+m.load*m.speed end
    end end
    local ratio=load>0 and mass/load or math.huge
    local factor=ratio>2 and 0 or Math.Clamp(1.25-.5*ratio,0,1)
    local thrusterSpeed,lift=0,0
    for _,t in ipairs(out.thrusters) do
        if t.dir[3]>.7 or t.dir[2]>.7 then thrusterSpeed=math.max(thrusterSpeed,t.speedLimit) end
        lift=lift+math.max(0,t.dir[2])*t.thrust
    end
    out.motion={mass=mass,load=load,L=ratio,topSpeed=(load>0 and speed/load or 0)*factor,thrusterSpeed=thrusterSpeed,
        thrustScale=1,liftRatio=lift/(mass*9.81),thrusters=#out.thrusters,accelFactor=math.max(.3,factor)}
    local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
    local function Grow(c,h) for k=1,3 do lo[k]=math.min(lo[k],c[k]-h[k]);hi[k]=math.max(hi[k],c[k]+h[k]) end end
    for _,b in ipairs(out.boxes) do Grow(b.center,b.half) end
    for _,h in ipairs(out.hulls) do
        local q=h.quat;local x,y,z,w=q.x,q.y,q.z,q.w
        local m={1-2*(y*y+z*z),2*(x*y-w*z),2*(x*z+w*y),2*(x*y+w*z),1-2*(x*x+z*z),2*(y*z-w*x),2*(x*z-w*y),2*(y*z+w*x),1-2*(x*x+y*y)}
        local half={}
        for r=0,2 do half[r+1]=math.abs(m[r*3+1])*h.half[1]+math.abs(m[r*3+2])*h.half[2]+math.abs(m[r*3+3])*h.half[3] end
        Grow(h.center,half)
    end
    for _,wheel in ipairs(out.wheels) do Grow(wheel.center,{wheel.radius,wheel.radius,wheel.radius}) end
    for _,leg in ipairs(out.legs) do
        local bounds=Geometry.legs[leg.type].bounds
        for _,x in ipairs({bounds.min[1],bounds.max[1]}) do for _,y in ipairs({bounds.min[2],bounds.max[2]}) do for _,z in ipairs({bounds.min[3],bounds.max[3]}) do
            Grow(Math.Add(Math.Scale(Rot.ApplyRot(leg.rot,{x,y,z}),CELL),leg.origin),{0,0,0})
        end end end
    end
    for _,leg in ipairs(out.mechLegs) do
        local bounds=Mech.Data(leg.type).bounds
        for _,x in ipairs({bounds.min[1],bounds.max[1]}) do for _,y in ipairs({bounds.min[2],bounds.max[2]}) do for _,z in ipairs({bounds.min[3],bounds.max[3]}) do
            Grow(Math.Add(Math.Scale(Rot.ApplyRot(leg.rot,{x,y,z}),CELL),leg.origin),{0,0,0})
        end end end
    end
    if lo[1]==math.huge then return {ok=false,reason="车身是空的"} end
    out.bounds={min=lo,max=hi,radius=Math.Length(Math.Sub(hi,lo))/2}
    return out
end
function M.Build(bp,checkpoint,connected)
    local stage=0
    local pause=checkpoint and function() checkpoint(stage) end or nil
    local adj=connected and connected.adj or bp:Graph(pause);stage=.15
    local conn=connected and connected.conn or bp:Connectivity(adj,pause)
    if not conn.coreId then return {ok=false,reason="车上没有核心驾驶舱，无法试车"} end
    local parts={}
    for _,p in ipairs(bp:List()) do if conn.reached[p.id] then parts[#parts+1]=p end end
    stage=.2
    local rotors,owner=require('construction.Rotors').Spec(bp,adj,conn.reached,pause)
    stage=.4
    local out=M.BuildParts(parts,bp:Size()-#parts,rotors,owner,pause)
    if out.ok then
        stage=.6
        local ranges=require('construction.TurretRange').For(bp,owner,pause)
        for _,w in ipairs(out.weapons) do w.range=ranges[w.partId] end
    end
    if checkpoint then checkpoint(1) end
    return out
end
return M

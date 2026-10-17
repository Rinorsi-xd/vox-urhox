-- Exceptional soft-lock recovery only: at most seven probes and four visibility rays.
local V=require 'core.Math3'
local CELL=require('Config').CELL
local M={}
function M.Find(origin,dir,near,player,selected,candidates,castRay,stats,wide,canReach)
    local unit=selected.unit;local body=unit.vehicle.body
    local p,q,velocity=body.translation(),body.rotation(),body.linvel()
    local centre=unit.Position and unit:Position() or unit.pos
    local along=V.Dot(V.Sub(centre,origin),dir)
    local vel={velocity.x,velocity.y,velocity.z}
    local side=V.Length(V.Sub(vel,V.Scale(dir,V.Dot(vel,dir))))
    local angle=stats.assist.angle*(wide or 1)/(1+side/math.max(1,along)/.6)
    local from=player.Position and player:Position() or player.pos
    local points={};local seen={}
    local function Add(point)
        local delta=V.Sub(point,origin);local a=V.Dot(delta,dir)
        if a<=1 or a>near+2 or V.Length(V.Sub(point,from))>stats.range then return end
        local ang=math.atan(math.max(0,V.Length(V.Sub(delta,V.Scale(dir,a)))-CELL*.5),a)
        if ang>angle then return end
        local key=string.format('%.4f:%.4f:%.4f',point[1],point[2],point[3])
        if seen[key] then return end
        seen[key]=true;points[#points+1]={point=point,ang=ang,ordinal=#points+1}
    end
    local count=0
    for _,candidate in ipairs(candidates) do
        if candidate.unit==unit and candidate.id~=selected.id then
            Add(candidate.point);count=count+1;if count==4 then break end
        end
    end
    local bounds=unit.vehicle.spec and unit.vehicle.spec.bounds
    if bounds then
        local localPoint=V.Unrotate(q,V.Sub(selected.point,{p.x,p.y,p.z}))
        for _,lift in ipairs({CELL,CELL*2,CELL*4}) do
            local y=math.min(bounds.max[2]-1e-4,localPoint[2]+lift)
            if y>localPoint[2]+1e-4 then
                local raised=V.Rotate(q,{localPoint[1],y,localPoint[3]})
                Add({raised[1]+p.x,raised[2]+p.y,raised[3]+p.z})
            end
        end
    end
    table.sort(points,function(a,b)return a.ang<b.ang or a.ang==b.ang and a.ordinal<b.ordinal end)
    local rays=0
    for _,candidate in ipairs(points) do
        if rays==4 then break end
        if canReach(candidate.point,unit) then
            rays=rays+1
            local d=V.Sub(candidate.point,origin);local length=V.Length(d)
            local hit=castRay(origin,V.Scale(d,1/length),length+CELL*2,player.vehicle.body)
            if hit and hit.owner and hit.owner.ref==unit and canReach(hit.point,unit) then
                return {point=hit.point,ref=unit,partId=hit.partId or selected.id,slow=stats.assist.slow}
            end
        end
    end
end
return M

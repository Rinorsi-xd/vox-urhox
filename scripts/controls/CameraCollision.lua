-- H5 cameraCollision: sweep a 35 cm volume, then leave a 3 cm skin.
local Coord=require 'core.Coord'
local V=require 'core.Math3'
local M={RADIUS=.35,SKIN=.03}
function M.Cast(space,origin,direction,distance,excluded,mask)
    if distance<1e-6 then return nil end
    local hidden={}
    local function Hide(body)
        hidden[#hidden+1]={body,body.collisionLayer};body.collisionLayer=0
    end
    if excluded then Hide(excluded) end
    local ok,result=pcall(function()
        local ray=Ray(Coord.Vec(table.unpack(origin)),Coord.Vec(table.unpack(direction)))
        while true do
            -- Exclude pass-through rocks (0x1000), sensors (0x2000), debris (8).
            local hit=space.world:SphereCast(ray,M.RADIUS,distance,mask or 0xcff7)
            if not hit.body then return nil end
            if not hit.body.trigger or hit.body.collisionLayer==0x8000 then return hit.distance end
            Hide(hit.body)
        end
    end)
    for _,entry in ipairs(hidden) do entry[1].collisionLayer=entry[2] end
    if not ok then error(result) end
    return result
end
function M.Distance(cast,origin,direction,distance)
    local hit=cast(origin,direction,distance)
    return hit and math.max(0,math.min(distance,hit-M.SKIN)) or distance
end
function M.Constrain(cast,anchor,position)
    local delta=V.Sub(position,anchor);local length=V.Length(delta)
    if length<1e-6 then return position end
    local dir=V.Scale(delta,1/length)
    return V.Add(anchor,V.Scale(dir,M.Distance(cast,anchor,dir,length)))
end
return M

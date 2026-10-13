-- Source selectionTools.cornerParts: inclusive occupied-cell intersection.
local M={}
function M.Bounds(a,b)
    local lo,hi={},{}
    for axis=1,3 do lo[axis]=math.min(a[axis],b[axis]);hi[axis]=math.max(a[axis],b[axis]) end
    return lo,hi
end
function M.CornerParts(bp,a,b)
    local lo,hi=M.Bounds(a,b);local out={}
    for _,part in ipairs(bp:List()) do
        for _,cell in ipairs(part._cells) do
            if cell[1]>=lo[1] and cell[1]<=hi[1] and cell[2]>=lo[2] and cell[2]<=hi[2] and cell[3]>=lo[3] and cell[3]<=hi[3] then
                out[#out+1]=part;break
            end
        end
    end
    return out
end
return M

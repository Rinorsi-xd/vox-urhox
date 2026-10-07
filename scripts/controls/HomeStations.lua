-- shared/ui/shell.js _station + editor.js _carCenter. Source logical coordinates
-- remain unchanged until this presentation boundary mirrors X into UrhoX.
local CELL=require('Config').CELL
local M={}
function M.Get(stats,id,maxDist)
    local x,y,z,r=0,1,0,2
    if stats.count>0 then
        local b,d=stats.bb,stats.dims
        x=(b.minX+b.maxX)*.5*CELL;y=((b.minY+b.maxY)*.5+.5)*CELL;z=(b.minZ+b.maxZ)*.5*CELL
        r=math.sqrt(d.L*d.L+d.W*d.W+d.H*d.H)*CELL*.5
    end
    local near=math.min(math.max(r*2.5+3.2,5),maxDist*.85)
    local s=({
        hangar={x,y,z,near,.7,1.22,true},
        battle={x-r*.75-1.2,y+.3,z-6,near*1.15+6,.3,1.36,false},
        workshop={22,3,-2,15,-1.3,1.38,false},
        shop={22,3,8,15,-1.75,1.38,false},
    })[id]
    if not s then return nil end
    return {target={-s[1],s[2],s[3]},dist=math.min(maxDist,math.max(2.5,s[4])),
        yaw=180-math.deg(s[5]),pitch=90-math.deg(s[6]),fov=48,spin=s[7]}
end
return M

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
    local near=math.min(math.max(r*2.5+3.2,5),maxDist*.85,36)
    local s=({
        hangar={x,y,z,near,.7,1.22,true},
        livery={x,y,z,near*.9,1.1,1.28,false},
        battle={x-r*.75-1.2,y+.3,z-6,near*1.15+6,.3,1.36,false},
        workshop={22,3,-2,15,-1.3,1.38,false},
        shop={22,3,8,15,-1.75,1.38,false},
        svLoadoutC={x-r*.25-.5,y,z,near*1.05,.6,1.24,false},
        svLoadout={x+r*.5+1,y,z,near*1.15,.6,1.24,false},
        svGarage={x,y-.2,z,near*.95,-.62,1.3,false},
        svOps={x,y+3,z-8,near*1.6+8,.2,1.2,false},
        svMarket={-7.2,2.9,-23,16,.45,1.4,false},
    })[id]
    if not s then return nil end
    local dist=math.min(maxDist,math.max(2.5,s[4]))
    -- 手机紧凑机库：下方三成被改装/出战/试车和车位条占住。镜头拉近，目标点下移，
    -- 让车落在按钮上方那块空白的中间
    if (id=='hangar' or id=='svLoadoutC') and require('controls.TouchMode').Compact() then
        -- 只给普通尺寸的车拉近；蝎型战车这类大车本来就填满画面，再拉近会装不下
        dist=math.max(2.5,dist*(r<3 and .85 or r<5 and .95 or 1));s={s[1],s[2]-dist*.085,s[3],dist,s[5],s[6],s[7]}
    end
    return {target={-s[1],s[2],s[3]},dist=dist,
        yaw=180-math.deg(s[5]),pitch=90-math.deg(s[6]),fov=48,spin=s[7]}
end
return M

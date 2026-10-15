-- Precomputed source alpha masks. No GPU readback, new context or per-frame blur.
local Theme=require 'ui.VoxTheme'
local M={}
local profiles={card={size=94,blur=3,x=2,y=6,color={9,20,35,255}},
    slot={size=43,blur=3,x=0,y=2,color={9,20,35,102}},
    detail={size=200,blur=6,x=0,y=3,color={7,17,30,102}}}
function M.Path(id,kind) return 'UI/Parts/Shadows/'..kind..'-'..Theme.Thumbnail(id):match('([^/]+)$') end
function M.Image(widget,vg,id,kind,r)
    local p=profiles[kind];local scale=r.w/p.size;local pad=p.blur*4*scale
    widget:RenderBackgroundImage(vg,M.Path(id,kind),{x=r.x+p.x*scale-pad,y=r.y+p.y*scale-pad,w=r.w+pad*2,h=r.h+pad*2},'fill',nil,nil,p.color)
end
function M.Tile(widget,vg,r,m)
    local hover=m and m.hover.value or 0;local press=m and m.shadowPress and m.shadowPress.value or 0
    local weights={rest=(1-hover)*(1-press),hover=hover*(1-press),press=press}
    local alpha={rest=64,hover=77,press=64};local offset={rest=2,hover=3,press=1}
    for kind,weight in pairs(weights) do if weight>.001 then
        widget:RenderBackgroundImage(vg,'UI/Parts/Shadows/tile-'..kind..'.png',
            {x=r.x-24,y=r.y-24+offset[kind],w=r.w+48,h=r.h+48},'sliced',{64,64,64,64},nil,{5,11,20,alpha[kind]*weight})
    end end
end
return M

local D=require 'ui.SourceDraw'
local M={}
function M.Draw(vg,b,w,h)
    local watched=require('combat.MatchActions').Watched(b)
    local hint='A / D 切换队友'
    if b.rules.cfg.respawn then
        hint=math.ceil(math.max(0,b.rules.cfg.respawn-(b.world.time-b.player.deadAt)))..' 秒后复活 · '..hint
    end
    local name=watched and watched.name or ''
    local a=D.Width(vg,'观战',15,'vox-display',2)
    local n=D.Width(vg,name,15,'vox-display',2)
    local c=D.Width(vg,hint,12.5,'vox-display',2)
    local width=a+n+c+72;local x=(w-width)/2;local y=h-120-34
    D.Rect(vg,x+width*.2,y,width*.6,34,{11,13,17,216})
    nvgBeginPath(vg);nvgRect(vg,x,y,width*.2,34)
    D.Gradient(vg,x,y,width*.2,34,{11,13,17,0},{11,13,17,216},true)
    nvgBeginPath(vg);nvgRect(vg,x+width*.8,y,width*.2,34)
    D.Gradient(vg,x+width*.8,y,width*.2,34,{11,13,17,216},{11,13,17,0},true)
    D.Text(vg,'观战',x+24,y+8,15,{242,246,248,255},'vox-display',NVG_ALIGN_LEFT,2)
    D.Text(vg,name,x+30+a,y+8,15,{127,200,255,255},'vox-display',NVG_ALIGN_LEFT,2)
    D.Text(vg,hint,x+48+a+n,y+10,12.5,{255,255,255,144},'vox-display',NVG_ALIGN_LEFT,2)
end
return M

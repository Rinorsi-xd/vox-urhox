local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Chrome=Panel:Extend('VoxHomeChrome')
function Chrome:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local s=self.owner;local w,h=r.w,r.h
    if s.tab=='salvage' or s.tab=='story' then return end
    nvgSave(vg)
    if s.tab~='hangar' then nvgGlobalAlpha(vg,0) end
    -- CSS paints the first listed gradient last; preserve that alpha layering.
    nvgBeginPath(vg);nvgRect(vg,0,0,w,130);D.Gradient(vg,0,0,w,130,{8,15,28,204},{8,15,28,0})
    nvgBeginPath(vg);nvgRect(vg,0,h-355,w,175);D.Gradient(vg,0,h-355,w,175,{8,15,28,0},{8,15,28,163})
    nvgBeginPath(vg);nvgRect(vg,0,h-180,w,180);D.Gradient(vg,0,h-180,w,180,{8,15,28,163},{8,15,28,242})
    nvgBeginPath(vg);nvgRect(vg,w-420,0,230,h);D.Gradient(vg,w-420,0,230,h,{8,15,28,0},{8,15,28,107},true)
    nvgBeginPath(vg);nvgRect(vg,w-190,0,190,h);D.Gradient(vg,w-190,0,190,h,{8,15,28,107},{8,15,28,184},true)
    nvgBeginPath(vg);nvgRect(vg,0,0,230,h);D.Gradient(vg,0,0,230,h,{8,15,28,199},{8,15,28,143},true)
    nvgBeginPath(vg);nvgRect(vg,230,0,280,h);D.Gradient(vg,230,0,280,h,{8,15,28,143},{8,15,28,0},true)
    nvgRestore(vg)
    if w>=h then
    local home=s.tab=='hangar';local dx=home and 6 or 0;local dy=home and 2 or 0
    nvgSave(vg);nvgTranslate(vg,41+dx,30+dy);nvgRotate(vg,math.pi/4);nvgScale(vg,.86,.86)
    D.Rect(vg,-15,-15,13.5,13.5,D.orange);D.Rect(vg,1.5,-15,13.5,13.5,{255,255,255,71});D.Rect(vg,-15,1.5,13.5,13.5,D.white);D.Rect(vg,1.5,1.5,13.5,13.5,{255,255,255,153});nvgRestore(vg)
    D.Text(vg,'构装纪元',68+dx,18+dy,24,D.white,nil,nil,1,false,24);D.Rect(vg,186+dx,13+dy,1,34,{255,255,255,36})
    end
    if s.tab=='hangar' then D.Rect(vg,32,63,w-64,1,{122,216,255,34}) end
    local metaX=w-(s.tab=='hangar' and 364.15625 or 356.15625);local metaY=s.tab=='hangar' and 2 or 0
    D.Icon(vg,'car',metaX,20+metaY,20,D.orange);D.Text(vg,tostring(s.usedCount or 0),metaX+27,17.5+metaY,21,nil,'vox-tabular');D.Text(vg,'/ 20',metaX+43.234375,21+metaY,15,D.muted,'vox-tabular')
    if s.tab=='hangar' then
        D.Icon(vg,'car',36,h-141,18,D.orange);D.Text(vg,'我的战车',61,h-143,17);D.Text(vg,(s.usedCount or 0)..' / 20',143,h-140,14,D.muted)
    end
end
return Chrome

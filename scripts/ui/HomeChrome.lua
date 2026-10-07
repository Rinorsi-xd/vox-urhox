local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Chrome=Panel:Extend('VoxHomeChrome')
function Chrome:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local s=self.owner;local w,h=r.w,r.h
    nvgSave(vg)
    if s.tab=='shop' or s.tab=='workshop' then nvgGlobalAlpha(vg,.4) end
    -- Same three edge fades as .home-shade; all widths are source CSS pixels.
    nvgBeginPath(vg);nvgRect(vg,0,0,w,150);D.Gradient(vg,0,0,w,150,{9,10,12,204},{9,10,12,0})
    nvgBeginPath(vg);nvgRect(vg,0,h-420,w,170);D.Gradient(vg,0,h-420,w,170,{9,10,12,0},{9,10,12,153})
    nvgBeginPath(vg);nvgRect(vg,0,h-250,w,250);D.Gradient(vg,0,h-250,w,250,{9,10,12,153},{9,10,12,240})
    nvgBeginPath(vg);nvgRect(vg,0,0,400,h);D.Gradient(vg,0,0,400,h,{9,10,12,230},{9,10,12,168},true)
    nvgBeginPath(vg);nvgRect(vg,400,0,300,h);D.Gradient(vg,400,0,300,h,{9,10,12,168},{9,10,12,0},true)
    nvgRestore(vg)
    nvgSave(vg);nvgTranslate(vg,41,30);nvgRotate(vg,math.pi/4);nvgScale(vg,.86,.86)
    D.Rect(vg,-15,-15,13.5,13.5,D.orange);D.Rect(vg,1.5,-15,13.5,13.5,{255,255,255,71});D.Rect(vg,-15,1.5,13.5,13.5,D.white);D.Rect(vg,1.5,1.5,13.5,13.5,{255,255,255,153});nvgRestore(vg)
    D.Text(vg,'方块战车',68,16,24,D.white);D.Rect(vg,167,13,1,34,{255,255,255,36})
    D.Icon(vg,'car',w-198,20,20,D.orange);D.Text(vg,tostring(s.usedCount or 0),w-171,17,21);D.Text(vg,'/ 20',w-153,23,15,D.muted)
    if s.tab=='hangar' then
        D.Icon(vg,'car',28,h-206,20,D.orange);D.Text(vg,'我的战车',56,h-211,21);D.Text(vg,(s.usedCount or 0)..' / 20',135,h-207,16,D.muted)
    end
end
return Chrome

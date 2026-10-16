-- Source reticle is drawn in the shared UI frame, never a second VG context.
local ReticleGauges=require("ui.ReticleGauges")
local ReticleWeapons=require("ui.ReticleWeapons")

local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local R=require 'ui.ReticleDraw'
local State=require 'ui.ReticleState'
local M=Panel:Extend('VoxMechReticle')
function M:Render(vg)
    local s=self.session
    if not s.pointer.captured or s.dialog or s.combat and not s.combat.player.alive then return end
    D.HudFont(vg);local rect=self:GetAbsoluteLayout();local l=State.Layout(rect.w,rect.h)
    l.cx=l.cx+rect.x;l.cy=l.cy+rect.y;R.SetTextScale(l.k)
    -- The source places svg.scope before svg.frame in the same stacking layer.
    if s.scope then self:Scope(vg,l) end
    ReticleGauges.Render(vg,self,l)
    ReticleGauges.Compass(vg,self,l)
    if not s.touch then ReticleWeapons.Render(vg,self,l) end
    self:Center(vg,l)
end
function M:Center(vg,l)
    local k=l.k;local s=self.session;local g=s.weapons:Group();local kind=g and g.kind or 'laser'
    local color=(self.aimState=='blocked' or self.aimState=='limited') and {255,194,58,255} or R.white
    local scale=1.5*k;nvgSave(vg);nvgTranslate(vg,l.cx,l.cy);nvgScale(vg,scale,scale)
    if kind=='laser' then
        for i=0,3 do R.Arc(vg,0,0,10,i*90,i*90+63,color,1.7) end
    elseif kind=='mg' then
        local ready=g and State.Clamp(s.weapons:Readiness(g)) or 1;local spread=1+(s.firing and .4 or 0)*(1-ready)
        for _,dir in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do D.Line(vg,dir[1]*12*spread,dir[2]*12*spread,dir[1]*22*spread,dir[2]*22*spread,color,1.7) end
    elseif kind=='sniper' then
        for _,dir in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do D.Line(vg,dir[1]*7,dir[2]*7,dir[1]*30,dir[2]*30,color,1.2) end
        D.Line(vg,-5,11,0,6,color,1.7);D.Line(vg,0,6,5,11,color,1.7)
    else
        for _,sx in ipairs({-1,1}) do for _,sy in ipairs({-1,1}) do
            D.Line(vg,sx*18,sy*11,sx*18,sy*18,color,1.7);D.Line(vg,sx*18,sy*18,sx*11,sy*18,color,1.7)
        end end
    end
    nvgBeginPath(vg);nvgCircle(vg,0,0,kind=='sniper' and 1.4 or 1.8);nvgFillColor(vg,D.Color(color));nvgFill(vg);nvgRestore(vg)
    local remaining=self.hit or 0
    if remaining>0 then
        local duration=self.hitDuration or .3;local progress=1-State.Clamp(remaining/duration)
        local alpha=progress<=.35 and 1 or (1-progress)/.65
        nvgSave(vg);nvgGlobalAlpha(vg,alpha)
        for _,sx in ipairs({-1,1}) do for _,sy in ipairs({-1,1}) do
            D.Line(vg,l.cx+sx*18*1.9*k,l.cy+sy*18*1.9*k,l.cx+sx*8*1.9*k,l.cy+sy*8*1.9*k,self.killed and {255,59,48,255} or self.broken and {255,160,46,255} or R.white,(5-2.6*progress)*k)
        end end;nvgRestore(vg)
    end
end
function M:Scope(vg,l)
    local s=self.session;local g=s.weapons:Group();local kind=g and g.kind or 'laser'
    if kind~='sniper' then return end
    local pixel=l.pixel or 1;R.SetTextScale(pixel)
    local cx,cy=l.cx,l.cy;local radius=math.min(l.width,l.height)*.3;local color={238,243,246,255}
    D.Line(vg,cx-radius,cy,cx-14*pixel,cy,color,1.2*pixel);D.Line(vg,cx+14*pixel,cy,cx+radius,cy,color,1.2*pixel)
    D.Line(vg,cx,cy+14*pixel,cx,cy+radius,color,1.2*pixel)
    for i=1,6 do for _,sign in ipairs({-1,1}) do
        local d=radius*.11*i*sign;nvgBeginPath(vg);nvgCircle(vg,cx+d,cy,1.8*pixel);nvgCircle(vg,cx,cy+d,1.8*pixel)
        nvgFillColor(vg,D.Color(color));nvgFill(vg)
    end end
    R.Text(vg,string.format('%.1f×',State.zoom.sniper),cx-radius*.62,cy+24*pixel,15*pixel,R.white,NVG_ALIGN_RIGHT)
    if s.aimPoint then
        local p=s.vehicle.body.translation();local a=s.aimPoint
        local distance=math.sqrt((a[1]-p.x)^2+(a[2]-p.y)^2+(a[3]-p.z)^2)
        if distance>0 then R.Text(vg,'RNG '..math.floor(distance+.5)..' M',cx+radius*.62,cy+24*pixel,15*pixel,R.white) end
    end
    R.SetTextScale(l.k)
end
return M

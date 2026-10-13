-- Source reticle is drawn in the shared UI frame, never a second VG context.
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local R=require 'ui.ReticleDraw'
local State=require 'ui.ReticleState'
local M=Panel:Extend('VoxMechReticle')
function M:Render(vg)
    local s=self.session
    if not s.pointer.captured or s.dialog or s.combat and not s.combat.player.alive then return end
    D.HudFont(vg);local rect=self:GetAbsoluteLayout();local l=State.Layout(rect.w,rect.h)
    l.cx=l.cx+rect.x;l.cy=l.cy+rect.y
    if s.scope then self:Scope(vg,l);return end
    require('ui.ReticleGauges').Render(vg,self,l)
    require('ui.ReticleGauges').Compass(vg,self,l)
    if not s.touch then require('ui.ReticleWeapons').Render(vg,self,l) end
    self:Center(vg,l)
    if s.story and self.hint and self.hint~='' then R.Text(vg,self.hint,l.cx,l.cy+150*l.k,13*l.k,R.warn,NVG_ALIGN_CENTER,true) end
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
    local cx,cy,w,h=l.cx,l.cy,l.width,l.height;local radius=math.min(w,h)*(kind=='sniper' and .44 or .3)
    if kind=='sniper' then
        nvgBeginPath(vg);nvgRect(vg,cx-w/2,cy-h/2,w,h);nvgCircle(vg,cx,cy,radius);nvgPathWinding(vg,NVG_HOLE);nvgFillColor(vg,nvgRGBA(5,8,11,235));nvgFill(vg)
        R.Arc(vg,cx,cy,radius,0,360,{238,243,246,204},2);R.Arc(vg,cx,cy,radius-6,0,360,{238,243,246,102},1)
        for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            D.Line(vg,cx+d[1]*14,cy+d[2]*14,cx+d[1]*radius,cy+d[2]*radius,{238,243,246,255},1.2)
            for i=1,6 do nvgBeginPath(vg);nvgCircle(vg,cx+d[1]*radius*.11*i,cy+d[2]*radius*.11*i,2.2);nvgFillColor(vg,nvgRGBA(238,243,246,255));nvgFill(vg) end
        end
    else
        D.Rect(vg,cx-w/2,cy-h/2,w,h,{0,0,0,46})
        if kind=='missile' then
            for _,sx in ipairs({-1,1}) do for _,sy in ipairs({-1,1}) do
                D.Line(vg,cx+sx*radius,cy+sy*radius*.6,cx+sx*radius,cy+sy*radius,R.white,2.4)
                D.Line(vg,cx+sx*radius,cy+sy*radius,cx+sx*radius*.6,cy+sy*radius,R.white,2.4)
            end end
        else
            R.Arc(vg,cx,cy,radius,0,360,{238,243,246,204},kind=='mg' and 1 or 2)
            local inner=radius*(kind=='mg' and .55 or .82);local segments=kind=='mg' and 64 or 90
            for i=0,segments-1 do R.Arc(vg,cx,cy,inner,i*360/segments,(i+.35)*360/segments,{238,243,246,102},1) end
        end
        for _,d in ipairs({{-1,0},{1,0},{0,1}}) do D.Line(vg,cx+d[1]*10,cy+d[2]*10,cx+d[1]*26,cy+d[2]*26,R.white,1.2) end
    end
    nvgBeginPath(vg);nvgCircle(vg,cx,cy,2.2);nvgFillColor(vg,nvgRGBA(238,243,246,255));nvgFill(vg)
    R.Text(vg,string.format('%.1f×',State.zoom[kind] or 2),cx-radius*.75,cy+radius+26,15,R.white)
end
return M

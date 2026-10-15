-- One NanoVG layer for pooled damage, projected unit tags and actual muzzle aim.
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Layer=Panel:Extend('VoxDriveFeedback')
local outline={{-1.2,0},{1.2,0},{0,-1.2},{0,1.2}}
local Marks=require 'ui.UnitMarkState'
local markOutline={{-1,0},{1,0},{0,-1},{0,1},{-.707107,-.707107},{.707107,-.707107},{-.707107,.707107},{.707107,.707107}}
local markOutlineColor={0,0,0,170}
local markColors={foe={255,74,58,255},ally={111,230,207,255},foeText={255,138,128,255},allyText={159,243,226,255},white={255,255,255,255},yellow={255,210,74,255},bg={255,255,255,48}}
local function MarkText(vg,text,x,y,size,color,pixel)
    for _,d in ipairs(markOutline) do
        D.Text(vg,text,x+d[1]*1.25*pixel,y+d[2]*1.25*pixel,size,markOutlineColor,'vox-hud',nil,pixel,true)
    end
    D.Text(vg,text,x,y,size,color,'vox-hud',nil,pixel,true)
end
local function UnitMark(vg,o,t,layout,now)
    local hp,ghost,low,dim=Marks.Read(o.markGhosts,t,now)
    local k,pixel=layout.k,layout.pixel;local x,y=t.x,t.y
    local team=t.enemy and markColors.foe or markColors.ally
    local text=t.hit and markColors.white or t.enemy and markColors.foeText or markColors.allyText
    nvgLineCap(vg,NVG_BUTT)
    for i=0,9 do
        local state=Marks.Segment(i,hp,ghost)
        local color=state=='bg' and markColors.bg or state=='lost' and markColors.white or dim and markColors.yellow or team
        D.Line(vg,x-26*k+i*5.2*k+pixel,y,x-26*k+i*5.2*k+5.2*k-pixel,y,color,3.5*pixel)
    end
    if t.enemy then MarkText(vg,math.ceil(hp*100)..'%',x+31*k,y+4.5*k,13*k,t.hit and markColors.white or low and markColors.yellow or text,pixel) end
    D.Path(vg,{x-37*k,y-5*k,x-30*k,y,x-37*k,y+5*k});nvgFillColor(vg,D.Color(team));nvgFill(vg)
    MarkText(vg,t.unit.name,x-26*k,y-7*k,13*k,text,pixel)
    local distance=tostring(math.floor(t.dist+.5))
    MarkText(vg,distance,x-26*k,y+20*k,17*k,text,pixel)
    MarkText(vg,'M',x-26*k+D.Advance(vg,distance,17*k,'vox-hud',pixel),y+20*k,11*k,text,pixel)
end
local function DamageIcon(vg,x,y,shield,color)
    nvgSave(vg);nvgTranslate(vg,x,y);nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,shield and 1.7 or 2.4);nvgBeginPath(vg)
    if shield then
        nvgScale(vg,.85,.85);nvgMoveTo(vg,10,1);nvgLineTo(vg,18,4);nvgLineTo(vg,18,10)
        nvgQuadTo(vg,18,16,10,21);nvgQuadTo(vg,2,16,2,10);nvgLineTo(vg,2,4);nvgClosePath(vg)
        nvgMoveTo(vg,6,10);nvgLineTo(vg,9,13);nvgLineTo(vg,14,7)
    else
        nvgMoveTo(vg,1,7);nvgLineTo(vg,17,7);nvgMoveTo(vg,12,2);nvgLineTo(vg,18,7);nvgLineTo(vg,12,12)
    end
    nvgStroke(vg)
    if not shield then D.Line(vg,8,1,8,13,{color[1],color[2],color[3],140},1.6) end
    nvgRestore(vg)
end
local function DamagePop(vg,p)
    local size=p.killed and 40 or p.shield and 24 or p.pierce and 30 or p.broke>0 and 32 or p.amount>=100 and 32 or 24
    local color=p.killed and {255,74,54,255} or p.shield and {103,189,255,255} or p.pierce and {255,207,74,255}
        or p.broke>0 and {255,154,46,255} or p.amount>=100 and {255,210,74,255} or {255,246,220,255}
    local extra=p.broke>0 and not p.killed and ('击碎'..(p.broke>1 and (' ×'..p.broke) or '')) or ''
    local icon=p.shield and 21 or p.pierce and 27 or 0;local font='vox-hud'
    local width=D.Width(vg,p.text,size,font);local small=size*.55
    local suffix=extra~='' and size*.25+D.Width(vg,extra,small,font,small*.08) or 0
    local age=p.t*1.1;local scale=age<.12 and 1.7-.7*age/.12 or 1
    nvgSave(vg);nvgTranslate(vg,p.x,p.y-p.t*70);nvgScale(vg,scale,scale);nvgGlobalAlpha(vg,1-p.t^3)
    local x=-(width+suffix+icon)/2;local y=-size/2
    if icon>0 then DamageIcon(vg,x,y+size*.25,p.shield,color);x=x+icon end
    nvgFontBlur(vg,4);D.Text(vg,p.text,x,y+2,size,{0,0,0,217},font);nvgFontBlur(vg,0)
    for _,d in ipairs(outline) do D.Text(vg,p.text,x+d[1],y+d[2],size,{0,0,0,255},font) end
    D.Text(vg,p.text,x,y,size,color,font)
    if extra~='' then
        local sx,sy=x+width+size*.25,y+size-small
        D.Text(vg,extra,sx,sy+1,small,{0,0,0,255},font,nil,small*.08)
        D.Text(vg,extra,sx,sy,small,color,font,nil,small*.08)
    end
    nvgRestore(vg)
end
function Layer:Render(vg)
    D.HudFont(vg);local o=self.owner
    if o.session.pointer.captured then
        local rect=self:GetAbsoluteLayout();local layout=require('ui.ReticleState').Layout(rect.w,rect.h)
        require('ui.CombatFeedbackDraw').Render(vg,o.feedback,layout)
        local now=Time:GetSystemTime()
        for _,t in ipairs(o.tags) do if t.visible and t.unit.alive and (not o.focus or o.focus.ref~=t.unit) then
            UnitMark(vg,o,t,layout,now)
        end end
        require('ui.ReticleTarget').Render(vg,o,layout)
        local aim=o.aim
        if aim.visible then
            local x,y=aim.x,aim.y;nvgSave(vg);nvgTranslate(vg,x,y);nvgStrokeWidth(vg,2)
            if aim.state=='blocked' then
                nvgRotate(vg,math.pi/4);nvgBeginPath(vg);nvgRoundedRect(vg,-5,-5,10,10,2);nvgStrokeColor(vg,nvgRGBA(255,90,70,255));nvgStroke(vg)
            elseif aim.state=='limited' then
                nvgStrokeColor(vg,nvgRGBA(160,165,175,204))
                for i=0,7 do nvgBeginPath(vg);nvgArc(vg,0,0,5,i*math.pi/4,(i+.5)*math.pi/4,NVG_CW);nvgStroke(vg) end
            else
                nvgBeginPath(vg);nvgCircle(vg,0,0,5);nvgStrokeColor(vg,aim.state=='turning' and nvgRGBA(255,255,255,140) or nvgRGBA(120,220,255,242));nvgStroke(vg)
            end
            nvgRestore(vg)
        end
    end
    for _,p in ipairs(o.pops) do if p.t<1 then
        DamagePop(vg,p)
    end end
end
return Layer

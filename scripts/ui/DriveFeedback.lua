-- One NanoVG layer for pooled damage, projected unit tags and actual muzzle aim.
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Layer=Panel:Extend('VoxDriveFeedback')
function Layer:Render(vg)
    D.HudFont(vg);local o=self.owner
    if o.session.pointer.captured then
        local rect=self:GetAbsoluteLayout();local layout=require('ui.ReticleState').Layout(rect.w,rect.h)
        local R=require 'ui.ReticleDraw';local k=layout.k
        require('ui.CombatFeedbackDraw').Render(vg,o.feedback,layout)
        for _,t in ipairs(o.tags) do if t.visible and t.unit.alive and (not o.focus or o.focus.ref~=t.unit) then
            local name=t.unit.name
            local me=o.session.combat and o.session.combat.player;local enemy=not me or me.team~=t.unit.team
            local color=enemy and {255,138,128,255} or {159,243,226,255}
            local p=t.unit:Position();local camera=o.session.camera:GetNode().position
            local distance=math.sqrt((p[1]+camera.x)^2+(p[2]-camera.y)^2+(p[3]-camera.z)^2)
            if distance<=260 then
                R.Text(vg,name,t.x-26*k,t.y-7*k,13*k,color)
                local hp=t.unit:Health()
                for i=0,9 do D.Line(vg,t.x-26*k+i*5.2*k+1,t.y,t.x-26*k+(i+1)*5.2*k-1,t.y,(i+.5)/10<=hp and (enemy and R.red or R.hp) or {255,255,255,48},3.5*k) end
                R.Text(vg,math.floor(distance+.5)..' M',t.x-26*k,t.y+20*k,17*k,color)
            end
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
        local size=p.killed and 28 or p.amount>=100 and 26 or 18;local color=p.killed and {255,106,80,255} or p.amount>=100 and {255,207,74,255} or {255,243,208,255}
        local y=p.y-p.t*60-size/2;nvgSave(vg);nvgGlobalAlpha(vg,1-p.t*p.t)
        nvgFontBlur(vg,3);D.Text(vg,p.text,p.x,y+1,size,{0,0,0,204},nil,NVG_ALIGN_CENTER);nvgFontBlur(vg,0)
        D.Text(vg,p.text,p.x,y,size,color,'vox-hud',NVG_ALIGN_CENTER);nvgRestore(vg)
    end end
end
return Layer

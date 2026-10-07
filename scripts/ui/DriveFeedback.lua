-- One NanoVG layer for pooled damage, projected unit tags and actual muzzle aim.
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Draw=require 'ui.DriveDraw'
local Layer=Panel:Extend('VoxDriveFeedback')
function Layer:Render(vg)
    D.Begin(vg);local o=self.owner
    if o.session.pointer.captured then
        for _,t in ipairs(o.tags) do if t.visible then
            local name=t.unit.name;local detail=t.text
            local width=math.max(120,Draw.Width(vg,name,12,1),D.Width(vg,detail,11,'vox-body'))+18
            local height=t.unit.alive and 50 or 42;local x,y=t.x-width/2,t.y-height
            nvgSave(vg);if not t.unit.alive then nvgGlobalAlpha(vg,.8) end
            D.Rect(vg,x,y,width,height,{6,14,22,184});nvgBeginPath(vg);nvgRect(vg,x+.5,y+.5,width-1,height-1)
            nvgStrokeWidth(vg,1);nvgStrokeColor(vg,D.Color(o.session.world.time-(t.unit.hitAt or -1)<.16 and {255,176,58,204} or {53,58,66,255}));nvgStroke(vg)
            Draw.Text(vg,name,t.x,y+5,12,D.white,1,nil,NVG_ALIGN_CENTER)
            if t.unit.alive then
                local bx=t.x-60;D.Rect(vg,bx,y+23,120,5,{0,0,0,153});D.Rect(vg,bx,y+23,120*t.integrity,5,t.integrity<.45 and {255,194,26,255} or D.green);D.Rect(vg,bx+36,y+23,2,5,{255,90,70,255})
            end
            D.Text(vg,detail,t.x,y+height-18,11,t.unit.alive and D.muted or {255,138,112,255},'vox-body',NVG_ALIGN_CENTER);nvgRestore(vg)
        end end
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
        D.Text(vg,p.text,p.x,y,size,color,nil,NVG_ALIGN_CENTER);nvgRestore(vg)
    end end
end
return Layer

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Motion=require 'ui.BossHudMotion'
local Panel=UI.Panel:Extend('VoxFoxBossHud')
local M={}
local red={255,59,70,255};local white={255,255,255,255};local cream={255,215,217,255}
local function Text(vg,text,x,y,size,color,align,spacing) D.Text(vg,text,x,y,size,color,'vox-display',align,spacing or 0) end
function Panel:Render(vg)
    local b=self.session.story and self.session.story.boss;if not b then return end
    D.Begin(vg);local box=self:GetAbsoluteLayout();local w,h=box.w,box.h;local r=b:Snapshot()
    nvgSave(vg);nvgTranslate(vg,box.x,box.y);local motion=self.motion
    if motion.letter.value>0 then
        local height=h*.09*motion.letter.value;D.Rect(vg,0,0,w,height,{0,0,0,255});D.Rect(vg,0,h-height,w,height,{0,0,0,255})
        Text(vg,'Enter 下一句 · 长按 Enter 跳过演出',w-28,h-height/2-8,13,{255,255,255,140*motion.prompt.value},NVG_ALIGN_RIGHT,3)
    end
    if not r.cinematic and motion.bar.value>0 then
        nvgSave(vg);nvgGlobalAlpha(vg,motion.bar.value)
        local width=math.min(620,w*.48);local x,y=(w-width)/2,24
        Text(vg,'九尾狐',x,y,22,white,nil,4);Text(vg,'MEGA · 狐狐海盗团镇团之宝',x+90,y+8,11,red,nil,3)
        Text(vg,({'一阶段','二阶段 · 急眼了','三阶段 · 九尾全开'})[r.phase],x+width,y+7,13,cream,NVG_ALIGN_RIGHT,2)
        local points={x+8,y+27,x+width,y+27,x+width-8,y+39,x,y+39};D.Path(vg,points);nvgFillColor(vg,nvgRGBA(10,8,10,199));nvgFill(vg);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(255,90,96,128));nvgStroke(vg)
        D.Rect(vg,x+2,y+29,(width-4)*motion.trail.value,8,{255,208,210,115});nvgBeginPath(vg);nvgRect(vg,x+2,y+29,(width-4)*motion.main.value,8);D.Gradient(vg,x+2,y+29,(width-4)*motion.main.value,8,{184,29,42,255},{255,74,82,255},true)
        for _,ratio in ipairs({.6,.25}) do D.Rect(vg,x+width*ratio,y+24,2,18,{255,255,255,191}) end
        if motion.kneel.value>0 then nvgSave(vg);nvgGlobalAlpha(vg,motion.bar.value*motion.kneel.value);D.Rect(vg,x,y+43,width,4,{10,8,10,153});D.Rect(vg,x,y+43,width*(1-r.kneelK),4,{255,224,138,255});nvgRestore(vg) end
        local exposed=true;local broken=0;for _,n in ipairs(r.nodes) do if n.broken then broken=broken+1 else exposed=false end end
        Text(vg,exposed and '失衡' or '能量节点',x,y+50,11,cream,nil,2)
        if exposed then D.Rect(vg,x+40,y+54,120,6,{10,8,10,179});D.Rect(vg,x+40,y+54,120*math.min(1,r.stagger),6,{255,176,46,255})
        else for i,n in ipairs(r.nodes) do local dx=x+76+(i-1)*19;local dy=y+56;D.Path(vg,{dx,dy-7,dx+7,dy,dx,dy+7,dx-7,dy});nvgFillColor(vg,n.broken and nvgRGBA(58,42,42,255) or nvgRGBA(255,176,46,255));nvgFill(vg) end end
        local word=r.kneel and '虚弱 · 伤害 ×3 · 驾驶舱 ×4' or exposed and '护盾全破 · 打哪都疼' or '驾驶舱护盾 · 挡 '..math.floor((1-b.rules.config.chip[broken+1])*100+.5)..'%'
        local alpha=r.kneel and 255*Motion.Blink(motion.kneelAge) or 255;Text(vg,word,x+width,y+49,12,r.kneel and {255,224,138,alpha} or {127,224,255,255},NVG_ALIGN_RIGHT,3)
        nvgRestore(vg)
    end
    if motion.ult.value>0 then
        nvgSave(vg);nvgGlobalAlpha(vg,motion.ult.value)
        nvgBeginPath(vg);nvgRect(vg,0,0,w,h);nvgFillPaint(vg,nvgRadialGradient(vg,w/2,h/2,h*.2,h*.65,nvgRGBA(255,40,30,0),nvgRGBA(255,40,30,82)));nvgFill(vg)
        Text(vg,motion.lastUlt,w/2,h*.18,120,white,NVG_ALIGN_CENTER,4);Text(vg,'天狐 · 焚野',w/2,h*.18+126,22,{255,208,200,255},NVG_ALIGN_CENTER,8)
        local p=b.mission.player:Position();local shelter=not b:UnderRoof(p,4) and b:Shelter(p)
        Text(vg,shelter and '整片坑都会被烧 · 跟着标记钻进顶棚底下' or '待在顶棚底下 · 别出去',w/2,h*.18+160,14,{255,255,255,217},NVG_ALIGN_CENTER,4)
        nvgRestore(vg)
    end
    if b.ultFlash and b.time-b.ultFlash<.9 then D.Rect(vg,0,0,w,h,{255,230,210,math.floor(242*Motion.Boom(b.time-b.ultFlash))}) end
    nvgRestore(vg)
end
function M.Attach(session,root)
    local layer=Panel{position='absolute',width='100%',height='100%',pointerEvents='none'};layer.session=session;layer.motion=Motion.New();root:AddChild(layer)
    return {layer=layer,Update=function(dt)
        local boss=session.story and session.story.boss;if not boss then return end
        local r=boss:Snapshot();Motion.Update(layer.motion,dt,{hp=r.hp,cinematic=r.cinematic,kneel=r.kneel,ult=r.ult,
            shown=not r.cinematic and r.hp>0 and r.state~='idle' and r.state~='intro' and r.state~='standoff'})
    end,Dispose=function() if layer.parent then layer.parent:RemoveChild(layer) end end}
end
return M

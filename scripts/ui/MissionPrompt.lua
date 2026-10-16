-- Frozen StoryHud.prompt/dead feedback inside MissionHud's UI-owned frame.
local D=require 'ui.SourceDraw'
local Ease=require('ui.SourceButtonMotion').Ease
local M={};M.__index=M
local white={244,245,247,255};local orange={255,106,19,255};local red={255,59,70,255}
function M.Select(r,touch)
    local step=r:StepSpec();if not r.inside or not step then return nil end
    if step.kind=='install' then
        local progress=r.install/2.4;local blocked=r.blocked==true
        return {progress=progress,blocked=blocked,key=true,
            title=blocked and '先停稳' or progress>0 and '正在安装采集器…' or touch and '按住交互安装采集器' or '按住 G 安装采集器',
            sub=blocked and '车速太快，停进圈里再安装' or '松开会慢慢退回'}
    end
    if step.kind~='capture' or not r.cap then return nil end
    if r.cap.phase=='cap' then
        local count=r.cap.contested or 0
        return {progress=r.progress,blocked=count>0,key=false,
            title=count>0 and '圈里还有海盗' or '正在夺回采集器…',
            sub=count>0 and '先清掉圈附近的 '..count..' 辆' or '待在圈里别出去'}
    end
    if r.cap.phase=='scrub' then return {progress=r.progress,blocked=false,key=true,
        title=touch and '按住交互擦掉涂鸦' or '按住 G 擦掉涂鸦',sub='「狐狐到此一游」——清理费从工资里扣'} end
end
function M.Dead(sec)
    if sec==nil then return nil end
    return {label=math.ceil(sec)..' 秒后从上一个检查点重新空投',progress=tonumber(string.format('%.3f',math.max(0,1-sec/3)))}
end
local function Value(t,now)
    return t.start+(t.target-t.start)*Ease(math.max(0,math.min(1,(now-t.at)/t.duration)),'ease')
end
local function Fade(t,on,now)
    local target=on and 1 or 0
    if target~=t.target then
        local value=Value(t,now);local factor=1
        -- CSS transitions shorten a reversal by the already-eased progress.
        if target==t.reverseStart then
            local p=Ease(math.max(0,math.min(1,(now-t.at)/t.duration)),'ease')
            factor=math.abs(p*t.factor+1-t.factor)
        end
        t.reverseStart=t.target;t.start=value;t.at=now;t.target=target;t.factor=factor
        t.duration=math.max(.000001,t.nominal*factor)
    end
    return Value(t,now)
end
function M.New()
    return setmetatable({promptFade={start=0,target=0,at=0,duration=200,nominal=200,reverseStart=0,factor=1},
        deadFade={start=0,target=0,at=0,duration=300,nominal=300,reverseStart=0,factor=1}},M)
end
function M:State(r,touch,alive,now)
    now=now or Time:GetSystemTime();self.bornAt=self.bornAt or now
    -- StoryMission.update returns during death without changing the prompt DOM.
    local prompt=alive and M.Select(r,touch) or not alive and self.promptFade.target==1 and self.prompt or nil
    local dead=M.Dead(not alive and (r.respawnLeft or 3) or nil)
    if prompt then self.prompt=prompt end;if dead then self.dead=dead end
    return self.prompt,Fade(self.promptFade,prompt~=nil,now),self.dead,Fade(self.deadFade,dead~=nil,now),now-self.bornAt
end
local function Arc(vg,x,y,progress,color)
    if progress<=0 then return end
    nvgBeginPath(vg);nvgArc(vg,x,y,35.7,-math.pi/2,-math.pi/2+math.pi*2*math.min(1,progress),NVG_CW)
    for _,glow in ipairs({{13,15},{9,32},{5.25,255}}) do
        nvgStrokeWidth(vg,glow[1]);nvgStrokeColor(vg,nvgRGBA(color[1],color[2],color[3],glow[2]));nvgStroke(vg)
    end
end
function M.Draw(vg,p,w,h,alpha)
    if not p or alpha<=0 then return end
    local x,y=w/2,h*.63;local color=p.blocked and red or orange
    nvgSave(vg);nvgGlobalAlpha(vg,alpha)
    nvgBeginPath(vg);nvgCircle(vg,x,y+42,35.7);nvgFillColor(vg,nvgRGBA(0,0,0,89));nvgFill(vg)
    nvgStrokeWidth(vg,5.25);nvgStrokeColor(vg,nvgRGBA(255,255,255,38));nvgStroke(vg)
    Arc(vg,x,y+42,p.progress,color)
    if p.key then
        D.Rect(vg,x-16,y+27,32,30,{0,0,0,128})
        nvgBeginPath(vg);nvgRect(vg,x-15.5,y+27.5,31,29);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(255,255,255,51));nvgStroke(vg)
        D.Text(vg,'G',x,y+27,17,white,'vox-display',NVG_ALIGN_CENTER,0,false,30)
    end
    D.Text(vg,p.title,x,y+90,20,p.blocked and {255,176,180,255} or white,'vox-display',NVG_ALIGN_CENTER,2,false,24,
        {{y=1,blur=4,color={0,0,0,255}}})
    D.Text(vg,p.sub,x,y+118,13,{200,210,220,255},'vox-body',NVG_ALIGN_CENTER,0,false,15.6,
        {{y=1,blur=3,color={0,0,0,255}}})
    nvgRestore(vg)
end
function M.DrawDead(vg,p,w,h,alpha,elapsed)
    if not p or alpha<=0 then return end
    nvgSave(vg);nvgGlobalAlpha(vg,alpha)
    nvgSave(vg);nvgTranslate(vg,w/2,h/2);nvgScale(vg,w*.7,h*.7)
    nvgBeginPath(vg);nvgRect(vg,-1/.7/2,-1/.7/2,1/.7,1/.7)
    nvgFillPaint(vg,nvgRadialGradient(vg,0,0,.3,1,nvgRGBA(120,0,8,0),nvgRGBA(120,0,8,140)));nvgFill(vg);nvgRestore(vg)
    nvgBeginPath(vg);for y=0,h,3 do nvgRect(vg,0,y,w,1) end
    nvgFillColor(vg,nvgRGBA(255,60,70,13));nvgFill(vg)
    local x,y=w/2,h*.44-58.4
    local blink=({1,.625,.25,.625})[math.floor((elapsed or 0)%800/200)+1]
    D.Text(vg,'信号丢失 · SIGNAL LOST',x,y,13,{255,107,115,255*blink},'vox-body',NVG_ALIGN_CENTER,4,false,15.6)
    D.Text(vg,'战车损毁',x,y+21.6,46,{255,213,215,255},'vox-display',NVG_ALIGN_CENTER,6,false,55.2,
        {{blur=24,color={255,59,70,153}}})
    D.Text(vg,p.label,x,y+82.8,15,white,'vox-body',NVG_ALIGN_CENTER,0,false,18,{{y=1,blur=3,color={0,0,0,255}}})
    D.Rect(vg,x-130,y+112.8,260,3,{255,255,255,38})
    local width=260*p.progress
    if width>0 then
        nvgBeginPath(vg);nvgRect(vg,x-138,y+104.8,width+16,19)
        nvgFillPaint(vg,nvgBoxGradient(vg,x-130,y+112.8,width,3,0,8,D.Color(red),nvgRGBA(255,59,70,0)));nvgFill(vg)
        D.Rect(vg,x-130,y+112.8,width,3,{255,107,115,255})
    end
    nvgRestore(vg)
end
function M:Render(vg,r,touch,alive,w,h,now)
    local prompt,pa,dead,da,elapsed=self:State(r,touch,alive,now)
    M.Draw(vg,prompt,w,h,pa);M.DrawDead(vg,dead,w,h,da,elapsed)
end
return M

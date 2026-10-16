-- Frozen StoryHud.objective/retitle/objectiveDone, independent of game time.
local SourceDraw=require("ui.SourceDraw")

local Ease=require('ui.SourceButtonMotion').Ease
local M={};M.__index=M
local function Now() return Time:GetSystemTime() end
local function Color(rgb,brightness,alpha)
    return {math.min(255,rgb[1]*brightness),math.min(255,rgb[2]*brightness),math.min(255,rgb[3]*brightness),alpha or 255}
end
function M.New(touch)
    return setmetatable({touch=touch,title='',hint='',index=0,total=0,pending={},done=false,fill=0,sample={}},M)
end
function M:Advance(now)
    if self.disposed then return end
    now=now or Now()
    while self.pending[1] and now>=self.pending[1].at do
        local swap=table.remove(self.pending,1)
        self.title=swap.title;self.hint=swap.hint;self.enterAt=swap.at
        self:SetDone(false,swap.at)
    end
end
function M:SetDone(done,now)
    if self.done==done then return end
    self.fill=self:Fill(now);self.fillAt=now;self.done=done
end
function M:Fill(now)
    if not self.fillAt then return self.done and 1 or 0 end
    return self.fill+((self.done and 1 or 0)-self.fill)*Ease(math.max(0,math.min(1,(now-self.fillAt)/200)),'ease')
end
function M:Objective(step,index,total,now)
    if self.disposed then return end
    now=now or Now();self:Advance(now);self.index=index;self.total=total
    local hint=step.hint or ''
    if self.touch then
        hint=hint:gsub('WASD 开车 · 鼠标看路','左手摇杆开车 · 右手拖动看路'):gsub('停进圈里按住 G','停进圈里按住「交互」')
    end
    local swap={title=step.title,hint=hint,at=now}
    if self.title~='' then self:SetDone(true,now);swap.at=now+650 end
    self.pending[#self.pending+1]=swap;self:Advance(now)
end
function M:Retitle(title,now)
    if self.disposed then return end
    self:Advance(now or Now());self.title=title
end
function M:Done(now)
    if self.disposed then return end
    now=now or Now();self:Advance(now);self:SetDone(true,now)
end
function M:State(now)
    if self.disposed then return nil end
    now=now or Now();self:Advance(now)
    if self.title=='' then return nil end
    local p=self.enterAt and Ease(math.max(0,math.min(1,(now-self.enterAt)/420))) or 1
    local s=self.sample;s.title=self.title;s.hint=self.hint;s.index=self.index;s.total=self.total;s.done=self.done
    s.alpha=p;s.x=-18*(1-p);s.brightness=1+1.2*(1-p);s.fill=self:Fill(now)
    return s
end
function M:Draw(vg,hint,x,y,width)
    local s=self:State();if not s then return end
    local D=SourceDraw
    local color=Color(s.done and {61,220,132} or {255,106,19},s.brightness)
    nvgSave(vg);nvgTranslate(vg,s.x,0);nvgGlobalAlpha(vg,s.alpha)
    nvgSave(vg);nvgTranslate(vg,x+8,y+14);nvgRotate(vg,math.pi/4)
    local blur=s.done and 14 or 10;local alpha=s.done and 179 or 128
    nvgBeginPath(vg);nvgRect(vg,-6-blur,-6-blur,12+2*blur,12+2*blur)
    nvgFillPaint(vg,nvgBoxGradient(vg,-6,-6,12,12,0,blur,D.Color({color[1],color[2],color[3],alpha}),D.Color({color[1],color[2],color[3],0})));nvgFill(vg)
    nvgBeginPath(vg);nvgRect(vg,-6,-6,12,12)
    nvgFillColor(vg,D.Color(Color({61,220,132},s.brightness,255*s.fill)));nvgFill(vg)
    nvgStrokeWidth(vg,2);nvgStrokeColor(vg,D.Color(color));nvgStroke(vg);nvgRestore(vg)
    D.Text(vg,s.title,x+18,y,23,Color(s.done and {61,220,132} or {244,245,247},s.brightness),'vox-display',nil,1,false,27.6,
        {{y=1,blur=3,color={0,0,0,153}}})
    hint:Draw(vg,s.hint,x+18,y+35,width-18,Color({154,163,173},s.brightness))
    nvgRestore(vg)
end
function M:Dispose()
    if self.disposed then return end
    self.disposed=true;self.pending={};self.sample={};self.title='';self.hint=''
end
return M

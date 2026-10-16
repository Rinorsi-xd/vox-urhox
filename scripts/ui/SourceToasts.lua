-- Source #toasts: at most three messages, timed exit, drawn above owned modals.
-- App lifetime owns this component; PC resize and scene UI replacement retain it.
local UiSound=require("audio.UiSound")

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Rich=require 'ui.SourceRichText'
local M={};M.__index=M
local stripes={info=D.muted,ok=D.green,bad={255,59,48,255},warn={255,194,26,255}}
function M.New() return setmetatable({items={},text='',disposed=false},M) end
function M:Attach()
    UI.RegisterGlobalComponent('vox-source-toasts',self);self.attached=true
end
function M:Push(text,kind,ms)
    if self.disposed then return end
    self.text=text or '';if self.text=='' then return end
    if kind=='bad' then UiSound.Play('error') end
    local item={text=self.text,kind=kind or 'info',age=0,hold=(ms or 2200)/1000}
    self.items[#self.items+1]=item;if #self.items>3 then table.remove(self.items,1) end
    return item
end
function M:SetText(text) return self:Push(text) end
function M:GetText() return self.text end
function M:Update(dt)
    for i=#self.items,1,-1 do
        local item=self.items[i];item.age=item.age+math.max(0,dt)
        if item.age>=item.hold+.4 then table.remove(self.items,i) end
    end
end
-- CSS cubic-bezier(.16,1,.3,1), evaluated only for three entering messages.
local function Enter(t)
    local lo,hi=0,1
    for _=1,12 do local u=(lo+hi)/2;local v=1-u;local x=3*v*v*u*.16+3*v*u*u*.3+u^3;if x<t then lo=u else hi=u end end
    return 1-(1-(lo+hi)/2)^3
end
function M:Render(vg)
    if self.disposed or #self.items==0 then return end
    D.Begin(vg);local width=UI.GetViewportSize();local maxWidth=math.min(720,width*.9)-38;local y=80
    for _,item in ipairs(self.items) do
        local color=item.kind=='bad' and {255,211,205,255} or D.white
        if item.layoutWidth~=maxWidth then
            item.layout=Rich.Layout(vg,{{{text=item.text,size=17,spacing=.5,color=color}}},maxWidth,23.8);item.layoutWidth=maxWidth
        end
        local w,h=item.layout.width+38,item.layout.height+18;local t=math.min(1,item.age/.26)
        local enter=Enter(t);local out=math.min(1,math.max(0,(item.age-item.hold)/.35));local x=(width-w)/2-18*(1-enter)
        nvgSave(vg);nvgGlobalAlpha(vg,enter*(1-out));nvgTranslate(vg,0,-8*out)
        -- Source clip-path cuts the entire right edge towards a 10px inset bottom.
        D.Path(vg,{x,y,x+w,y,x+w-10,y+h,x,y+h});D.Gradient(vg,x,y,w,h,{38,42,49,255},{26,28,33,255})
        D.Rect(vg,x,y,4,h,stripes[item.kind] or stripes.info)
        Rich.Draw(vg,item.layout,x+16,y+9);nvgRestore(vg);y=y+h+6
    end
end
function M:Dispose()
    self.disposed=true;self.items={};self.text=''
    if self.attached then UI.UnregisterGlobalComponent('vox-source-toasts');self.attached=false end
end
return M

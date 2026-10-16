local LiveryPage=require("ui.LiveryPage")
local Workshop=require("ui.Workshop")
local HomeBattle=require("ui.HomeBattle")
local StoryPage=require("ui.StoryPage")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Paragraph=require 'ui.SourceParagraph'
local Page=Panel:Extend('VoxHomeShop')
function Page:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local w=r.w
    local top=r.y+84;local width=math.min(1040,w*.92);local x=r.x+(w-width)/2
    D.Rect(vg,r.x,top,w,r.h-206,{9,22,39,217})
    D.Rect(vg,x,top,width,316,{18,38,59,255})
    D.Rect(vg,x,top,4,74,D.orange);D.Rect(vg,x,top+73,width,1,{61,88,114,255})
    D.Icon(vg,'shop',x+30,top+22,30,D.orange);D.Text(vg,'商店',x+72,top+18,32)
    D.Text(vg,'还在设计',x+150,top+31,13,D.muted,'vox-body')
    D.Rect(vg,r.x+w/2-44,top+108,88,88,{41,70,95,255})
    D.Icon(vg,'shop',r.x+w/2-23,top+129,46,D.orange)
    D.Text(vg,'商店还没开张',r.x+w/2,top+214,28,D.white,nil,NVG_ALIGN_CENTER)
    self.paragraph:Draw(vg,'以后这里卖零件、涂装和装饰件。原型阶段所有零件都已开放，直接去编辑页用就行。',x+36,top+264,width-72,D.muted,true)
end
local M={}
function M.Create(s)
    if s.tab=='livery' then return LiveryPage.Create(s) end
    if s.tab=='workshop' then return Workshop.Create(s) end
    if s.tab=='battle' then return HomeBattle.Create(s) end
    if s.tab=='story' then return StoryPage.Create(s) end
    if s.tab=='salvage' then return DeferredModules['ui.SalvagePage'].Create(s) end
    local page=Page{position='absolute',width=s.width,height=s.height,pointerEvents='none'}
    page.paragraph=Paragraph.New(13,22.1)
    return page
end
return M

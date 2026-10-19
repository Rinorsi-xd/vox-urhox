local LiveryPage=require("ui.LiveryPage")
local Workshop=require("ui.Workshop")
local HomeBattle=require("ui.HomeBattle")
local StoryPage=require("ui.StoryPage")
local StoryPrefetch=require("app.StoryPrefetch")
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
-- 手机紧凑界面：模式选择 / 创意工坊 / 打捞按 PC 设计，放进 600 高画布会挤爆。按 810 高（600/.74）的逻辑尺寸排版，
-- 整页缩到 .74（点击区域同步缩放）。字号与 H5 @container (max-height:600px) 紧凑规则相当：模式名 30→22、规则 15→11
local PAGE_SCALE={battle=.74,workshop=.74,salvage=.74}
local Build
function M.Create(s)
    local k=s.compact and PAGE_SCALE[s.tab]
    if not k then return Build(s) end
    local w,h=s.width,s.height;s.width,s.height=w/k,h/k
    local ok,page=pcall(Build,s);s.width,s.height=w,h
    if not ok then error(page,0) end
    page:SetStyle({scale=k,transformOrigin='top-left'});page.pageScale=k
    return page
end
function Build(s)
    if s.tab=='livery' then return LiveryPage.Create(s) end
    if s.tab=='workshop' then return Workshop.Create(s) end
    -- The mode page leads to the story holo; fetch its bytes while the player chooses.
    if s.tab=='battle' then StoryPrefetch.Start();return HomeBattle.Create(s) end
    if s.tab=='story' then return StoryPage.Create(s) end
    if s.tab=='salvage' then return DeferredModules['ui.SalvagePage'].Create(s) end
    local page=Page{position='absolute',width=s.width,height=s.height,pointerEvents='none'}
    page.paragraph=Paragraph.New(13,22.1)
    return page
end
return M

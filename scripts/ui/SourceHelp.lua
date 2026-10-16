-- Help text is imported verbatim from the H5 UI, not a second key map.
local SourceModal=require("ui.SourceModal")
local HelpWheelBridge=require("ui.HelpWheelBridge")

local UI=require 'urhox-libs/UI'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Paragraph=require 'ui.SourceParagraph'
local Host=require 'ui.DialogHost'
local groups=require('core.ResourceData').Read('UI/SourceHelp.json')
local bodies={}
for i,g in ipairs(groups) do
    bodies[i]={}
    for j,row in ipairs(g.rows) do
        local before,after=row[2]:match('^(.-)⇄(.*)$')
        bodies[i][j]=before and {{text=before},{text='⇄',font='vox-help-symbol'},{text=after}} or row[2]
    end
end
local Help=Panel:Extend('VoxSourceHelp')
local Heading=Panel:Extend('VoxSourceHelpHeading')
function Heading:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout()
    SourceModal.DrawHeading(vg,r.x,r.y,r.w,'操作说明','机库、建造、视角和试车的全部按键')
end
function Help:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local cw=(r.w-96)/5
    if self.measuredWidth~=r.w or self.measuredContext~=vg then
        local heights={};local maximum=0
        self.paragraphs=self.paragraphs or {}
        for i,g in ipairs(groups) do
            local cy=35;heights[i]={};self.paragraphs[i]=self.paragraphs[i] or {}
            for j,row in ipairs(g.rows) do
                local paragraph=self.paragraphs[i][j] or Paragraph.New(12.5,'normal')
                self.paragraphs[i][j]=paragraph
                local layout=paragraph:Measure(vg,bodies[i][j],cw,D.muted)
                heights[i][j]=layout.height;cy=cy+34+layout.height
            end
            maximum=math.max(maximum,cy)
        end
        self.rows=heights;self.measuredWidth=r.w;self.measuredContext=vg;self.bodyHeight=maximum
        self:SetHeight(maximum+31)
    end
    local viewportHeight=UI.GetHeight()
    if self.measuredViewportHeight~=viewportHeight or self.scrollBodyHeight~=self.bodyHeight then
        local natural=self.bodyHeight+149
        self.scroll.props.sourceNaturalHeight=natural
        self.scroll:SetHeight(math.min(natural,viewportHeight*.9))
        self.measuredViewportHeight=viewportHeight;self.scrollBodyHeight=self.bodyHeight
    end
    for i,g in ipairs(groups) do
        local x=r.x+(i-1)*(cw+24);local y=r.y
        D.Text(vg,g.title,x,y,19,D.orange,nil,nil,1)
        local titleWidth=D.Width(vg,g.title,19,nil,1);D.Rect(vg,x+titleWidth+8,y+11,cw-titleWidth-8,1,{255,255,255,31})
        y=y+35
        for j,row in ipairs(g.rows) do
            local key=row[1]:gsub('%s+',' ');local kw=math.max(18,D.Width(vg,key,12,'vox-body',.5)+12)
            nvgBeginPath(vg);nvgRoundedRect(vg,x,y,kw,19,2);nvgFillColor(vg,nvgRGBA(0,0,0,89));nvgFill(vg)
            D.Text(vg,key,x+kw/2,y+2,12,nil,'vox-body',NVG_ALIGN_CENTER,.5)
            self.paragraphs[i][j]:Draw(vg,bodies[i][j],x,y+23,cw,D.muted)
            y=y+34+self.rows[i][j]
        end
    end
    D.Text(vg,'按 H 或点击任意处关闭',r.x+r.w/2,r.y+self.bodyHeight+16,12,D.dim,'vox-body',NVG_ALIGN_CENTER)
end
local M={}
function M.Open(owner)
    local releaseWheel=function()end
    local modal=Host.Open(owner,'操作说明',function() releaseWheel() end,
        {width=1240,widthRatio=.94,heightRatio=.9,fullScroll=true,help=true},function() releaseWheel() end)
    local scroll=UI.ScrollView{width='100%',height=math.min(895,UI.GetHeight()*.9),showScrollbar=false}
    scroll.props.sourceNaturalHeight=895
    scroll:AddChild(Heading{width='100%',height=94,flexShrink=0})
    local body=UI.Panel{width='100%',paddingHorizontal=28,paddingBottom=24,flexShrink=0}
    local content=Help{width='100%',height=777,flexShrink=0,onClick=function() Host.Close(owner) end};content.scroll=scroll
    body:AddChild(content);scroll:AddChild(body);modal:AddContent(scroll);modal.helpContent=content;modal.scroll=scroll
    -- Overlay hit testing may return the modal shell instead of detached content.
    modal.OnWheel=function(_,dx,dy) scroll:OnWheel(dx,dy) end
    releaseWheel=HelpWheelBridge.Attach(owner,modal,scroll)
    owner.dialogTick=function()
        if input:GetKeyPress(KEY_H) or input:GetKeyPress(KEY_F1) then Host.Close(owner) end
    end
    return modal
end
return M

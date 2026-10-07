-- .bay-new-menu: original PC content, CSS boxes, transparent items and entry.
-- UI retains hit testing/ownership; entry opacity composites one bounded layer.
local Popover=require 'ui.SourcePopover'
local Button=require 'urhox-libs/UI/Widgets/Button'
local D=require 'ui.SourceDraw'
local Rich=require 'ui.SourceRichText'
local Motion=require 'ui.SourceButtonMotion'
local Presets=require 'ui.HomePresets'
local Menu=Popover:Extend('VoxHomeNewMenu')
local Item=Button:Extend('VoxHomeNewMenuItem')
local function Tween(value) return {value=value,start=value,target=value,elapsed=0,duration=0} end
function Item:Update(dt)
    self.hoverMotion=self.hoverMotion or Tween(0)
    Motion.Step(self.hoverMotion,self.state.hovered and 1 or 0,.12,dt,'ease')
end
function Item:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props
    local hover=self.hoverMotion and self.hoverMotion.value or 0
    D.Rect(vg,r.x,r.y,r.w,r.h,{255,255,255,math.floor(15.3*hover+.5)})
    D.Rect(vg,r.x,r.y,3,r.h,{255,106,19,math.floor(255*hover+.5)})
    D.Icon(vg,p.icon,r.x+15,r.y+(r.h-24)/2,24,self.state.hovered and D.orange or D.muted)
    D.Text(vg,p.text,r.x+51,r.y+10,18)
    if not self.description or self.descriptionWidth~=r.w-63 then
        self.descriptionWidth=r.w-63
        self.description=Rich.Layout(vg,{{{text=p.subtitle,size=12,font='vox-body',color=D.muted}}},self.descriptionWidth,16.796875)
    end
    Rich.Draw(vg,self.description,r.x+51,r.y+35)
end
local M={height=332.375}
function M.Create(s)
    local menu=Menu{position='absolute',padding=6,gap=2,visible=false}
    local rows={{'empty','从零建造','只有一个核心驾驶舱','cube'}}
    for i=1,2 do local p=Presets[i];rows[#rows+1]={p[1],'预制车：'..p[2],p[3],p[4]} end
    rows[#rows+1]={'import','导入蓝图码','别人分享的 FKZC1: 蓝图码','download'}
    for i,p in ipairs(rows) do
        menu:AddChild(s.Track(Item{text=p[2],subtitle=p[3],icon=p[4],width='100%',height=(i==2 or i==3) and 95.390625 or 61.796875,flexShrink=0,
            onClick=function()
                if p[1]=='import' then s.SetNew(false);require('ui.GarageDialogs').Code(s,true)
                else s.CreateVehicle(p[1]) end
            end}))
    end
    return menu
end
return M

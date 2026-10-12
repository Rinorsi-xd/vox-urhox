-- .bay-new-menu: original PC content, CSS boxes, transparent items and entry.
-- UI retains hit testing/ownership; entry opacity composites one bounded layer.
local Popover=require 'ui.SourcePopover'
local Button=require 'urhox-libs/UI/Widgets/Button'
local D=require 'ui.SourceDraw'
local Motion=require 'ui.SourceButtonMotion'
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
    D.Rect(vg,r.x,r.y,3,r.h,{49,154,255,math.floor(255*hover+.5)})
    D.Icon(vg,p.icon,r.x+15,r.y+(r.h-24)/2,24,self.state.hovered and D.orange or D.muted)
    D.Text(vg,p.text,r.x+51,r.y+21,20)
    D.Icon(vg,'chev',r.x+r.w-30,r.y+24,18,D.muted)
end
local M={height=204}
function M.Create(s)
    local menu=Menu{position='absolute',padding=6,gap=2,visible=false}
    local rows={{'empty','创建新车','cube'},{'import','导入蓝图','download'},{'workshop','创意工坊','workshop'}}
    for i,p in ipairs(rows) do
        menu:AddChild(s.Track(Item{text=p[2],icon=p[3],width='100%',height=62,flexShrink=0,
            onClick=function()
                if p[1]=='workshop' then s.SetNew(false);s.SetTab('workshop')
                elseif p[1]=='import' then s.SetNew(false);require('ui.GarageDialogs').Code(s,true)
                else s.CreateVehicle(p[1]) end
            end}))
    end
    return menu
end
return M

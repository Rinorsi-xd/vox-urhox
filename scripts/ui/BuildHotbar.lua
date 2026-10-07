local UI=require 'urhox-libs/UI'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local Defs=require 'parts.Defs'
local Theme=require 'ui.VoxTheme'
local D=require 'ui.SourceDraw'
local Slot=Panel:Extend('VoxBuildSlot')
function Slot:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local def=Defs.PARTS[p.partType]
    D.Panel(vg,r.x,r.y,r.w,r.h,10,{44,48,55,255},{23,25,29,255})
    if p.active then
        D.Path(vg,{r.x+1,r.y+1,r.x+r.w-10,r.y+1,r.x+r.w-1,r.y+10,r.x+r.w-1,r.y+r.h-1,r.x+1,r.y+r.h-1})
        nvgStrokeWidth(vg,2);nvgStrokeColor(vg,D.Color(D.orange));nvgStroke(vg)
    end
    D.Text(vg,tostring(p.index%10),r.x+5,r.y+2,15,p.selected and D.orange or D.muted)
    if def then
        local size=p.thumbnailSize or 46
        self:RenderBackgroundImage(vg,Theme.Thumbnail(p.partType),{x=r.x+(r.w-size)/2,y=r.y+54-size,w=size,h=size},'contain',nil)
        nvgSave(vg);nvgIntersectScissor(vg,r.x+2,r.y+55,r.w-4,18)
        D.Text(vg,def.name,r.x+r.w/2,r.y+55,13,D.white,nil,NVG_ALIGN_CENTER);nvgRestore(vg)
    else D.Icon(vg,'plus',r.x+r.w/2-9,r.y+38,18,D.dim) end
end
local M={}
function M.Create(session,compact,onHover)
    local inventory=session.inventory;local slots={};local children={}
    local sourceMain=not onHover
    local layout=require('ui.SourceBuildLayout').ForWidth(sourceMain and UI.GetWidth() or 1920)
    for i=1,10 do
        local slot=Slot{index=i,width=layout.slot,height=76,thumbnailSize=layout.thumbnail,flexShrink=0,
            onClick=function(_,e) if not e or e:IsTouch() or e:IsPrimaryButton() then session:SelectHotbar(i) end end,
            onPointerUp=function(e) if e:IsSecondaryButton() then session:ClearHotbar(i) end end,
            onLongPressStart=function() session:ClearHotbar(i) end,
            onPointerEnter=function() if onHover and inventory.hotbar[i] then onHover(inventory.hotbar[i]) end end}
        slots[i]={widget=slot};children[i]=slot
    end
    local root=UI.Panel{width=layout.hotbar,height=76,flexDirection='row',gap=6,children=children}
    local revision,tool=-1,''
    local function Refresh()
        local currentTool=session.editor.tool
        if revision==inventory.revision and tool==currentTool then return end;revision=inventory.revision;tool=currentTool
        for i,s in ipairs(slots) do
            local p=s.widget.props;p.partType=inventory.hotbar[i];p.selected=i==inventory.active;p.active=p.selected and (not sourceMain or currentTool=='build')
            s.widget:SetStyle({top=p.active and -8 or 0})
        end
    end
    Refresh()
    return {root=root,slots=slots,Refresh=Refresh,Hit=function(x,y)
        for i,s in ipairs(slots) do local r=s.widget:GetAbsoluteLayoutForHitTest();if x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h then return i end end
    end}
end
return M

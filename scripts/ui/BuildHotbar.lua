local InventoryShadows=require("ui.InventoryShadows")
local SourceBuildLayout=require("ui.SourceBuildLayout")
local TouchMode=require("controls.TouchMode")

local UI=require 'urhox-libs/UI'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local Defs=require 'parts.Defs'
local Theme=require 'ui.VoxTheme'
local D=require 'ui.SourceDraw'
local Relief=require 'ui.SourceRelief'
local Feedback=require 'ui.InventoryFeedback'
local Slot=Panel:Extend('VoxBuildSlot')
function Slot:Update(dt) Feedback.Slot(self,dt) end
function Slot:OnMouseEnter() self:SetState({hovered=true}) end
function Slot:OnMouseLeave() self:SetState({hovered=false}) end
function Slot:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local def=Defs.PARTS[p.partType]
    if p.inventoryStyle then
        local focused=Feedback.Focused(self);local m=self.inventoryFeedback
        local color=Feedback.Mix({32,58,84,255},{49,92,131,255},m and m.hover.value or 0)
        color=Feedback.Mix(color,{157,207,238,255},m and m.active.value or (p.active and 1 or 0))
        color=Feedback.Mix(color,{67,104,137,255},m and m.drop.value or 0)
        D.Path(vg,{r.x,r.y,r.x+r.w-9,r.y,r.x+r.w,r.y+9,r.x+r.w,r.y+r.h,r.x,r.y+r.h})
        nvgFillColor(vg,D.Color(Feedback.Color(color,focused)));nvgFill(vg)
        if not self.state.hovered and not p.dropTarget or p.active then Relief.Halftone(vg,r.x,r.y,r.w,r.h,p.active,140,{r.x,r.y,r.x+r.w-9,r.y,r.x+r.w,r.y+9,r.x+r.w,r.y+r.h,r.x,r.y+r.h}) end
        if focused or p.dropTarget then Feedback.Edges(vg,r,{r.x,r.y,r.x+r.w-9,r.y,r.x+r.w,r.y+9,r.x+r.w,r.y+r.h,r.x,r.y+r.h},false,focused,p.dropTarget and {230,187,112,255} or D.orange)
            if p.dropTarget and not focused then D.Rect(vg,r.x,r.y+r.h-4,r.w,4,{230,187,112,255}) end end
        D.Text(vg,tostring(p.index%10),r.x+5,r.y+2,14,Feedback.Color(p.active and D.ink or {153,182,208,255},focused),'vox-display')
        if def then
            local size=p.thumbnailSize;InventoryShadows.Image(self,vg,p.partType,'slot',{x=r.x+(r.w-size)/2,y=r.y+8,w=size,h=size})
            Feedback.Image(self,vg,Theme.Thumbnail(p.partType),{x=r.x+(r.w-size)/2,y=r.y+8,w=size,h=size},focused)
            nvgSave(vg);nvgIntersectScissor(vg,r.x+2,r.y+r.h-18,r.w-4,16)
            D.Text(vg,def.name,r.x+r.w/2,r.y+r.h-17,p.compactInventory and 10 or 11,p.active and D.ink or D.white,'vox-body',NVG_ALIGN_CENTER);nvgRestore(vg)
        else D.Icon(vg,'plus',r.x+r.w/2-9,r.y+25,18,D.dim) end
        return
    end
    nvgSave(vg);if p.dimmed and not self.state.hovered then nvgGlobalAlpha(vg,.5) end
    D.Path(vg,{r.x,r.y,r.x+r.w-6,r.y,r.x+r.w,r.y+6,r.x+r.w,r.y+r.h,r.x,r.y+r.h})
    nvgFillColor(vg,D.Color(p.active and {52,86,114,255} or {32,56,78,255}));nvgFill(vg)
    D.Rect(vg,r.x,r.y+r.h-3,r.w,p.active and 3 or 2,p.active and {155,215,250,255} or {8,15,28,112})
    D.Text(vg,tostring(p.index%10),r.x+4,r.y+3,12,p.selected and D.orange or {127,154,180,255},'vox-display')
    if def then
        local size=p.thumbnailSize or 46
        self:RenderBackgroundImage(vg,Theme.Thumbnail(p.partType),{x=r.x+(r.w-size)/2,y=r.y+(r.h-size)/2,w=size,h=size},'contain',nil)
    else D.Icon(vg,'plus',r.x+r.w/2-8,r.y+(r.h-16)/2,16,D.dim) end
    nvgRestore(vg)
end
local M={}
function M.Create(session,compact,onHover)
    local inventory=session.inventory;local slots={};local children={}
    local sourceMain=not onHover
    local layout=SourceBuildLayout.ForWidth(sourceMain and UI.GetWidth() or 1920)
    local sw,sh=UI.GetViewportSize();local compactInventory=not sourceMain and sh<=600 and sw>sh
    if not sourceMain then layout.slot=compactInventory and 54 or 64;layout.thumbnail=compactInventory and 29 or 43;layout.hotbar=layout.slot*10+(compactInventory and 5 or 8)*9 end
    for i=1,10 do
        local slot=Slot{index=i,width=layout.slot,height=sourceMain and (sw<=1440 and 50 or 54) or compactInventory and 54 or 70,inventoryStyle=not sourceMain,compactInventory=compactInventory,thumbnailSize=layout.thumbnail,flexShrink=0,
            onClick=function(_,e) if not e or e:IsTouch() or e:IsPrimaryButton() then session:SelectHotbar(i) end end,
            onPointerUp=function(e) if e:IsSecondaryButton() then session:ClearHotbar(i) end end,
            onLongPressStart=function()
                if sourceMain and TouchMode.Enabled() then session:OpenInventory()
                else session:ClearHotbar(i) end
            end,
            onPointerEnter=function() if onHover and inventory.hotbar[i] then onHover(inventory.hotbar[i]) end end}
        slots[i]={widget=slot};children[i]=slot
    end
    local root=UI.Panel{width=layout.hotbar,height=sourceMain and (sw<=1440 and 50 or 54) or compactInventory and 54 or 70,flexDirection='row',gap=sourceMain and 4 or compactInventory and 5 or 8,children=children}
    local revision,tool=-1,''
    local function Refresh()
        local currentTool=session.editor.tool
        if revision==inventory.revision and tool==currentTool then return end;revision=inventory.revision;tool=currentTool
        for i,s in ipairs(slots) do
            local p=s.widget.props;p.partType=inventory.hotbar[i];p.selected=i==inventory.active;p.active=p.selected and (not sourceMain or currentTool=='build');p.dimmed=sourceMain and currentTool~='build'
            s.widget:SetStyle({top=sourceMain and p.active and -5 or 0})
        end
    end
    Refresh()
    return {root=root,slots=slots,Refresh=Refresh,Hit=function(x,y)
        for i,s in ipairs(slots) do local r=s.widget:GetAbsoluteLayoutForHitTest();if x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h then return i end end
    end}
end
return M

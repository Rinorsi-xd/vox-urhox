-- Shared source CSS popover surface: shadow, whole-group entry and ownership.
-- UI keeps the original child tree for input; temporary textures retire at rest.
local UI=require 'urhox-libs/UI'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Motion=require 'ui.SourceButtonMotion'
local Shadow=require 'ui.SourceBoxShadow'
local Layer=require 'ui.SourceLayer'
local Popover=Panel:Extend('VoxSourcePopover')
local function Tween(value) return {value=value,start=value,target=value,elapsed=0,duration=0} end
function Popover:SetOpen(open)
    self:SetVisible(open)
    if open then
        if not self.layer then
            self.layer=Layer.New(self.props.sourceLayerOrder or 999979,function() return self:PrepareLayer() end,function(vg,r)
                nvgSave(vg);nvgTranslate(vg,-r.x,-r.y);self:DrawBackground(vg)
                for _,child in ipairs(self:GetRenderChildren()) do UI.RenderWidgetSubtree(child,vg) end
                nvgRestore(vg)
            end)
        end
        self.entry=Tween(0);self.layer.ready=false;self:SetStyle({translateY=self.props.sourceEntryOffset or 10})
    else
        self.entry=nil;self:SetStyle({translateY=0})
        if self.layer then self.layer:ReleaseTexture() end
    end
end
function Popover:Update(dt)
    if not self.entry then return end
    Motion.Step(self.entry,1,self.props.sourceEntryDuration or .2,dt,false)
    self:SetStyle({translateY=(self.props.sourceEntryOffset or 10)*(1-self.entry.value)})
    if self.entry.value==1 then self.entry=nil;self.layer:ReleaseTexture() end
end
function Popover:PrepareLayer()
    if not self:IsVisible() or not self.entry then return end
    -- This event precedes UI.Render; an opening/resized menu must use this
    -- frame's Yoga layout, not the previous hidden layout.
    if UI.IsLayoutDirty() then UI.Layout() end
    local r=self:GetAbsoluteLayout();local scale=UI.GetScale()
    if r.w<=0 or r.h<=0 then return end
    -- blur=36 => three-sigma support 54px, shifted down 16px. Keep the
    -- untransformed layer stable; UI applies translation once for hit/render.
    -- The declared fixed size avoids Yoga edge rounding changing texture
    -- extent when the same menu moves by a fractional pixel.
    local width=type(self.props.width)=='number' and self.props.width or r.w
    local height=type(self.props.height)=='number' and self.props.height or r.h
    self.layerRect={x=(math.floor((r.x-54)*scale)-2)/scale,y=(math.floor((r.y-38)*scale)-2)/scale,
        w=(math.ceil((width+108)*scale)+5)/scale,h=(math.ceil((height+108)*scale)+5)/scale,scale=scale}
    local previous=self.contentRect
    local dirty=not previous or previous.x~=r.x or previous.y~=r.y or previous.w~=r.w or previous.h~=r.h or previous.scale~=scale
    self.contentRect={x=r.x,y=r.y,w=r.w,h=r.h,scale=scale}
    self.childVisuals=self.childVisuals or {}
    for i,child in ipairs(self.children) do
        local hover=child.hoverMotion and child.hoverMotion.value or 0;local old=self.childVisuals[i]
        local bar=child.barMotion and child.barMotion.value or 0;local arrow=child.arrowMotion and child.arrowMotion.value or 0
        if not old or old.hover~=hover or old.bar~=bar or old.arrow~=arrow or old.hovered~=child.state.hovered or old.selected~=child.props.selected then
            dirty=true;self.childVisuals[i]={hover=hover,bar=bar,arrow=arrow,hovered=child.state.hovered,selected=child.props.selected}
        end
    end
    -- Entry translation/opacity changes only the composite. Repaint the
    -- static contents only for layout/DPR changes or actual hover feedback.
    return self.layerRect,dirty
end
function Popover:DrawBackground(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout()
    self.shadow=self.shadow or Shadow.New()
    self.shadow:Draw(vg,r.x,r.y+16,r.w,r.h,36,nvgRGBA(0,0,0,128))
    nvgBeginPath(vg);nvgRect(vg,r.x,r.y,r.w,r.h)
    D.Gradient(vg,r.x,r.y,r.w,r.h,{38,42,49,255},{26,28,33,255})
    D.Rect(vg,r.x,r.y,r.w,1,{255,255,255,20})
end
function Popover:Render(vg)
    if self.entry then
        if self.layerRect then self.layer:Draw(vg,self.layerRect.x,self.layerRect.y,self.entry.value) end
    else self:DrawBackground(vg) end
end
function Popover:CustomRenderChildren(vg,renderFn)
    -- Offscreen draw already contains these same children at full opacity.
    if not self.entry then Panel.CustomRenderChildren(self,vg,renderFn) end
end
function Popover:Destroy()
    if self.shadow then self.shadow:Dispose();self.shadow=nil end
    if self.layer then self.layer:Dispose();self.layer=nil end
    Panel.Destroy(self)
end
return Popover

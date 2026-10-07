-- Two nested CSS groups, bounded to the clipped card; the rest of the backdrop
-- stays direct vector drawing. Input coordinates remain in logical screen px.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Layer=require 'ui.SourceLayer'
local M={};M.__index=M
function M.New(modal)
    local self=setmetatable({modal=modal},M)
    self.card=Layer.New(999980,function() return self:Prepare() end,function(vg,r) self:Card(vg,r) end)
    self.composite=Layer.New(999981,function() return not self.direct and self.rect or nil end,function(vg,r)
        nvgSave(vg);nvgTranslate(vg,-r.x,-r.y);M.Backdrop(vg,r.sw,r.sh,1);nvgRestore(vg)
        self.card:Draw(vg,0,0,r.cardAlpha)
    end)
    return self
end
function M:Prepare()
    local modal=self.modal
    if not modal:IsVisible() then self.rect=nil;return end
    local sw,sh=UI.GetViewportSize();local spec=modal.props.source
    local w=math.min(spec.width or 780,sw*(spec.widthRatio or .92))
    if spec.fullScroll then
        local scroll=modal.contentContainer_.children[1]
        if scroll and scroll.props.sourceNaturalHeight then
            local height=math.min(scroll.props.sourceNaturalHeight,sh*(spec.heightRatio or .86))
            if scroll.props.height~=height then scroll:SetHeight(height) end
        end
    end
    local cw=spec.fullScroll and w or w-56
    local chrome=spec.fullScroll and 0 or 118
    local naturalHeight=spec.contentHeight and spec.contentHeight(cw) or modal:CalculateContentHeight(cw)
    local ch=math.min(naturalHeight,sh*(spec.heightRatio or .86)-chrome)
    local h=ch+chrome;local alpha,cardAlpha,offset=modal:EntryState()
    self.direct=alpha==1 and cardAlpha==1
    local x,y=(sw-w)/2,(sh-h)/2+offset;local scale=UI.GetScale()
    -- Align only the texture bounds; preserve source card's fractional layout.
    local left,top=(math.floor(x*scale)-2)/scale,(math.floor(y*scale)-2)/scale
    -- Fixed pixel extent across fractional animation offsets avoids reallocating
    -- a texture for the extra edge pixel as the card moves through pixel rows.
    -- Source clip-path removes the outer box-shadow. Only a two-pixel guard
    -- for edge filtering is needed; do not allocate a nonexistent shadow.
    local extentW=(math.ceil(w*scale)+5)/scale
    local extentH=(math.ceil(h*scale)+5)/scale
    self.rect={x=left,y=top,w=extentW,h=extentH,scale=scale,sw=sw,sh=sh,
        cardX=x,cardY=y,cardW=w,cardH=h,contentW=cw,contentH=ch,alpha=alpha,cardAlpha=cardAlpha}
    modal.modalLayout_={x=x,y=y,w=w,h=h};modal.closeButtonLayout_=nil
    local content=modal.contentContainer_
    YGNodeCalculateLayout(content.node,cw,ch,YGDirectionLTR)
    content.renderOffsetX_=x+(spec.fullScroll and 0 or 28);content.renderOffsetY_=y+(spec.fullScroll and 0 or 94)
    content.renderWidth_=cw;content.renderHeight_=ch
    if spec.layoutContent then spec.layoutContent(content.renderOffsetX_,content.renderOffsetY_,cw) end
    return not self.direct and self.rect or nil
end
function M.Backdrop(vg,sw,sh,alpha)
    nvgSave(vg);nvgGlobalAlpha(vg,alpha);nvgTranslate(vg,sw/2,sh/2);nvgScale(vg,sw/sh,1)
    nvgBeginPath(vg);nvgRect(vg,-sh/2,-sh/2,sh,sh)
    nvgFillPaint(vg,nvgRadialGradient(vg,0,0,0,sh*.57,nvgRGBA(10,11,13,158),nvgRGBA(6,7,9,230)));nvgFill(vg);nvgRestore(vg)
end
function M:Card(vg,r,direct)
    local modal=self.modal;local spec=modal.props.source
    D.Begin(vg);nvgSave(vg);if not direct then nvgTranslate(vg,-r.x,-r.y) end
    local x,y,w,h=r.cardX,r.cardY,r.cardW,r.cardH
    -- The original CSS clips both the card and its outer shadow to this path.
    D.Path(vg,{x,y,x+w-20,y,x+w,y+20,x+w,y+h,x,y+h})
    D.Gradient(vg,x,y,w,h,{35,38,44,255},{23,25,29,255});D.Rect(vg,x,y,w-20,1,{255,255,255,20})
    if not spec.fullScroll then modal.DrawHeading(vg,x,y,w,modal.title_,spec.subtitle) end
    local content=modal.contentContainer_
    nvgIntersectScissor(vg,content.renderOffsetX_,content.renderOffsetY_,r.contentW,r.contentH)
    UI.RenderWidgetSubtree(content,vg);nvgRestore(vg)
end
function M:Draw(vg)
    local r=self.rect;if not r then return end
    if self.direct then M.Backdrop(vg,r.sw,r.sh,1);self:Card(vg,r,true);return end
    if not self.composite.ready then return end
    local x,y,w,h=r.x,r.y,self.composite.width,self.composite.height
    for _,clip in ipairs({{0,0,r.sw,math.max(0,y)},{0,y+h,r.sw,math.max(0,r.sh-y-h)},
        {0,y,math.max(0,x),h},{x+w,y,math.max(0,r.sw-x-w),h}}) do
        if clip[3]>0 and clip[4]>0 then
            nvgSave(vg);nvgIntersectScissor(vg,table.unpack(clip));M.Backdrop(vg,r.sw,r.sh,r.alpha);nvgRestore(vg)
        end
    end
    self.composite:Draw(vg,x,y,r.alpha)
end
function M:Dispose()
    -- Composite context samples card texture; remove that bridge first.
    self.card:Dispose();self.composite:Dispose();self.modal=nil;self.rect=nil
end
return M

-- Original testDrive.js _resetBar: a thin line below the reticle, no panel.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Panel=UI.Panel:Extend('VoxResetProgress')
local M={}
local white={232,242,248,255};local shadow={{x=0,y=1,blur=3,color={0,0,0,204}}}
function Panel:Render(vg)
    local channel=self.session.resetChan;if not channel then return end
    D.HudFont(vg);local box=self:GetAbsoluteLayout()
    -- The source appends this fixed overlay to body, outside the scaled #ui.
    -- Convert CSS pixels to UI coordinates while retaining the viewport centre.
    local pixel=graphics:GetDPR()/math.max(.001,UI.GetScale());local x,y=0,118
    local frac=math.max(0,math.min(1,channel.t/channel.dur));local width=180*frac
    nvgSave(vg)
    nvgTranslate(vg,box.x+box.w/2,box.y+box.h/2);nvgScale(vg,pixel,pixel)
    D.Text(vg,'重置中 · R 取消',x,y,13,white,'vox-hud-medium',NVG_ALIGN_CENTER,3,false,13,shadow)
    D.Rect(vg,x-90,y+20,180,3,{255,255,255,38})
    if width>0 then
        nvgBeginPath(vg);nvgRect(vg,x-98,y+12,width+16,19)
        nvgFillPaint(vg,nvgBoxGradient(vg,x-90,y+20,width,3,0,8,nvgRGBA(127,208,255,150),nvgRGBA(127,208,255,0)));nvgFill(vg)
        D.Rect(vg,x-90,y+20,width,3,{127,208,255,255})
    end
    nvgRestore(vg)
end
function M.Attach(session,root)
    local layer=Panel{position='absolute',width='100%',height='100%',pointerEvents='none'}
    layer.session=session;root:AddChild(layer)
    return {layer=layer,Dispose=function() if layer.parent then layer.parent:RemoveChild(layer) end end}
end
return M

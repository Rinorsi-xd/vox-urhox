-- Original combatFeedback sniper chevrons. No warning text or audio is added.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Layout=require 'ui.ReticleState'
local Panel=UI.Panel:Extend('VoxSniperThreat')
local M={}
function Panel:Render(vg)
    local s=self.session;if s.paused or s.story and s.story.boss and s.story.boss.cinematic then return end
    local p=self.player;if not p or not p.alive then return end
    D.Begin(vg);local box=self:GetAbsoluteLayout();local l=Layout.Layout(box.w,box.h)
    local k=l.k or l.scale or 1;local cx,cy=l.cx or box.w/2,l.cy or box.h/2
    local radius=l.radius+26*k;local time=s.world.time
    local camera=s.camera:GetCamera().node;local f=camera.worldRotation*Vector3.FORWARD;local yaw=math.atan(-f.x,f.z)
    nvgSave(vg);nvgTranslate(vg,box.x,box.y);nvgLineCap(vg,NVG_SQUARE);nvgLineJoin(vg,NVG_MITER)
    for _,warning in ipairs(self.warnings or {}) do
        local pos=warning.pos;local angle=math.atan(pos[1]-p.pos[1],pos[3]-p.pos[3])-yaw
        nvgSave(vg);nvgTranslate(vg,cx+math.sin(angle)*radius,cy-math.cos(angle)*radius);nvgRotate(vg,angle)
        local alpha=.6+.4*(.5-.5*math.cos(time*math.pi*2/.8))
        for _,blur in ipairs({4,0}) do nvgBeginPath(vg)
            for i=0,1 do local y=-i*7*k;local z=10*k;nvgMoveTo(vg,-z,y+z*.55);nvgLineTo(vg,0,y-z*.45);nvgLineTo(vg,z,y+z*.55) end
            nvgStrokeColor(vg,nvgRGBA(255,59,48,math.floor(alpha*(blur==0 and 255 or 170))));nvgStrokeWidth(vg,2.6*k+blur);nvgStroke(vg)
        end;nvgRestore(vg)
    end;nvgRestore(vg)
end
function M.Attach(session,root)
    local layer=Panel{position='absolute',width='100%',height='100%',pointerEvents='none'};layer.session=session;root:AddChild(layer)
    return {layer=layer,Update=function(warnings,player) layer.warnings=warnings or {};layer.player=player end,Dispose=function() layer.warnings={};if layer.parent then layer.parent:RemoveChild(layer) end end}
end
return M

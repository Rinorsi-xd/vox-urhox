-- Source reticle.js _seek and missile target acquisition, in the UI-owned frame.
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Math=require 'core.Math3'
local M=Panel:Extend('VoxMissileHud')
local function Line(vg,x,y,x1,y1,color,width)
    nvgBeginPath(vg);nvgMoveTo(vg,x,y);nvgLineTo(vg,x1,y1);nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,width or 1);nvgStroke(vg)
end
local function Box(vg,x,y,w,h,color,width)
    for _,corner in ipairs({{-1,-1},{1,-1},{1,1},{-1,1}}) do
        local sx,sy=corner[1],corner[2]
        nvgBeginPath(vg);nvgMoveTo(vg,x+sx*w,y+sy*h*.78);nvgLineTo(vg,x+sx*w,y+sy*h);nvgLineTo(vg,x+sx*w*.78,y+sy*h)
        nvgStrokeWidth(vg,width or 2);nvgStrokeColor(vg,D.Color(color));nvgStroke(vg)
    end
end
function M:Render(vg)
    local s=self.session
    if not s.pointer.captured or s.dialog or s.combat and not s.combat.player.alive then return end
    local info=s.weapons:LockInfo();if not info then return end
    D.Begin(vg);local r=self:GetAbsoluteLayout();local cx,cy=r.x+r.w/2,r.y+r.h/2
    local scale=math.min(1,r.h/720);local camera=s.camera:GetCamera()
    local box=math.max(40*scale,math.tan(info.box)*r.h/(2*math.tan(camera.fov*math.pi/360)))
    local cool=info.firing or info.cooling
    local color=cool and {242,246,248,85} or info.locked and {255,59,48,192} or info.progress>0 and {255,176,46,192} or {242,246,248,176}
    Box(vg,cx,cy,box,box,color,2*scale)
    for i=-4,4 do local p=i/5*box;local length=(i%2~=0 and 4 or 8)*scale;local c={242,246,248,96}
        Line(vg,cx+p,cy-box,cx+p,cy-box+length,c);Line(vg,cx+p,cy+box,cx+p,cy+box-length,c)
        Line(vg,cx-box,cy+p,cx-box+length,cy+p,c);Line(vg,cx+box,cy+p,cx+box-length,cy+p,c)
    end
    if not cool and info.progress==0 then
        local y=cy-box+(s.world.time/1.4%1)*2*box;Line(vg,cx-box+10*scale,y,cx+box-10*scale,y,{242,246,248,64})
    end
    local font=math.max(11,13*scale)
    local fill=info.phase=='reload' and info.reload or info.firing and 0 or info.locked and 1 or info.progress
    D.Rect(vg,cx-box,cy+box+26*scale,box*2,3*scale,{242,246,248,30});D.Rect(vg,cx-box,cy+box+26*scale,box*2*fill,3*scale,color)
    local target=info.ref
    if target and target.pos and not self.overlay.focus then
        local x,y=self.overlay:Project(target.pos)
        if x then
            local progress=info.locked and 1 or 1-(1-info.progress)^3
            local tight=34*scale;local half=math.max(box,tight)+(tight-math.max(box,tight))*progress
            local tx,ty=cx+(x-cx)*progress,cy+(y-cy)*progress
            nvgSave(vg);nvgTranslate(vg,tx,ty);nvgRotate(vg,(1-progress)*math.pi/4)
            Box(vg,0,0,half,half*(1-.2*progress),info.locked and {255,59,48,255} or {255,176,46,255},2.6*scale);nvgRestore(vg)
            if info.locked then D.Text(vg,'LOCK',tx,ty-half*.8-25*scale,font,{255,59,48,255},'vox-code',NVG_ALIGN_CENTER) end
        end
    end
end
return M

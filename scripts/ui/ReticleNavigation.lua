-- Frozen reticle._compass waypoint, in logical H5 world coordinates.
local MarkerRules=require("story.MarkerRules")

local D=require 'ui.SourceDraw'
local R=require 'ui.ReticleDraw'
local M={}
function M.Read(session)
    local mission=session.story
    if not mission or not mission.player.alive or not mission.rules.begun or mission.rules.finished
        or mission.boss and mission.boss.cinematic or mission.epilogue then return nil end
    local state=MarkerRules.Select(mission)
    if not state or state.close then return nil end
    local pos=mission.player:Position();local target=state.target
    local dx,dz=target[1]-pos[1],target[3]-pos[3]
    return {yaw=math.atan(dx,dz),dy=target[2]-pos[2],dist=math.sqrt(dx*dx+dz*dz),label=state.label,enemy=state.enemy}
end
function M.Layout(l,head,wp)
    if not wp then return nil end
    -- Session heading is already -H5 yaw in degrees; waypoint yaw stays radians.
    local delta=(-wp.yaw*180/math.pi-head+540)%360-180
    local x=l.cx+math.max(-60,math.min(60,delta))*320*l.k/60
    local height=math.abs(wp.dy)>4 and math.floor(math.abs(wp.dy)+.5) or nil
    return {x=x,y=36*l.k,r=8*l.k,edge=math.abs(delta)>60 and (delta<0 and -1 or 1) or 0,
        height=height,up=wp.dy>0,label=(wp.label and wp.label~='' and wp.label..' ' or '')..math.floor(wp.dist+.5)..'m',
        labelY=(math.abs(x-l.cx)<46*l.k and 94 or 62)*l.k,color=wp.enemy and {255,74,58,255} or {255,201,74,255}}
end
function M.Render(vg,l,head,wp)
    local p=M.Layout(l,head,wp);if not p then return end
    local k,x,y,r,c=l.k,p.x,p.y,p.r,p.color
    if p.edge~=0 then R.Poly(vg,{x+p.edge*12*k,y,x+p.edge*3*k,y-7*k,x+p.edge*3*k,y+7*k},c) end
    nvgSave(vg);nvgTranslate(vg,x,y);nvgRotate(vg,math.pi/4)
    local side=r*math.sqrt(2)
    nvgBeginPath(vg);nvgRect(vg,-side/2-6*k,-side/2-6*k,side+12*k,side+12*k)
    nvgFillPaint(vg,nvgBoxGradient(vg,-side/2,-side/2,side,side,0,6*k,nvgRGBA(c[1],c[2],c[3],170),nvgRGBA(c[1],c[2],c[3],0)))
    nvgFill(vg);nvgRestore(vg)
    R.Poly(vg,{x,y-r,x+r,y,x,y+r,x-r,y},c)
    if p.height then
        local direction=p.up and 1 or -1;local ax=x+14*k
        R.Poly(vg,{ax,y-direction*7*k,ax+6*k,y+direction*2*k,ax-6*k,y+direction*2*k},c)
        R.Text(vg,tostring(p.height),ax+9*k,y+5*k,14*k,c,nil,false,false,0)
    end
    R.Text(vg,p.label:gsub('[<&]',''),x,p.labelY,14*k,c,NVG_ALIGN_CENTER,false,true,0)
end
return M

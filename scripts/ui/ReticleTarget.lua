local D=require 'ui.SourceDraw'
local R=require 'ui.ReticleDraw'
local State=require 'ui.ReticleState'
local Coord=require 'core.Coord'
local M={}
local function Ease(t) return 1-(1-State.Clamp(t))^3 end
function M.Update(o,dt)
    local s=o.session;local owner=s.aimHit and s.aimHit.owner;local ref=owner and owner.ref
    local me=s.combat and s.combat.player
    local lock=s.weapons:LockInfo();local missile=lock~=nil
    if missile then ref=lock.progress>0 and lock.ref or nil
    elseif ref and ref.spec and ref.alive and ref~=me and (not me or ref.team~=me.team) then o.focusHold=ref;o.focusHoldTime=.5
    else o.focusHoldTime=(o.focusHoldTime or 0)-dt;ref=o.focusHoldTime>0 and o.focusHold or nil end
    if not ref or not ref.spec or not ref.alive then o.focus=nil;o.acquired=nil;o.snapAt=nil;return end
    local pos=ref:Position();local x,y=o:Project(pos)
    if not x then o.focus=nil;return end
    local camera=s.camera:GetCamera();local distance=(Coord.Vec(table.unpack(pos))-camera.node.position):Length()
    local w,h=require('urhox-libs/UI').GetViewportSize();local l=State.Layout(w,h)
    local b=ref.spec.bounds;local radius=.5*math.sqrt((b.max[1]-b.min[1])^2+(b.max[2]-b.min[2])^2+(b.max[3]-b.min[3])^2)
    local half=math.max(34*l.k,math.min(h*.38,.4*radius*h/(math.max(1,distance)*math.tan(camera.fov*math.pi/360))))
    if o.acquired~=ref then o.acquired=ref;o.acquireAt=s.world.time;o.snapAt=nil end
    local progress=missile and (lock.locked and 1 or Ease(lock.progress)) or Ease((s.world.time-o.acquireAt)/.42)
    if progress>=1 and not o.snapAt then o.snapAt=s.world.time end
    local hp=ref:Health();local ghost=o.focusGhost or {v=hp,last=hp,at=0}
    if o.ghostRef~=ref then ghost={v=hp,last=hp,at=0};o.ghostRef=ref end
    if hp<ghost.last-.0001 then ghost.at=s.world.time end
    if hp>=ghost.v then ghost.v=hp elseif s.world.time-ghost.at>.4 then ghost.v=math.max(hp,ghost.v-dt*1.2) end
    ghost.last=hp;o.focusGhost=ghost
    o.focus={ref=ref,x=x,y=y,half=half,progress=progress,missile=missile,locked=missile and lock.locked or progress>=1,
        big=missile and math.max(half,math.tan(lock.box)*h/(2*math.tan(camera.fov*math.pi/360))) or half*2.6,
        hp=hp,ghost=ghost.v,distance=distance,name=ref.name,arms=#ref.spec.weapons}
end
local function Bracket(vg,hw,hh,k,c,alpha,rotation,x,y)
    nvgSave(vg);nvgGlobalAlpha(vg,alpha);nvgTranslate(vg,x,y);nvgRotate(vg,rotation)
    local len=math.max(8*k,math.min(hw,hh)*.42);local cut=math.min(7*k,len*.45)
    for _,sx in ipairs({-1,1}) do for _,sy in ipairs({-1,1}) do
        nvgBeginPath(vg);nvgMoveTo(vg,sx*hw,sy*(hh-len));nvgLineTo(vg,sx*hw,sy*(hh-cut));nvgLineTo(vg,sx*(hw-cut),sy*hh);nvgLineTo(vg,sx*(hw-len),sy*hh)
        nvgStrokeWidth(vg,2.6*k);nvgStrokeColor(vg,D.Color(c));nvgStroke(vg)
        D.Line(vg,sx*(hw+5*k),sy*(hh+5*k),sx*(hw+10*k),sy*(hh+10*k),c,1.3*k)
    end end
    R.Poly(vg,{-6*k,-hh-12*k,6*k,-hh-12*k,0,-hh-3*k},c)
    nvgRestore(vg)
end
function M.Render(vg,o,l)
    local f=o.focus;if not f then return end
    local k=l.k;local e=f.progress;local color=f.locked and {255,59,48,255} or f.missile and R.warn or R.white
    local function Box(p,alpha)
        local hw=f.big+(f.half-f.big)*p;local hh=f.big+(f.half*.8-f.big)*p
        local x=f.missile and l.cx+(f.x-l.cx)*p or f.x;local y=f.missile and l.cy+(f.y-l.cy)*p or f.y
        Bracket(vg,hw,hh,k,color,alpha,(1-p)*math.pi/4,x,y)
    end
    if e<1 then Box(math.max(0,e-.16),.35);Box(math.max(0,e-.32),.16) end
    Box(e,1)
    local snap=o.snapAt and (o.session.world.time-o.snapAt)/.3 or 1
    if snap<1 then Bracket(vg,f.half*(1+.7*snap),f.half*.8*(1+.7*snap),k,color,1-snap,0,f.x,f.y) end
    if e<=.5 then return end
    local x,y=State.TargetPlate(l,f);local endX=x+168*k
    nvgSave(vg);nvgGlobalAlpha(vg,(e-.5)*2)
    D.Line(vg,x-14*k,y+14*k,x,y,R.red,1.6*k);D.Line(vg,x,y,endX,y,R.red,1.6*k)
    local size=15*k;local width=D.Width(vg,f.name or '',size,'vox-hud')
    R.Text(vg,f.name or '',x+2*k,y-7*k,width>166*k and size*166*k/width or size,{255,138,128,255})
    for i=0,9 do
        local bx=x+4*k+i*15.5*k;local color=(i+.5)/10<=f.hp and R.red or (i+.5)/10<=f.ghost and R.white or {255,255,255,46}
        R.Poly(vg,{bx+2.5*k,y+5*k,bx+14.5*k,y+5*k,bx+12*k,y+11*k,bx,y+11*k},color)
    end
    R.Text(vg,math.floor(f.distance+.5)..' M',x+2*k,y+38*k,27*k,{255,138,128,255})
    R.Text(vg,'HULL '..math.ceil(f.hp*100)..'%',endX,y+33*k,13*k,{255,138,128,176},NVG_ALIGN_RIGHT)
    nvgRestore(vg)
end
return M

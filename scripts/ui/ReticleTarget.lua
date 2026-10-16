local UI=require("urhox-libs/UI")

local D=require 'ui.SourceDraw'
local R=require 'ui.ReticleDraw'
local State=require 'ui.ReticleState'
local Focus=require 'ui.ReticleFocus'
local M={}
local function Ease(t) return 1-(1-State.Clamp(t))^3 end
function M.Update(o,dt)
    local s=o.session;local camera=s.camera:GetCamera()
    local w,h=UI.GetViewportSize();local l=State.Layout(w,h)
    local ref=Focus.Resolve(o,dt,camera,w,h)
    local lock=s.weapons:LockInfo();local missile=lock~=nil
    if missile then ref=lock.progress>0 and lock.ref or nil end
    if not ref or not ref.spec or not ref.alive then o.focus=nil;o.acquired=nil;o.snapAt=nil;return end
    local pos=ref:Position();local x,y,distance=Focus.Project(camera,pos,w,h)
    if not x then o.focus=nil;return end
    local b=ref.spec.bounds;local radius=.5*math.sqrt((b.max[1]-b.min[1])^2+(b.max[2]-b.min[2])^2+(b.max[3]-b.min[3])^2)
    local half=math.max(34*l.k,math.min(h*.38,.4*radius*h/(math.max(1,distance)*math.tan(camera.fov*math.pi/360))))
    if o.acquired~=ref then o.acquired=ref;o.acquireAt=s.world.time;o.snapAt=nil end
    local progress=missile and (lock.locked and 1 or Ease(lock.progress)) or Ease((s.world.time-o.acquireAt)/.42)
    if missile and not lock.locked then o.snapAt=nil
    elseif progress>=1 and not o.snapAt then o.snapAt=s.world.time end
    local hp=ref:Life();local ghost=o.focusGhost or {v=hp,last=hp,at=0}
    if o.ghostRef~=ref then ghost={v=hp,last=hp,at=0};o.ghostRef=ref end
    if hp<ghost.last-.0001 then ghost.at=s.world.time end
    if hp>=ghost.v then ghost.v=hp elseif s.world.time-ghost.at>.4 then ghost.v=math.max(hp,ghost.v-dt*1.2) end
    ghost.last=hp;o.focusGhost=ghost
    o.focus={ref=ref,x=x,y=y,half=half,progress=progress,missile=missile,locked=missile and lock.locked or progress>=1,
        big=missile and math.max(half,math.tan(lock.box)*h/(2*math.tan(camera.fov*math.pi/360))) or half*2.6,
        hp=hp,ghost=ghost.v,distance=distance,name=ref.name,arms=ref.spec.weapons and #ref.spec.weapons,scoped=s.scope}
end
local function Bracket(vg,hw,hh,k,c,alpha,rotation,x,y)
    nvgSave(vg);nvgGlobalAlpha(vg,alpha);nvgTranslate(vg,x,y);nvgRotate(vg,rotation)
    local thin={c[1],c[2],c[3],c[1]==242 and 160 or 176}
    local perimeter=4*(hw+hh)
    local function Point(t)
        if t<2*hw then return -hw+t,-hh end
        if t<2*hw+2*hh then return hw,-hh+t-2*hw end
        if t<4*hw+2*hh then return hw-(t-2*hw-2*hh),hh end
        return -hw,hh-(t-4*hw-2*hh)
    end
    nvgSave(vg);nvgGlobalAlpha(vg,alpha*.45)
    nvgBeginPath(vg)
    for t=0,perimeter,7*k do
        local tail=math.min(perimeter,t+2*k);local a,b=Point(t);local ax,by=Point(tail)
        nvgMoveTo(vg,a,b)
        for _,corner in ipairs({2*hw,2*hw+2*hh,4*hw+2*hh})do
            if corner>t and corner<tail then local px,py=Point(corner);nvgLineTo(vg,px,py)end
        end
        nvgLineTo(vg,ax,by)
    end
    nvgStrokeWidth(vg,.9*k);nvgStrokeColor(vg,D.Color(thin));nvgStroke(vg)
    nvgRestore(vg)
    local len=math.max(8*k,math.min(hw,hh)*.42);local cut=math.min(7*k,len*.45)
    for _,sx in ipairs({-1,1}) do for _,sy in ipairs({-1,1}) do
        nvgBeginPath(vg);nvgMoveTo(vg,sx*hw,sy*(hh-len));nvgLineTo(vg,sx*hw,sy*(hh-cut));nvgLineTo(vg,sx*(hw-cut),sy*hh);nvgLineTo(vg,sx*(hw-len),sy*hh)
        nvgStrokeWidth(vg,2.6*k);nvgStrokeColor(vg,D.Color(c));nvgStroke(vg)
        D.Line(vg,sx*(hw+5*k),sy*(hh+5*k),sx*(hw+10*k),sy*(hh+10*k),thin,1.3*k)
    end end
    D.Line(vg,0,hh+3*k,0,hh+11*k,thin,1.3*k)
    D.Line(vg,-hw-3*k,0,-hw-11*k,0,thin,1.3*k)
    D.Line(vg,hw+3*k,0,hw+11*k,0,thin,1.3*k)
    R.Poly(vg,{-6*k,-hh-12*k,6*k,-hh-12*k,0,-hh-3*k},c)
    nvgRestore(vg)
end
function M.Render(vg,o,l)
    local f=o.focus;if not f then return end
    R.SetTextScale(l.k)
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
    if e>.5 then M.Plate(vg,o,l,f,e) end
    if f.locked and (f.missile or f.scoped) then
        local hh=f.half*.8
        R.Poly(vg,{f.x-30*k,f.y-hh-34*k,f.x+34*k,f.y-hh-34*k,f.x+28*k,f.y-hh-18*k,f.x-36*k,f.y-hh-18*k},{255,59,48,255})
        D.Text(vg,f.missile and 'LOCK' or '锁定',f.x-k,f.y-hh-21*k,13*k,{22,4,4,255},'vox-hud',NVG_ALIGN_CENTER,3*k,true)
    end
end
function M.Plate(vg,o,l,f,e)
    local k=l.k;local x=f.x+f.half+22*k;local y=f.y-f.half*.8-16*k;local endX=x+168*k
    local low=f.hp<.3;local blink=low and math.floor(o.session.world.time/.22)%2==1
    local red={255,59,48,255};local warning={255,210,74,255};local label={255,138,128,255};local sub={255,138,128,176}
    nvgSave(vg);nvgGlobalAlpha(vg,(e-.5)*2)
    D.Line(vg,x-14*k,y+14*k,x,y,red,1.6*k);D.Line(vg,x,y,endX,y,red,1.6*k)
    D.Line(vg,endX-26*k,y-3*k,endX,y-3*k,red,3*k)
    R.Text(vg,f.name or '',x+2*k,y-7*k,15*k,label)
    for i=0,9 do
        local bx=x+4*k+i*15.5*k;local color=(i+.5)/10<=f.hp and (blink and warning or red) or (i+.5)/10<=f.ghost and {255,255,255,255} or {255,255,255,46}
        R.Poly(vg,{bx+2.5*k,y+5*k,bx+14.5*k,y+5*k,bx+12*k,y+11*k,bx,y+11*k},color)
    end
    local text=math.floor(f.distance+.5)..'';local tx=x+2*k
    R.Text(vg,text,tx,y+38*k,27*k,label)
    R.Text(vg,' M',tx+R.Width(vg,text,27*k),y+38*k,12*k,label)
    R.Text(vg,'HULL '..math.ceil(f.hp*100)..'%',endX,y+33*k,13*k,low and warning or sub,NVG_ALIGN_RIGHT,nil,false,2)
    if f.arms~=nil then R.Text(vg,'武装 ×'..f.arms,endX,y-7*k,12*k,f.arms<=1 and warning or sub,NVG_ALIGN_RIGHT,nil,false,2) end
    nvgRestore(vg)
end
return M

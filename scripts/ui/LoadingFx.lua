-- Source loadingFx.js geometry; bounded arrays seeded once per opening.
local M={};M.__index=M
local D=require 'ui.SourceDraw'
local TAU=math.pi*2
local function Rand(a,b) return a+math.random()*(b-a) end
function M.New() return setmetatable({shards={},dust={},cells={}},M) end
function M:Seed(w,h)
    self.w=w;self.h=h;local scale=h/1080;self.shards={};self.dust={};self.cells={}
    for _=1,28 do
        local left=math.random()<.7;local pts={}
        for i=0,2 do pts[#pts+1]={i*TAU/3+Rand(-.5,.5),Rand(.55,1)} end
        self.shards[#self.shards+1]={x=Rand(0,left and w*.5 or w),y=Rand(left and 0 or h*.62,h),vx=Rand(-6,10)*scale,vy=Rand(-8,3)*scale,r=Rand(14,90)*scale,a=Rand(0,TAU),va=Rand(-.25,.25),pts=pts,fill=math.random()<.3,k=Rand(.5,1)}
    end
    for _=1,70 do self.dust[#self.dust+1]={x=Rand(0,w),y=Rand(0,h),v=Rand(6,22)*scale,r=Rand(.6,1.8)*scale,p=Rand(0,TAU)} end
    local radius=34*scale;local width=math.sqrt(3)*radius
    for row=0,math.ceil(h*.55/(radius*1.5)) do for col=0,math.ceil(w*.42/width) do
        local x=col*width+(row%2)*width/2+20*scale;local y=row*radius*1.5+30*scale
        local fade=math.max(0,1-math.sqrt((x/(w*.42))^2+(y/(h*.55))^2))
        if fade>.02 then self.cells[#self.cells+1]={x=x,y=y,fade=fade,r=radius,phase=Rand(0,7)} end
    end end
end
local function Mask(x,y,w,h) return math.max(0,math.min(1,math.max(1-x/(w*.5),(y-h*.58)/(h*.32)))) end
local function Color(c,a) return nvgRGBA(c[1],c[2],c[3],255*a) end
local function Stroke(vg,c,a,width) nvgStrokeColor(vg,Color(c,a));nvgStrokeWidth(vg,width);nvgStroke(vg) end
function M:Draw(vg,w,h,t,c)
    if w~=self.w or h~=self.h then self:Seed(w,h) end
    for _,cell in ipairs(self.cells) do
        nvgBeginPath(vg)
        for i=0,5 do local a=i*TAU/6+TAU/12;local x,y=cell.x+math.cos(a)*cell.r,cell.y+math.sin(a)*cell.r;if i==0 then nvgMoveTo(vg,x,y) else nvgLineTo(vg,x,y) end end
        nvgClosePath(vg);Stroke(vg,c,.07*cell.fade,1)
    end
    for _,arc in ipairs({{.30,.22,.12,1.6,2},{.36,-.12,.08,3.4,1.2},{.43,.06,.06,.9,1}}) do
        local radius=h*arc[1];local a0=t*arc[2];local cx,cy=w*.13,h*.74
        for i=0,2 do nvgBeginPath(vg);nvgArc(vg,cx,cy,radius,a0+i*TAU/3,a0+i*TAU/3+arc[4]*.6,NVG_CW);Stroke(vg,c,arc[3],arc[5]*1.5) end
        nvgBeginPath(vg)
        for i=0,71 do local a=a0*.5+i*TAU/72;local length=i%6==0 and 12 or 5;nvgMoveTo(vg,cx+math.cos(a)*(radius+6),cy+math.sin(a)*(radius+6));nvgLineTo(vg,cx+math.cos(a)*(radius+6+length),cy+math.sin(a)*(radius+6+length)) end
        Stroke(vg,{255,255,255},arc[3]*.5,1)
    end
    for _,p in ipairs(self.shards) do
        local x=(p.x+p.vx*t+p.r*2)%(w+p.r*4)-p.r*2;local y=(p.y+p.vy*t+p.r*2)%(h+p.r*4)-p.r*2
        local mask=Mask(x,y,w,h)*p.k*math.min(1,t/1.2)
        if mask>=.02 then
            nvgBeginPath(vg)
            for i,pt in ipairs(p.pts) do local a=pt[1]+p.a+p.va*t;local px,py=x+math.cos(a)*p.r*pt[2],y+math.sin(a)*p.r*pt[2];if i==1 then nvgMoveTo(vg,px,py) else nvgLineTo(vg,px,py) end end
            nvgClosePath(vg);if p.fill then nvgFillColor(vg,Color(c,.06*mask));nvgFill(vg) end;Stroke(vg,c,.32*mask,1.2)
        end
    end
    for _,d in ipairs(self.dust) do
        local y=(d.y-d.v*t)%(h+8);local x=d.x+math.sin(t*.6+d.p)*12
        local a=(.12+.25*Mask(x,y,w,h))*(.6+.4*math.sin(t*2+d.p))
        nvgBeginPath(vg);nvgCircle(vg,x,y,d.r);nvgFillColor(vg,Color({255,240,220},a));nvgFill(vg)
    end
    nvgSave(vg);nvgScissor(vg,0,h*.83,w,h*.06);nvgBeginPath(vg)
    for x=-h*.06+(t*60)%46,w,46 do nvgMoveTo(vg,x,h*.89);nvgLineTo(vg,x+h*.06,h*.83) end
    Stroke(vg,c,.04,1);nvgRestore(vg)
end
return M

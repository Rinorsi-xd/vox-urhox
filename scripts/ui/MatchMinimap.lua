-- Frozen matchHud.minimap, fixed 472px canvas displayed at 236 CSS pixels.
local D=require 'ui.SourceDraw'
local M={};M.__index=M
local colors={blue={46,168,255,255},red={255,74,61,255},none={216,221,227,255}}
local C,PAD,R=236,24,170
local scale=(C-PAD)/R
function M.Project(pos,at) return C-(pos[1]-at[1])*scale,C-(pos[3]-at[3])*scale end
function M.Clamp(x,y,margin,square)
    local dx,dy=x-C,y-C;local limit=C-PAD-margin
    local ratio=(square and math.max(math.abs(dx),math.abs(dy)) or math.sqrt(dx*dx+dy*dy))/limit
    if ratio<=1 then return x,y,false end
    return C+dx/ratio,C+dy/ratio,true
end
function M.Visible(unit,units)
    if not unit.alive or unit.me then return false end
    if unit.team~='red' then return true end
    for _,ally in ipairs(units) do if ally.alive and ally.team=='blue' and (ally.pos[1]-unit.pos[1])^2+(ally.pos[3]-unit.pos[3])^2<120^2 then return true end end
    return false
end
function M.New(session)
    local self=setmetatable({session=session,images={},nextUpdate=0,frames=0},M)
    local preference=session.app.store:Read('minimap-style',function(v)return type(v)=='table' and (v.style=='square' or v.style=='round')end)
    self.style=preference and preference.style or 'round'
    self.texture=Texture2D:new();self.texture:SetNumLevels(1);self.texture:SetSRGB(false)
    assert(self.texture:SetSize(472,472,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Cannot allocate minimap canvas')
    self.texture:SetFilterMode(FILTER_BILINEAR)
    self.vg=assert(nvgCreate(1));nvgSetRenderTarget(self.vg,self.texture);nvgSetColorSpace(self.vg,NVG_COLOR_GAMMA)
    self.masks={}
    for _,style in ipairs({'round','square'}) do
        self.masks[style]=nvgCreateImage(self.vg,'UI/Match/minimap-mask-'..style..'.png',0)
        assert(self.masks[style]>0,'Minimap clipping mask unavailable')
    end
    assert(nvgCreateFont(self.vg,'vox-hud','Fonts/ChakraPetch-Bold.ttf')>=0,'Minimap font unavailable')
    SubscribeToEvent(self.vg,'NanoVGRender',function()
        if not self.requested or self.disposed then return end
        self.requested=false
        nvgBeginFrame(self.vg,472,472,1)
        nvgSave(self.vg);nvgGlobalCompositeOperation(self.vg,NVG_COPY)
        D.Rect(self.vg,0,0,472,472,{0,0,0,0});nvgRestore(self.vg)
        self:Paint(self.vg);nvgEndFrame(self.vg)
        self.frames=self.frames+1
    end)
    if session.mapBase then
        self:SetBase(session.mapBase.texture,session.mapBase.half);session.mapBase=nil
    elseif session.mapCapture then
        self.capture=session.mapCapture;session.mapCapture=nil
    elseif session.scene then self.capture=require('render.MatchMapShot').New(session.scene) end
    return self
end
function M:SetBase(texture,half)
    if self.base then
        nvgDeleteVideo(self.vg,self.base.image);self.base.texture:Dispose()
    end
    local image=nvgCreateVideo(self.vg,texture);assert(image>0,'Minimap base image unavailable')
    self.base={image=image,half=half,texture=texture};self.requested=true
end
function M:Update(now)
    if self.capture then
        self.capture:Update()
        if self.capture.ready then
            local texture,half=self.capture:Take();self.capture:Dispose();self.capture=nil
            self:SetBase(texture,half)
        end
    end
    now=now or Time:GetSystemTime()/1000
    if now<self.nextUpdate then return end
    self.nextUpdate=now+.033;self.now=now
    local b=self.session.battle;local units={};local me
    for _,entry in ipairs(b.entries) do local u=entry.unit
        local yaw=u.vehicle and u.vehicle:Yaw() or 0
        local unit={pos=u:Position(),team=u.team,alive=u.alive,me=u==b.player,yaw=yaw}
        units[#units+1]=unit;if unit.me then me=unit end
    end
    local at=me and me.alive and me.pos or self.at or me and me.pos or {0,0,0}
    self.at={at[1],at[2],at[3]};self.units=units;self.me=me
    self.points={}
    for _,p in ipairs(b.objectives.points or {}) do
        for _,st in ipairs(b.rules.points or {}) do if st.id==p.id then self.points[#self.points+1]={id=p.id,pos=p.pos,radius=p.radius,owner=st.owner,v=st.v,contested=st.contested};break end end
    end
    self.path=b.objectives.path;self.cart=b.mode=='escort' and b.objectives:At(b.rules.s).pos or nil
    self.view=-math.rad(self.session.yaw or 0);self.requested=true
end
local function Shape(vg,square)
    if square then D.Path(vg,{24,24,422,24,448,50,448,448,50,448,24,422})
    else nvgBeginPath(vg);nvgCircle(vg,C,C,C-PAD) end
end
local function Circle(vg,x,y,r,color)
    nvgBeginPath(vg);nvgCircle(vg,x,y,r);nvgFillColor(vg,D.Color(color));nvgFill(vg)
end
local function Stroke(vg,color,width) nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,width);nvgStroke(vg) end
local function Arrow(vg,x,y,yaw,size,color)
    nvgSave(vg);nvgTranslate(vg,x,y);nvgRotate(vg,-yaw)
    D.Path(vg,{0,-1.25*size,.9*size,.85*size,0,.35*size,-.9*size,.85*size})
    Stroke(vg,{11,13,17,204},3)
    -- The offscreen NanoVG backend has no stencil attachment. Two convex
    -- triangles retain the exact source concave arrow without its stencil fill.
    for _,side in ipairs({-1,1}) do
        D.Path(vg,{0,-1.25*size,side*.9*size,.85*size,0,.35*size})
        nvgFillColor(vg,D.Color(color));nvgFill(vg)
    end
    nvgRestore(vg)
end
local function ClipOutside(vg,image)
    -- Complete rectangle applies alpha outside the path too; no stencil needed.
    nvgSave(vg);nvgGlobalCompositeOperation(vg,NVG_DESTINATION_IN)
    nvgBeginPath(vg);nvgRect(vg,0,0,472,472)
    nvgFillPaint(vg,nvgImagePattern(vg,0,0,472,472,0,image,1));nvgFill(vg)
    nvgRestore(vg)
end
function M:Paint(vg)
    if not self.at then return end
    local square=self.style=='square';local at=self.at
    local function P(pos) return M.Project(pos,at) end
    if self.base then
        local x,y=P({self.base.half,0,self.base.half});local width=2*self.base.half*scale
        nvgBeginPath(vg);nvgRect(vg,x,y,width,width)
        nvgFillPaint(vg,nvgImagePattern(vg,x,y,width,width,0,self.base.image,.92));nvgFill(vg)
    else D.Rect(vg,0,0,472,472,{26,34,48,204}) end
    nvgBeginPath(vg);nvgRect(vg,0,0,472,472)
    nvgFillPaint(vg,nvgRadialGradient(vg,C,C,C*(square and .7 or .55),C*(square and 1.42 or 1)-PAD,nvgRGBA(11,13,17,0),nvgRGBA(11,13,17,170)));nvgFill(vg)
    for _,team in ipairs({'blue','red'}) do
        local x,y=P({0,0,team=='blue' and -246 or 246});local c=colors[team]
        nvgBeginPath(vg);nvgEllipse(vg,x,y,84*scale,56*scale);nvgFillColor(vg,nvgRGBA(c[1],c[2],c[3],28));nvgFill(vg);Stroke(vg,{c[1],c[2],c[3],136},2)
    end
    local path=self.path
    if path and #path>0 then
        local ci=1;local best=math.huge
        if self.cart then for i,p in ipairs(path) do local d=(p[1]-self.cart[1])^2+(p[3]-self.cart[3])^2;if d<best then best=d;ci=i end end end
        local function Route(a,b,c,width,dashed)
            nvgBeginPath(vg)
            local walked=0
            for i=a,b-1 do
                local ax,ay=P(path[i]);local bx,by=P(path[i+1]);local length=math.sqrt((bx-ax)^2+(by-ay)^2)
                if not dashed then nvgMoveTo(vg,ax,ay);nvgLineTo(vg,bx,by)
                elseif length>0 then
                    local d=0
                    while d<length do
                        local phase=(walked+d)%17;local step=math.min(length-d,phase<9 and 9-phase or 17-phase)
                        if phase<9 then nvgMoveTo(vg,ax+(bx-ax)*d/length,ay+(by-ay)*d/length);nvgLineTo(vg,ax+(bx-ax)*(d+step)/length,ay+(by-ay)*(d+step)/length) end
                        d=d+math.max(.0001,step)
                    end
                end
                walked=walked+length
            end
            nvgLineCap(vg,NVG_ROUND);nvgLineJoin(vg,NVG_ROUND);Stroke(vg,c,width)
        end
        Route(1,#path,{11,13,17,170},9);Route(1,ci,{255,208,96,255},5);Route(ci,#path,{255,208,96,170},3,true)
        local x,y=P(path[#path]);D.Path(vg,{x,y-9,x+9,y,x,y+9,x-9,y});nvgFillColor(vg,nvgRGBA(255,208,96,255));nvgFill(vg)
    end
    if self.me and self.me.alive and self.view then
        local a=-math.pi/2-self.view
        nvgBeginPath(vg);nvgMoveTo(vg,C,C);nvgArc(vg,C,C,100,a-.6,a+.6,NVG_CW);nvgClosePath(vg)
        nvgFillPaint(vg,nvgRadialGradient(vg,C,C,6,100,nvgRGBA(255,255,255,80),nvgRGBA(255,255,255,0)));nvgFill(vg)
    end
    for _,u in ipairs(self.units) do if M.Visible(u,self.units) then local x,y=P(u.pos);Arrow(vg,x,y,u.yaw,10,colors[u.team]) end end
    ClipOutside(vg,self.masks[self.style])
    for _,p in ipairs(self.points) do
        local px,py=P(p.pos);local x,y,out=M.Clamp(px,py,20,square)
        local radius=out and 15 or math.max(17,p.radius*scale);local c=colors[p.owner or 'none']
        Circle(vg,x,y,radius,p.owner and {c[1],c[2],c[3],204} or {11,13,17,176});Stroke(vg,{255,255,255,64},2)
        if p.v~=0 and math.abs(p.v)<1 then nvgBeginPath(vg);nvgArc(vg,x,y,radius+1,-math.pi/2,-math.pi/2+math.pi*2*math.abs(p.v),NVG_CW);Stroke(vg,p.v>0 and colors.blue or colors.red,4) end
        if p.contested and math.floor(self.now*4)%2==1 then nvgBeginPath(vg);nvgCircle(vg,x,y,radius+5);Stroke(vg,{255,106,19,255},3) end
        D.Text(vg,p.id,x,y-(out and 9 or 11)+1,out and 18 or 22,D.white,'vox-hud',NVG_ALIGN_CENTER)
    end
    if self.cart then local px,py=P(self.cart);local x,y=M.Clamp(px,py,16,square)
        nvgSave(vg);nvgTranslate(vg,x,y);nvgRotate(vg,math.pi/4);D.Rect(vg,-10,-10,20,20,{255,208,96,255});Stroke(vg,{11,13,17,255},3);nvgRestore(vg)
    end
    if self.me and self.me.alive then Arrow(vg,C,C,self.me.yaw,13,D.white) end
    Shape(vg,square);Stroke(vg,{255,255,255,56},2)
    if square then
        D.Line(vg,24,54,24,24,{255,255,255,128},3.5);D.Line(vg,24,24,54,24,{255,255,255,128},3.5)
        D.Line(vg,448,418,448,448,{255,255,255,128},3.5);D.Line(vg,448,448,418,448,{255,255,255,128},3.5)
    else
        for i=0,23 do local a=i/24*math.pi*2;local l=i%6==0 and 12 or 6;local r=C-PAD
            D.Line(vg,C+math.sin(a)*r,C-math.cos(a)*r,C+math.sin(a)*(r-l),C-math.cos(a)*(r-l),{255,255,255,128},i%6==0 and 2.5 or 1.5)
        end
    end
    D.Path(vg,{C,PAD+9,C+7,PAD,C-7,PAD});nvgFillColor(vg,nvgRGBA(255,106,19,255));nvgFill(vg)
    D.Text(vg,'N',C,PAD-20.5,19,D.white,'vox-hud',NVG_ALIGN_CENTER)
end
function M:Draw(vg)
    if self.frames==0 then return end
    local image=self.images[vg];if not image then image=nvgCreateVideo(vg,self.texture);self.images[vg]=image end
    nvgSave(vg)
    nvgBeginPath(vg);nvgRect(vg,14,52,236,236);nvgFillPaint(vg,nvgImagePattern(vg,14,52,236,236,0,image,1));nvgFill(vg);nvgRestore(vg)
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.capture then self.capture:Dispose();self.capture=nil end
    UnsubscribeFromEvent(self.vg,'NanoVGRender')
    for vg,image in pairs(self.images) do nvgDeleteVideo(vg,image) end;self.images={}
    if self.base then nvgDeleteVideo(self.vg,self.base.image);self.base.texture:Dispose();self.base=nil end
    for _,image in pairs(self.masks)do nvgDeleteImage(self.vg,image)end;self.masks={}
    nvgDelete(self.vg);self.vg=nil
    require('render.RenderTargetLifetime').Retire(self.texture);self.texture=nil
end
return M

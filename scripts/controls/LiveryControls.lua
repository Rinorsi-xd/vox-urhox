local TouchPreferences=require("controls.TouchPreferences")
local LiveryData=require("construction.LiveryData")
local Wheel=require("controls.Wheel")

local UI=require 'urhox-libs/UI'
local P=require 'render.LiveryProjection'
local Models=require 'render.LiveryModel'
local Coord=require 'core.Coord'
local M={};M.__index=M
function M.New(s) local self=setmetatable({},M);self:init(s);return self end
function M:init(s)
    self.session=s;self.app=s.app;self.drag=false;self.pointer=false
    self.touches={};self.touchOrder={};self.touchX=0;self.touchY=0;self.touchMode=false
end
function M:CssPoint(x,y)
    local w=UI.GetViewportSize();local k=(graphics:GetWidth()/graphics:GetDPR())/w
    return x*k,y*k
end
function M:CameraMove(dx,dy,pan)
    local c=self.app.camera
    if pan then
        local rot=c.node.rotation;c.target=c.target-rot*Vector3.RIGHT*(dx*c.dist*.0014)+rot*Vector3.UP*(dy*c.dist*.0014)
        c.target=Vector3(c.target.x,math.max(0,math.min(c.panMaxY,c.target.y)),c.target.z)
    else c.yaw=c.yaw+math.deg(dx*.005);c.pitch=math.max(90-math.deg(1.62),math.min(90-math.deg(.12),c.pitch+math.deg(dy*.004))) end
end
function M:TouchDown(e)
    if self.touches[e.pointerId] then return end
    local x,y=self:CssPoint(e.x,e.y)
    self.touches[e.pointerId]={x=x,y=y};self.touchOrder[#self.touchOrder+1]=e.pointerId
end
function M:TouchMove(e)
    local p=self.touches[e.pointerId];if not p then return end
    local x,y=self:CssPoint(e.x,e.y);local dx,dy=x-p.x,y-p.y;local other=false
    for _,id in ipairs(self.touchOrder) do if id~=e.pointerId then other=self.touches[id];if other then break end end end
    if other then
        local before=math.sqrt((p.x-other.x)^2+(p.y-other.y)^2);local after=math.sqrt((x-other.x)^2+(y-other.y)^2)
        if before>8 and after>8 then
            local c=self.app.camera;c.dist=math.max(c.minDist,math.min(c.maxDist,c.dist*before/after))
        end
        self.touchX=self.touchX+dx/2;self.touchY=self.touchY+dy/2;self.touchMode='pan'
    else
        local prefs=TouchPreferences.Get(self.app)
        local short=math.min(graphics:GetWidth(),graphics:GetHeight())/graphics:GetDPR()
        local gain=math.min(3,600/math.max(240,short))*prefs.sens
        self.touchX=self.touchX+dx*gain;self.touchY=self.touchY+dy*gain;self.touchMode='orbit'
    end
    self.app.camera.flight=false;self.app.camera.autoSpin=false;p.x=x;p.y=y
end
function M:Ray(x,y)
    local w,h=UI.GetViewportSize();return self.app.camera.camera:GetScreenRay(x/w,y/h)
end
function M:Hit(x,y)
    local app=self.app;local root=app.car.root;self.blocked=false
    local hits=app.scene:GetComponent('Octree'):Raycast(self:Ray(x,y),RAY_TRIANGLE,160,DRAWABLE_GEOMETRY)
    for _,h in ipairs(hits) do for _,v in pairs(app.car.visuals) do for _,model in ipairs(v.models) do if h.drawable==model then
        if not Models.Fixed(v.part) then self.blocked=true;return nil end
        local p=root:WorldToLocal(h.position);local n=root.worldRotation:Inverse()*h.normal
        return {p={-p.x,p.y,p.z},n={-n.x,n.y,n.z}}
    end end end end
end
function M:Surface(x,y)
    local c=self:Hit(x,y);if not c then return nil end;local n={table.unpack(c.n)}
    local w=UI.GetViewportSize();local k=w/(graphics:GetWidth()/graphics:GetDPR())
    for _,delta in ipairs({{-7,0},{7,0},{0,-7},{0,7}}) do
        local h=self:Hit(x+delta[1]*k,y+delta[2]*k)
        if h and P.Dot(h.n,c.n)>.3 and P.Dot(P.Sub(h.p,c.p),P.Sub(h.p,c.p))<2.25 then for i=1,3 do n[i]=n[i]+h.n[i] end end
    end;n=P.Normalize(n);local axis=1;for i=2,3 do if math.abs(n[i])>math.abs(n[axis]) then axis=i end end
    if math.abs(n[axis])>.9 then local sign=n[axis]>0 and 1 or -1;n={0,0,0};n[axis]=sign end
    for i=1,3 do c.p[i]=math.floor(c.p[i]*1000+.5)/1000;n[i]=math.floor(n[i]*1000+.5)/1000 end;c.n=n;return c
end
function M:DecalAt(x,y)
    local hits=self.app.scene:GetComponent('Octree'):Raycast(self:Ray(x,y),RAY_TRIANGLE,160,DRAWABLE_GEOMETRY)
    for _,h in ipairs(hits) do
        for i,m in pairs(self.app.car.livery.meshes) do if h.drawable==m.geometry then return i end end
        for _,v in pairs(self.app.car.visuals) do for _,model in ipairs(v.models) do if h.drawable==model then return 0 end end end
    end;return 0
end
function M:Screen(p)
    local world=self.app.car.root:LocalToWorld(Coord.Vec(table.unpack(p)));local camera=self.app.camera
    if (camera.node.worldRotation:Inverse()*(world-camera.node.worldPosition)).z<=0 then return nil end
    local v=camera.camera:WorldToScreenPoint(world);local w,h=UI.GetViewportSize();return {x=v.x*w,y=v.y*h}
end
function M:Corners(d)
    local st=LiveryData.Catalog().byId[d.s];if not st then return nil end
    local f=P.Frame(d);local w,h=P.Size(d,st);local out={}
    for _,sign in ipairs({{-1,-1},{1,-1},{1,1},{-1,1}}) do
        local q=self:Screen(P.ToWorld(f,{sign[1]*w/2,sign[2]*h/2,.05}));if not q then return nil end;out[#out+1]=q
    end;return out
end
function M:Gizmo()
    local d=self.session:List()[self.session.sel];local box=d and self:Corners(d);if not box then return nil end
    local tx,ty=(box[3].x+box[4].x)/2,(box[3].y+box[4].y)/2;local cx,cy=(box[1].x+box[3].x)/2,(box[1].y+box[3].y)/2
    local len=math.sqrt((tx-cx)^2+(ty-cy)^2);if len<1e-6 then len=1 end
    local w=UI.GetViewportSize();local k=w/(graphics:GetWidth()/graphics:GetDPR())
    return {box=box,tx=tx,ty=ty,x=tx+(tx-cx)/len*26*k,y=ty+(ty-cy)/len*26*k,k=k}
end
function M:Start(kind,x,y,id)
    local d=self.session:List()[self.session.sel];local c=d and self:Screen(d.p)
    if not c then return end
    self.touchX=0;self.touchY=0;self.touchMode=false
    self.drag={kind=kind,id=id,dx=c.x-x,dy=c.y-y,cx=c.x,cy=c.y,w=d.w,r=d.r,d=math.sqrt((x-c.x)^2+(y-c.y)^2),a=math.atan(c.y-y,x-c.x)}
end
function M:Down(e)
    if self.drag then return end
    self.pointer={id=e.pointerId,x=e.x,y=e.y}
    local primary=e.IsPrimaryAction and e:IsPrimaryAction() or e.button==MOUSEB_LEFT or e.pointerType=='touch'
    local x,y=e.x,e.y;local session=self.session
    if primary and not input:GetKeyDown(KEY_SPACE) then
        local g=self:Gizmo()
        if g then
            for _,p in ipairs(g.box) do if math.abs(x-p.x)<8*g.k and math.abs(y-p.y)<8*g.k then self:Start('scale',x,y,e.pointerId);return end end
            if (x-g.x)^2+(y-g.y)^2<(10*g.k)^2 then self:Start('rotate',x,y,e.pointerId);return end
        end
        local i=not session.pick and self:DecalAt(x,y) or 0
        if i>0 then session:Select(i);self:Start('move',x,y,e.pointerId);return end
        if session.pick then local h=self:Surface(x,y);if h then session:Place(h);self:Start('move',x,y,e.pointerId);return end
        elseif session.sel>0 then session:Select(0) end
    end
    local camera=self.app.camera;camera.flight=false;camera.autoSpin=false
    if e.pointerType=='touch' then self:TouchDown(e);return end
    self.drag={kind=(e.button==MOUSEB_MIDDLE or input:GetKeyDown(KEY_SHIFT)) and 'pan' or 'orbit',x=x,y=y,id=e.pointerId}
end
function M:Move(e)
    local x,y=e.x,e.y;self.pointer={id=e.pointerId,x=x,y=y};local g=self.drag
    if g and g.id~=e.pointerId then
        local p=self.touches[e.pointerId];if p then p.x,p.y=self:CssPoint(x,y) end
        return
    end
    if not g and self.touches[e.pointerId] then self:TouchMove(e);return end
    if g then
        if g.kind=='move' then local hit=self:Surface(x+g.dx,y+g.dy);if hit then self.session:Edit(function(d) d.p=hit.p;d.n=hit.n end);g.moved=true end
        elseif g.kind=='scale' then self.session:Edit(function(d) d.w=math.floor(math.max(1,math.min(30,g.w*math.sqrt((x-g.cx)^2+(y-g.cy)^2)/math.max(4,g.d)))*100+.5)/100 end);g.moved=true
        elseif g.kind=='rotate' then
            local r=g.r+math.atan(g.cy-y,x-g.cx)-g.a;local snapped=math.floor(r/(math.pi/12)+.5)*math.pi/12
            if not input:GetKeyDown(KEY_SHIFT) and math.abs(r-snapped)<.06 then r=snapped end
            self.session:Edit(function(d) d.r=r end);g.moved=true
        else
            local dx,dy=self:CssPoint(x-g.x,y-g.y);self:CameraMove(dx,dy,g.kind=='pan')
            g.x=x;g.y=y
        end
    elseif self.session.pick then
        local h=self:Surface(x,y);self.app.car.livery:SetPreview(h and self.session:NewDecal(self.session.pick,h) or nil)
    end
end
function M:Up(e)
    if self.touches[e.pointerId] then
        self.touches[e.pointerId]=nil
        for i,id in ipairs(self.touchOrder) do if id==e.pointerId then table.remove(self.touchOrder,i);break end end
        if #self.touchOrder==0 then self.touchMode=false end
    end
    if self.drag and self.drag.id==e.pointerId then if self.drag.moved then self.session:Record() end;self.drag=false end
end
function M:Cancel()
    if self.drag and self.drag.moved then self.session:Record() end
    self.drag=false;self.pointer=false;self.touches={};self.touchOrder={};self.touchMode=false;self.touchX=0;self.touchY=0
    self.app.car.livery:SetPreview(nil)
end
function M:Update(dt,blocked)
    self.session:Update(dt);local c=self.app.camera
    if blocked or not input.focus or input.minimized then self:Cancel();c:Step(dt);return end
    -- H5 accumulates CSS-pixel deltas until CameraRig.update; pinch changes
    -- distance immediately, so a frame's pan uses its final zoom distance.
    if self.touchMode and (self.touchX~=0 or self.touchY~=0) then self:CameraMove(self.touchX,self.touchY,self.touchMode=='pan') end
    self.touchX=0;self.touchY=0
    local x,y=input.mousePosition.x,input.mousePosition.y;local w,h=UI.GetViewportSize();x=x/graphics:GetWidth()*w;y=y/graphics:GetHeight()*h
    local over=x>=28 and x<=332 and y>=84 and y<=h-96 or x>=w-328 and x<=w-28 and y>=84 and y<=h-96 or y<=60 or y>=h-88
    local wheel=input.mouseMoveWheel
    if wheel~=0 and not over then
        local alt,shift=input:GetKeyDown(KEY_ALT),input:GetKeyDown(KEY_SHIFT)
        if self.session.sel>0 and (alt or shift) then
            local direction=wheel>0 and -1 or 1
            self.session:Edit(function(d) if alt then d.w=math.max(1,math.min(30,d.w*(direction>0 and .92 or 1.08))) else d.r=d.r+direction*math.pi/36 end end,'soon')
        else c.flight=false;c.autoSpin=false;c.dist=Wheel.Zoom(c.dist,wheel,c.minDist,c.maxDist) end
    end;c:Step(dt)
end
function M:Key()
    local s=self.session;local ctrl=input:GetKeyDown(KEY_CTRL) or input:GetKeyDown(KEY_GUI)
    if ctrl and input:GetKeyPress(KEY_Z) then s:Undo(input:GetKeyDown(KEY_SHIFT));return true end
    if ctrl and input:GetKeyPress(KEY_Y) then s:Undo(true);return true end
    if ctrl and input:GetKeyPress(KEY_D) then s:Duplicate();return true end
    if input:GetKeyPress(KEY_ESCAPE) then
        if self.drag then return true end;if s.pick then s:Pick(nil);return true end;if s.sel>0 then s:Select(0);return true end;return false
    end
    for _,key in ipairs({KEY_E,KEY_F,KEY_T,KEY_G,KEY_RETURN}) do if input:GetKeyPress(key) then return true end end
    if s.sel>0 then
        if input:GetKeyPress(KEY_DELETE) or input:GetKeyPress(KEY_BACKSPACE) then s:Remove();return true end
        if input:GetKeyPress(KEY_R) then s:Edit(function(d) d.r=d.r+(input:GetKeyDown(KEY_SHIFT) and -1 or 1)*math.pi/12 end,'soon');return true end
        if input:GetKeyPress(KEY_X) then s:Edit(function(d) d.f=d.f and d.f~=0 and 0 or 1 end,true);return true end
        if input:GetKeyPress(KEY_M) then s:Mirror();return true end
        if input:GetKeyPress(KEY_PAGEUP) then s:MoveLayer(1);return true end
        if input:GetKeyPress(KEY_PAGEDOWN) then s:MoveLayer(-1);return true end
        if input:GetKeyPress(KEY_LEFTBRACKET) or input:GetKeyPress(KEY_MINUS) then s:Edit(function(d) d.w=math.max(1,d.w/1.12) end,'soon');return true end
        if input:GetKeyPress(KEY_RIGHTBRACKET) or input:GetKeyPress(KEY_EQUALS) then s:Edit(function(d) d.w=math.min(30,d.w*1.12) end,'soon');return true end
    end;return false
end
return M

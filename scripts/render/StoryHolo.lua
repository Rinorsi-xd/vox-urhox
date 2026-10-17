-- Frozen three/src/ui/storyHolo.js: same terrain, models, routes and camera.
local StoryPrefetch=require("app.StoryPrefetch")
local WindowViewports=require("render.WindowViewports")

local Data=require('core.ResourceData').Read('Story/Manifest.json')
local Levels=require('core.ResourceData').Read('UI/Outgame.json').levels
local M={};M.__index=M
-- Opening: radial scan wave from the table centre, routes draw after it, camera settles.
local REVEAL_TIME,REVEAL_RADIUS,ROUTE_DELAY,ROUTE_TIME,CAMERA_TIME,LEVEL_TIME=1.5,20,.55,.9,2.1,.8
local HIDDEN,SHOWN=0,99
local function Clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function EaseOut(t) t=Clamp(t,0,1);return 1-(1-t)^3 end
function M.New(app)
    local self=setmetatable({},M);self:init(app);return self
end
function M:init(app)
    self.app=app;self.time=0;self.level=1;self.cursor=1;self.ready=false;self.disposed=false
    self.scene=Scene();self.scene:CreateComponent('Octree')
    local zone=self.scene:CreateComponent('Zone')
    zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100))
    zone.fogColor=Color(.00005,.00049,.00169);zone.fogStart=100;zone.fogEnd=200
    self.node=self.scene:CreateChild('StoryCamera');self.camera=self.node:CreateComponent('Camera')
    self.camera.fov=30;self.camera.nearClip=.1;self.camera.farClip=100
    self.camera.projectionOffset=Vector2(-.045,.06)
    self.view={az=0,azTo=0,el=.92,elTo=.92,zoom=1,zoomTo=1,sway=1,swayTo=1}
    self.focus=Vector3.ZERO;self.distance=15.5;self.materials={};self.nodes={}
    -- Batches stream in fully discarded (uReveal=0) behind the page's boot cover,
    -- so their shaders compile during loading instead of on the reveal frame.
    self.revealTime=nil;self.levelTime=nil;self.reveal=HIDDEN;self.levelMaterials={}
    for _,m in ipairs(Data.models) do if m.level then self.levelMaterials[m.material+1]=true end end
    WindowViewports.Set(1,Viewport:new(self.scene,self.camera))
    self.onDownloaded=function(ok,message)
        if self.disposed then return end
        self.downloaded=ok;self.failure=not ok and message or nil
        if not ok then app.toasts:Push(message,'bad') end
    end
    StoryPrefetch.Start(self.onDownloaded)
    self:Select(1)
end
function M:Material(index)
    if self.materials[index] then return self.materials[index] end
    local data=Data.materials[index];local kind=data.story=='Edges' and 'Solid' or data.story
    local material=Material:new()
    assert(material:SetSurfaceShader('Shaders/BLGL/Story/'..kind..'.shader'),'Story shader '..kind)
    material:SetShaderParameter('uColor',Variant(Vector3(table.unpack(data.color))))
    material:SetShaderParameter('uLen',Variant(data.len))
    material:SetShaderParameter('opacity',Variant(data.opacity))
    material:SetShaderParameter('uReveal',Variant(HIDDEN))
    if kind=='Dash' then material:SetShaderParameter('uDraw',Variant(0)) end
    material.renderOrder=kind=='Depth' and 10 or kind=='Shell' and 11 or data.story=='Edges' and 12 or 1
    self.materials[index]=material;return material
end
function M:Select(index)
    local changed=self.level~=index;self.level=index
    local h=Levels[index].holo
    self.focusTo=Vector3(-h.focus[1]*.004,0,h.focus[2]*.004)
    self.distanceTo=15.5/(1+((h.zoom or 1)-1)*.5)
    for i,node in pairs(self.nodes) do local level=Data.models[i].level;node.enabled=not level or tonumber(level)==index end
    -- After the opening, a level switch redraws only that level's routes and beacons.
    if changed and self.revealTime and self.revealTime>=REVEAL_TIME then self.levelTime=0 end
end
-- 0 while loading, 1 once the opening has settled; page labels follow it.
function M:Intro()
    if not self.revealTime then return 0 end
    return Clamp((self.revealTime-ROUTE_DELAY)/ROUTE_TIME,0,1)
end
function M:Progress()
    if not self.downloaded then return 'download',StoryPrefetch.Progress() end
    return 'build',self.cursor-1,#Data.models
end
function M:TakeOver()
    local v=self.view;if v.sway==0 and v.swayTo==0 then return end
    local off=math.sin(self.time*.18)*.28*v.sway
    v.az=v.az+off;v.azTo=v.azTo+off;v.sway=0;v.swayTo=0
end
function M:Drag(dx,dy,height)
    self:TakeOver();local v=self.view;local scale=1/math.max(600,height)
    v.azTo=v.azTo-dx*scale*3.2;v.elTo=Clamp(v.elTo+dy*scale*2,.5,1.32)
end
function M:Zoom(delta)
    self:TakeOver();self.view.zoomTo=Clamp(self.view.zoomTo*math.exp(delta*.0012),.7,1.45)
end
function M:Reset()
    local v=self.view;v.az=v.az-math.floor(v.az/(math.pi*2)+.5)*math.pi*2
    v.azTo=0;v.elTo=.92;v.zoomTo=1;v.swayTo=1
end
function M:Project(position,w,h)
    local p=self.camera:WorldToScreenPoint(Vector3(-position[1],position[2],position[3]))
    return p.x*w,p.y*h
end
function M:Stream()
    -- Queue one model at a time: without worker threads BackgroundLoadResource
    -- loads synchronously, so never request the whole manifest at once.
    local started=Time:GetSystemTime()
    while self.cursor<=#Data.models do
        local index=self.cursor;local m=Data.models[index]
        local model=cache:GetExistingResource('Model',m.model)
        if not model then
            if not self.pending then
                -- false can mean another owner already queued it; keep polling the cache.
                self.pending={at=started};cache:BackgroundLoadResource('Model',m.model,true)
                model=cache:GetExistingResource('Model',m.model)
            end
            if not model and started-self.pending.at>15000 then model=cache:GetResource('Model',m.model) end
            if not model then return end
        end
        self.pending=nil
        local node=self.scene:CreateChild('StoryBatch'..index)
        local mesh=node:CreateComponent('StaticModel')
        mesh.model=assert(model,'Story model '..m.model)
        mesh:SetMaterial(self:Material(m.material+1))
        node.enabled=not m.level or tonumber(m.level)==self.level
        self.nodes[index]=node;self.cursor=index+1
        if Time:GetSystemTime()-started>=6 then break end
    end
    if self.cursor>#Data.models then
        -- One more frame keeps the last batches drawn hidden before the cover lifts.
        if self.settle then self.ready=true;self.revealTime=0;print('[StoryHolo] Ready frozen batches='..#Data.models)
        else self.settle=true end
    end
end
function M:UpdateReveal(dt)
    if not self.revealTime then return end
    local opening=self.revealTime<REVEAL_TIME+ROUTE_DELAY+ROUTE_TIME
    if not opening and not self.levelTime and self.reveal==SHOWN then return end
    self.revealTime=self.revealTime+dt
    local t=self.revealTime
    local reveal=t>=REVEAL_TIME and SHOWN or REVEAL_RADIUS*(Clamp(t/REVEAL_TIME,0,1)^2)
    local draw=EaseOut((t-ROUTE_DELAY)/ROUTE_TIME)
    local levelReveal,levelDraw=reveal,draw
    if self.levelTime then
        self.levelTime=self.levelTime+dt;local p=self.levelTime/LEVEL_TIME
        levelReveal=p>=1 and SHOWN or REVEAL_RADIUS*.5*EaseOut(p);levelDraw=EaseOut(p)
        if p>=1 then self.levelTime=nil end
    end
    for index,material in pairs(self.materials) do
        local data=Data.materials[index];local level=self.levelMaterials[index]
        material:SetShaderParameter('uReveal',Variant(level and levelReveal or reveal))
        if data.story=='Dash' then material:SetShaderParameter('uDraw',Variant(level and levelDraw or draw)) end
    end
    self.reveal=reveal
end
function M:Update(dt)
    if self.disposed then return end
    if self.downloaded and not self.ready then self:Stream() end
    self:UpdateReveal(math.min(dt,.05))
    self.time=self.time+math.min(dt,.05)
    local k=1-math.exp(-dt*3);self.focus=self.focus+(self.focusTo-self.focus)*k
    self.distance=self.distance+(self.distanceTo-self.distance)*k
    local v=self.view;local kv=1-math.exp(-dt*10)
    for _,key in ipairs({'az','el','zoom'}) do v[key]=v[key]+(v[key..'To']-v[key])*kv end
    v.sway=v.sway+(v.swayTo-v.sway)*(1-math.exp(-dt*2))
    -- Opening camera: starts high, wide and rotated, then settles onto the frozen pose.
    local fly=1-EaseOut((self.revealTime or 0)/CAMERA_TIME)
    local az=v.az+math.sin(self.time*.18)*.28*v.sway-.75*fly;local el=Clamp(v.el+.38*fly,.5,1.45)
    local dist=self.distance*v.zoom*(1+.55*fly);local f=self.focus
    self.node.position=Vector3(f.x-math.sin(az)*math.cos(el)*dist,math.sin(el)*dist,f.z-math.cos(az)*math.cos(el)*dist)
    self.node:LookAt(Vector3(f.x,.05,f.z))
    for _,material in pairs(self.materials) do material:SetShaderParameter('uTime',Variant(self.time)) end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    -- Leaving keeps the shared download running as a prefetch; map loads cancel it.
    StoryPrefetch.Remove(self.onDownloaded);WindowViewports.Set(1,nil);self.scene:Dispose()
    for _,material in pairs(self.materials) do material:Dispose() end
    self.materials={};self.nodes={}
end
return M

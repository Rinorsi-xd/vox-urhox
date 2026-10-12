-- Frozen three/src/ui/storyHolo.js: same terrain, models, routes and camera.
local Data=require('core.ResourceData').Read('Story/Manifest.json')
local Levels=require('core.ResourceData').Read('UI/Outgame.json').levels
local M={};M.__index=M
local function Clamp(v,a,b) return math.max(a,math.min(b,v)) end
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
    self.gate=require('app.ResourceGate').New()
    local paths={}
    for _,m in ipairs(Data.models) do paths[#paths+1]=m.model end
    for _,m in ipairs(Data.materials) do
        local kind=m.story=='Edges' and 'Solid' or m.story
        paths[#paths+1]='Shaders/BLGL/Story/'..kind..'.shader'
    end
    self.gate:Start(paths,function(ok,message)
        if self.disposed then return end
        self.downloaded=ok;self.failure=not ok and message or nil
        if not ok then app.toasts:Push(message,'bad') end
    end)
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
    material.renderOrder=kind=='Depth' and 10 or kind=='Shell' and 11 or data.story=='Edges' and 12 or 1
    self.materials[index]=material;return material
end
function M:Select(index)
    self.level=index
    local h=Levels[index].holo
    self.focusTo=Vector3(-h.focus[1]*.004,0,h.focus[2]*.004)
    self.distanceTo=15.5/(1+((h.zoom or 1)-1)*.5)
    for i,node in pairs(self.nodes) do local level=Data.models[i].level;node.enabled=not level or tonumber(level)==index end
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
function M:Update(dt)
    if self.disposed then return end
    if self.downloaded and self.cursor<=#Data.models then
        -- Bound CPU uploads; the frozen scene contains only 63 merged batches.
        local index=self.cursor;local m=Data.models[index]
        local node=self.scene:CreateChild('StoryBatch'..index)
        local mesh=node:CreateComponent('StaticModel')
        mesh.model=assert(cache:GetResource('Model',m.model),'Story model '..m.model)
        mesh:SetMaterial(self:Material(m.material+1))
        node.enabled=not m.level or tonumber(m.level)==self.level
        self.nodes[index]=node;self.cursor=index+1
        if self.cursor>#Data.models then
            self.ready=true;renderer:SetViewport(1,Viewport:new(self.scene,self.camera))
            print('[StoryHolo] Ready frozen batches='..#Data.models)
        end
    end
    self.time=self.time+math.min(dt,.05)
    local k=1-math.exp(-dt*3);self.focus=self.focus+(self.focusTo-self.focus)*k
    self.distance=self.distance+(self.distanceTo-self.distance)*k
    local v=self.view;local kv=1-math.exp(-dt*10)
    for _,key in ipairs({'az','el','zoom'}) do v[key]=v[key]+(v[key..'To']-v[key])*kv end
    v.sway=v.sway+(v.swayTo-v.sway)*(1-math.exp(-dt*2))
    local az=v.az+math.sin(self.time*.18)*.28*v.sway;local dist=self.distance*v.zoom;local f=self.focus
    self.node.position=Vector3(f.x-math.sin(az)*math.cos(v.el)*dist,math.sin(v.el)*dist,f.z-math.cos(az)*math.cos(v.el)*dist)
    self.node:LookAt(Vector3(f.x,.05,f.z))
    for _,material in pairs(self.materials) do material:SetShaderParameter('uTime',Variant(self.time)) end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.gate:Cancel();renderer:SetViewport(1,nil);self.scene:Dispose()
    for _,material in pairs(self.materials) do material:Dispose() end
    self.materials={};self.nodes={}
end
return M

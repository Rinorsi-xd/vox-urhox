-- Runtime behavior for the SAME authored scene opened by UrhoXEditor.
-- No environment geometry or lights are reconstructed here.
local Data = require "scene.HangarConfig"
local Mat = require "scene.HangarMaterials"
local Config = require "Config"
local Motion = require "scene.HangarMotion"
local Atmosphere = require "scene.HangarAtmosphere"
---@class Hangar
local Hangar = {}
Hangar.__index = Hangar
for k,v in pairs(require "scene.HangarBuffers") do Hangar[k]=v end
Hangar.ROOM=Data.room
function Hangar.Bind(scene,options)
    local self=setmetatable({},Hangar)
    self:init(scene,options)
    return self
end
function Hangar:init(scene,options)
    self.scene=scene
    self.renderSize=options and options.renderSize
    self.canvasScale=options and options.canvasScale
    self.root=assert(scene:GetChild("OrbitalHangar"),"Missing OrbitalHangar scene root")
    self.layout=Data.layout
    self.time=0
    self.reflW,self.reflH=0,0
    self.materials,self.animatedMaterials=Mat.Bind(self.root)
    self.planeMats={}
    self.holos={}
    self.niches={}
    self.padMat=self:Material("BuildDeck")
    self.grid=1;self.frame=1
    self.reflMats={self.padMat}
    for _,key in ipairs({"bay","mark"}) do self.planeMats[key]=self:Material(key) end
    for _,def in ipairs(self.layout.holos) do
        local node=self:Node("Holo_"..def.id)
        self.holos[#self.holos+1]={node=node,mat=node:GetComponent("StaticModel").material,def=def,origin=node.position}
    end
    for i=1,6 do self.niches[i]=self:Node("DisplayPart"..i) end
    self.boundary=self:Node("BuildBoundary")
    self.guides=self:Node("BuildHeightGuides")
    self.guideMat=self.guides:GetComponent("CustomGeometry"):GetMaterial(0)
    Motion.Bind(self)
    self.motion=Motion
    Atmosphere.Bind(self)
    self:Welcome()
    self:SetGrid(false)
    print("[Hangar] Bound authored scene; dynamic behaviors attached to existing nodes")
end
function Hangar:Node(name)
    return assert(self.root:GetChild(name,true),"Missing hangar node: "..name)
end
function Hangar:Material(name)
    return assert(self:Node(name):GetComponent("StaticModel"),name).material
end
function Hangar:SetEnvelope(bounds)
    -- The frozen source uses one shared build volume for all tiers.
    local x0,x1=(bounds.minX-.5)*Config.CELL,(bounds.maxX+.5)*Config.CELL
    local z0,z1=(bounds.minZ-.5)*Config.CELL,(bounds.maxZ+.5)*Config.CELL
    Mat.Set(self.padMat,"uEnvMin",Vector2(x0,z0))
    Mat.Set(self.padMat,"uEnvMax",Vector2(x1,z1))
end
function Hangar:SetTier(tier)
    self.tier=tier
end
function Hangar:SetInfoSource(provider)
    if self.panels then self.panels:Dispose() end
    self.panels=require('scene.HangarPanels').New(self,provider,self.canvasScale)
end
function Hangar:SetGrid(on,frame)
    -- Boolean callers select the original homepage/editing presets.
    self.gridTarget=type(on)=="number" and on or (on and 1 or .3)
    self.frameTarget=frame or (type(on)=="number" and on or (on and 1 or .8))
    self.gridOn=self.gridTarget>.6
end
function Hangar:UpdateGrid(dt)
    local k=math.min(1,dt*5)
    self.grid=self.grid+(self.gridTarget-self.grid)*k
    self.frame=self.frame+(self.frameTarget-self.frame)*k
    Mat.Set(self.padMat,"uGrid",self.grid)
    Mat.Set(self.padMat,"uFrame",self.frame)
    Mat.Set(self.guideMat,"uOpacity",.16*self.grid)
    local visible=self.grid>.6
    self.boundary.enabled=visible;self.guides.enabled=visible
end
function Hangar:Welcome(bp)
    local bb=bp and bp:Stats().bb or {minX=-4,maxX=4,minZ=-6,maxZ=6,maxY=4}
    self.scanBox={x0=(bb.minX-0.5)*Config.CELL-0.8,x1=(bb.maxX+0.5)*Config.CELL+0.8,
        z0=(bb.minZ-0.5)*Config.CELL-1,z1=(bb.maxZ+0.5)*Config.CELL+1,h=(bb.maxY+1)*Config.CELL+1.2}
    self.greet=3.2;self.scanTime=0
end
function Hangar:Dispose()
    if self.panels then self.panels:Dispose();self.panels=nil end
    if self.reflFilter then self.reflFilter:Dispose();self.reflFilter=nil end
    if self.reflTex then require('render.RenderTargetLifetime').Retire(self.reflTex); self.reflTex=nil end
    if self.reflNode then self.reflNode:Remove(); self.reflNode=nil end
    self.materials={}
    self.animatedMaterials={}
end
function Hangar:Update(camNode,cam,dt)
    if not self.root.enabled then self.time=self.time+(dt or 1/60);return end
    if self.panels then self.panels:Update() end
    dt=dt or 1/60
    self.time=self.time+dt
    local dbg=rawget(_G,"VOX_DEBUG")
    local t=type(dbg)=="table" and dbg.time or self.time
    if type(dbg)=="table" and dbg.time then self.greet=0;self.scanTime=10 end
    Mat.Update(self.animatedMaterials,t)
    self:UpdateGrid(dt)
    self.motion.Update(self,dt,t)
    Atmosphere.Update(self,camNode,cam,t)
end
function Hangar.ClampCamera(p)
    local b=Data.layout.cameraLimit
    return Vector3(math.max(-b.x,math.min(b.x,p.x)),math.max(b.y0,math.min(b.y1,p.y)),math.max(b.z0,math.min(b.z1,p.z)))
end
return Hangar

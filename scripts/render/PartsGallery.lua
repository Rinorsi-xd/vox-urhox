-- A bounded page is built incrementally; closing it releases all instances.
---@class PartsGallery
local Gallery={}
Gallery.__index=Gallery
local VehicleView=require "render.VehicleView"
local Config=require "Config"
local Rot=require "core.Rotations"
local Defs=require "parts.Defs"
function Gallery.New(scene,page)
    local self=setmetatable({},Gallery)
    self:init(scene,page or 1)
    return self
end
function Gallery:init(scene,page)
    self.root=scene:CreateChild("Gallery")
    self.view=VehicleView.New(self.root,"GalleryParts")
    self.labels={};self.pending={};self.page=1;self.gate=require('app.ResourceGate').New()
    self:Page(page)
end
function Gallery:Page(page)
    self.gate:Cancel();self.ready=false
    self.view:Clear()
    for _,n in ipairs(self.labels) do n:Remove() end
    self.labels={};self.pending={}
    self.pages=math.ceil(#Defs.LIST/12)
    self.page=math.max(1,math.min(self.pages,page))
    local side=Rot.RotIndex({-1,0,0},{0,0,1})
    for i=(self.page-1)*12+1,math.min(#Defs.LIST,self.page*12) do
        local d=Defs.LIST[i];local index=i-(self.page-1)*12-1
        local rot=d.wheel and side or Rot.IDENTITY
        if d.hover then rot=Rot.RotIndex({0,-1,0},{0,0,1}) end
        local low=0
        for _,c in ipairs(d.cells) do low=math.min(low,Rot.ApplyRot(rot,c)[2]) end
        self.pending[#self.pending+1]={id=i,type=d.id,pos={(index%4-1.5)*9,1-low,-12-(index//4)*9},rot=rot,color=d.color}
    end
    self.gate:Start(require('parts.Dependencies').For(self.pending),function(ok,message)
        self.ready=ok;if not ok then print('[PartsGallery] '..message) end
    end)
end
function Gallery:Update()
    if not self.ready then return end
    local started=os.clock()
    local font=cache:GetResource("Font","Fonts/MiSans-Regular.ttf")
    while #self.pending>0 and os.clock()-started<0.002 do
        local part=table.remove(self.pending,1)
        self.view:AddPart(part)
        local n=self.root:CreateChild("Label")
        n.position=Vector3(-part.pos[1]*Config.CELL,0.05,(part.pos[3]+4)*Config.CELL)
        n.rotation=Quaternion(90,180,0)
        local t=n:CreateComponent("Text3D")
        t:SetFont(font,24);t.text=Defs.PARTS[part.type].name;t:SetAlignment(HA_CENTER,VA_CENTER)
        t.color=Color(1,0.85,0.35);n:SetScale(1.6);self.labels[#self.labels+1]=n
    end
end
function Gallery:Dispose()
    self.gate:Cancel();self.pending={};self.view:Dispose();self.root:Remove();self.labels={}
end
return Gallery

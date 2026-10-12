-- Isolated comparison scene using the production VehicleView and prefab.
-- Scene/camera lifetime follows scaffold-3d-scene; no gameplay or save mutation.
---@type Scene|nil
local scene=nil
---@type Camera|nil
local camera=nil
---@type VehicleView|nil
local view=nil
local mats={}
local function FlatMaterial(slot)
    if mats[slot] then return mats[slot] end
    local hex=({rubber=0x555555,paint=0xda3434,armorWhite=0xbbbbbb})[slot] or 0x9caabb
    local mat=Material:new();mat:SetTechnique(0,cache:GetResource('Technique','Techniques/NoTextureUnlit.xml'))
    mat:SetShaderParameter('MatDiffColor',Variant(Color(require('Config').HexToRGB(hex))));mats[slot]=mat;return mat
end
local function Pose(p,up,target)
    camera.node.position=Vector3(-p[1],p[2],p[3]);camera.node:LookAt(Vector3(-target[1],target[2],target[3]),Vector3(-up[1],up[2],up[3]))
end
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img),'capture native '..name)
    local crop=img:GetSubimage(IntRect(0,0,1280,800))
    V.assert(crop:SavePNG('docs/migration/evidence/wheel-size-native-'..name..'.png'),'save native '..name);crop:Dispose();img:Dispose()
end
V.atFrame(50,function()
    local UI=require 'urhox-libs/UI';UI.SetRoot(UI.Panel{width=0,height=0})
    scene=Scene();scene:CreateComponent('Octree')
    local zone=scene:CreateChild('Zone'):CreateComponent('Zone');zone.boundingBox=BoundingBox(-100,100)
    zone.fogColor=require('Config').HexLinear(0x18202b);zone.ambientColor=Color.WHITE;zone.ambientSource=AMBIENT_COLOR
    zone:SetAttribute('Bloom Enable',Variant(false));zone:SetAttribute('Auto Exposure Enable',Variant(false));zone.vignetteEnabled=false
    view=require('render.VehicleView').New(scene,'MeasuredCar');view:Rebuild(require('construction.Prefab').BuildRaceCar(require('construction.Blueprint').New()))
    for _,vis in pairs(view.visuals) do
        local layers={}
        local function Find(value)
            if type(value)~='table' then return end
            if value.layers then for _,layer in ipairs(value.layers) do layers[layer.model]=layer.slots end
            else for _,v in pairs(value) do Find(v) end end
        end
        Find(vis.data)
        for _,sm in ipairs(vis.models) do
            sm.instanceColor=Color.WHITE
            for i,slot in ipairs(layers[sm.model.name]) do sm:SetMaterial(i-1,FlatMaterial(slot)) end
        end
    end
    camera=scene:CreateChild('Camera'):CreateComponent('Camera');camera.orthographic=true;camera.orthoSize=10;camera.nearClip=.1;camera.farClip=100
    camera.autoAspectRatio=false;camera.aspectRatio=1.6
    local viewport=Viewport:new(scene,camera);viewport:SetRect(IntRect(0,0,1280,800))
    renderer:SetViewport(0,viewport);Pose({0,3,20},{0,1,0},{0,3,0})
end)
V.atFrame(60,function() Shot('front');Pose({0,20,0},{0,0,1},{0,0,0}) end)
V.atFrame(70,function() Shot('top');Pose({11,9,16},{0,1,0},{0,2.5,0}) end)
V.atFrame(80,function() Shot('angle');V.finish() end)

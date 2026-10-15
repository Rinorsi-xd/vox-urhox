-- Actual imported parts in a fixed native viewport. Capture changing GPU
-- motion and a repeated timestamp to distinguish it from camera/scene changes.
local Materials=require 'parts.Materials'
local Assets=require 'parts.PartAssets'
local View=require 'render.VehicleView'
local Rot=require 'core.Rotations'
local slots={'holoPaint','spinSteel','spinGlow','glowBlink','glowCyan','glowGreen'}
---@type Scene|nil
local scene=nil
---@type VehicleView|nil
local view=nil
local instances={}
local function Clock(t) for _,slot in ipairs(slots) do Materials.Get(slot):SetShaderParameter('animation_time',Variant(t)) end end
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img),'decor framebuffer '..name)
    local crop=img:GetSubimage(IntRect(0,0,1440,900))
    V.assert(crop:SavePNG('docs/migration/evidence/decor-motion-'..name..'.png'),'saved decor '..name)
    crop:Dispose();img:Dispose()
end
V.atFrame(60,function()
    local app=VOX_HANGAR.app;app.Update=function() end;app.PostUpdate=function() end
    require('urhox-libs/UI').SetRoot(nil)
    scene=Scene();scene:CreateComponent('Octree')
    local zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(-100,100)
    zone.fogColor=Color(.035,.045,.06);zone.fogStart=90;zone.fogEnd=100
    local lamp=scene:CreateChild('Key');lamp.rotation=Quaternion(35,-30,0)
    local light=lamp:CreateComponent('Light');light.lightType=LIGHT_DIRECTIONAL;light.brightness=1.5
    local cn=scene:CreateChild('Camera');cn.position=Vector3(0,4,-14);cn:LookAt(Vector3(0,0,0))
    local camera=cn:CreateComponent('Camera');camera.orthographic=true;camera.orthoSize=7;camera.farClip=100
    local vp=Viewport:new(scene,camera);vp:SetRect(IntRect(0,0,1440,900));renderer:SetViewport(0,vp)
    view=View.New(scene,'DecorMotion');view.root:SetScale(1)
    for i,spec in ipairs({{'holoBadge',0xff6a13},{'holoBadge',0x2ea8ff},{'radar',0x4a4e55},{'sharkFin',0x4a4e55},
                          {'holoBadgeL',0xff6a13},{'holoBadgeL',0x2ea8ff},{'radarL',0x4a4e55},{'sharkFinL',0x4a4e55}}) do
        local part={id=i,type=spec[1],pos={0,0,0},rot=Rot.IDENTITY,color=spec[2]}
        local vis=view:AddPart(part);vis.node.position=Vector3(-4.1+((i-1)%4)*2.7,i<=4 and 1.4 or -1.4,0)
        if i<=4 then vis.node:SetScale(1.8) end
        instances[i]=vis
        V.assert(#vis.models>0,spec[1]..' imported geometry renders')
        for _,layer in ipairs(vis.data.whole.layers) do
            local model=Assets.Model(layer);local bound=BoundingBox(model.boundingBox)
            for _=1,4 do Assets.Model(layer) end
            V.assert(model.boundingBox==bound,'repeated binds do not inflate '..spec[1]..' bounds')
            for _,slot in ipairs(layer.slots) do if slot=='holoPaint' or slot=='spinSteel' or slot=='spinGlow' then
                V.assert(bound.min.x==bound.min.z and bound.max.x==bound.max.z,'full Y rotation stays in bounds '..slot)
            end end
        end
    end
    V.assert(instances[1].models[2].material==instances[2].models[2].material,'paint colours share one hologram material')
    V.assert(instances[1].models[2].instanceColor~=instances[2].models[2].instanceColor,'holograms retain independent instance paint')
    V.assert(not instances[1].models[2].castShadows,'additive hologram casts no opaque shadow')
    V.assert(Materials.Get('holoPaint'):GetSurfaceShader().name=='Shaders/BLGL/VoxHoloPaint.shader','hologram uses original additive scan shader')
    V.assert(math.abs(Materials.Get('spinSteel'):GetShaderParameter('spin_speed'):GetFloat()-.9)<.00001,'source radar speed')
    Clock(0)
end)
V.atFrame(85,function() Shot('zero');Clock(.4) end)
V.atFrame(105,function() Shot('turn');Clock(1.95) end)
V.atFrame(125,function() Shot('side') end)
V.atFrame(145,function()
    Shot('repeat')
    view:RemovePart(1)
    V.assert(instances[2].models[2].model~=nil and instances[2].models[2].material~=nil,'removing one hologram preserves shared resources')
    view:Dispose();view=nil
    V.assert(scene:GetChild('DecorMotion')==nil,'decor instances and drawables released')
    Clock(-1);renderer:SetViewport(0,nil);scene:Dispose();scene=nil;V.finish()
end)

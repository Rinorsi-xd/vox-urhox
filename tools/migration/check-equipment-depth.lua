-- Isolated rendered acceptance inside the normal hidden runtime, no editor calls.
local Resources=require 'render.EquipmentResources'
---@type Scene|nil
local scene=nil
---@type Material|nil
local wall=nil
local phase='on';local kind='Thruster'
for _,a in ipairs(GetArguments()) do phase=a:match('^%-depth%-phase=(.+)$') or phase;kind=a:match('^%-volume%-kind=(.+)$') or kind end
V.atFrame(60,function()
    local app=assert(VOX_HANGAR).app;app.Update=function() end;app.PostUpdate=function() end
    require('urhox-libs/UI').SetRoot(nil)
    scene=Scene();scene:CreateComponent('Octree');Resources.Acquire()
    local zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(-100,100)
    zone.fogColor=Color.BLACK;zone.fogStart=90;zone.fogEnd=100
    local cn=scene:CreateChild('Camera');cn.position=phase=='inside' and Vector3.ZERO or Vector3(0,0,-12)
    local camera=cn:CreateComponent('Camera');camera.fov=40;camera.farClip=100
    renderer:SetViewport(0,Viewport:new(scene,camera));Resources.Clock(2)
    wall=Material:new();assert(wall:SetSurfaceShader('Shaders/BLGL/VoxPBR.shader'))
    wall:SetShaderParameter('base_color',Variant(Vector4(.18,.18,.18,1)))
    wall:SetShaderParameter('emission_color',Variant(Vector4(.18,.18,.18,1)))
    wall:SetShaderParameter('emission_strength',Variant(1.0))
    V.assert(wall:GetTechnique(0):GetPass('depth')~=nil,'opaque blocker participates in scene depth prepass')
    local function Box(name,p,scale,mat)
        local node=scene:CreateChild(name);node.position=p;node:SetScale(scale)
        local model=node:CreateComponent('StaticModel');model.model=Resources.Box();model.material=mat;return model,node
    end
    if phase=='inside' then
        local model=Box('Inside',Vector3.ZERO,Vector3(4,4,4),Resources.Material(kind))
        model.instanceCustomData=Vector4(1,.2,2,12)
    else
        for _,x in ipairs({-3,0,3}) do
            local model,node=Box('Volume',Vector3(x,0,0),Vector3(2,2,4),Resources.Material(kind))
            node.rotation=Quaternion(90,Vector3.RIGHT)
            model.instanceCustomData=Vector4(phase=='on' and 1 or 0,.2,4,12)
        end
        Box('FullOccluder',Vector3(0,0,-3),Vector3(2.6,4.4,.4),wall)
        Box('PartialOccluder',Vector3(2.4,0,-3),Vector3(.8,4.4,.4),wall)
    end
    V.assert(scene:GetNumChildren()>0,'depth acceptance scene ready')
end)
V.atFrame(145,function()
    renderer:SetViewport(0,nil);scene:Dispose();scene=nil;wall:Dispose();Resources.Release()
    V.assert(Resources.users==0,'depth acceptance resources released');V.finish()
end)

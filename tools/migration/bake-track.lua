V.atFrame(5,function()
    local A=require "scene.TrackAssets"
    local materials=A.MakeMaterials()
    for i,m in ipairs(materials) do assert(m:Save("assets/Track/material-"..i..".xml")) end
    local scene=Scene();scene:CreateComponent("Octree")
    local lightGroup=scene:CreateChild("LightGroup")
    lightGroup:LoadXML(assert(cache:GetResource("XMLFile","LightGroup/Daytime.xml")):GetRoot())
    local zone=lightGroup:GetComponent("Zone",true)
    zone.fogColor=Color(.3968,.4793,.5841);zone.depthFogStart=220;zone.depthFogEnd=620
    local sun=lightGroup:GetComponent("Light",true)
    sun.node.direction=Vector3(.45,-.78,-.38);sun.brightness=3.6;sun.color=Color(1,.815,.624)
    local root=scene:CreateChild("TrialTrack")
    for i,item in ipairs(A.data.statics) do A.Attach(root:CreateChild("Section"..i),{item}) end
    local sky=root:CreateChild("Sky");sky:SetScale(1200)
    local skyModel=sky:CreateComponent("StaticModel");skyModel.model=assert(cache:GetResource("Model","Models/Sphere.mdl"))
    local skyMat=Material:new();assert(skyMat:SetSurfaceShader("Shaders/BLGL/Track/Sky.shader"));skyMat.renderOrder=0
    assert(skyMat:Save("assets/Track/sky.xml"));skyModel.material=cache:GetResource("Material","Track/sky.xml")
    local camera=scene:CreateChild("Camera");camera.position=Vector3(0,10,-33);camera:LookAt(Vector3(0,2,0))
    camera:CreateComponent("Camera").farClip=1500
    -- Reimports are staging candidates; preserve edits in the authored scene.
    assert(scene:SaveXML(".tmp/TrialTrack.xml"))
    scene:Dispose();V.assert(true,"source trial scene authored");V.finish()
end)

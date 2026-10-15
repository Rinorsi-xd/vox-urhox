-- Pixel checks on actual materials: opaque occlusion, visible control, overlay.
local scene,camera,fx,overlay,material
local samples={}
local function Sample()
    local image=Image:new();assert(graphics:TakeScreenShot(image))
    local center=image:GetPixel(image.width//2,image.height//2)
    local control=image:GetPixel(math.floor(image.width*(.5+3/(10*camera.aspectRatio))),image.height//2)
    image:Dispose();return {center=center.r+center.g+center.b,control=control.r+control.g+control.b}
end
local function Draw(z,on)
    fx:Begin({0,0,-10},0)
    if on then
        fx:Disc({0,0,z},1,{1,.1,.05},1,{1,0,0},{0,1,0},0)
        fx:Disc({-3,0,z},1,{1,.1,.05},1,{1,0,0},{0,1,0},0)
    end
    fx:Finish()
end
V.atFrame(45,function()
    require('urhox-libs/UI').SetRoot(nil)
    scene=Scene();scene:CreateComponent('Octree')
    local zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(-100,100);zone.fogColor=Color(0,0,0)
    zone:SetAttribute('Bloom Enable',Variant(false));zone:SetAttribute('Auto Exposure Enable',Variant(false));zone.vignetteEnabled=false
    camera=scene:CreateChild('Camera'):CreateComponent('Camera');camera.node.position=Vector3(0,0,-10);camera.orthographic=true;camera.orthoSize=10
    local node=scene:CreateChild('Wall');node.scale=Vector3(2,2,1)
    local box=node:CreateComponent('StaticModel');box.model=cache:GetResource('Model','Models/Box.mdl')
    material=Material:new();material:SetTechnique(0,cache:GetResource('Technique','Techniques/NoTextureUnlit.xml'));material:SetShaderParameter('MatDiffColor',Variant(Color(.08,.08,.08)));box.material=material
    fx=require('render.EffectBatch').New(scene,'Glow',4)
    for _,name in ipairs({'base','alpha'}) do local pass=fx.material:GetPass(0,name)
        if pass then print('EFFECT_DEPTH '..name..' '..tostring(pass:GetDepthTestMode())..' write='..tostring(pass:GetDepthWrite()));V.assert(pass:GetDepthTestMode()==CMP_LESSEQUAL,'actual Glow '..name..' depth test') end
    end
    renderer:SetViewport(0,Viewport:new(scene,camera));Draw(2,false)
end)
V.atFrame(50,function() samples.off=Sample();Draw(2,true) end)
V.atFrame(55,function() samples.behind=Sample();Draw(-2,true) end)
V.atFrame(60,function()
    samples.front=Sample()
    V.assert(math.abs(samples.behind.center-samples.off.center)<.025,'wall blocks behind glow pixels')
    V.assert(samples.behind.control>samples.off.control+.15,'behind glow remains visible outside wall')
    V.assert(samples.front.center>samples.off.center+.15,'front glow visible')
    Draw(2,false)
    local node=scene:CreateChild('Overlay');node.position=Vector3(0,0,2)
    overlay=node:CreateComponent('CustomGeometry');overlay:BeginGeometry(0,TRIANGLE_LIST)
    for _,p in ipairs({{-1,-1},{1,-1},{1,1},{-1,-1},{1,1},{-1,1}}) do
        overlay:DefineVertex(Vector3(p[1],p[2],0));overlay:DefineNormal(Vector3(0,0,-1));overlay:DefineColor(Color(1,0,0,.8))
    end
    overlay:Commit();local m=Material:new();assert(m:SetSurfaceShader('Shaders/BLGL/Combat/ObjectiveOverlay.shader'));overlay.material=m
end)
V.atFrame(65,function()
    local value=Sample();V.assert(value.center>samples.off.center+.15,'intentional objective overlay through wall')
    print('EFFECT_DEPTH_PIXELS '..cjson.encode({off=samples.off,behind=samples.behind,front=samples.front,overlay=value}))
    renderer:SetViewport(0,nil);overlay.material:Dispose();fx:Dispose();material:Dispose();scene:Dispose();V.finish()
end)

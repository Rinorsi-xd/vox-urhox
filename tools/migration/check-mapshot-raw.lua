local Shot=require 'render.MatchMapShot'
local scene,shot
V.atFrame(2,function()
    scene=Scene();local octree=scene:CreateComponent('Octree')
    local zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(-5000,5000);zone.depthFogEnable=false;zone.heightFogEnable=false;zone.depthFogDensity=0;zone.depthFogStart=10000;zone.depthFogEnd=20000
    local n=scene:CreateChild('Box');n.position=Vector3(0,0,0);n.scale=Vector3(200,20,200)
    local model=n:CreateComponent('StaticModel');model:SetModel(cache:GetResource('Model','Models/Box.mdl'))
    local mat=Material:new();mat:SetTechnique(0,cache:GetResource('Technique','Techniques/NoTextureUnlit.xml'));mat:SetShaderParameter('MatDiffColor',Variant(Vector4(1,0,0,1)));model:SetMaterial(mat)
    model.instanceColor=Color(1,1,1,1)
    model.drawDistance=10000
    shot=Shot.New(scene)
    renderer.defaultZone.depthFogEnable=false;renderer.defaultZone.heightFogEnable=false;renderer.defaultZone.depthFogStart=10000;renderer.defaultZone.depthFogEnd=20000
    print('RAW_FOG '..cjson.encode({enable=renderer.defaultZone.depthFogEnable,start=renderer.defaultZone.depthFogStart,stop=renderer.defaultZone.depthFogEnd}))
    SubscribeToEvent('BeginViewRender',function(_,e)print('RAW_RENDER '..cjson.encode({camera=e:GetPtr('Camera')==shot.camera,texture=e:GetPtr('Texture')==shot.texture,enable=renderer.defaultZone.depthFogEnable,start=renderer.defaultZone.depthFogStart,stop=renderer.defaultZone.depthFogEnd}))end)
    local dir=shot.node.worldDirection;local up=shot.node.worldUp
    print('RAW_DIR '..cjson.encode({dir={dir.x,dir.y,dir.z},up={up.x,up.y,up.z},projection=shot.camera.orthoSize,far=shot.camera.farClip,near=shot.camera.nearClip,draw=model.drawDistance,lod=model.lodBias}))
    SubscribeToEvent('Update',function() if shot and shot.texture and not shot.captured then shot.texture:GetRenderSurface():QueueUpdate()end end)
end)
V.atFrame(15,function()
    local octree=scene:GetComponent('Octree')
    local all=octree:GetAllDrawables(DRAWABLE_GEOMETRY,0xffffffff)
    local visible=octree:GetDrawables(shot.camera.frustum,DRAWABLE_GEOMETRY,0xffffffff)
    print('RAW_DRAWABLES '..cjson.encode({all=#all,visible=#visible,views=shot.views}))
    local image=assert(shot.texture:GetImage());image:SavePNG('docs/migration/evidence/minimap-raw-only.png')
    local center=image:GetPixel(512,512);print('RAW_PIXEL '..cjson.encode({center.r,center.g,center.b,center.a}));image:Dispose()
    image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/minimap-raw-main.png');image:Dispose()
    shot:Dispose();scene:Dispose();V.finish()
end)

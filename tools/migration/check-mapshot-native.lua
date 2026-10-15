local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local MapShot=require 'render.MatchMapShot'
local Minimap=require 'ui.MatchMinimap'
local scene,root,mm,zone
local fogBefore={}
local fogKeys={'fogStart','fogEnd','fogDensity','heightFog','depthFogStart','depthFogEnd','depthFogDensity','heightFogDensity','depthFogEnable','heightFogEnable','volumetricFogEnabled'}
local function Box(name,pos,size,color)
    local node=scene:CreateChild(name);node.position=pos;node.scale=size
    local model=node:CreateComponent('StaticModel');model:SetModel(cache:GetResource('Model','Models/Box.mdl'))
    local material=Material:new();material:SetTechnique(0,cache:GetResource('Technique','Techniques/NoTextureUnlit.xml'))
    material:SetShaderParameter('MatDiffColor',Variant(color));model:SetMaterial(material)
    return material
end
local materials={}
local distanceNodes={}
V.atFrame(2,function()
    scene=Scene();scene:CreateComponent('Octree')
    local n=scene:CreateChild('Zone');zone=n:CreateComponent('Zone');zone.boundingBox=BoundingBox(-2000,2000)
    zone.depthFogDensity=.003;zone.heightFogDensity=.002
    for _,z in ipairs({zone,renderer.defaultZone})do local item={zone=z,values={}};for _,key in ipairs(fogKeys)do item.values[key]=z[key]end;fogBefore[#fogBefore+1]=item end
    materials[1]=Box('Ground',Vector3(0,-2,0),Vector3(600,4,600),Color(.15,.15,.15))
    materials[2]=Box('NorthRed',Vector3(-60,5,100),Vector3(80,10,80),Color(1,0,0))
    materials[3]=Box('EastBlue',Vector3(80,5,-80),Vector3(80,10,80),Color(0,0,1))
    materials[4]=Box('White',Vector3(80,5,100),Vector3(120,10,120),Color(1,1,1))
    for _,name in ipairs({'Ground','NorthRed','EastBlue','White'})do
        local drawable=scene:GetChild(name):GetComponent('StaticModel');drawable.drawDistance=150;distanceNodes[#distanceNodes+1]=drawable
    end
    UI.Init({scale=1});root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root)
    local me={team='blue',alive=true,Position=function()return {0,0,0}end,vehicle={Yaw=function()return 0 end}}
    mm=Minimap.New({scene=scene,app={store={Read=function()return nil end}},yaw=0,battle={entries={{unit=me}},player=me,mode='elimination',rules={},objectives={}}})
    local direction=mm.capture.node.worldDirection;print('MAPSHOT_DIRECTION '..cjson.encode({direction.x,direction.y,direction.z}))
    root.Render=function(_,vg)D.Rect(vg,0,0,graphics.width,graphics.height,{90,30,50,255});mm:Draw(vg)end
    SubscribeToEvent('Update',function()if mm and not mm.disposed then mm:Update()end end)
end)
V.atFrame(12,function()
    if mm.capture and mm.capture.image then mm.capture.image:SavePNG('docs/migration/evidence/minimap-mapshot-raw.png') end
end)
V.atFrame(360,function()
    local cap=mm.capture
    print('CAPTURE_DEBUG '..cjson.encode({capture=cap~=nil,captured=cap and cap.captured,worker=cap and cap.worker and coroutine.status(cap.worker),image=cap and cap.image~=nil,ready=cap and cap.ready,disposed=cap and cap.disposed,progress=cap and cap.progress}))
    V.assert(mm.base~=nil and mm.capture==nil,'single actual scene map capture completed and worker released')
    V.assert(math.abs(zone.depthFogDensity-.003)<1e-7 and math.abs(zone.heightFogDensity-.002)<1e-7,'map capture restores scene fog')
    for i,item in ipairs(fogBefore)do for _,key in ipairs(fogKeys)do V.assert(item.zone[key]==item.values[key],'restored scene/default fog '..i..' '..key)end end
    for _,drawable in ipairs(distanceNodes)do V.assert(drawable.drawDistance==150,'restores capture-only distance culling')end
    V.assert(scene:GetChild('MatchMapShotCamera')==nil,'capture camera released after readback')
    assert(mm.base,'capture base was not ready')
    local image=assert(mm.base.texture:GetImage());image:SavePNG('docs/migration/evidence/minimap-mapshot-base.png')
    local red=image:GetPixel(416,352);local blue=image:GetPixel(640,640);local white=image:GetPixel(640,352)
    print('MAPSHOT_COLORS '..cjson.encode({red={red.r,red.g,red.b},blue={blue.r,blue.g,blue.b},white={white.r,white.g,white.b}}))
    V.assert(red.r>blue.r+.03 and white.r>red.r+.1,'actual mapshot north/east orientation and source contrast')
    V.assert(math.abs(red.b-red.r-.1)<.07 and red.a>.99,'mapshot source cold grayscale and opaque alpha')
    image:Dispose();image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/minimap-mapshot-screen.png');image:Dispose()
    mm:Dispose();mm:Dispose();V.assert(not mm.base and not mm.capture,'minimap owns and releases transferred base')
    local cancelled=MapShot.New(scene);cancelled:Dispose();cancelled:Dispose()
    V.assert(not cancelled.node and not cancelled.texture and not cancelled.result,'capture cancellation releases native ownership')
    UI.SetRoot(nil);root:Destroy();UI.Shutdown();scene:Dispose()
    for _,material in ipairs(materials)do material:Dispose()end
    V.finish()
end)

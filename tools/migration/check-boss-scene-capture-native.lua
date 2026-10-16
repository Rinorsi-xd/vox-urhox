local UI=require 'urhox-libs/UI'
local Lifetime=require 'render.RenderTargetLifetime'
local Viewports=require 'render.WindowViewports'
local owner,scene,box,viewport,root
local Boss=require 'combat.StoryBoss'
local function Red(c) return c.r>.35 and c.g<.2 and c.b<.2 end
local function Green(c) return c.g>.6 and c.r<.2 and c.b<.2 end
local function Center(image) return image:GetPixel(math.floor(image.width/2),math.floor(image.height/2)) end
local function Frame(frame,fn) V.atFrame(frame,function()
 local ok,err=xpcall(fn,debug.traceback)
 if not ok then V.assert(false,tostring(err));V.finish() end
end) end
Frame(2,function()
 print('[BossSceneCaptureNative] started')
 scene=Scene();scene:CreateComponent('Octree')
 local zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100));zone.fogColor=Color(0,0,.5);zone.fogStart=50;zone.fogEnd=100
 local camera=scene:CreateChild('Camera'):CreateComponent('Camera');camera.node.position=Vector3(0,0,-6);camera.farClip=100
 box=scene:CreateChild('RedBox');local model=box:CreateComponent('StaticModel');model.model=cache:GetResource('Model','Models/Box.mdl')
 local material=Material:new();material:SetTechnique(0,cache:GetResource('Technique','Techniques/NoTextureUnlit.xml'));material:SetShaderParameter('MatDiffColor',Variant(Color(1,0,0)));model.material=material
 viewport=Viewport:new(scene,camera);Viewports.Set(0,viewport)
 UI.Init({theme='default-dark',scale=UI.Scale.DEFAULT,fonts={{family='sans',weights={normal='Fonts/VoxIndustrial-Bold.otf',bold='Fonts/VoxIndustrial-Bold.otf'}}}})
 root=UI.Panel{width='100%',height='100%',backgroundColor={0,0,0,0},children={UI.Panel{position='absolute',left='37.5%',top='37.5%',width='25%',height='25%',backgroundColor={0,255,0,255}}}}
 UI.SetRoot(root)
 owner=setmetatable({time=0,shots={},view={Dispose=function()end},unit={},allies={},Remove=function()end},{__index=Boss})
 owner.captureClock=function()return owner.time end
 owner:Capture('first',.2);owner:Capture('first',.1);owner:Capture('late',5)
 V.assert(owner.captureWanted.first==.2 and owner.captureWanted.late==5,'independent delayed captures retain first scheduling')
 owner:FramePresented()
 V.assert(next(owner.shotCaptures)==nil,'capture does not render before authored time')
end)
Frame(3,function()
 owner.time=.199;owner:FramePresented()
 V.assert(next(owner.shotCaptures)==nil,'capture remains pending below delay boundary')
end)
Frame(4,function()
 owner.time=.2;owner:FramePresented()
 V.assert(owner.shotCaptures.first~=nil and owner.shotCaptures.late==nil,'only due capture allocates native render target')
 local capture=owner.shotCaptures.first
 V.assert(capture.texture.width<=1280 and capture.texture.width>0 and capture.texture.height>0,'capture is bounded to 1280 with nonzero dimensions')
 V.assert(math.abs(capture.texture.width/capture.texture.height-graphics:GetWidth()/graphics:GetHeight())<.01,'capture preserves native viewport aspect')
 V.assert(capture.texture:GetRenderSurface().updateMode==SURFACE_MANUALUPDATE,'capture surface uses manual updates')
 V.assert(Viewports.Get(0)==viewport,'creating capture preserves main viewport identity')
end)
Frame(5,function() owner:FramePresented();V.assert(owner.shots.first==nil,'first presented frame keeps capture pending')end)
Frame(6,function() owner:FramePresented();V.assert(owner.shots.first==nil,'second presented frame keeps capture pending')end)
Frame(7,function()
 owner:FramePresented();V.assert(owner.shots.first~=nil,'third presented frame publishes actual GPU texture')
 V.assert(owner.shots.first:GetRenderSurface().numViewports==0,'published capture detaches borrowed scene viewport')
end)
Frame(9,function()
 local image=assert(owner.shots.first:GetImage());local pixel=Center(image)
 print(string.format('[BossSceneCaptureNative] capture center %.4f %.4f %.4f',pixel.r,pixel.g,pixel.b))
 V.assert(Red(pixel),'actual captured pixels contain the red 3D box')
 image:SavePNG('docs/migration/evidence/boss-scene-capture-native-3d.png');image:Dispose()
 local screen=Image:new();graphics:TakeScreenShot(screen);local ui=Center(screen)
 print(string.format('[BossSceneCaptureNative] screen center %.4f %.4f %.4f',ui.r,ui.g,ui.b))
 V.assert(Green(ui),'actual screen contains green NanoVG UI overlay')
 V.assert(not Red(ui),'full-screen screenshot negative control differs from 3D capture')
 screen:SavePNG('docs/migration/evidence/boss-scene-capture-native-screen.png');screen:Dispose()
 box.position=Vector3(3,0,0)
end)
Frame(12,function()
 local image=assert(owner.shots.first:GetImage());V.assert(Red(Center(image)),'detached GPU capture stays frozen when 3D scene changes');image:Dispose()
 V.assert(Viewports.Get(0)==viewport,'capture completion preserves main viewport ownership')
 local cancelled=require('render.BossSceneCapture').New(viewport);cancelled:Dispose();cancelled:Dispose()
 V.assert(cancelled.disposed and cancelled.texture==nil,'in-flight cancellation retires texture idempotently')
 owner:Dispose();owner:Dispose()
 V.assert(owner.disposed and owner.captureWanted==nil and next(owner.shotCaptures)==nil,'boss disposal cancels delayed captures and releases active capture owners')
 Lifetime.Flush();Viewports.Set(0,nil);UI.SetRoot(nil);scene:Dispose();scene=nil;viewport=nil;box=nil;root=nil
end)
Frame(16,function()
 Lifetime.Flush();V.assert(Lifetime.PendingCount()==0,'render targets release after borrowed surfaces are collected')
 print('[BossSceneCaptureNative] completed 20 checks;')
end)
Frame(18,function() V.finish() end)

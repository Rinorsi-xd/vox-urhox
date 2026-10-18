local scene,camera,rtt;local frame=0;local tag='current'
for _,a in ipairs(GetArguments()) do tag=a:match('^%-tag=(.+)$') or tag end
function Start()
 local ok,err=xpcall(function()
  scene=Scene();assert(scene:LoadXML(cache:GetResource('XMLFile','Scenes/Salvage.xml'):GetRoot()))
  camera=scene:CreateChild('CompareCamera'):CreateComponent('Camera');camera.fov=48;camera.farClip=2600;camera.nearClip=.2
  camera.node.position=Vector3(450,75,420);camera.node:LookAt(Vector3(0,25,0),Vector3.UP)
  renderer:SetViewport(0,Viewport:new(scene,camera))
  rtt=Texture2D:new();rtt:SetNumLevels(1);assert(rtt:SetSize(1400,900,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET))
  local vp=Viewport:new(scene,camera);vp:SetRenderPath(renderer:GetDefaultRenderPath():Clone())
  local surface=rtt:GetRenderSurface();surface:SetViewport(0,vp);surface:SetUpdateMode(SURFACE_UPDATEALWAYS)
  camera.aspectRatio=1400/900;camera.autoAspectRatio=false
 end,debug.traceback)
 if not ok then print('[MAP COMPARE] FAIL '..err);engine:Exit();return end
 SubscribeToEvent('EndAllViewsRender','CaptureMap')
end
function CaptureMap()
 frame=frame+1
 if frame==20 then local img=rtt:GetImage();assert(img and img:SavePNG('delta-map-'..tag..'.png'));img:Dispose();print('[MAP COMPARE] '..tag..' saved');engine:Exit() end
end

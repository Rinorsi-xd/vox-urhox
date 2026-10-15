local UI=require 'urhox-libs/UI'
local Images=require 'urhox-libs/UI/Core/ImageCache'
local D=require 'ui.SourceDraw'
---@type table
local I=nil
---@type Widget?
local root=nil
local borrowed=0;local rendered=0;local previous=0;local checked=false;local contact=false
function HoldIntroImageAcceptance()if root then UI.SetRoot(root)end end
V.atFrame(2,function()
 UI.UnregisterGlobalComponent('vox-loading-page')
 I=require('intro.IntroSession').New({},{state={}});I.active=true;I.stage='boot';I.shot='boot'
 for _,path in pairs(I.data.images)do Images.Release(path)end
 local warm=I.page.imageWarmup
 V.assert(#warm.items==14 and warm.index==0,'all fourteen frozen images have explicit warmup entries')
 local faces=0;for _,item in ipairs(warm.items)do if item.face then faces=faces+1 end end
 V.assert(faces==4,'four original portraits use existing engine texture owner instead of duplicate NanoVG uploads')
 V.assert(not warm:Step(nil,true) and warm.index==0,'missing UI context cannot create or cache a failed image')
 I.audioReady=true;I.sceneReady=true;I:Update(0,true)
 V.assert(not I.ready,'original narrative readiness waits for actual image uploads')
 root=I.page;local render=root.Render
 root.Render=function(page,vg)
  rendered=rendered+1
  if contact then
   D.Begin(vg);local w,h=UI.GetViewportSize();D.Rect(vg,0,0,w,h,{3,10,18,255});local column=0
   for _,item in ipairs(page.imageWarmup.items)do if not item.face then
    local x=column%5*w/5;local y=math.floor(column/5)*h/2
    require('ui.IntroPage').Image(vg,I,item.name,x+8,y+28,w/5-16,h/2-36)
    D.Text(vg,item.name,x+8,y+6,16,{214,240,255,255},'vox-title');column=column+1
   end end
  else
   local facesBefore=0;if page.portrait then for _ in pairs(page.portrait.faces)do facesBefore=facesBefore+1 end end
   render(page,vg)
   local facesAfter=0;if page.portrait then for _ in pairs(page.portrait.faces)do facesAfter=facesAfter+1 end end
   V.assert(facesAfter-facesBefore<=1,'actual portrait preparation loads at most one original face per render frame')
   local at=page.imageWarmup.index
   local _,err=page.imageWarmup:Step(vg,I.downloaded)
   V.assert(not err and page.imageWarmup.index==at,'same presented frame never uploads a second original image')
  end
 end
 UI.SetRoot(root);SubscribeToEvent('PostUpdate','HoldIntroImageAcceptance')
end)
V.atFrame(4,function()
 V.assert(rendered>0 and I.page.imageWarmup.index==0,'actual boot page does not upload before resource gate download completion')
 V.assert(not Images.IsLoaded(I.data.images['company-emblem']),'boot emblem cannot poison shared cache with an early failed load')
 borrowed=Images.Get(I.data.images['company-emblem']);V.assert(borrowed>0,'preexisting shared emblem handle is borrowed')
 I.downloaded=true
end)
for frame=5,23 do V.atFrame(frame,function()
 local at=I.page.imageWarmup.index;V.assert(at-previous<=1,'original uploads advance at most one item per real render frame');previous=at
 if I.page.imageWarmup.ready and not checked then
  checked=true;local warm=I.page.imageWarmup;local actual=true;local vgCount=0
  for _,item in ipairs(warm.items)do
   actual=actual and item.width>0 and item.height>0
   if item.face then actual=actual and I.page.portrait.faces[item.face]~=nil
   else actual=actual and Images.IsLoaded(item.path);vgCount=vgCount+1 end
  end
  V.assert(actual and vgCount==10 and warm.index==14,'actual ten NanoVG images and four real portrait textures have valid original dimensions')
  V.assert(warm.context==Images.GetContext() and I.page.portrait.ready,'prewarm uses stable actual UI context and submits actual portrait render target')
  I:Update(0,true);V.assert(I.ready,'actual narrative readiness opens only after complete source visual prewarm')
  local owned=0;for _ in pairs(warm.owned)do owned=owned+1 end
  V.assert(owned==9 and Images.Get(I.data.images['company-emblem'])==borrowed,'only nine newly created UI images are owned; borrowed emblem identity is unchanged')
  contact=true
 end
end)end
V.atFrame(25,function()
 V.assert(checked,'all original visual uploads finish under bounded rendered frames')
 local image=Image:new();V.assert(graphics:TakeScreenShot(image) and image:SavePNG('docs/migration/evidence/intro-image-warmup-contact.png'),'actual warmed original image contact sheet rendered');image:Dispose()
 local warm=I.page.imageWarmup;local portrait=I.page.portrait;root=nil;I:Dispose()
 local cleared=true;for _,item in ipairs(warm.items)do if not item.face and item.name~='company-emblem' then cleared=cleared and not Images.IsLoaded(item.path)end end
 V.assert(cleared and Images.Get(I.data.images['company-emblem'])==borrowed,'closing opening releases only owned NanoVG images and retains shared borrowed image')
 V.assert(next(portrait.faces)==nil and next(portrait.images)==nil,'real portrait owner disposes its faces and video handles exactly once')
 warm:Dispose();Images.Release(I.data.images['company-emblem']);V.finish()
end)

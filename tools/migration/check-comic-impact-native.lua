-- QA only: actual final-build glyph rendering, isolated from natural playback.
local state={index=1,renders=0}
local cases={
 {name='1920x1080-no',w=1920,h=1080,kind='No'},
 {name='1920x1080-bang',w=1920,h=1080,kind='Bang'},
 {name='2400x1080-no',w=2400,h=1080,kind='No'},
 {name='2400x1080-bang',w=2400,h=1080,kind='Bang'},
 {name='1440x1080-no',w=1440,h=1080,kind='No'},
 {name='1440x1080-bang',w=1440,h=1080,kind='Bang'},
 {name='1333x600-no',w=1333,h=600,kind='No'},
 {name='1333x600-bang',w=1333,h=600,kind='Bang'},
}
local folder='__EVIDENCE__/'
local root=nil ---@type table|nil
local UI=nil ---@type table|nil
local D=nil ---@type table|nil
local Comic=nil ---@type table|nil
function HoldComicImpactRaster()if root then UI.SetRoot(root)end end
V.atFrame(2,function()
 V.assert(COMIC_IMPACT_APP_STARTED==true and VOX_HANGAR==nil,'isolated UI main started without game application')
 UI=require 'urhox-libs/UI';D=require 'ui.SourceDraw';Comic=require 'ui.IntroComicText'
 local G=require 'ui.IntroGlyphs'
 V.assert(G.Glyph('!').advance==.196 and G.Glyph('！').advance==.765,'real ASCII and fullwidth glyph advances retained')
 UI.UnregisterGlobalComponent('vox-loading-page')
 local Layer=UI.Widget:Extend('VoxComicImpactRasterAcceptance')
 function Layer:Render(vg)
  local hw,hh=UI.GetViewportSize();local c=cases[state.index]
  D.Rect(vg,0,0,hw,hh,{12,17,23,255})
  local k=math.min(hw/c.w,hh/c.h)*.92;local x,y=(hw-c.w*k)/2,(hh-c.h*k)/2
  nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,k,k)
  D.Rect(vg,0,0,c.w,c.h,{42,66,89,255})
  if c.kind=='No' then Comic.No(vg,c.w,c.h,c.h/100,.4)
  else Comic.Bang(vg,c.w*.52,c.h*.32,c.h/100,.4) end
  nvgRestore(vg);state.rendered=state.index;state.renders=state.renders+1
 end
 root=Layer{width='100%',height='100%',pointerEvents='none'};UI.SetRoot(root)
 V.assert(UI.GetRoot()==root,'actual UI renderer owns isolated glyph widget')
 SubscribeToEvent('PostUpdate','HoldComicImpactRaster')
 print('[ComicImpactRaster] started')
end)
local function Shot(index)
 local c=cases[index]
 V.assert(state.rendered==index,'actual NanoVG draw completed for '..c.name)
 local image=Image:new()
 V.assert(graphics:TakeScreenShot(image),'actual screenshot readback '..c.name)
 V.assert(image.width>0 and image.height>0,'nonempty screenshot dimensions '..c.name)
 local k=math.min(image.width/c.w,image.height/c.h)*.92
 local x,y=(image.width-c.w*k)/2,(image.height-c.h*k)/2
 local red,white,dark=0,0,0
 for py=math.ceil(y+2),math.floor(y+c.h*k-2),3 do for px=math.ceil(x+2),math.floor(x+c.w*k-2),3 do
  local color=image:GetPixel(px,py)
  if color.r>.45 and color.g<.35 and color.b<.35 then red=red+1 end
  if math.min(color.r,color.g,color.b)>.75 then white=white+1 end
  if math.max(color.r,color.g,color.b)<.1 then dark=dark+1 end
 end end
 V.assert(red>20,'original red glyph fill visible '..c.name)
 V.assert(white>20,'original white outline or shadow visible '..c.name)
 V.assert(dark>20,'original dark extruded shadow visible '..c.name)
 V.assert(image:SavePNG(folder..c.name..'.png'),'saved actual glyph screenshot '..c.name)
 print('[ComicImpactRaster] shot '..c.name..' '..image.width..' '..image.height..' '..red..' '..white..' '..dark)
 image:Dispose()
 if index<#cases then state.index=index+1 else
  V.assert(state.renders>=8,'all eight raster cases executed')
  root=nil;UnsubscribeFromEvent('PostUpdate')
  print('[ComicImpactRaster] completed 60 checks;');V.finish()
 end
end
for index=1,#cases do local i=index;V.atFrame(2+i*4,function()Shot(i)end)end

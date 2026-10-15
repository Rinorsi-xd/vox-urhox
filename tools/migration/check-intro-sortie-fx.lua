-- Isolated original teaching-layer render; real actors/host are covered by the
-- warmup fixture and natural Web controls, not by this synthetic UI clock.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Fx=require 'ui.IntroSortieFx'
local Frame=UI.Widget:Extend('VoxSortieFxAcceptance')
local state={step=1,elapsed=4,controlling=false}
local stamp=false
---@type Widget?
local root=nil
function Frame:Render(vg)
 D.Begin(vg);local vw,vh=UI.GetViewportSize();local k=math.min(vw/1920,vh/1080)
 nvgSave(vg);nvgScale(vg,k,k);local w,h=vw/k,vh/k;local u=h/100
 D.Rect(vg,0,0,w,h,{8,15,28,255})
 if stamp then
  require('ui.IntroSortieUi').Stamp(vg,w,h,u,{stamped=true,elapsed=1.3,reason='被「援军」误伤'})
 else
  Fx.LockRing(vg,w*.23,h*.38,8*u,0,u)
  require('ui.IntroSortieUi').Draw({},vg,{sortie=state,time=10},w,h,u)
 end
 nvgRestore(vg)
end
function HoldSortieFxRoot() if root then UI.SetRoot(root) end end
local function Shot(name)
 local image=Image:new();V.assert(graphics:TakeScreenShot(image),'source teaching '..name..' GPU screenshot')
 V.assert(image:SavePNG('docs/migration/evidence/intro-sortie-fx-'..name..'.png'),'saved real '..name..' teaching-layer render');image:Dispose()
end
V.atFrame(2,function()
 UI.UnregisterGlobalComponent('vox-loading-page');root=Frame{width='100%',height='100%',pointerEvents='none'}
 UI.SetRoot(root);SubscribeToEvent('PostUpdate','HoldSortieFxRoot')
end)
V.atFrame(6,function()Shot('nudge-rest');state.elapsed=4.45 end)
V.atFrame(10,function()
 Shot('nudge-peak');stamp=true
end)
V.atFrame(14,function()
 Shot('original-game-font-stamp');root=nil;V.finish()
end)

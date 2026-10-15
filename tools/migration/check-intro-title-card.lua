local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Title=require 'ui.IntroTitleCard'
local Layer=UI.Widget:Extend('VoxOriginalTitleAcceptance')
local mode='prosper';local age=1
---@type Widget?
local root=nil
function Layer:Render(vg)
 D.Begin(vg);local w,h=UI.GetViewportSize();local u=h/100
 D.Rect(vg,0,0,w,h,{8,15,28,255});Title.Draw(vg,w,h,u,age,Title.Plan(mode))
end
function HoldTitleAcceptance()if root then UI.SetRoot(root)end end
local function Shot(id)
 local image=Image:new();V.assert(graphics:TakeScreenShot(image),'real original title '..id..' rendered')
 V.assert(image:SavePNG('docs/migration/evidence/intro-title-'..id..'.png'),'original title '..id..' screenshot');image:Dispose()
end
V.atFrame(2,function()
 UI.UnregisterGlobalComponent('vox-loading-page');root=Layer{width='100%',height='100%',pointerEvents='none'};UI.SetRoot(root)
 SubscribeToEvent('PostUpdate','HoldTitleAcceptance')
end)
V.atFrame(6,function()Shot('prosper');mode='recruit' end)
V.atFrame(10,function()Shot('recruit');mode='mechanic' end)
V.atFrame(14,function()Shot('mechanic');mode='recruit';age=.22 end)
V.atFrame(18,function()Shot('stagger');root=nil;V.finish()end)

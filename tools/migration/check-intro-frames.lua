-- Isolated render acceptance for original source art; real host is covered by
-- check-intro-host/live.lua, so these short shots do not build a second crater.
local intro=nil
function HoldIntroFrameRoot()
 if intro and intro.active then require('urhox-libs/UI').SetRoot(intro.page) end
end
local function Shot(name)
 local image=Image:new();V.assert(graphics:TakeScreenShot(image),'opening frame is readable')
 V.assert(image:SavePNG('docs/migration/evidence/intro-frame-'..name..'.png'),'original '..name..' frame saved');image:Dispose()
end
V.atFrame(2,function()
 intro=require('intro.IntroSession').New({},{})
 intro.active=true;intro.stage='ad';intro.shot='no';intro.age=.62;intro.time=3
 local UI=require('urhox-libs/UI');UI.UnregisterGlobalComponent('vox-loading-page');UI.SetRoot(intro.page)
 SubscribeToEvent('PostUpdate','HoldIntroFrameRoot')
end)
V.atFrame(5,function()Shot('laser-gag');intro.stage='reality';intro.shot='gate';intro.age=1.5;intro.name='验收机修师' end)
V.atFrame(10,function()Shot('armored-gate');intro.shot='contract';intro.age=.8;intro.page:ShowContract(true) end)
V.atFrame(15,function()
 V.assert(intro.page.termMax>0 and not intro.page.readTerms,'hidden contract clause starts below scrollable source terms')
 intro.page.termScroll=intro.page.termMax
end)
V.atFrame(20,function()
 V.assert(intro.page.readTerms and intro.page.termScroll<math.huge,'scrolling to bottom reveals source hidden clause')
 Shot('contract-egg');intro.page:ShowContract(false);intro.shot='tvcut';intro.age=.2
end)
V.atFrame(23,function()Shot('tv-cut');intro.shot='m-salvage';intro.age=.35 end)
V.atFrame(27,function()Shot('hero-cut');intro:Dispose();V.finish() end)

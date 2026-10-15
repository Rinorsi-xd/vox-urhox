local UI=require 'urhox-libs/UI'
local PointerEvent=require 'urhox-libs/UI/Core/PointerEvent'
local Host=require 'ui.DialogHost'
local owner={}
local modal,root
local previousWheel,staleBridge
local previousCalls,scrollCalls=0,0
local previousArgs={}
local function ClearHover()
    UI.HandlePointerCancel(PointerEvent.new(PointerEvent.Types.PointerCancel,
        {pointerId=0,pointerType=PointerEvent.PointerTypes.Mouse,x=0,y=0,isPrimary=true}))
end
V.atFrame(2,function()
    local fonts=require('ui.SourceFonts').Resolve()
    UI.Init({theme='default-dark',scale=UI.Scale.DPR,fonts={{family='sans',weights={normal=fonts.body,bold=fonts.bold}}}})
    root=UI.Panel{width='100%',height='100%'}
    previousWheel=function(self,dx,dy) previousCalls=previousCalls+1;previousArgs={self,dx,dy} end
    root.OnWheel=previousWheel;UI.SetRoot(root)
    modal=require('ui.SourceHelp').Open(owner)
    V.assert(root.OnWheel~=previousWheel,'help installs root fallback while original handler is retained')
    local wheel=modal.scroll.OnWheel
    modal.scroll.OnWheel=function(self,dx,dy) scrollCalls=scrollCalls+1;return wheel(self,dx,dy) end
    local groups=require('core.ResourceData').Read('UI/SourceHelp.json');local rows=0
    for _,group in ipairs(groups) do rows=rows+#group.rows end
    V.assert(rows==48,'all 48 frozen help rows imported')
    V.assert(groups[2].rows[2][1]=='J' and groups[3].title=='工具与上色','actual October 14 stretch and paint help')
    V.assert(groups[4].title=='视角（第一人称）','current first person controls replace legacy orbit help')
end)
V.atFrame(10,function()
    local r=modal.modalLayout_;local _,h=UI.GetViewportSize()
    V.assert(math.abs(r.h-h*.9)<1,'help clips to original 90 percent viewport height')
    V.assert(modal.props.source.fullScroll and modal.helpContent.bodyHeight>900,'long frozen content uses whole-card scrolling')
    local image=Image();V.assert(graphics:TakeScreenShot(image),'actual help top GPU capture')
    image:SavePNG('docs/migration/evidence/source-help-native-top.png');image:Dispose()
    local _,before=modal.scroll:GetScroll();V.assert(before==0,'help starts at top')
    ClearHover();V.assert(UI.GetHoveredWidget()==nil,'wheel regression explicitly uses no-hover root fallback')
    UI.HandleWheel(0,-4)
    V.assert(scrollCalls==1 and previousCalls==0,'UI HandleWheel reaches detached help exactly once')
end)
V.atFrame(16,function()
    local _,offset=modal.scroll:GetScroll();V.assert(offset>0,'UI wheel root fallback scrolls original help content')
    local r=modal.scroll.children[1]:GetAbsoluteLayoutForHitTest()
    V.assert(r.y<modal.modalLayout_.y,'source heading scrolls with help card')
    modal:OnWheel(0,-1)
    V.assert(scrollCalls==2 and previousCalls==0,'direct modal route does not double-dispatch through root')
    local blocker=UI.Panel{width=10,height=10};UI.PushOverlay(blocker)
    ClearHover();UI.HandleWheel(0,-1)
    V.assert(scrollCalls==2 and previousCalls==1,'covered help delegates root wheel without scrolling hidden help')
    UI.PopOverlay(blocker);blocker:Destroy()
    modal.scroll:ScrollToBottom()
end)
V.atFrame(22,function()
    local content=modal.helpContent;local r=content:GetAbsoluteLayoutForHitTest();local card=modal.modalLayout_
    V.assert(r.y+content.bodyHeight+31<=card.y+card.h+1,'all help rows and close footer reachable')
    local image=Image();V.assert(graphics:TakeScreenShot(image),'actual help GPU capture')
    image:SavePNG('docs/migration/evidence/source-help-native-bottom.png');image:Dispose()
    staleBridge=root.OnWheel
    Host.Close(owner);V.assert(owner.dialog==nil and modal.sourceDestroyed,'help closes and releases ownership')
    V.assert(root.OnWheel==previousWheel,'close restores exact original root wheel handler')
    ClearHover();UI.HandleWheel(3,-2)
    V.assert(previousCalls==2 and previousArgs[1]==root and previousArgs[2]==3 and previousArgs[3]==-2,'original root wheel self and deltas survive help lifetime')
    staleBridge(root,0,-1)
    V.assert(previousCalls==3 and scrollCalls==2,'retained retired bridge forwards without touching destroyed help')
    local nextHelp=require('ui.SourceHelp').Open(owner);Host.Dispose(owner)
    V.assert(nextHelp.sourceDestroyed and root.OnWheel==previousWheel,'owner dispose releases wheel bridge')
    nextHelp:Destroy();V.assert(root.OnWheel==previousWheel,'repeated disposal is idempotent')
    root.OnWheel=nil;require('ui.SourceHelp').Open(owner);Host.Close(owner)
    V.assert(root.OnWheel==nil,'help restores absent root wheel handler')
    root.OnWheel=previousWheel;nextHelp=require('ui.SourceHelp').Open(owner)
    local beforeRootReplacement=scrollCalls;local oldBridge=root.OnWheel
    local replacement=UI.Panel{width='100%',height='100%'};UI.SetRoot(replacement)
    oldBridge(root,0,-1)
    V.assert(scrollCalls==beforeRootReplacement and previousCalls==4,'old root cannot forward into help after root replacement')
    Host.Close(owner);V.assert(root.OnWheel==previousWheel,'root replacement still restores original old-root handler')
    UI.SetRoot(root);replacement:Destroy()
    nextHelp=require('ui.SourceHelp').Open(owner);local displaced=root.OnWheel
    local laterHandler=function(self,dx,dy) return displaced(self,dx,dy) end;root.OnWheel=laterHandler
    nextHelp:Destroy()
    V.assert(root.OnWheel==laterHandler,'disposing help preserves a later externally installed handler')
    laterHandler(root,0,-1);V.assert(previousCalls==5,'external wrapper can safely invoke retired bridge')
    root.OnWheel=previousWheel
    local first=require('ui.SourceHelp').Open(owner);local secondOwner={}
    local second=require('ui.SourceHelp').Open(secondOwner);local secondBridge=root.OnWheel
    first:Destroy();V.assert(root.OnWheel==secondBridge,'out-of-order close preserves newer help bridge')
    Host.Close(secondOwner)
    V.assert(second.sourceDestroyed and root.OnWheel==previousWheel,'last help unwraps retired nested bridge to original handler')
    UI.SetRoot(nil);root:Destroy();UI.Shutdown();V.finish()
end)

local UI=require 'urhox-libs/UI'
local Hud=require 'ui.GarageHud'
local Host=require 'ui.DialogHost'
local Dialogs=require 'ui.GarageDialogs'
local E=require 'urhox-libs/UI/Core/PointerEvent'
local app,s,oldContent,field,originalCode,metrics,steadyRenders,closingVisual,closeAllocations
local originalBays,originalBlueprint,testStore,testBlueprint
local groupBudgets={}
local function CheckHint(modal,kind)
    local f=assert(io.open('tools/migration/fixtures/source-'..kind..'-1920.json','r'));local ref=cjson.decode(f:read('*a'));f:close()
    local hint=modal.status;local r=hint:GetAbsoluteLayout();local card=modal.modalLayout_
    V.assert(math.abs(card.h-ref.card.h)<.1 and math.abs(card.y-ref.card.y)<.1,kind..' dialog matches original browser box: '..cjson.encode(card))
    V.assert(math.abs(hint.drawnWidth-ref.hint.w)<.05 and math.abs(r.h-ref.hint.h)<.05,kind..' hint matches original intrinsic flex width and height: '..cjson.encode(r)..' width '..hint.drawnWidth)
    V.assert(#hint.parts==#ref.runs,kind..' hint retains original anonymous text/code flex items')
    for i,part in ipairs(hint.parts) do
        local expected=ref.runs[i]
        V.assert(math.abs(r.x+34+part.x-expected.box.x)<.1 and math.abs(part.width-expected.advance)<.05,kind..' flex item '..i..' matches original advance and 7px gap')
    end
    local field=modal.field:GetAbsoluteLayout()
    V.assert(math.abs(field.y-ref.textarea.y)<.1 and field.h==ref.textarea.h,kind..' text area stays at original vertical position: '..cjson.encode(field))
end
local function GroupBudget(modal,name)
    local visual=modal.visual;local r=modal.modalLayout_
    local bytes=(visual.card.bytes or 0)+(visual.composite.bytes or 0)
    local old=math.ceil(r.w+122)*math.ceil(r.h+122)*16
    groupBudgets[name]={width=r.w,height=r.h,bytes=bytes,previousBytes=old,reduction=1-bytes/old}
    V.assert(bytes>0 and bytes<=math.ceil(r.w+5)*math.ceil(r.h+5)*16,'clipped '..name..' groups allocate card and filter guard only')
end
local oldSize,oldW,oldH,oldScale=UI.GetViewportSize,UI.GetWidth,UI.GetHeight,UI.GetScale()
local function Click(widget)
    local r=widget:GetAbsoluteLayoutForHitTest();local e={x=r.x+r.w/2,y=r.y+r.h/2,pointerType='mouse',pointerId=99,button=MOUSEB_LEFT}
    UI.HandlePointerEvent(E.new('PointerDown',e));UI.HandlePointerEvent(E.new('PointerUp',e))
end
local function Pointer(widget,kind)
    local r=widget:GetAbsoluteLayoutForHitTest()
    UI.HandlePointerEvent(E.new(kind,{x=r.x+r.w/2,y=r.y+r.h/2,pointerType='mouse',pointerId=99,button=MOUSEB_LEFT}))
end
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img),'native frame available')
    local crop=img:GetSubimage(IntRect(0,0,1920,1080));V.assert(crop:SavePNG('docs/migration/evidence/pc-dialog-'..name..'.png'),'saved '..name);crop:Dispose();img:Dispose()
end
V.atFrame(50,function()
    app=VOX_HANGAR.app;app.camera.autoSpin=false
    UI.SetScale(1);UI.GetViewportSize=function() return 1920,1080 end;UI.GetWidth=function() return 1920 end;UI.GetHeight=function() return 1080 end
    Hud.Update(0);s=Hud.GetState();s.root:SetStyle({width=1920,height=1080});renderer:GetViewport(0):SetRect(IntRect(0,0,1920,1080))
end)
V.atFrame(66,function() Click(s.buttons.settings) end)
V.atFrame(84,function()
    Shot('pause');local r=s.dialog.modalLayout_
    V.assert(s.dialog.visual.direct,'settled modal uses direct vectors instead of rendering offscreen groups')
    V.assert(math.abs(r.x-720)<1 and math.abs(r.y-340)<1 and r.w==480 and r.h==400,'pause matches actual H5 480x400 box')
    GroupBudget(s.dialog,'pause')
    V.assert(s.dialog.actions.keys.props.disabled,'unavailable source keyboard settings remain disabled')
    oldContent=s.dialog.contentContainer_;Click(s.dialog.actions.help)
    V.assert(oldContent.node and s.closingDialog and s.dialog.props.source.help,'help enters above the retiring source modal')
end)
V.atFrame(104,function()
    V.assert(not oldContent.node and not s.closingDialog,'home update retires the old modal while help stays open')
    Shot('help');local data=require('core.ResourceData').Read('UI/SourceHelp.json');local count=0;for _,g in ipairs(data) do count=count+#g.rows end
    V.assert(#data==5 and count==41,'source five groups and all 41 instructions imported')
    V.assert(s.dialog.modalLayout_.w==1240 and s.dialog.helpContent.bodyHeight>600,'help renders original five-column sheet')
    local f=assert(io.open('tools/migration/fixtures/source-help-1920.json','r'));local reference=cjson.decode(f:read('*a'));f:close()
    local content=s.dialog.helpContent;local rect=content:GetAbsoluteLayout();local D=require 'ui.SourceDraw'
    local symbol=require('ui.SourceFonts').ResolveHelpSymbol()
    local symbolFile=assert(io.open('docs/migration/evidence/pc-help-symbol-font.json','w'));symbolFile:write(cjson.encode(symbol));symbolFile:close()
    V.assert(math.abs(s.dialog.modalLayout_.h-reference.card.h)<.1 and math.abs(content.bodyHeight-reference.cols.h)<.1,'help card and columns match original browser heights')
    for i,g in ipairs(reference.groups) do
        local cy=rect.y+35
        for j,row in ipairs(g.rows) do
            local paragraph=content.paragraphs[i][j]
            V.assert(math.abs(content.rows[i][j]-row.body.h)<.01 and math.abs(cy+23-row.body.y)<.1,'help body row '..i..':'..j..' matches original browser position and height ('..content.rows[i][j]..'/'..row.body.h..', '..(cy+23)..'/'..row.body.y..')')
            local key=row.key:gsub('%s+',' ')
            V.assert(math.abs(math.max(18,D.Width(paragraph.context,key,12,nil,.5)+12)-row.keyBox.w)<.05,'help key '..i..':'..j..' matches source border padding and tracking')
            cy=cy+34+content.rows[i][j]
        end
    end
    GroupBudget(s.dialog,'help')
    local budgetFile=assert(io.open('docs/migration/evidence/pc-modal-group-budget.json','w'));budgetFile:write(cjson.encode(groupBudgets));budgetFile:close()
    Click(s.dialog.helpContent);V.assert(not s.dialog and not Hud.IsBlocked(),'help closes with actual content click')
    Dialogs.Code(s,false)
end)
V.atFrame(122,function()
    Shot('export');field=s.dialog.field;originalCode=field:GetValue()
    CheckHint(s.dialog,'export')
    steadyRenders=s.dialog.visual.card.renders
    V.assert(field.props.readOnly and #field.lines>1 and field.visibleRows<=7,'export is readonly, wrapped and bounded to visible lines')
    field:OnTextInput('unexpected');field:OnKeyDown(KEY_BACKSPACE);V.assert(field:GetValue()==originalCode,'export cannot mutate its source code')
    field:OnWheel(0,-2);V.assert(field.topRow>1,'textarea scrolls multiple rows')
    Pointer(s.dialog.actions.confirm,'PointerMove')
end)
V.atFrame(128,function()
    local button=s.dialog.actions.confirm
    V.assert(s.dialog.visual.card.renders==steadyRenders,'steady hover does not redraw offscreen groups')
    V.assert(button.state.hovered and button.sourceMotion.hover.value>0,'native mouse hover drives source sweep animation')
    Shot('export-hover');Pointer(button,'PointerDown')
end)
V.atFrame(133,function()
    V.assert(s.dialog.actions.confirm.sourceMotion.scale.value<1,'held primary button shrinks around its center')
    Shot('export-pressed')
    Pointer(s.dialog.actions.confirm,'PointerCancel')
    oldContent=s.dialog.contentContainer_;Click(s.dialog.actions.cancel)
    V.assert(oldContent.node and not UI.GetFocus() and not s.dialog,'textarea closure releases input before visual retirement')
    Dialogs.Code(s,true)
    s.dialog:Update(.26) -- Capture the settled original layout before editing.
    V.assert(not oldContent.node and not s.closingDialog,'new modal immediately releases old closing content')
end)
V.atFrame(137,function()
    Shot('import');CheckHint(s.dialog,'import')
    field=s.dialog.field;field:OnTextInput('not-a-blueprint');Click(s.dialog.actions.confirm)
    V.assert(s.dialog and s.dialog.status:GetText()=='蓝图码无效','invalid blueprint stays editable and cannot replace car')
    V.assert(not s.dialog.status.props.segments,'validation feedback clears original code flex items')
    Click(field);V.assert(UI.GetFocus()==field,'clicking textarea restores keyboard focus after invalid import')
    field:SelectAll();field:OnTextInput('ABCD\n中文 EF');V.assert(field:GetValue()=='ABCD\n中文 EF','multiline and UTF8 input preserve text')
    field:OnKeyDown(KEY_UP);V.assert(field.state.cursorPos<=4,'navigation sees edited rows before next render')
    field.state.cursorPos=utf8.len(field:GetValue())
end)
V.atFrame(145,function()
    V.assert(#field.lines==2,'explicit newline splits rows')
    field:OnKeyDown(KEY_UP);V.assert(field.state.cursorPos<=4,'up arrow moves to previous text row')
    field:OnKeyDown(KEY_HOME);V.assert(field.state.cursorPos==0,'home goes to wrapped line start')
    field:SetValue(string.rep('FKZC1:ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',400));field.state.cursorPos=0
end)
V.atFrame(157,function()
    Shot('import-long');metrics=field.metricsBuilds
    V.assert(#field.lines>100 and field.visibleRows<=7,'long code draws at most seven rows')
end)
V.atFrame(175,function()
    V.assert(field.metricsBuilds==metrics,'unchanged long code does not remeasure each frame')
    field:SetValue(originalCode);field.state.cursorPos=0;Host.Close(s)
    local clicked=false;local m=Host.Confirm(s,'删除当前战车？','删除车位中的战车，此操作无法撤销。',function() clicked=true end)
    m.testResult=function() return clicked end
end)
V.atFrame(190,function()
    Shot('confirm');local m=s.dialog;Click(m.actions.cancel);V.assert(not m.testResult() and not s.dialog,'cancel never executes destructive callback')
    for _=1,12 do local m=require('ui.PauseMenu').Open(s);local c=m.contentContainer_;Host.Close(s);Host.Update(s,.16);V.assert(not c.node,'repeated source modal retires layout at 160ms') end
    originalBays,originalBlueprint=app.bays,app.blueprint
    testBlueprint=require('construction.Blueprint').New():Load(originalBlueprint:ToTable())
    testStore={slots={}}
    function testStore:LoadSlot(i) return self.slots[i] end
    function testStore:SaveSlot(i,bp) self.slots[i]=bp:ToTable();return true end
    function testStore:SaveGarageState(i) self.active=i;return true end
    function testStore:Queue(bp) self.pending=bp:ToTable() end
    function testStore:Flush() return true end
    app.blueprint=testBlueprint
    app.bays=require('construction.Garage').New(testBlueprint,testStore,function(data) testBlueprint:Load(data);return true end,false)
    local m=Dialogs.Code(s,true);m.field:SetValue(originalCode)
end)
V.atFrame(205,function()
    Click(s.dialog.actions.confirm)
    V.assert(not s.dialog and app.vehicleSwitch:IsBusy(),'home import waits for old-car descent')
    app.vehicleSwitch:Update(.2)
    V.assert(not s.dialog and app.bays.active==2,'successful home import closes dialog and selects new bay')
    V.assert(testStore.slots[1] and testStore.slots[2] and #testStore.slots[2].parts==testBlueprint:Size(),'home import preserves current draft in first bay and saves imported car separately')
    for i=1,20 do testStore.slots[i]=testBlueprint:ToTable() end
    app.bays.active=false;app.bays.unsaved=true;testBlueprint.name='保留的未保存草稿'
    local m=Dialogs.Code(s,true);m.field:SetValue(originalCode)
end)
V.atFrame(220,function()
    Click(s.dialog.actions.confirm)
    app.vehicleSwitch:Update(.2)
    V.assert(s.dialog and s.dialog.title_=='放弃未保存的草稿？','full garage import requests discard through existing source action flow')
end)
V.atFrame(235,function()
    Click(s.dialog.actions.cancel)
    V.assert(not s.dialog and testBlueprint.name=='保留的未保存草稿' and app.bays.unsaved,'cancel import retains unsaved car')
    app.bays=originalBays;app.blueprint=originalBlueprint
    app.vehicleSwitch:Finish()
    Dialogs.Help(s);UI.GetHeight=function() return 720 end;UI.GetViewportSize=function() return 1920,720 end
end)
V.atFrame(249,function()
    V.assert(s.dialog.modalLayout_.h<=720*.96+1,'height-only PC resize keeps help in viewport')
    local r=s.dialog.modalLayout_;s.dialog:OnPointerDown({x=r.x+50,y=r.y+30,button=MOUSEB_LEFT})
    V.assert(not s.dialog,'help header click also closes original click-anywhere sheet')
    UI.GetHeight=function() return 1080 end;UI.GetViewportSize=function() return 1920,1080 end
end)
local entryModal,entryUpdate,entrySamples
V.atFrame(251,function()
    local f=assert(io.open('tools/migration/fixtures/source-modal-entry.json','r'))
    entrySamples=cjson.decode(f:read('*a')).samples;f:close()
    entryModal=require('ui.PauseMenu').Open(s);entryUpdate=entryModal.Update
    entryModal.Update=function() end
end)
for i=1,8 do
    V.atFrame(252+(i-1)*3,function()
        local sample=entrySamples[i]
        entryUpdate(entryModal,sample.time/1000-(i>1 and entrySamples[i-1].time/1000 or 0))
        local overlay,card=entryModal:EntryState()
        V.assert(math.abs(overlay-sample.overlay)<.0001,'overlay opacity matches Chromium at '..sample.time..'ms')
        V.assert(math.abs(card-sample.card)<.0001,'card opacity matches Chromium at '..sample.time..'ms')
    end)
    V.atFrame(254+(i-1)*3,function()
        local sample=entrySamples[i]
        Shot('entry-'..sample.time)
        if sample.time>0 then
            local box=entryModal.modalLayout_
            V.assert(math.abs(box.y-340-sample.offset)<.001,'rendered card offset matches Chromium at '..sample.time..'ms')
            local hit=entryModal.actions.help:GetAbsoluteLayoutForHitTest()
            V.assert(hit.y>=box.y and hit.y+hit.h<=box.y+box.h,'animated content hit box follows card at '..sample.time..'ms')
        end
    end)
end
V.atFrame(278,function()
    local old=entryModal.contentContainer_
    entryModal=require('ui.PauseMenu').Open(s)
    local overlay,card=entryModal:EntryState()
    V.assert(overlay==1 and card==0 and not old.node,'same source overlay persists while replacement card re-enters')
    entryModal.Update=function() end;entryUpdate(entryModal,.06)
end)
V.atFrame(281,function()
    Click(entryModal.actions.help)
    V.assert(s.dialog.props.source.help and s.closingDialog==entryModal,'click during entrance retains old modal only for its closing animation')
    local overlay,card=s.dialog:EntryState()
    V.assert(overlay==0 and card==0,'separate help overlay begins its own fade')
    Host.Update(s,.16);V.assert(not entryModal.node and s.dialog.node,'retirement leaves separate help overlay alive')
    Host.Close(s);V.assert(not s.dialog and not s.closingDialog,'help itself closes immediately')
end)
local closing,advanceClose,closeSamples,closeContent
V.atFrame(283,function()
    local f=assert(io.open('tools/migration/fixtures/source-modal-close.json','r'))
    closeSamples=cjson.decode(f:read('*a')).samples;f:close()
    closing=require('ui.PauseMenu').Open(s);closing:Update(.03)
    closing:Close();closeContent=closing.contentContainer_;advanceClose=closing.AdvanceClose
    closingVisual=closing.visual
    closing.AdvanceClose=function() end
    V.assert(not s.dialog and not Hud.IsBlocked() and closing.node,'logical close immediately unblocks home')
    V.assert(not closing:HitTest(960,540) and closing.props.pointerEvents=='none','retiring overlay cannot capture input')
    V.assert(UI.GetTopOverlay()~=closing,'closing modal immediately leaves input overlay stack')
end)
for i=1,7 do
    V.atFrame(284+(i-1)*3,function()
        local sample=closeSamples[i]
        advanceClose(closing,sample.time/1000-(i>1 and closeSamples[i-1].time/1000 or 0))
        if sample.time<160 then
            local overlay,card,offset=closing:EntryState()
            V.assert(math.abs(overlay-sample.overlay)<.0001 and math.abs(card-sample.card)<.0001,'closing opacity matches Chromium at '..sample.time..'ms')
            V.assert(math.abs(offset-sample.offset)<.001,'closing translation matches Chromium at '..sample.time..'ms')
            V.assert(closeContent.node and s.closingDialog==closing,'closing content retained until deadline')
        else
            V.assert(not closeContent.node and not s.closingDialog,'160ms releases content and ownership')
            V.assert(not closingVisual.card.vg and not closingVisual.composite.vg and closingVisual.card.bytes==0 and closingVisual.composite.bytes==0,'retirement releases offscreen targets and render contexts')
        end
    end)
    V.atFrame(286+(i-1)*3,function()
        Shot('close-'..closeSamples[i].time)
        if i==2 then closeAllocations=closingVisual.card.allocations end
        if i>2 and i<7 then V.assert(closingVisual.card.allocations==closeAllocations,'fractional card motion reuses fixed-size textures') end
    end)
end
local fakeOwner,settings,slider,opacityProbe,flushes= nil,nil,nil,nil,0
V.atFrame(307,function()
    local old=require('ui.PauseMenu').Open(s);old:Close();local previous=old.contentContainer_
    local m=require('ui.PauseMenu').Open(s);local overlay,card=m:EntryState()
    V.assert(not previous.node and not s.closingDialog and overlay==0 and card==0,'fast reopen restarts entry and releases retiring card')
    Host.Update(s,1);V.assert(s.dialog==m and m.node,'old close cannot destroy reopened modal')
    Host.Dispose(s)
    local fading=require('ui.PauseMenu').Open(s);fading:Close()
    local help=Dialogs.Help(s);Host.Close(s)
    V.assert(not help.node and s.closingDialog==fading and fading.node,'closing help immediately preserves independent modal fade')
    Host.Dispose(s)
    settings={data={quality='high',bloom=.18,mist=.04,exposure=1.1,vignette=.3,grain=0,ao=true}}
    function settings:Supports() return true end
    function settings:Set(k,v) self.data[k]=v;return true end
    function settings:Flush() flushes=flushes+1;return true end
    fakeOwner={app={graphicsSettings=settings}}
    local graphics=require('ui.GraphicsPanel').Open(fakeOwner);graphics:Update(.3);slider=graphics.controls.bloom
    opacityProbe=UI.Panel{width=1,height=1,pointerEvents='none'}
    opacityProbe.Render=function(self,vg)
        UI.QueueOverlay(function(nvg)
            local D=require('ui.SourceDraw');nvgSave(nvg);nvgGlobalAlpha(nvg,1)
            D.Rect(nvg,0,0,120,40,{0,0,0,255})
            nvgSave(nvg);nvgGlobalAlpha(nvg,.5);D.Rect(nvg,0,0,40,40,{255,255,255,255})
            nvgSave(nvg);nvgGlobalAlpha(nvg,.5);D.Rect(nvg,40,0,40,40,{255,255,255,255});nvgRestore(nvg)
            nvgGlobalAlpha(nvg,.25);D.Rect(nvg,80,0,40,40,{255,255,255,255});nvgRestore(nvg);nvgRestore(nvg)
        end)
    end
    s.root:AddChild(opacityProbe)
end)
V.atFrame(310,function()
    local image=Image:new();graphics:TakeScreenShot(image)
    local single,nested,explicit=image:GetPixel(20,20).r,image:GetPixel(60,20).r,image:GetPixel(100,20).r
    local f=assert(io.open('docs/migration/evidence/pc-nvg-opacity.json','w'))
    f:write(cjson.encode({single=single,nested=nested,explicit=explicit}));f:close();image:Dispose();opacityProbe:Destroy()
    V.assert(math.abs(single-nested)<.01 and explicit<single*.6,'actual GPU globalAlpha replaces inherited alpha; explicit product is necessary')
end)
V.atFrame(313,function()
    Pointer(slider,'PointerDown')
    V.assert(slider.state.dragging and UI.GetPressedWidgetForPointer(99)==slider and UI.GetFocus()==slider,'real pointer starts focused graphics drag')
    local m=fakeOwner.dialog;Host.Close(fakeOwner)
    V.assert(not slider.state.dragging and not UI.GetPressedWidgetForPointer(99) and not UI.GetFocus(),'close cancels pointer capture, dragging and keyboard focus')
    V.assert(flushes==1 and m.node and not fakeOwner.dialog,'settings flush once at logical close while pixels remain')
    local value=settings.data.bloom;Pointer(slider,'PointerMove');Pointer(slider,'PointerUp')
    V.assert(settings.data.bloom==value,'released pointer cannot edit fading slider')
    m:Close();Host.Dispose(fakeOwner);V.assert(flushes==1 and not m.node,'repeated close and disposal cannot duplicate callbacks')
    local a=require('ui.PauseMenu').Open(s);a:Close();local content=a.contentContainer_
    local help=Dialogs.Help(s);local helpContent=help.contentContainer_
    Hud.Dispose()
    V.assert(not content.node and not helpContent.node and not s.dialog and not s.closingDialog,'scene disposal releases both active help and retiring modal')
    UI.GetViewportSize=oldSize;UI.GetWidth=oldW;UI.GetHeight=oldH;UI.SetScale(oldScale);V.finish()
end)

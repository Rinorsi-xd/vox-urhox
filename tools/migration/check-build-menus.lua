local UI=require 'urhox-libs/UI'
local Host=require 'ui.DialogHost'
local app,session,library,oldContent,oldPicture,oldSession,savedName,isolated,warningX,warningY
local viewportSize=UI.GetViewportSize
local viewportWidth,viewportHeight,viewportScale=UI.GetWidth,UI.GetHeight,UI.GetScale()
local testWidth,testHeight=1920,1080
local importDraft
local motionUpdate
local function Bound()
    session=app.build;session.hud.root:SetStyle({width=testWidth,height=testHeight})
    renderer:GetViewport(0):SetRect(IntRect(0,0,testWidth,testHeight))
end
local function Pointer(x,y,kind)
    local E=require 'urhox-libs/UI/Core/PointerEvent';local scale=UI.GetScale()
    UI.HandlePointerEvent(E.new(kind,{x=x*scale,y=y*scale,pointerId=89,pointerType='mouse',button=MOUSEB_LEFT}))
end
local function Shot(name)
    local img=Image:new();local captured=graphics:TakeScreenShot(img)
    local crop=captured and img:GetSubimage(IntRect(0,0,testWidth,testHeight))
    V.assert(crop and crop:SavePNG('docs/migration/evidence/'..name..'.png'),'rendered '..name)
    if crop then crop:Dispose() end;img:Dispose()
end
local function Click(widget)
    local Events=require 'urhox-libs/UI/Core/PointerEvent'
    local r=widget:GetAbsoluteLayoutForHitTest();local scale=UI.GetScale()
    local e={x=(r.x+r.w/2)*scale,y=(r.y+r.h/2)*scale,pointerId=89,pointerType='mouse',button=MOUSEB_LEFT}
    UI.HandlePointerEvent(Events.new('PointerDown',e));UI.HandlePointerEvent(Events.new('PointerUp',e))
end
local function Cleanup()
    app.store.pending=nil
    for _,key in ipairs({'draft','garage-state','build-settings'}) do for _,suffix in ipairs({'-a.json','-b.json'}) do local p=app.store.prefix..key..suffix;if fileSystem:FileExists(p) then fileSystem:Delete(p) end end end
    for i=1,20 do for _,suffix in ipairs({'-a.json','-b.json'}) do local p=app.store.prefix..'slot'..i..suffix;if fileSystem:FileExists(p) then fileSystem:Delete(p) end end end
end
V.atFrame(55,function()
    UI.SetScale(1);UI.GetViewportSize=function() return testWidth,testHeight end
    UI.GetWidth=function() return testWidth end;UI.GetHeight=function() return testHeight end
    app=VOX_HANGAR.app;app.store=require('storage.BlueprintStore').New('vox-build-menus-test');app.bays.store=app.store;Cleanup()
    app.bays.active=false;app.bays.unsaved=true;V.assert(app.bays:Save(),'initial car saved')
    local bp=require 'build.Blueprint';local prefab=require 'build.Prefab'
    app.store:SaveSlot(2,prefab.BuildTank(bp.New()));app.store:SaveSlot(3,prefab.BuildEmpty(bp.New()))
    app:EnterBuild();session=app.build;session.hud.root:SetStyle({width=testWidth,height=testHeight})
    renderer:GetViewport(0):SetRect(IntRect(0,0,testWidth,testHeight))
    session.editor:SelectAll();session.editor.pasting=true
    session:Escape();V.assert(not session.editor.pasting and next(session.editor.selection) and not session.dialog,'Escape cancels paste before clearing selection')
    session:Escape();V.assert(not next(session.editor.selection) and not session.dialog,'second Escape clears selection without opening menu')
    session:Escape();V.assert(session.dialog and not session.controls.pointer,'third Escape opens pause and cancels holds')
    local count=app.blueprint:Size();local yaw=app.camera.yaw
    V.assert(not session:Act(),'pause blocks build commands')
    session.controls:Position({x=900,y=600});session.controls:Move({x=920,y=620})
    session.controls:Up({x=900,y=600});session:Refresh()
    V.assert(not session.controls.inside and app.camera.yaw==yaw and app.blueprint:Size()==count and #session.ghost.pool==0,'pause prevents pointer reentry, camera drift and ghost rebuild')
end)
V.atFrame(75,function()
    Shot('build-pause');oldContent=session.dialog.contentContainer_;Click(session.dialog.actions.help)
    V.assert(oldContent.node and session.closingDialog and session.dialog.props.source.help,'pause fades behind the separate help overlay')
    session:Escape();V.assert(not session.dialog and UI.GetFocus()==nil,'Escape closes help without reopening pause')
    library=session:OpenLibrary('save')
    V.assert(not oldContent.node and not session.closingDialog,'library replacement immediately releases previous closing layout')
end)
V.atFrame(95,function()
    Shot('build-library-save');oldPicture=library.previews.items[1];oldContent=library.contentContainer_
    V.assert(#library.cards==20 and oldPicture.ready,'library shows 20 bays and real vehicle thumbnail')
    V.assert(oldPicture.images[UI.GetNVGContext()] and library.visual.direct,'settled library samples thumbnail in UI context')
    local box=library.modalLayout_;local a=library.cards[1]:GetAbsoluteLayout();local b=library.cards[4]:GetAbsoluteLayout();local c=library.cards[5]:GetAbsoluteLayout()
    V.assert(math.abs(box.x-570)<1 and box.w==780 and math.abs(box.h-928.8)<1,'PC library uses original 780px modal and 86vh cap')
    V.assert(math.abs(a.w-169.75)<1 and math.abs(a.y-b.y)<1 and math.abs(a.x-c.x)<1 and math.abs(b.x-a.x-539.25)<1,'four source columns reserve Chromium scrollbar gutter with 169.75px cards and 10px gaps')
    Click(library.cards[2].selectButton)
    V.assert(not oldContent.node and not oldPicture.texture and session.dialog.actions.confirm~=nil,'overwrite asks confirmation and releases library preview')
end)
V.atFrame(105,function() Click(session.dialog.actions.cancel);library=session.dialog;V.assert(library.mode=='save','cancel overwrite returns to save library') end)
V.atFrame(116,function() Click(library.cards[2].selectButton) end)
V.atFrame(126,function()
    Click(session.dialog.actions.confirm)
    V.assert(not session.dialog and app.bays.active==2 and session.slot==2,'confirmed save updates actual selected bay')
    V.assert(app.store:LoadSlot(2).name==app.blueprint.name and not app.bays.unsaved,'overwrite persists current vehicle')
    library=session:OpenLibrary('load');app.bays:Rename('未保存的改名')
end)
V.atFrame(130,function()
    library:Update(1) -- Finish modal entrance before comparing card-only motion.
    local card=library.cards[1];motionUpdate=card.Update
    card.props.data.name='原版长名称战车测试 ABC 0123456789'
    for _,c in ipairs(library.cards) do if c.props.data then c.props.data.savedTime=os.time({year=2026,month=10,day=6,hour=10,min=5,sec=0})*1000;c.metaData=nil end end
    app.toasts:Update(4)
    Pointer(20,20,'PointerMove');motionUpdate(card,1)
    card.Update=function() end
end)
V.atFrame(132,function()
    Shot('pc-library-idle')
    local card=library.cards[1];local r=card:GetAbsoluteLayoutForHitTest()
    Pointer(r.x+r.w/2,r.y+r.h/2,'PointerMove');motionUpdate(card,.06)
    V.assert(card.state.hovered and card.props.translateY<-2 and card.props.translateY>-3,'real pointer starts source cubic Bezier card lift')
    V.assert(card.libraryMotion.delete.value>.79 and card.libraryMotion.delete.value<.82,'delete opacity uses CSS ease at half duration')
    V.assert(card.props.data.savedTime and card.metaText:find(' · ')~=nil,'rendered library includes persisted save date')
    V.assert(card.fittedTitle:sub(-3)=='…' and utf8.len(card.fittedTitle)<utf8.len(card.props.data.name),'long source title renders UTF-8-safe ellipsis')
end)
V.atFrame(134,function()
    Shot('pc-library-hover-mid');motionUpdate(library.cards[1],.14)
end)
V.atFrame(136,function()
    Shot('pc-library-hover')
    local card=library.cards[1];local r=card:GetAbsoluteLayoutForHitTest()
    V.assert(card.props.translateY==-3 and card.libraryMotion.delete.value==1,'hover completes exact source 3px lift and delete fade')
    Pointer(r.x+r.w/2,r.y-2,'PointerMove')
    V.assert(UI.GetHoveredWidgetForPointer(89)==card,'translated upper edge participates in actual pointer hit testing')
    local d=card.deleteButton:GetAbsoluteLayoutForHitTest();Pointer(d.x+15,d.y+12,'PointerMove')
    V.assert(card.deleteButton.state.hovered,'translated delete button is hit at its visible position')
    motionUpdate(card,.2);V.assert(card.props.translateY==-3,'entering delete child preserves parent card hover')
    Pointer(20,20,'PointerMove');motionUpdate(card,.2)
end)
V.atFrame(140,function()
    Shot('pc-library-leave');local card=library.cards[1]
    V.assert(card.props.translateY==0 and card.libraryMotion.delete.value==0,'leaving card restores source position and hides delete')
    card.Update=motionUpdate
end)
V.atFrame(142,function()
    Shot('build-library-load');Click(library.cards[1].selectButton)
    V.assert(session.dialog.actions.confirm and app.blueprint.name=='未保存的改名','library restore protects unsaved changes with confirmation')
    oldSession=session
end)
V.atFrame(153,function()
    Click(session.dialog.actions.confirm);session=app.build
    V.assert(oldSession.disposed and oldSession~=session and app.bays.active==1,'load replaces build owner and activates chosen bay')
    V.assert(app.blueprint.name==app.store:LoadSlot(1).name and not app.bays.unsaved,'load restores saved data and clears unsaved flag')
    V.assert(session.slot==1 and session.message:find('1')~=nil,'load result delivered to live session')
    library=session:OpenLibrary('load')
end)
V.atFrame(168,function() Click(library.cards[2].deleteButton);V.assert(app.store:LoadSlot(2)~=nil,'delete requires confirmation') end)
V.atFrame(180,function()
    Click(session.dialog.actions.confirm);library=session.dialog
    V.assert(not app.store:LoadSlot(2) and library.mode=='load' and app.bays.active==1,'delete inactive bay keeps current car and refreshes library')
    Host.Close(session)
    local blank=require('build.Prefab').BuildEmpty(require('build.Blueprint').New())
    for i=2,20 do blank.name='存档 '..i;app.store:SaveSlot(i,blank) end
    savedName=app.store:LoadSlot(1).name;app.bays.active=false;app.bays.unsaved=true
    -- Exercise clipping in a short PC window; four source columns show more
    -- cards than the removed three-column UI at the default large viewport.
    testWidth,testHeight=1440,720
    V.assert(not session:SaveSlot() and session.dialog.mode=='save','full garage save opens explicit destination chooser')
    V.assert(app.store:LoadSlot(1).name==savedName,'full save never silently overwrites first bay')
    library=session.dialog
end)
V.atFrame(190,function() testWidth,testHeight=1920,1440 end)
V.atFrame(194,function()
    local a=library.cards[1]:GetAbsoluteLayout()
    V.assert(session.dialog==library and library.scroll.props.paddingRight==0 and math.abs(a.w-173.5)<1,'tall PC window preserves modal and removes unnecessary scrollbar gutter')
    V.assert(library.scroll.props.sourceNaturalHeight<testHeight*.86,'full library fits tall PC window without alternate layout')
    testWidth,testHeight=1440,720
end)
V.atFrame(198,function()
    V.assert(session.dialog==library and library.scroll.props.paddingRight==15 and math.abs(library.cards[1]:GetAbsoluteLayout().w-169.75)<1,'short PC window restores source four-column gutter without replacing dialog')
    library.scroll:SetScroll(0,100000)
end)
V.atFrame(240,function()
    V.assert(not library.previews.items[1].texture and library.previews.items[20].ready,'library scroll releases offscreen images and completes last thumbnail')
    V.assert(session.dialog==library and library.node and library.parent==session.hud.root,'PC resize retains live modal in replacement HUD root')
    Shot('build-library-scroll');local picture=library.previews.items[20];local texture=picture.texture
    Host.Close(session)
    V.assert(not session.dialogTick and not library.previews.job and picture.texture==texture,'closing library stops preview work but retains rendered image')
    Host.Update(session,.159);V.assert(picture.texture==texture,'library image survives 159ms fade')
    Host.Update(session,.001);V.assert(not picture.texture and not library.node,'library image and layout released at 160ms')
    testWidth,testHeight=1920,1080
    for _=1,12 do local m=session:OpenPause();local c=m.contentContainer_;session:Escape();Host.Update(session,.16);V.assert(not c.node,'pause repeated layout cleanup after fade') end
    session:OpenPause()
end)
V.atFrame(246,function()
    Click(session.dialog.actions.resume);V.assert(not session.dialog,'continue returns to edit')
    app.bays.active=1;app.bays:Rename('菜单回机库自动保存');session:OpenPause()
end)
V.atFrame(253,function()
    Click(session.dialog.actions.home)
    V.assert(not app.build and app.store:LoadSlot(1).name=='菜单回机库自动保存','pause return home autosaves active bay')
    app:EnterBuild();Bound()
    local e=session.editor;isolated=e.bp.nextId
    e.history:Commit({{op='add',data={id=isolated,type='cube',pos={25,5,0},rot=require('core.Rotations').IDENTITY,color=0xffffff}}})
    session:Refresh();local diag=session.inspection:Get();local found=false
    for _,w in ipairs(diag.list) do for _,id in ipairs(w.ids) do if id==isolated and w.text:find('没有连到核心') then found=true end end end
    V.assert(found and session.inspection.view.counts.red==1,'disconnected part produces exact diagnostic and red native overlay')
    local count=session.inspection.computations
    for _=1,50 do session:Refresh() end
    V.assert(session.inspection.computations==count,'unchanged UI refresh never recomputes diagnostics')
end)
V.atFrame(260,function()
    -- Let actual timed notifications expire before the visual comparison.
    app.toasts:Update(4);Bound()
    Click(session.hud.stats.pane.more)
    V.assert(session.hud.stats.pane.expanded and not session.dialog,'original detailed diagnostics expand inline without invented modal')
end)
V.atFrame(268,function()
    local pane=session.hud.stats.pane;local hit
    for _,row in ipairs(pane.warningHits) do if row.detail and row.item and row.item.text:find('没有连到核心') then hit=row;break end end
    V.assert(hit~=nil,'original inline list contains disconnected-part warning')
    local r=pane:GetAbsoluteLayoutForHitTest();warningX=r.x+60;warningY=r.y+hit.y+hit.h/2
    V.assert(math.abs(r.y+hit.y-641.53125)<1 and math.abs(r.w-272)<1,'expanded source diagnostics match measured DOM Y and width')
    local save=session.hud.buttons.save:GetAbsoluteLayoutForHitTest()
    V.assert(save.x+save.w<=testWidth-17,'PC screenshot includes complete original save action')
    Pointer(warningX,warningY,'PointerMove')
    V.assert(pane.hoverWarning==hit.item and session.inspection.view.counts.orange==1,'actual inline hover highlights related parts')
end)
V.atFrame(274,function()
    Shot('pc-build-diagnostics');Pointer(warningX,warningY,'PointerDown');Pointer(warningX,warningY,'PointerUp')
    local target=session.camera.target
    V.assert(not session.dialog and math.abs(target.x+12.5)<.0001 and math.abs(target.y-2.75)<.0001 and math.abs(target.z)<.0001 and session.camera.dist==4,'warning click uses source cell bounds and mirrors camera X')
    V.assert(session.inspection.view.counts.orange==1 and #session.editor:Selected()==0,'warning focus highlights without changing edit selection')
end)
local warningMeasurements,warningPane,statsViewportHeight
V.atFrame(278,function()
    warningPane=session.hud.stats.pane;warningMeasurements={}
    for i,p in ipairs(warningPane.warningParagraphs) do warningMeasurements[i]=p.measurements end
    -- Isolate a height-only change without rebuilding the HUD/diagnosis owner.
    statsViewportHeight=UI.GetHeight;UI.GetHeight=function() return 720 end
end)
V.atFrame(286,function()
    V.assert(session.hud.stats.pane==warningPane and warningPane.scroll.props.height==510,'same diagnostic owner updates scroll range on height-only PC resize')
    for i,p in ipairs(warningPane.warningParagraphs) do
        V.assert(p.measurements==warningMeasurements[i],'unchanged warning paragraph does not remeasure during redraw or height-only resize')
    end
    UI.GetHeight=statsViewportHeight
end)
V.atFrame(294,function()
    Shot('pc-build-diagnostic-focus');Pointer(900,500,'PointerMove')
    V.assert(session.inspection.view.counts.orange==0 and session.inspection.view.counts.red==1,'leaving source warning clears hover and preserves disconnected overlay')
    local before=session.inspection.computations
    session.editor.selection={[isolated]=true};session.editor:DeleteSelection();session:Refresh()
    V.assert(session.inspection.computations==before+1 and session.inspection.view.counts.red==0 and session.inspection.view.counts.orange==0,'repair clears diagnostic and stale focus on edit revision')
    session.editor:Undo();session:Refresh();V.assert(session.inspection.view.counts.red==1,'undo restores disconnected highlight')
    session.editor:Redo();session:Refresh()
    app:ExitBuild();V.assert(not app.scene:GetChild('BuildDiagnostics'),'leaving build disposes diagnostic scene nodes')
    app:EnterBuild();session=app.build
    require('ui.GarageDialogs').Code(session,true)
end)
V.atFrame(299,function()
    importDraft=session.dialog.field;importDraft:SetValue('尚未提交的蓝图草稿');UI.SetFocus(importDraft)
    testWidth,testHeight=1440,900
end)
V.atFrame(303,function()
    V.assert(session.dialog.field==importDraft and importDraft.node and importDraft:GetValue()=='尚未提交的蓝图草稿','PC resize preserves unsubmitted import text and field identity')
    V.assert(UI.GetFocus()==importDraft and session.dialog.parent==session.hud.root,'PC resize preserves modal text focus and mounts under new HUD')
    testWidth,testHeight=1920,1080
end)
V.atFrame(306,function()
    local current=app.blueprint;session.dialog.field:SetValue('invalid')
    Click(session.dialog.actions.confirm)
    V.assert(app.blueprint==current and session.dialog.field~=nil,'invalid import keeps vehicle and input available')
    local data=require('build.Prefab').BuildTank(require('build.Blueprint').New()):ToTable()
    data.name='导入独立草稿';session.dialog.field:SetValue(require('storage.BlueprintCode').Encode(data))
    savedName=app.store:LoadSlot(1).name;oldSession=session
    Click(session.dialog.actions.confirm)
    V.assert(session.dialog.actions.confirm and app.bays.active==1,'valid import confirms replacement before changing occupied bay')
end)
V.atFrame(316,function()
    Click(session.dialog.actions.confirm);session=app.build
    V.assert(oldSession.disposed and session~=oldSession and app.bays.active==false and app.bays.unsaved,'import replaces build owner with unslotted dirty draft')
    V.assert(app.blueprint.name=='导入独立草稿' and app.store:LoadSlot(1).name==savedName,'import preserves previous occupied bay')
    app:ExitBuild()
    V.assert(app.store:LoadSlot(1).name==savedName and app.blueprint.name=='导入独立草稿','leaving imported draft never overwrites old bay')
    app:EnterBuild();session=app.build
    V.assert(not session:SaveSlot() and session.dialog.mode=='save','import in full garage requires explicit destination')
    Host.Close(session);app:ExitBuild();Cleanup()
    UI.GetViewportSize=viewportSize;UI.GetWidth=viewportWidth;UI.GetHeight=viewportHeight;UI.SetScale(viewportScale);V.finish()
end)

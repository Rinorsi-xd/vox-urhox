-- Real packaged editor and native widgets, with isolated test credit/transient
-- and salvage rule states. No natural-wave, account or mobile-performance claim.
local UI=require 'urhox-libs/UI'
local phase='boot';local worker=nil
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not Equal(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end
    return true
end
local function Find(widget,predicate)
    if predicate(widget) then return widget end
    for _,child in ipairs(widget.children or {}) do local found=Find(child,predicate);if found then return found end end
end
local function Capture(name)
    coroutine.yield();coroutine.yield()
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG(VOX_G5_OUTPUT..'/'..name..'.png');image:Dispose()
end
local function Exercise(app)
    local s=app.trial;local controller=s.endless
    V.assert(controller and controller.run.state=='countdown','Real production endless controller mounted in initial countdown')
    V.assert(controller:EnterEdit(),'Actual initial countdown enters retained-world BuildSession')
    local edit=assert(controller.edit);local b=edit.build;local editor=edit.host.editor;local inventory=edit.host.inventory
    for _=1,5 do coroutine.yield() end
    local id='laser2';local Inv=require 'endless.Inventory';local price=Inv.Price(id)
    local oldCredit=controller.run.credits;controller.run.credits=price*2
    for i=1,10 do inventory.hotbar[i]=i<=4 and ({'cube','slope','heavy','truss'})[i] or false end
    inventory.active=2
    local stock=controller.run.inventory[id] or 0
    require('ui.EndlessEditBar').Shop(edit);for _=1,3 do coroutine.yield() end
    local card=Find(edit.shop,function(w) return w.props.shop and w.props.text==require('parts.Defs').PARTS[id].name end)
    V.assert(card and not card.props.disabled,'Real native source weapon shop card is enabled')
    card.props.onClick(card)
    V.assert(controller.run.inventory[id]==stock+1 and controller.run.credits==price,'Actual shop callback charges once and adds one stock')
    V.assert(inventory.hotbar[5]==id and inventory.hotbar[6]==false and inventory.active==2,'Actual purchase fills first empty shortcut and preserves active slot')
    card=Find(edit.shop,function(w) return w.props.shop and w.props.text==require('parts.Defs').PARTS[id].name end);card.props.onClick(card)
    local count=0;for i=1,10 do if inventory.hotbar[i]==id then count=count+1 end end
    V.assert(count==1 and controller.run.inventory[id]==stock+2,'Actual repeat purchase adds stock without duplicate shortcut')
    edit.shop:Close();controller.run.credits=oldCredit
    local expected=require('construction.Blueprint').New():Load(controller.run.blueprint):ToTable()
    editor.history.undoStack={{qa=true}};editor.history.redoStack={{qa=true}}
    editor.selection={[1]=true};editor.selectionOrder={1};editor.selectionCorners={{id=1}}
    editor.clipboard={{type='cube'}};editor.pasting=true;editor.stretch={phase='rect'}
    for _,key in ipairs({'hit','preview','focusIds','boxing','down','hold','rotorAim','turretPreview','dragPreview'}) do editor[key]={qa=true} end
    b.controls.pointer={qa=true};b.controls.selectionBox={};b.controls.dragSelection={};b.controls.touchPrimary=true
    local reset=Find(edit.bar.root,function(w) return w.props.text=='重置本次改装' end)
    V.assert(reset and reset.props.onClick,'Actual reset control is mounted')
    reset.props.onClick(reset)
    V.assert(Equal(edit.host.blueprint:ToTable(),expected),'Actual Reset restores exact normalized entry blueprint')
    V.assert(#editor.history.undoStack==0 and #editor.history.redoStack==0 and next(editor.selection)==nil and #editor.selectionOrder==0 and #editor.selectionCorners==0,'Actual Reset clears undo redo and every selection representation')
    V.assert(#editor.clipboard==0 and not editor.pasting and not editor.stretch,'Actual Reset clears pending paste and stretch')
    local clean=true;for _,key in ipairs({'hit','preview','focusIds','boxing','down','hold','rotorAim','turretPreview','dragPreview'}) do clean=clean and editor[key]==nil end
    V.assert(clean and not b.controls.pointer and not b.controls.selectionBox and not b.controls.dragSelection and not b.controls.touchPrimary,'Actual Reset clears transient tools pointer and touch holds')
    V.assert(inventory.hotbar[5]==id and controller.run.inventory[id]==stock+2,'Actual Reset preserves purchased stock and shortcut')
    for _,key in ipairs({'home','trial','save','help'}) do V.assert(b.hud.buttons[key].props.disabled,'Retained editor blocks source forbidden toolbar '..key) end
    V.assert(b.SaveSlot==b.OpenLibrary,'Ctrl S invokes the same source unavailable action')
    Capture('edit-reset')
    V.assert(edit:Depart().ok and not controller.edit,'Actual departure restores retained battlefield')
    local Run=require 'salvage.Run'
    local run=setmetatable({rules={time=0,search={items={{state='full'}}}}},Run)
    local oldSalvage=s.salvage;s.salvage=run;run:TouchContext()
    local root=UI.GetRoot();local controls=require('ui.TouchDriveControls').Create(s,root)
    controls.Update(false)
    V.assert(controls.contextRole=='swap' and controls.buttons.interact:IsVisible() and controls.buttons.interact.props.text=='换货','Real native touch context shows full cargo swap role')
    local gesture=controls.gestures;gesture.adapter.Action('interact')
    V.assert(run.tapF==true,'Actual touch swap adapter routes F action to salvage run')
    Capture('touch-swap')
    run.rules.search=nil;run.rules.prompt={title='locked',blocked=true};run:TouchContext();controls.Update(false)
    V.assert(controls.contextRole==nil and not controls.buttons.interact:IsVisible(),'Blocked search prompt hides actual touch interaction')
    run.rules.prompt={title='crate'};run:TouchContext();controls.Update(false)
    V.assert(controls.contextRole=='interact' and controls.buttons.interact:IsVisible(),'Unblocked source prompt restores actual touch interaction')
    local feedback=s.cameraFeedback;feedback:Reset()
    local cameraNode=s.camera:GetNode();local before=cameraNode.position
    run.session=s;run.audio={Event=function() end};run.rules.events={{type='cargoPickup',items={{'scrap',2}}}}
    run.rules.Drain=function(r) local events=r.events;r.events={};return events end
    run:Events()
    V.assert(math.abs(s.stompV+.65)<1e-9,'Actual Run.Events writes source 16 kg pickup impulse into session spring')
    feedback:Apply(1/60,cameraNode,nil)
    V.assert(cameraNode.position.y<before.y and math.abs(cameraNode.position.y-before.y-s.stompY)<1e-6,'Actual CameraFeedback.Apply consumes pickup spring and moves native camera down')
    feedback:Reset();cameraNode.position=before
    run.rules.finished=true;run:AfterStep(.016);controls.Update(false)
    V.assert(not run.touchPrompt and not run.touchSwap and controls.contextRole==nil and not controls.buttons.interact:IsVisible(),'Finished production AfterStep clears actual touch context')
    controls.Dispose();s.salvage=oldSalvage
    app:Reload();phase='return'
end
local function Poll()
    if phase=='boot' and VOX_HANGAR then
        local app=VOX_HANGAR.app;app.blueprint:Load(require('endless.Data').starters[1].source)
        V.assert(app:EnterTrial('endless'),'Actual frozen package entry starts endless map loader');phase='loading'
    elseif phase=='loading' and VOX_HANGAR.app.trial and not VOX_HANGAR.app.loadingFlow.active then
        worker=coroutine.create(function() Exercise(VOX_HANGAR.app) end);phase='exercise'
    elseif phase=='exercise' then
        local ok,err=coroutine.resume(worker)
        if not ok then V.assert(false,debug.traceback(worker,tostring(err)));phase='failed';VOX_HANGAR.app:Stop();V.finish() end
    elseif phase=='return' and not VOX_HANGAR.app.trial and not VOX_HANGAR.app.loadingFlow.active and not VOX_HANGAR.app.pendingAssetRelease then
        V.assert(true,'Real editor and controlled touch overlay return through production loader');VOX_HANGAR.app:Stop();phase='done';V.finish()
    end
end
V.atFrame(3,function() engine.maxInactiveFps=1000;engine.maxFps=1000 end)
for i=40,4500 do V.atFrame(i,Poll) end
V.atFrame(4505,function() V.assert(phase=='done','G5 increment native run completed');V.finish() end)

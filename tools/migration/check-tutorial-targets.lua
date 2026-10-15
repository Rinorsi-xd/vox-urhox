local UI=require 'urhox-libs/UI'
local Event=require 'urhox-libs/UI/Core/PointerEvent'
local Touch=require 'controls.TouchMode'
local app,build,tutorial ---@type table|nil
local phase='boot';local entered=0;local finished=false
local function Change(name,frame) phase=name;entered=frame end
local function Click(widget,touch)
    assert(widget,'missing production tutorial target');UI.Layout()
    local r=widget:GetAbsoluteLayoutForHitTest();local scale=UI.GetScale()
    assert(r.w>2 and r.h>2,'missing actual target hit bounds')
    local p={pointerType=touch and 'touch' or 'mouse',pointerId=31,x=(r.x+r.w/2)*scale,y=(r.y+r.h/2)*scale,button=MOUSEB_LEFT}
    UI.HandlePointerEvent(Event.new('PointerDown',p));UI.HandlePointerEvent(Event.new('PointerUp',p))
end
local function Contains(widget,label)
    UI.Layout();local target=tutorial.page:Target();local r=widget:GetAbsoluteLayoutForHitTest()
    V.assert(target and target.w>2 and target.h>2,label..' uses nonzero live target')
    assert(target,'missing target '..label)
    V.assert(target.x<=r.x+.1 and target.y<=r.y+.1 and target.x+target.w>=r.x+r.w-.1 and target.y+target.h>=r.y+r.h-.1,label..' contains actual visible control')
    print('[TutorialTarget] '..cjson.encode({id=tutorial.rules:StepSpec().id,label=label,target=target,control=r,physical={graphics:GetWidth(),graphics:GetHeight()},uiScale=UI.GetScale()}))
end
local function Place()
    local e=app.editor;e.mirror=false;e:SelectType('cube')
    for _,p in ipairs(e.bp:List())do for _,cell in ipairs(p._cells)do
        e:Preview({hit=true,partId=p.id,cell=cell,place={cell[1],cell[2]+1,cell[3]},normal={0,1,0}})
        if e.preview and e.preview.res.ok and e:Place()then build:Refresh();return true end
    end end
    return false
end
local function Tick(frame)
    if phase=='boot' then
        if not VOX_HANGAR or VOX_HANGAR.app.loadingFlow.active then return end
        app=VOX_HANGAR.app;app.store=require('storage.BlueprintStore').New('vox-tutorial-targets-'..os.time());app.bays.store=app.store
        app.bays.active=false;app.bays.unsaved=true;Touch.override=true;app:EnterBuild();build=app.build;tutorial=app.tutorial
        assert(build and build.hud.touchControls,'actual production touch builder unavailable');tutorial:Replay();Change('bag',frame)
    elseif frame-entered<8 then return
    elseif phase=='bag' then
        if tutorial.rules:StepSpec().id~='bag' then return end
        Contains(build.hud.touchControls.buttons['me-bag'],'touch bag')
        V.assert(not build.hud.toolbar:IsVisible() and not build.hud.dock:IsVisible(),'touch tutorial excludes hidden PC toolbar and dock ancestors')
        Click(build.hud.touchControls.buttons['me-bag'],true)
        V.assert(build.inventoryPanel~=nil,'real touch bag click opens production inventory');Change('pick',frame)
    elseif phase=='pick' then
        if tutorial.rules:StepSpec().id~='pick' then return end
        Contains(build.inventoryPanel.body,'inventory body');Click(build.inventoryPanel.closeButton,true)
        V.assert(build.inventoryPanel==nil,'real touch close click returns to production editor');Change('place',frame)
    elseif phase=='place' then
        if tutorial.rules:StepSpec().id~='place' then return end
        local visible=0
        for _,slot in ipairs(build.hud.touchControls.slots)do if slot:IsVisible()then Contains(slot,'touch slot '..tostring(visible+1));visible=visible+1 end end
        V.assert(visible>=8,'source visible touch slots all remain inside assembly target')
        local before=app.blueprint:Size();V.assert(Place() and app.blueprint:Size()~=before,'actual connected cube placement satisfies original count-change condition');Change('save',frame)
    elseif phase=='save' then
        if tutorial.rules:StepSpec().id~='save' then return end
        Contains(build.hud.touchControls.buttons['me-save'],'touch save');Click(build.hud.touchControls.buttons['me-save'],true)
        V.assert(app.bays.active and not app.bays.unsaved,'real touch save click writes actual garage bay')
        Change('replay-complete',frame)
    elseif phase=='replay-complete' then
        if tutorial.rules.running then return end
        tutorial.rules:Start(9,'build',tutorial:State());Change('back',frame)
    elseif phase=='back' then
        V.assert(tutorial.rules:StepSpec().id=='back','back fixture uses original build route target')
        Contains(build.hud.touchControls.buttons['me-back'],'touch back');Click(build.hud.touchControls.buttons['me-back'],true)
        V.assert(not app.build,'real touch back click returns to production garage');tutorial.rules:Stop();Touch.override=false;app:EnterBuild();build=app.build
        tutorial:Replay();Change('pc-bag',frame)
    elseif phase=='pc-bag' then
        V.assert(not build.hud.touchControls,'actual PC builder has no touch controls')
        Contains(build.hud.hotbar.root,'PC bag');tutorial.rules:Start(8,'build',tutorial:State());Change('pc-save',frame)
    elseif phase=='pc-save' then
        Contains(build.hud.buttons.save,'PC save');tutorial.rules:Start(9,'build',tutorial:State());Change('pc-back',frame)
    elseif phase=='pc-back' then
        Contains(build.hud.buttons.home,'PC back');tutorial.rules:Stop();app:ExitBuild();Touch.override=nil;finished=true;V.finish()
    end
end
for frame=5,590 do V.atFrame(frame,function()
    if finished then return end
    local ok,err=pcall(Tick,frame)
    if not ok then V.assert(false,'tutorial target '..phase..': '..tostring(err));finished=true;Touch.override=nil;V.finish() end
end)end
V.atFrame(595,function()if not finished then V.assert(false,'tutorial target deadline at '..phase);Touch.override=nil;V.finish()end end)

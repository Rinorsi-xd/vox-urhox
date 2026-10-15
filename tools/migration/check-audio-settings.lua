local UI=require 'urhox-libs/UI'
local Event=require 'urhox-libs/UI/Core/PointerEvent'
local Levels=require 'audio.AudioLevels'
local Host=require 'ui.DialogHost'
engine.maxInactiveFps=120
local app,home,modal,session,pause ---@type table|nil
local phase,phaseFrame,finished='boot',0,false
local destination='docs/migration/evidence'
for _,arg in ipairs(GetArguments()) do destination=arg:match('^%-audio%-ui%-out=(.+)$') or destination end
local function Click(widget)
    assert(widget,'missing actual audio widget');UI.Layout()
    local r=widget:GetAbsoluteLayoutForHitTest();local scale=UI.GetScale()
    assert(r.w>0 and r.h>0,'audio widget has actual hit-test layout')
    local p={pointerType='mouse',pointerId=1,x=(r.x+r.w/2)*scale,y=(r.y+r.h/2)*scale,button=MOUSEB_LEFT}
    UI.HandlePointerEvent(Event.new('PointerDown',p));UI.HandlePointerEvent(Event.new('PointerUp',p))
end
local function Key(widget,key)
    UI.SetFocus(widget);UI.HandleKeyDown(key);UI.HandleKeyUp(key)
end
local function Percent(widget,value)
    Key(widget,KEY_HOME);for _=1,value do Key(widget,KEY_RIGHT) end
end
local function Shot(name)
    local target=session and session.dialog or modal
    local r=target and target.modalLayout_;local k=target and target.sourceScale
    if r and k then
        local w,h=UI.GetViewportSize();local expectedH=math.min((target.compact and 376.25 or 424.25)*k,h*.86)
        V.assert(math.abs(r.w-math.min(780*k,w*.92))<1 and math.abs(r.h-expectedH)<1,'actual '..name..' source modal dimensions and reference scale')
        print('[AudioSettingsLayout] '..cjson.encode({phase=name,rect=r,scale=k,compact=target.compact,uiScale=UI.GetScale(),physical={graphics:GetWidth(),graphics:GetHeight()}}))
    end
    local image=Image();V.assert(graphics:TakeScreenShot(image),'audio settings actual rendered '..name)
    V.assert(image:SavePNG(destination..'/'..name..'.png'),'audio settings screenshot saved '..name);image:Dispose()
end
local function Change(nextPhase,frame) phase=nextPhase;phaseFrame=frame end
local function Tick(frame)
    if finished then return end
    if not app and VOX_HANGAR then app=VOX_HANGAR.app end
    if not app then return end
    if phase=='boot' then
        if app.loadingFlow.active then return end
        home=require('ui.GarageHud').GetState();if not home then return end
        pause=require('ui.PauseMenu').Open(home)
        V.assert(pause.actions.audio and pause.actions.audio.props.text=='声音与音乐','source audio row exists in production pause menu')
        Change('pause-presented',frame)
    elseif phase=='pause-presented' and frame-phaseFrame>=20 then
        Click(pause.actions.audio);modal=home.dialog
        V.assert(modal~=pause and modal and modal.controls and modal.controls.sfx and modal.controls.voice and modal.controls.music,'pause audio row opens all three controls through real pointer routing')
        assert(modal and modal.controls,'actual audio click did not open modal');Change('home-controls',frame)
    elseif phase=='home-controls' and frame-phaseFrame>=20 then
        local player=app.music
        Click(modal.controls.musicEnabled)
        V.assert(not player.enabled and not Levels.Get('musicEnabled'),'real checkbox disables scene music and shared level')
        Click(modal.controls.musicEnabled)
        V.assert(player.enabled and Levels.Get('musicEnabled'),'real checkbox restores scene music')
        Key(modal.controls.voice,KEY_HOME)
        V.assert(Levels.Get('voice')==0,'routed keyboard home on actual voice slider immediately mutes voice')
        Key(modal.controls.voice,KEY_RIGHT);V.assert(Levels.Get('voice')==.01,'routed keyboard increment persists integer percent')
        Key(modal.controls.voice,KEY_END);V.assert(Levels.Get('voice')==1,'routed keyboard end reaches full voice range')
        Percent(modal.controls.sfx,25);Percent(modal.controls.music,40)
        V.assert(Levels.Get('sfx')==.25 and player.volume==.4,'routed source sliders update effects and retained music player separately')
        local saved=app.store:Read(Levels.KEY,Levels.Valid)
        V.assert(saved and saved.voice==1 and saved.sfx==.25 and saved.music==.4,'all audio values persist through real BlueprintStore')
        local cloud=require('storage.CloudStorage')
        V.assert(cloud.Decode(cjson.encode({v=1,generation=1,data=saved}),'vox-save-v1-vox-garage-'..Levels.KEY)~=nil,'cloud restore accepts real audio record')
        V.assert(cloud.Decode(cjson.encode({v=1,generation=1,data={sfx=5,music=.4,voice=1,musicEnabled=true}}),'vox-save-v1-vox-garage-'..Levels.KEY)==nil,'cloud restore rejects corrupt out of range audio record')
        Click(modal.actions.pause);home.dialogTick()
        V.assert(player.userPaused and modal.actions.pause.props.text=='继续音乐' and modal.actions.next.props.disabled,'paused music updates label and disables next')
        V.assert(modal.status:GetText()=='音乐已暂停','source now playing status follows actual player')
        Change('home-shot',frame)
    elseif phase=='home-shot' and frame-phaseFrame>=15 then
        Shot('home-paused');Click(modal.actions.pause);home.dialogTick()
        V.assert(not app.music.userPaused and not modal.actions.next.props.disabled,'resume restores next track action')
        Click(modal.actions.done)
        V.assert(home.dialog==nil and home.dialogTick==nil,'closing settings retires callbacks and releases owner')
        modal=require('ui.AudioSettings').Open(home)
        V.assert(modal.controls.sfx.props.value==25 and modal.controls.music.props.value==40 and modal.controls.voice.props.value==100,'reopened controls restore independent saved values')
        Change('reopened',frame)
    elseif phase=='reopened' and frame-phaseFrame>=20 then
        Click(modal.actions.done);Change('retire-home-modal',frame)
    elseif phase=='retire-home-modal' and frame-phaseFrame>=20 then
        V.assert(home.dialog==nil and home.closingDialog==nil,'home modal fully retires before scene handoff')
        Levels.Set('sfx',.65);Levels.Set('voice',.6);app.music:SetVolume(.75)
        V.assert(app:EnterTrial()~=false,'production trial entry accepts unchanged vehicle');Change('trial-loading',frame)
    elseif phase=='trial-loading' then
        if not app.trial or app.loadingFlow.active then return end
        session=app.trial
        V.assert(session.hud.buttons.audio and session.hud.buttons.audio.props.text=='声音','production trial HUD owns source audio entry')
        session.HasFocus=function() return true end
        session:Pause();session.hud.Update(session,0);Change('trial-presented',frame)
    elseif phase=='trial-presented' and frame-phaseFrame>=20 then
        Click(session.hud.buttons.audio)
        V.assert(session.dialog and session.dialog.controls and session.dialog.controls.sfx,'actual trial audio entry opens shared modal through pointer routing')
        assert(session.dialog and session.dialog.controls,'actual trial audio click failed')
        V.assert(not session.pointer.captured,'audio dialog releases driving pointer lock');Change('trial-audio',frame)
    elseif phase=='trial-audio' and frame-phaseFrame>=20 then
        Shot('trial-audio');Click(session.dialog.actions.done)
        V.assert(session.dialog==nil and session.dialogTick==nil,'trial audio modal close releases dialog and callbacks')
        session.wantsReturn=true;Change('returning',frame)
    elseif phase=='returning' and not app.trial and not app.loadingFlow.active then
        V.assert(require('ui.GarageHud').GetState()~=nil,'settings interaction returns to production home')
        finished=true;V.finish()
    end
end
for frame=5,1090 do V.atFrame(frame,function()
    if finished then return end
    local ok,err=pcall(Tick,frame)
    if not ok then V.assert(false,'audio UI phase '..phase..': '..tostring(err));finished=true;V.finish() end
end) end
V.atFrame(1095,function() if not finished then V.assert(false,'audio production flow deadline phase '..phase);finished=true;V.finish() end end)

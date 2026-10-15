local UI=require 'urhox-libs/UI'
local Event=require 'urhox-libs/UI/Core/PointerEvent'
local Host=require 'ui.DialogHost'
local Settings=require 'ui.GameSettings'
local Levels=require 'audio.AudioLevels'
local Touch=require 'controls.TouchMode'
local session=nil ---@type table|nil
local scene=nil ---@type Scene|nil
local modal=nil ---@type table|nil
local touch=false;local destination='docs/migration/evidence';local records={};local resumes=0;local screenshots={}
for _,arg in ipairs(GetArguments()) do destination=arg:match('^%-settings%-out=(.+)$') or destination;if arg=='-settings-touch' then touch=true end end
local function Check(ok,label) V.assert(ok,'Unified settings: '..label) end
local function Click(widget)
    assert(widget,'missing routed settings control');UI.Layout();local r=widget:GetAbsoluteLayoutForHitTest();local k=UI.GetScale()
    Check(r.w>0 and r.h>0,'actual control has hit-test bounds')
    local p={pointerType=touch and 'touch' or 'mouse',pointerId=183,x=(r.x+r.w/2)*k,y=(r.y+r.h/2)*k,button=MOUSEB_LEFT}
    UI.HandlePointerEvent(Event.new('PointerDown',p));UI.HandlePointerEvent(Event.new('PointerUp',p))
end
local function Key(widget,key) UI.SetFocus(widget);UI.HandleKeyDown(key);UI.HandleKeyUp(key) end
local function Poll(key,typing)
    local original=session.KeyPressed
    session.KeyPressed=function(_,candidate) return candidate==key end
    session:PollKeys(typing==true)
    session.KeyPressed=original
end
local function Shot(name)
    local m=session.dialog;local r=m and m.modalLayout_;local sw,sh=UI.GetViewportSize()
    Check(r and r.x>=-1 and r.y>=-1 and r.x+r.w<=sw+1 and r.y+r.h<=sh+1,'actual '..name..' card stays inside viewport')
    screenshots[#screenshots+1]={name=name,physical={graphics:GetWidth(),graphics:GetHeight()},logical={sw,sh},dpr=graphics:GetDPR(),scale=m.sourceScale,compact=m.compact,rect=r}
    local image=Image();Check(graphics:TakeScreenShot(image),'actual screenshot '..name);Check(image:SavePNG(destination..'/'..name..'.png'),'saved screenshot '..name);image:Dispose()
end
local function Menu()
    Check(session.dialog and session.dialog.unifiedSettings,'same source pause card owns shared settings')
    Check(not session.pointer.captured and not session.wantsReturn,'settings does not capture input or return to garage')
    return session.dialog
end
for frame=3,361 do V.atFrame(frame,function()if session then Host.Update(session,1/60) end end) end
V.atFrame(2,function()
    Touch.override=touch
    local fonts=require('ui.SourceFonts').Resolve()
    UI.Init({theme='default-dark',scale=UI.Scale.DEFAULT,fonts={{family='sans',weights={normal=fonts.body,bold=fonts.bold}}}})
    scene=Scene();scene:CreateComponent('Octree')
    local app={ownsScene=false,store={Read=function(_,key)return records[key] end,Write=function(_,key,value)records[key]=value;return true end},toasts={Push=function()end}}
    Levels.Init(app.store)
    local music={enabled=true,volume=Levels.Get('music'),userPaused=false}
    function music:SetEnabled(on) self.enabled=on;Levels.SetMusicEnabled(on) end
    function music:SetVolume(value) self.volume=value;Levels.Set('music',value) end
    function music:SetPaused(on) self.userPaused=on end
    function music:Track() return {title='测试场景曲'} end
    function music:Next() end
    app.music=music;app.graphicsSettings=require('render.GraphicsSettings').New(app)
    session=require('app.TrialSession').New(scene,require('construction.Prefab').BuildRaceCar(require('construction.Blueprint').New()),app)
    session.hud=require('ui.DriveHud').Create(session)
    renderer:SetViewport(0,Viewport:new(scene,session.camera:GetCamera()))
    local originalResume=session.Resume;session.Resume=function(self)resumes=resumes+1;return originalResume(self)end
    session:Resume();Check(session:HasFocus(),'native input focus permits actual PollKeys')
    Poll(KEY_ESCAPE)
    Check(not session.pointer.captured and session.dialog==nil and not session.wantsReturn,'actual first Escape only releases driving pointer')
    Poll(KEY_ESCAPE);modal=Menu()
    Poll(KEY_ESCAPE,true);Check(session.dialog==modal,'typing gate prevents Escape from closing settings')
    Poll(KEY_T);Check(session.dialog==modal and not session.wantsReturn,'dialog blocks gameplay return shortcut')
    Poll(KEY_ESCAPE);Check(session.dialog==nil and not session.pointer.captured,'actual PollKeys Escape closes settings and remains released')
    Poll(KEY_ESCAPE);modal=Menu()
    Check(modal.actions.resume and modal.actions['return'] and modal.actions.graphics and modal.actions.audio,'visible continue, source garage return, graphics and audio entries remain')
    Check(session.hud.buttons.settings==session.hud.buttons.audio and session.hud.buttons.settings.props.text=='设置','actual DriveHud owns shared settings entry')
    Check(touch and modal.actions.touch~=nil or not touch and modal.actions.help~=nil,'platform-specific source settings actions remain')
end)
V.atFrame(42,function() Shot('menu');Click(modal.actions.audio);modal=session.dialog;Check(modal.controls.voice and modal.controls.music,'routed menu opens shared sound controls') end)
V.atFrame(82,function()
    local before=resumes;Key(modal.controls.voice,KEY_HOME);Key(modal.controls.voice,KEY_RIGHT)
    Check(Levels.Get('voice')==.01 and records[Levels.KEY].voice==.01,'actual keyboard slider saves voice level')
    Shot('audio');Click(modal.actions.done);modal=Menu();Check(resumes==before,'sound return does not recapture input')
end)
V.atFrame(122,function() Click(modal.actions.graphics);modal=session.dialog;Check(modal.controls.exposure and modal.actions.done.props.text=='返回设置','routed graphics uses common return navigation') end)
V.atFrame(162,function()
    Key(modal.controls.exposure,KEY_HOME);Key(modal.controls.exposure,KEY_RIGHT)
    Check(math.abs(session.app.graphicsSettings.data.exposure-.61)<.00001,'actual graphics slider changes real GraphicsSettings')
    local before=resumes;Shot('graphics');Click(modal.actions.done);modal=Menu()
    Check(records.graphics and math.abs(records.graphics.exposure-.61)<.00001,'leaving graphics flushes existing persistent settings')
    Check(resumes==before,'graphics return does not recapture input')
end)
V.atFrame(182,function() if touch then Click(modal.actions.touch);modal=session.dialog;Check(modal.settings~=nil,'shared settings opens actual touch controls after card layout') end end)
V.atFrame(202,function()
    if touch then
        local before=resumes;local choice=modal.settings.refs.sens[3].button
        Click(choice);Check(session.app.touchPrefs.sens==1.5 and records['touch-settings'].sens==1.5,'touch settings real buttons save and refresh actual DriveHud without missing Refresh method')
        Shot('touch');Click(modal.actions.done);modal=Menu();Check(resumes==before,'touch return does not recapture input')
    end
end)
V.atFrame(242,function()
    local before=resumes;Click(modal.actions.resume)
    Check(session.dialog==nil and session.pointer.captured and resumes==before+1,'visible continue captures exactly once and keeps actual session/world')
    session:Pause();session.hud.Update(session,0)
    Click(session.hud.buttons.settings);modal=Menu()
    Check(not session.wantsReturn,'actual HUD settings opens same panel and preserves world')
end)
V.atFrame(282,function()
    if touch then
        Host.Close(session);Host.Update(session,.2)
        local layer=session.hud.touchControls
        layer.Update(false)
        Check(layer.menuButtons.settings and layer.menuButtons.teleport and layer.menuButtons.spawn,'practice touch menu keeps settings and source teleport/spawn actions')
        layer.SetMenu(true);UI.Layout();local before=resumes;Click(layer.menuButtons.settings);modal=Menu()
        Check(resumes==before,'touch menu settings avoids transient Resume/recapture')
    end
end)
V.atFrame(322,function()
    if touch then
        Host.Dispose(session)
        local calls={};session.endless={run={state='rest'},rules={finished=false},HandleKey=function(_,key)calls.repair=key==KEY_V end,NextWave=function()calls.wave=true end,EnterEdit=function()calls.refit=true end}
        local layer=require('ui.TouchDriveControls').Create(session,session.hud.root)
        Check(layer.menuButtons.settings and layer.menuButtons.repair and layer.menuButtons.wave and layer.menuButtons.refit,'endless touch menu retains all source mode-specific commands')
        for _,id in ipairs({'repair','wave','refit'}) do layer.SetMenu(true);UI.Layout();Click(layer.menuButtons[id]) end
        Check(calls.repair and calls.wave and calls.refit,'real endless menu buttons still dispatch repair, next wave, and refit')
        layer.Dispose();layer.root:Destroy();session.endless=nil;session:Pause();modal=Settings.Open(session)
    end
end)
V.atFrame(362,function()
    Click(modal.actions['return']);Check(session.dialog==nil and session.wantsReturn,'garage action sets existing return request instead of bypassing controller gate')
    local report=assert(io.open(destination..'/layouts.json','w'));report:write(cjson.encode(screenshots));report:close()
    session:Dispose();scene:Dispose();UI.Shutdown();Touch.override=nil;V.finish()
end)

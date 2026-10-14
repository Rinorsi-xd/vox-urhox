local UI=require 'urhox-libs/UI'
local Flow=require 'app.LoadingFlow'
local Event=require 'urhox-libs/UI/Core/PointerEvent'
local app=nil ---@type HangarApp|nil
local originalScene=nil ---@type Scene|nil
local stage='boot';local zoomChecked=false;local phases={}
local partialSession=nil ---@type table|nil
local newTrial=require('app.TrialSession').New
local function Click(x,y)
    local scale=UI.GetScale()
    for _,kind in ipairs({'PointerDown','PointerUp'}) do UI.HandlePointerEvent(Event.new(kind,{x=x*scale,y=y*scale,pointerId=97,pointerType='mouse',button=MOUSEB_LEFT})) end
end
local function Rules()
    local visibility=true;local back=0
    local fake={graphicsSettings={SetSceneVisible=function(_,value) visibility=value end}}
    local flow=Flow.New(fake);local map=require('app.DriveMaps').trial
    flow:Open(map,function() back=back+1 end)
    V.assert(flow.active and flow.phase=='cover' and not flow.pageVisible,'cover starts before loading page is shown')
    V.assert(UI.GetTopOverlay()==flow.page and UI.FindWidgetAt(12,12)==flow.page,'loading owns actual native hit testing')
    local loader={phase='download',gate={total=8,completed=2}}
    flow:Observe(loader,12);V.assert(flow.progress==0 and flow.steps[1].note=='2 / 8','partial download never marks task complete')
    flow:Advance(.549);V.assert(not flow.pageVisible,'source 550ms cover duration is respected')
    flow:Advance(.0011);V.assert(flow.pageVisible and flow.phase=='reveal','page opens only under full cover')
    flow:Advance(.59);V.assert(flow.phase=='loading','source 590ms reveal finishes before steady loading')
    loader.phase='scene';flow:Observe(loader,.1)
    V.assert(flow.progress==2/6 and flow.steps[1].state=='done' and flow.steps[3].state=='run','checklist advances from actual loader phase')
    flow:Finish();flow:Advance(.1);V.assert(flow.phase=='loading' and flow.progress<1,'scene installation alone cannot announce rendered readiness')
    flow.steps[#flow.steps].elapsed=25
    flow:Observe({phaseTimes={activate=.04}},0)
    V.assert(flow.steps[#flow.steps].elapsed>=25,'short activation measurement cannot erase a long rendered-frame wait')
    flow:Rendered();flow:Advance(.1);V.assert(flow.phase=='loading','one rendered frame cannot complete warm-up')
    flow:Rendered();flow:Advance(.1);V.assert(flow.phase=='ready' and flow.progress==1,'two rendered frames complete final task')
    flow:Advance(.449);V.assert(flow.phase=='ready','ready remains visible for source 450ms')
    flow:Advance(.0011);V.assert(flow.phase=='exit-cover','success covers loading page before revealing scene')
    flow:Advance(.55);V.assert(not flow.pageVisible and flow.phase=='exit-reveal','loading page closes behind cover')
    flow:Advance(.59);V.assert(not flow.active and UI.GetTopOverlay()~=flow.page and visibility,'completion releases blocker and restores viewport')
    flow:Open(map,function() back=back+1 end);flow:Fail('fixture failed');flow:Advance(.55);flow:Advance(.59)
    V.assert(flow.failed and flow.active and flow.steps[1].state=='fail' and flow.error=='fixture failed','failure stays visible and preserves concrete error')
    flow:Back();flow:Back();V.assert(back==1 and flow.phase=='exit-cover','repeated return invokes cancellation once')
    flow:Close();flow:Open(map)
    V.assert(not flow.cancelled,'reopening after cancellation starts a fresh transition')
    local intro=0;fake.trial={StartIntro=function() intro=intro+1 end}
    flow.match={};flow.finished=true;flow:Close()
    V.assert(intro==1,'cancel then retry can start the battle cinematic')
    flow:Dispose()
    V.assert(not flow.active and flow.disposed and not flow.page and UI.GetTopOverlay()==nil,'dispose drops page, callbacks and overlay')
end
local function Poll()
    if not app then
        if not VOX_HANGAR then return end
        app=VOX_HANGAR.app;originalScene=app.scene;Rules()
        V.assert(app:EnterTrial('trial'),'real trial begins through loading flow')
        app.loader.options.prepare=function() error('intentional loading-flow preparation failure') end
        stage='failure';return
    end
    local flow=app.loadingFlow;phases[flow.phase]=true
    if flow.active then
        V.assert(UI.FindWidgetAt(20,20)==flow.page,'overlay blocks bottom scene throughout real transition')
    end
    if stage=='failure' and flow.failed and flow.page.backRect then
        V.assert(app.scene==originalScene and not app.trial,'failed trial preserves authored hall')
        local r=flow.page.backRect;Click(r.x+r.w/2,r.y+r.h/2)
        V.assert(flow.phase=='exit-cover','real error return button responds to native pointer dispatch')
        stage='failed-return'
    elseif stage=='failed-return' and not flow.active then
        V.assert(app.scene==originalScene and renderer:GetViewport(0)~=nil,'error return restores original viewport')
        require('app.TrialSession').New=function(scene,bp,owner,map,world,checkpoint,retain)
            return newTrial(scene,bp,owner,map,world,checkpoint,function(candidate)
                partialSession=candidate;if retain then retain(candidate) end
            end)
        end
        V.assert(app:EnterTrial('trial'),'partial session retry starts')
        stage='cancel-session'
    elseif stage=='cancel-session' and partialSession then
        V.assert(not partialSession.disposed and app.scene==originalScene and not app.trial,'candidate session stays private while preparation yields')
        V.assert(app:CancelMapLoad(true),'cancel is accepted after session ownership transfers')
        V.assert(partialSession.disposed and not app.loader.pending and not app.loader.job,'cancel disposes retained partial session and scene')
        require('app.TrialSession').New=newTrial
        flow:Close();stage='cancelled-session'
    elseif stage=='cancelled-session' then
        V.assert(app.scene==originalScene and not app.trial,'cancelled partial session preserves original hall')
        V.assert(app:EnterTrial('trial'),'real retry uses same application')
        stage='enter'
    elseif stage=='enter' and app.trial and not flow.active then
        local t=app.trial
        V.assert(app.hangar==nil and t.scene==app.scene,'successful activation releases hall and installs one trial')
        V.assert(not t.pointer.captured and not t.pointer.pending,'PC never captures mouse behind loading page')
        local d=t.cameraDistance;t:Zoom(-1)
        V.assert(math.abs(t.cameraDistance-d*1.0012^100)<.0001,'native notch uses original CSS pixel zoom curve')
        t:Zoom(1);V.assert(math.abs(t.cameraDistance-d)<.0001,'opposite notch exactly restores trial distance')
        local platform=require('urhox-libs.Platform.PlatformUtils');local web=platform.IsWebPlatform
        platform.IsWebPlatform=function() return true end;t:Zoom(-100)
        V.assert(math.abs(t.cameraDistance-d*1.0012^100)<.0001,'Web 100px wheel is not multiplied twice')
        t:Zoom(100);platform.IsWebPlatform=web
        V.assert(math.abs(t.cameraDistance-d)<.0001,'Web opposite wheel restores distance')
        zoomChecked=true;app:Reload();stage='return'
    elseif stage=='return' and app.mode=='hangar' and not flow.active then
        V.assert(app.trial==nil and app.car and app.hangar,'return completes without lingering gameplay owners')
        V.assert(phases.cover and phases.reveal and phases.loading and phases.ready and phases['exit-cover'] and phases['exit-reveal'],'all source transition phases executed in real runtime')
        V.assert(zoomChecked and UI.GetTopOverlay()==nil,'final input and camera checks completed')
        stage='done';V.finish()
    end
end
for frame=35,740 do V.atFrame(frame,Poll) end
V.atFrame(745,function() V.assert(stage=='done','loading failure retry and return completed');V.finish() end)

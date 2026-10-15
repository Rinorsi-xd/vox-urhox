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
    local Warmup=require 'render.SceneWarmup'
    local drawables={}
    for i=1,19 do drawables[i]={viewMask=i==19 and 0 or i} end
    local warm=Warmup.New({GetComponents=function(_,kind) return kind=='StaticModel' and drawables or {} end},8)
    V.assert(#warm.items==18 and warm.batches==1,'warm-up preserves nonzero drawable masks and leaves hidden objects hidden')
    for i,item in ipairs(drawables) do V.assert(item.viewMask==(i<=8 and i or 0),'only first rendering batch is exposed '..i) end
    V.assert(not warm:Rendered(),'first presented batch advances without announcing full readiness')
    V.assert(drawables[1].viewMask==0 and drawables[9].viewMask==9,'next batch retires previous drawables')
    warm:Restore()
    for i,item in ipairs(drawables) do V.assert(item.viewMask==(i==19 and 0 or i),'cancellation restores exact original view mask '..i) end
    warm=Warmup.New({GetComponents=function(_,kind) return kind=='StaticModel' and drawables or {} end},8)
    V.assert(not warm:Rendered() and not warm:Rendered() and warm:Rendered(),'all three batches must render before full scene is restored')
    for i,item in ipairs(drawables) do V.assert(item.viewMask==(i==19 and 0 or i),'completion restores exact original view mask '..i) end
    local scene=Scene();local camNode=scene:CreateChild('Camera');local camera=camNode:CreateComponent('Camera')
    camera.farClip=50;camera.aspectRatio=16/9
    local near=scene:CreateChild('Near');near.position=Vector3(0,0,5)
    local visible=near:CreateComponent('StaticModel');visible.model=cache:GetResource('Model','Models/Box.mdl')
    local far=scene:CreateChild('Far');far.position=Vector3(0,0,-20)
    local outside=far:CreateComponent('StaticModel');outside.model=visible.model
    warm=Warmup.New(scene,8,camera)
    V.assert(#warm.items==1 and warm.skipped==1,'real camera frustum excludes empty off-screen preparation batches')
    V.assert(visible.viewMask~=0 and outside.viewMask==0,'only visible geometry is submitted during preparation')
    warm:Restore();V.assert(outside.viewMask==visible.viewMask,'off-screen geometry is restored for later camera movement')
    scene:Dispose()
    local fonts=require('ui.SourceFonts').Resolve()
    V.assert(fonts.body=='Fonts/VoxIndustrial-Bold.otf' and fonts.bold==fonts.body,'October 14 body CSS selects original Industrial font on native and Web')
    local fontReport=assert(io.open('docs/migration/evidence/loading-selected-fonts.json','w'))
    fontReport:write(cjson.encode(fonts));fontReport:close()
    local Loader=require 'app.SceneLoader'
    local deferred=Loader.New();local calls=0;local allowed=false
    deferred.canStart=function() return allowed end
    deferred:Load('Scenes/TrialTrack.xml',function() end,function() end,{resources=function() calls=calls+1;return {} end})
    deferred:Update(.1)
    V.assert(calls==0,'resource dependency construction cannot execute before loading presentation')
    allowed=true;deferred:Update(.1)
    V.assert(calls==1,'resource dependency construction executes once after loading presentation')
    deferred:Cancel()
    deferred.state='loading';deferred.phase='prepare';deferred:FramePresented()
    V.assert(deferred.phaseFrames==1,'first presented stage frame is retained')
    deferred:FramePresented();deferred.phase='environment';deferred:FramePresented()
    V.assert(deferred.phaseFrames==1 and deferred.presentedPhase=='environment','changing stage resets the presentation counter')
    deferred:Cancel()
    local readCalls,activateCalls=0,0
    deferred.ReadScene=function() readCalls=readCalls+1 end
    deferred.Commit=function() activateCalls=activateCalls+1 end
    deferred.state='loading';deferred.phase='scene';deferred.readSceneToken=deferred.generation;deferred.warmPath='fixture'
    deferred:Update(.1);deferred:FramePresented();deferred:Update(.1)
    V.assert(readCalls==0,'scene decoding waits for two presented scene-stage frames')
    deferred:FramePresented();deferred:Update(.1)
    V.assert(readCalls==1,'scene decoding begins after the scene-stage presentation gate')
    deferred.phase='activate';deferred:Update(.1);deferred:FramePresented();deferred:Update(.1)
    V.assert(activateCalls==0,'scene activation waits for two presented activation-stage frames')
    deferred:FramePresented();deferred:Update(.1)
    V.assert(activateCalls==1,'scene activation begins after its presentation gate')
    deferred:Cancel()
    local visibility=true;local back=0
    local fake={graphicsSettings={SetSceneVisible=function(_,value) visibility=value end}}
    local flow=Flow.New(fake);local map=require('app.DriveMaps').trial
    flow:Open(map,function() back=back+1 end)
    V.assert(flow.active and flow.phase=='cover' and not flow.pageVisible,'cover starts before loading page is shown')
    V.assert(UI.GetTopOverlay()==flow.page and UI.FindWidgetAt(12,12)==flow.page,'loading owns actual native hit testing')
    local loader={phase='download',gate={total=8,completed=2}}
    flow:Observe(loader,12);V.assert(flow.progress==0 and flow.steps[1].note=='2 / 8','partial download never marks task complete')
    loader.phase='resources';loader.options={webWarmup={{},{},{},{}}};loader.warmIndex=3
    flow:Observe(loader,20)
    V.assert(flow.steps[2].note=='2 / 4','long resource preparation shows completed native resources rather than a generic stalled caption')
    loader.warmIndex=5;flow:Observe(loader,20)
    V.assert(flow.steps[2].note=='4 / 4','resource progress remains bounded at the actual dependency count')
    loader.phase='download';flow:Observe(loader,0)
    flow:Advance(.549);V.assert(not flow.pageVisible,'source 550ms cover duration is respected')
    flow:Advance(.0011);V.assert(flow.pageVisible and flow.phase=='reveal','page opens only under full cover')
    flow:Advance(.59);V.assert(flow.phase=='loading','source 590ms reveal finishes before steady loading')
    V.assert(not flow:CanStartLoad(),'transition time alone cannot begin heavy loading')
    flow:PageRendered();flow:FramePresented()
    V.assert(not flow:CanStartLoad(),'one loading-page presentation cannot begin heavy loading')
    flow:PageRendered();flow:FramePresented()
    V.assert(flow:CanStartLoad(),'resource loading starts after two visible page presentations')
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
    local retry=0;fake.Reload=function() retry=retry+1 end
    local boot=Flow.New(fake);boot:Open({id='hangar',boot=true})
    V.assert(boot.phase=='loading' and boot.pageVisible and not boot:CanStartLoad(),'source startup page is visible before hall resources begin')
    boot:PageRendered();boot:FramePresented();boot:PageRendered();boot:FramePresented()
    V.assert(boot:CanStartLoad(),'startup also requires two real page presentations')
    boot:Fail('startup fixture');boot:Back()
    V.assert(boot.active and boot.failed,'startup failure cannot cancel into a blank hall')
    boot:Retry();V.assert(retry==1,'startup failure exposes a real reload operation')
    boot:Close();boot:Open({id='hangar',boot=true});boot:Finish();boot:Rendered();boot:Rendered();boot:Advance(.1);boot:Advance(.45)
    V.assert(boot.phase=='boot-exit' and boot.pageVisible,'startup retains its original fade rather than a map transition')
    boot:Advance(.9);V.assert(not boot.active,'startup fade releases the UI overlay')
    boot:Dispose()
end
local function Poll()
    if not app then
        if not VOX_HANGAR or VOX_HANGAR.app.loadingFlow.active then return end
        app=VOX_HANGAR.app;originalScene=app.scene;Rules()
        V.assert(app:EnterTrial('trial'),'real trial begins through loading flow')
        V.assert(app.mapLoadingToast==nil,'dedicated loading page has no legacy toast covering its heading')
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
        -- Run the production captured Update path, which camera-math fixtures
        -- do not exercise. Ground VehicleSpec intentionally has no wings field.
        local pointer=t.pointer;local hasFocus=t.HasFocus;local read=t.controls.Read
        t.pointer={captured=true,Poll=function() end}
        t.HasFocus=function() return true end
        -- Hidden windows lack OS keyboard focus. Replace keyboard sampling only.
        t.controls.Read=function() return {throttle=0,steer=0} end
        t.controls:Look(0,10000)
        t:Update(0)
        V.assert(math.abs(t.pitch-.8*180/math.pi)<.0001,'ground session Update accepts absent wings and clamps source pitch')
        local wings=t.vehicle.spec.wings;t.vehicle.spec.wings={{partId=-1}}
        t.controls:Look(0,10000)
        -- This assertion selects the camera capability branch only. The marker
        -- is not an aerodynamic wing and must not advance the physics world.
        t:Update(0)
        V.assert(math.abs(t.pitch-1.25*180/math.pi)<.0001,'wing-capable session Update uses source flight pitch range')
        t.vehicle.spec.wings=wings;t.pointer=pointer;t.HasFocus=hasFocus;t.controls.Read=read;t:ResetCamera()
        zoomChecked=true;app:Reload();stage='return'
    elseif stage=='return' and app.mode=='hangar' and not flow.active then
        V.assert(app.trial==nil and app.car and app.hangar,'return completes without lingering gameplay owners')
        V.assert(phases.cover and phases.reveal and phases.loading and phases.ready and phases['exit-cover'] and phases['exit-reveal'],'all source transition phases executed in real runtime')
        V.assert(zoomChecked and UI.GetTopOverlay()==nil,'final input and camera checks completed')
        stage='done';V.finish()
    end
end
for frame=35,940 do V.atFrame(frame,Poll) end
V.atFrame(945,function() V.assert(stage=='done','loading failure retry and return completed');V.finish() end)

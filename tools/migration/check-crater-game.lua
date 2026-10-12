local UI=require 'urhox-libs/UI'
local Event=require 'urhox-libs/UI/Core/PointerEvent'
local app,session,oldSession,oldSessionPost,work
local stage='boot'
engine.maxInactiveFps=120
local function Click(widget)
    local r=widget:GetAbsoluteLayoutForHitTest()
    for _,kind in ipairs({'PointerDown','PointerUp'}) do UI.HandlePointerEvent(Event.new(kind,{x=r.x+r.w/2,y=r.y+r.h/2,pointerId=88,pointerType='mouse',button=MOUSEB_LEFT})) end
end
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image),'capture '..name);image:SavePNG('docs/migration/evidence/'..name..'.png');image:Dispose()
end
local function Step(n,command)
    for i=1,n do session:Tick(1/60,command or {throttle=0,steer=0});if i%30==0 then coroutine.yield() end end
end
local function Exercise()
    local lifetime=require('render.RenderTargetLifetime')
    lifetime.Flush()
    local initial=lifetime.PendingCount()
    local texture=Texture2D:new();texture:SetNumLevels(1)
    assert(texture:SetSize(16,16,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET))
    local borrower=texture:GetRenderSurface()
    lifetime.Retire(texture);lifetime.Flush()
    V.assert(lifetime.PendingCount()==initial+1 and borrower.parentTexture==texture and texture.width==16,'borrowed render surface keeps retired parent valid through collection')
    borrower=nil;lifetime.Flush();texture=nil
    V.assert(lifetime.PendingCount()==initial,'retired render target is released after its last Lua borrower')
    local update=session.Update
    session.Update=function() end
    V.assert(session.map.id=='crater' and #session.world.layout.teleports==9,'selected source map and all nine exploration locations')
    V.assert(session.cameraDistance>=24 and session.pitch==30,'PC camera starts above vehicle at 30 degrees and at least 24 metres away')
    V.assert(session.world.cameraObstacleCount>0,'visible building surfaces participate in camera avoidance')
    local probeOrigin=Vector3(0,10,-273);local probeDirection=Vector3(0,1,0)
    local visualHit=session.world.space.world:RaycastSingle(Ray(probeOrigin,probeDirection),20,require('controls.CameraObstacles').LAYER)
    V.assert(visualHit.body and visualHit.body.trigger,'camera-only ceiling collider is a non-solid trigger')
    local gameplayHit=session.world.space:Raycast({0,10,-273},{0,1,0},20)
    V.assert(gameplayHit and not gameplayHit.body.native.trigger,'gameplay ray ignores the camera-only ceiling surface')
    Step(180)
    local pointer=session.pointer;pointer.SetMouseMode=function() end;session.HasFocus=function() return true end
    pointer:Capture();session.hud.Update(session,0)
    for _,angle in ipairs({0,90,180,270}) do
        session.yaw=angle;session:PostUpdate(1);coroutine.yield();coroutine.yield()
        if angle==0 then V.assert(session.camera:GetNode().position.z>-289.35,'default camera clears fortress sign including its near plane') end
        if angle==0 then
            local car=session.view.view.root;local bounds=session.vehicle.spec.bounds
            local framed=true
            for _,x in ipairs({bounds.min[1],bounds.max[1]}) do for _,y in ipairs({bounds.min[2],bounds.max[2]}) do for _,z in ipairs({bounds.min[3],bounds.max[3]}) do
                local projected=session.camera:GetCamera():WorldToScreenPoint(car.position+car.rotation*Vector3(-x,y,z))
                if projected.x<.03 or projected.x>.97 or projected.y<.03 or projected.y>.97 then framed=false end
            end end end
            V.assert(framed,'full vehicle bounds remain in frame under fortress ceiling')
        end
        Shot('crater-default-orbit-'..angle)
    end
    session.yaw=0;session:PostUpdate(1);session:Pause();session.hud.Update(session,0);coroutine.yield()
    local distance=session.cameraDistance;session:Zoom(-3);session:PostUpdate(1)
    V.assert(session.cameraDistance>distance and session.camera:GetCurrentDistance()>distance,'wheel zoom changes actual third person library distance')
    session:Zoom(1000);session:PostUpdate(1);V.assert(session.cameraDistance==session.minCameraDistance,'zoom cannot enter the chassis')
    session:Zoom(-1000);session:PostUpdate(1);V.assert(session.cameraDistance==session.maxCameraDistance,'zoom has a far bound')
    session.cameraDistance=distance;session:Zoom(1);session:Zoom(-1);session:PostUpdate(1)
    Click(session.hud.playfield);V.assert(pointer.captured,'actual playfield pointer route captures look controls')
    pointer:Sample({},.016);pointer:Sample({},.016)
    local poll=pointer.Poll;pointer.Poll=function(p,dt) p:Sample({dx=75,dy=-12,wheel=-1},dt) end
    local key=session.KeyPressed;session.KeyPressed=function() return false end
    local read=session.controls.Read;session.controls.Read=function() return {throttle=0,steer=0} end
    local yaw,pitch=session.yaw,session.pitch;update(session,.016);session.controls.Read=read
    V.assert(session.yaw>yaw and session.pitch<pitch,'real session update consumes mouse orbit input')
    session.KeyPressed=key;pointer.Poll=poll;session:PostUpdate(1)
    session:Pause();V.assert(not pointer.captured,'Escape/pause releases capture')
    Step(180);local p=session.vehicle.body.translation()
    V.assert(session.vehicle.telemetry.contact>0,'vehicle grounded on source fortress floor')
    Step(90);local idle=session.vehicle.body.translation();V.assert(math.abs(idle.z-p.z)<.15,'neutral input remains stationary')
    V.assert(session.world.boulderCount>0,'source scattered boulders have collision')
    pointer:Capture();session.hud.Update(session,0);session:PostUpdate(1);coroutine.yield();coroutine.yield();Shot('crater-native-spawn')
    Step(300,{throttle=1,steer=0});local moved=session.vehicle.body.translation()
    V.assert(moved.z-p.z>12,'vehicle drives forward out of source spawn')
    V.assert(moved.y>-20,'vehicle does not fall through source floor')
    session:PostUpdate(1);coroutine.yield();coroutine.yield();Shot('crater-native-driving')
    for i,spot in ipairs(session.world.layout.teleports) do
        session.teleport=i;session:Reset();Step(120)
        local q=session.vehicle.body.translation();V.assert(q.y>-25 and session.vehicle.telemetry.contact>0,'grounded source location '..spot.name)
        if spot.name=='舰体大厅' then session:PostUpdate(1);coroutine.yield();coroutine.yield();Shot('crater-native-ship-interior') end
        if spot.name=='东洼地' then session:PostUpdate(1);coroutine.yield();coroutine.yield();Shot('crater-native-outdoors') end
    end
    local moving
    for _,d in ipairs(session.environment.dynamics) do if d.kind=='anchorRing' then moving=d;break end end
    local before=moving.node.rotation
    session.environment:Update(.5,session.camera:GetNode());local after=moving.node.rotation
    V.assert(math.abs(before.w-after.w)>1e-6 or math.abs(before.y-after.y)>1e-6,'authored map machinery animates')
    app.graphicsSettings:Set('exposure',.9)
    local post=app.graphicsSettings.post
    V.assert(post and not app.graphicsSettings.tonemap and post.data.exposure==.9,'map exposure updates GPU shader without LUT rebuild')
    V.assert(app.graphicsSettings:Supports('mist') and app.graphicsSettings:Set('mist',.08),'crater mist setting drives H5 diffusion')
    local firstGraph=post.graph
    app.graphicsSettings:Set('bloom',0);app.graphicsSettings:Set('mist',0)
    V.assert(post.graph==firstGraph and post.rebuild,'multiple toggles coalesce before next frame')
    coroutine.yield()
    V.assert(post.graph.passCount==4 and next(firstGraph.textures)==nil,'disabled bloom and mist remove both pyramids and release their buffers')
    app.graphicsSettings:Set('bloom',.18);app.graphicsSettings:Set('mist',.04)
    coroutine.yield()
    V.assert(post.graph.passCount==29,'restoring source effects rebuilds one ordered graph')
    dofile('tools/migration/check-adaptive-resolution.lua').Check(post)
    oldSessionPost=post
    oldSession=session;session=nil;stage='return';app:Reload()
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app;require('ui.GarageHud').GetState().SetTab('battle');stage='select'
    elseif stage=='select' then
        local s=require('ui.GarageHud').GetState();if not s.modeCards then return end
        Click(s.modeCards.crater);stage='selected'
    elseif stage=='selected' then stage='enter'
    elseif stage=='enter' then
        V.assert(app.selectedMap=='crater','[debug] map card selects crater');Shot('crater-mode-selection')
        Click(require('ui.GarageHud').GetState().buttons.battle);stage='loading'
    elseif stage=='loading' and app.trial then session=app.trial;stage='exercise';work=coroutine.create(Exercise)
    elseif stage=='exercise' and coroutine.status(work)~='dead' then local ok,err=coroutine.resume(work);assert(ok,err)
    elseif stage=='return' and app.mode=='hangar' then
        V.assert(oldSession.disposed and not app.trial,'return disposes crater world and controller')
        V.assert(not app.graphicsSettings.tonemap and not app.graphicsSettings.post and not oldSessionPost.graph,'return releases all map postprocessing targets')
        V.assert(app.pendingAssetRelease and app.assetReleaseFrames>0,'scene switch defers native garbage collection until stable render frames')
        oldSession=nil;work=nil;stage='unload'
    elseif stage=='unload' and not app.pendingAssetRelease then
        V.assert(require('render.RenderTargetLifetime').PendingCount()==0,'map switch drains retired render targets without retaining old buffers')
        V.assert(cache:GetExistingResource('Model','Crater/mesh-0.mdl')==nil,'unused crater geometry unloads on return')
        V.assert(app:EnterTrial('trial'),'original trial remains enterable');stage='trial'
    elseif stage=='trial' and app.trial then
        V.assert(app.trial.map.id=='trial','original trial map is independent of debug selection');stage='done';V.finish()
    end
end
for frame=45,480 do V.atFrame(frame,Poll) end
V.atFrame(490,function() V.assert(stage=='done','full map entry drive return sequence completed');V.finish() end)

-- Real app/trial post-update and real warmup stages with native boundary adapters.
COMBAT_WARMUP_TEST_HELPERS=true
local helpers=dofile('tools/migration/check-combat-warmup.lua')
COMBAT_WARMUP_TEST_HELPERS=nil
local checks=0
local function eq(a,b,label)
    assert(a==b,(label or 'equality')..': '..tostring(a)..' ~= '..tostring(b));checks=checks+1
end
local function noop() end
for _,name in ipairs({'construction.Blueprint','construction.Prefab','render.VehicleView','scene.Hangar',
    'controls.OrbitCamera','app.SceneLoader','app.HotReload','controls.ChaseState','ui.DriveHud',
    'render.DriveView','controls.DriveInput','render.WeaponView','render.CombatView','ui.DialogHost',
    'render.TargetFeedback'}) do package.loaded[name]={} end
package.loaded['urhox-libs/UI']={}
package.loaded['ui.GarageHud']={}
package.loaded['controls.ChaseCamera']={Apply=noop}
local App=assert(load(APP_SOURCE,'@scripts/app/HangarApp.lua'))()
local Trial=require'app.TrialSession'
local Flow=require'app.LoadingFlow'
graphics={GetHeight=function() return 900 end,GetDPR=function() return 1 end}
local clock=0
Time={GetSystemTime=function() return clock end}
local function fresh()
    local session=helpers.session()
    setmetatable(session,Trial)
    local root=session.scene:CreateChild('PlayerView')
    local source=session.scene:GetComponents('StaticModel',true)[1]
    session.view={view={root=root,visuals={[1]={joined=false,models={source}}}}}
    session.restoreFlash={root=session.scene:CreateChild('RestoreFlash'),material=Material:new()}
    session.world={time=0,units={}}
    session.combat={player={alive=true}}
    session.world.units[1]=session.combat.player
    session.weapons={Group=function() return nil end,drill={}}
    session.vehicle={com={0,0,0}}
    session.chase={Pose=function() return {} end}
    session.target=session.scene:CreateChild('CameraTarget')
    session.camera.GetNode=function(self) return self:GetCamera().node end
    session.drillSpeed={Update=noop}
    session.speedFov={Step=function() return 48 end}
    session.currentFov=48;session.fxContext={};session.pointer={captured=false}
    session.cameraFeedback={Flush=noop,Apply=noop}
    session.aimLines=require('render.AimLines').New(session.scene)
    local app=setmetatable({scene=session.scene,trial=session,stopped=false},App)
    local graphicsPosts=0
    app.graphicsSettings={PostUpdate=function() graphicsPosts=graphicsPosts+1 end,SetSceneVisible=noop}
    session.app=app
    local flow=setmetatable({app=app,active=true,finished=true,failed=false,warmFrames=0,warmupTimes={},combatWarmupAt=clock},Flow)
    app.loadingFlow=flow
    return app,session,flow,function() return graphicsPosts end
end
local function preRender(app,session)
    app:PostUpdate(1/60)
    local warm=app.loadingFlow.combatWarmup
    if warm and warm.phase:sub(1,7)=='effects' then
        eq(session.aimLines.mesh.enabled,true,'warm line survives real PostUpdate before render')
        eq(session.aimLines.glow.mesh.enabled,true,'warm glow survives real PostUpdate before render')
        eq(session.aimLines.count,1,'real trial scan does not overwrite warm line')
        eq(session.aimLines.mesh.vertices,6,'warm geometry retained until render')
    end
end
local completeFrames=0
do
    local app,session,flow,graphicsPosts=fresh()
    flow.finished=false;session.aimLines:Warmup(session.camera:GetCamera(),0)
    preRender(app,session)
    eq(session.aimLines.mesh.enabled,true,'unfinished covered old trial paused')
    eq(graphicsPosts(),1,'graphics post-update remains live before activation')
    flow.finished=true
    preRender(app,session)
    eq(session.aimLines.mesh.enabled,false,'scene warmup/restored-world camera stage stays live')
    eq(session.aimLines.count,0,'actual S3 no-enemy scan clears test line outside combat warmup')
    flow.combatWarmup=helpers.Warm.New(session)
    local seen={};local frames=0
    repeat
        local phase=flow.combatWarmup.phase
        seen[phase]=(seen[phase] or 0)+1
        preRender(app,session)
        frames=frames+1;assert(frames<100,'warmup must finish')
        clock=clock+16;flow:Rendered()
    until not flow.combatWarmup
    completeFrames=frames
    for _,phase in ipairs({'effects-instanced','effects-single','effects-point-instanced','effects-point-single',
        'flash-instanced','flash-single','point-light-instanced','point-light-single','point-volume-instanced','point-volume-single'}) do
        eq((seen[phase] or 0)>0,true,'rendered stage retained: '..phase)
    end
    eq(flow.warmFrames,0,'no warm frames counted before completion')
    eq(session.aimLines.mesh.enabled,false,'completion removes warm line')
    preRender(app,session)
    eq(session.aimLines.count,0,'normal real trial post-update resumes after completion')
    eq(graphicsPosts(),frames+3,'graphics post-update runs on every frame')
    flow:Rendered();eq(flow.warmFrames,1,'normal reveal fence resumes after completion')
end
for _,action in ipairs({'cancel','fail'}) do
    for stopAt=0,completeFrames do
        local app,session,flow=fresh()
        local masks={}
        for _,kind in ipairs({'StaticModel','CustomGeometry'}) do
            for _,d in ipairs(session.scene:GetComponents(kind,true)) do masks[d]=d.viewMask end
        end
        flow.combatWarmup=helpers.Warm.New(session)
        local warm=flow.combatWarmup
        for _=1,stopAt do if flow.combatWarmup then preRender(app,session);flow:Rendered() end end
        if action=='fail' then flow.steps={{}};flow.current=1;flow:Fail('controlled failure')
        else flow:Close() end
        eq(warm.disposed,true,'cancel/fail disposes warm owner')
        eq(flow.combatWarmup,nil,'cancel/fail clears guard owner')
        for d,mask in pairs(masks) do eq(d.viewMask,mask,'cancel/fail restores view mask') end
        preRender(app,session)
        eq(session.aimLines.mesh.enabled,false,'cancel/fail resumes normal actual trial scan')
    end
end
do
    local app,session,flow,graphicsPosts=fresh()
    flow.active=false;flow.combatWarmup=helpers.Warm.New(session)
    app:PostUpdate(1/60)
    eq(session.aimLines.mesh.enabled,false,'inactive flow never blocks normal trial')
    flow.combatWarmup:Dispose();flow.combatWarmup=nil
    session.aimLines:Warmup(session.camera:GetCamera(),0)
    app.stopped=true;app:PostUpdate(1/60)
    eq(session.aimLines.mesh.enabled,true,'stopped app does not mutate trial')
    eq(graphicsPosts(),1,'stopped app does not update graphics')
end
return {checks=checks,phases=10}

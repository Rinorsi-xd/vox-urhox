local UI=require 'urhox-libs/UI'
local Hud=require 'ui.GarageHud'
local Prefab=require 'construction.Prefab'
local Blueprint=require 'construction.Blueprint'
local Controller=require 'app.HomeVehicleSwitch'
local app,control,race,tank,retired,generation
local originalSize,originalW,originalH,originalScale=UI.GetViewportSize,UI.GetWidth,UI.GetHeight,UI.GetScale()
local function Near(a,b) return math.abs(a-b)<.00002 end
local function Advance(dt) Controller.Update(control,dt) end
local function Click(widget)
    local r=widget:GetAbsoluteLayoutForHitTest()
    local E=require 'urhox-libs/UI/Core/PointerEvent'
    local d={x=r.x+r.w/2,y=r.y+r.h/2,pointerId=96,pointerType='mouse',button=MOUSEB_LEFT}
    UI.HandlePointerEvent(E.new('PointerDown',d));UI.HandlePointerEvent(E.new('PointerUp',d))
end
local function Store()
    local s={slots={}}
    function s:LoadSlot(i) return self.slots[i] end
    function s:SaveSlot(i,bp) self.slots[i]=bp:ToTable();return true end
    function s:DeleteSlot(i) self.slots[i]=nil;return true end
    function s:SaveGarageState(i) if self.fail then return false,'injected metadata failure' end;self.active=i;return true end
    function s:LoadGarageState() return nil end
    function s:Queue(bp) self.draft=bp:ToTable() end
    function s:Flush() return true end
    function s:Update() end
    function s:LoadBuildSettings() return nil end
    function s:SaveBuildSettings() return true end
    return s
end
local function Replay()
    local f=assert(io.open('tools/migration/source-car-lift.json'));local data=cjson.decode(f:read('*a'));f:close()
    for _,case in ipairs(data.cases) do
        V.assert(app:LoadBlueprint(case.blueprint),'load source lift case '..case.name)
        control:Finish()
        V.assert(Near(app:DisplayHeight(),case.rest),'source ground height '..case.name)
        V.assert(Near(control:Depth(),case.depth),'source sink depth '..case.name)
        local lift=control.lift;local editing=false
        for i,frame in ipairs(case.frames) do
            if frame.action=='sink' then lift:Sink(case.depth)
            elseif frame.action=='rise' then lift:Rise(case.depth,case.rest)
            elseif frame.action=='settle' then lift:Settle(case.rest)
            elseif frame.action=='edit' then editing=true;lift:Settle(0)
            else lift:Update(frame.dt) end
            V.assert(Near(lift.root.position.y,frame.y),case.name..' source height sample '..i)
            V.assert((lift.anim~=nil)==frame.active,case.name..' source active sample '..i)
        end
    end
end
local function Bounds()
    Hud.Update(0);local s=Hud.GetState();s.root:SetStyle({width=1920,height=1080})
    renderer:GetViewport(0):SetRect(IntRect(0,0,1920,1080))
end
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img),'GPU capture '..name)
    local crop=img:GetSubimage(IntRect(0,0,1920,1080))
    V.assert(crop:SavePNG('docs/migration/evidence/pc-car-lift-'..name..'.png'),'saved '..name)
    crop:Dispose();img:Dispose()
end
V.atFrame(50,function()
    app=VOX_HANGAR.app;control=app.vehicleSwitch
    app.store=Store();app.bays=require('construction.Garage').New(app.blueprint,app.store,function(data) return app:LoadBlueprint(data) end,false)
    Replay()
    race=Prefab.BuildRaceCar(Blueprint.New()):ToTable();tank=Prefab.BuildTank(Blueprint.New()):ToTable()
    app:LoadBlueprint(race);control:Finish();app.bays:Save(1);app.store:SaveSlot(2,Prefab.BuildTank(Blueprint.New()))
    app.bays.revision=app.bays.revision+1
    UI.SetScale(1);UI.GetViewportSize=function() return 1920,1080 end;UI.GetWidth=function() return 1920 end;UI.GetHeight=function() return 1080 end
    Bounds();app:HomeView('hangar');app.camera:Step(.65);app.camera.autoSpin=false
    control.Update=function() end -- Only this test's controlled dt advances the actual controller.
    _G.VOX_DEBUG={time=10}
end)
V.atFrame(60,function()
    Click(Hud.GetState().cards[1]);V.assert(not control:IsBusy(),'active bay click does not sink the same car')
    Click(Hud.GetState().cards[2])
    V.assert(control:IsBusy() and app.bays.active==1 and app.blueprint.name==race.name,'UI click keeps old blueprint during descent')
    local reject=control:Begin(function() error('must not run second switch') end)
    V.assert(not reject,'concurrent bay request is rejected, not queued')
end)
V.atFrame(65,function() Shot('01-start');Advance(.1);V.assert(app.bays.active==1,'no storage commit halfway through sinking') end)
V.atFrame(70,function()
    Shot('02-sink');Advance(.1)
    V.assert(app.bays.active==2 and app.blueprint.name==tank.name and not control:IsBusy(),'source 200ms boundary commits exactly one new bay')
    V.assert(Near(app.car.root.position.y,app:DisplayHeight()-control:Depth()),'new vehicle begins entirely below platform')
end)
V.atFrame(75,function() Shot('03-replaced');Advance(.15) end)
V.atFrame(80,function() Shot('04-rise');Advance(.15);V.assert(app.car.root.position.y>app:DisplayHeight(),'source rise overshoots then settles') end)
V.atFrame(85,function() Shot('05-overshoot');Advance(.15) end)
V.atFrame(90,function()
    Shot('06-rest');V.assert(not control.lift.anim and Near(app.car.root.position.y,app:DisplayHeight()),'rise ends grounded after 450ms')
    local welcomes=0;local original=app.hangar.Welcome
    app.hangar.Welcome=function(h,bp) welcomes=welcomes+1;return original(h,bp) end
    app.store.fail=true
    control:Begin(function() return app.bays:Open(1) end);Advance(.2);app.store.fail=false
    V.assert(app.bays.active==2 and app.blueprint.name==tank.name,'failed metadata commit restores old selected vehicle')
    Advance(.45);V.assert(Near(app.car.root.position.y,app:DisplayHeight()),'failed switch raises old car back to rest')
    V.assert(welcomes>0,'replacement/failure recovery trigger real hall welcome')
    app.hangar.Welcome=original
    local completed=0
    control:Begin(function() completed=completed+1;return app.bays:Open(1) end)
    app:EnterBuild()
    V.assert(completed==1 and app.bays.active==1 and app.build~=nil,'enter-build completes accepted switch once before creating editor')
    V.assert(Near(app.car.root.position.y,0) and not control.lift.anim,'build hit tests get an untranslated render root')
    app:ExitBuild();Bounds()
    completed=0;control:Begin(function() completed=completed+1;return app.bays:Open(2) end)
    app:LoadBlueprint(race);Advance(.7)
    V.assert(completed==0 and not control:IsBusy() and app.blueprint.name==race.name,'direct replacement cancels superseded pending request')
    local canceled=Controller.New(app,app.car.root)
    canceled:Begin(function() error('disposed callback must not execute') end);canceled:Dispose();canceled:Update(1)
    V.assert(canceled.lift.root==nil and not canceled.pending,'disposed owner releases node and pending callback')
    control:Finish()
end)
V.atFrame(100,function()
    local s=Hud.GetState();s.CreateVehicle('empty');Advance(.2)
    V.assert(app.build and app.blueprint:Size()==1 and app.car.root.position.y==0,'empty preset enters build without a leftover rise offset')
    app:ExitBuild();Bounds()
    control:Begin(function() return app.bays:Open(1) end)
    retired=control;generation=app.generation;app:Reload()
    V.assert(app.bays.active==1 and not retired.pending,'reload completes accepted switch before scene handoff')
end)
V.atFrame(140,function()
    V.assert(app.generation==generation+1 and app.mode=='hangar','reload activates one new hall')
    V.assert(retired.disposed and retired.lift.root==nil,'reload releases animation references before old car disposal')
    control=app.vehicleSwitch;V.assert(control~=retired and not control.lift.anim,'new hall has a fresh settled animation owner')
    control:Begin(function() return app.bays:Open(2) end);retired=control
    V.assert(app:EnterTrial() and app.bays.active==2,'trial entry commits selected tank before loading track')
end)
V.atFrame(180,function()
    V.assert(app.trial~=nil and app.car==nil and app.vehicleSwitch==nil,'trial releases hangar car and animation owner')
    V.assert(retired.disposed and not retired.pending and retired.lift.root==nil,'trial has no delayed hall callbacks')
    app:Reload()
end)
V.atFrame(230,function()
    V.assert(not app.trial and app.bays.active==2 and app.vehicleSwitch~=nil,'trial return keeps selected car and rebinds hall lift')
    V.assert(Near(app.car.root.position.y,app:DisplayHeight()),'trial return starts at ground height')
    UI.GetViewportSize=originalSize;UI.GetWidth=originalW;UI.GetHeight=originalH;UI.SetScale(originalScale)
    _G.VOX_DEBUG=nil;V.finish()
end)

-- QA suffix only: transformed frozen modules retain the original algorithms.
local M={enabled=false,installed=false,epoch=0,frame=0,frames={},dropped=0,bindings=0,ids={},names={},calibration=false}
local clock=function() return Time:GetSystemTime() end
local boundary='Integer wall milliseconds including clock/wrapper/allocation/GC/preemption costs; not exact CPU time or presented FPS. Inclusive parents overlap children. Calibration is synthetic overhead evidence, not a subtractable gameplay correction.'
local boundMethods=setmetatable({},{__mode='k'})
local boundNames={}
local function Wrap(object,key,name)
    local methods=boundMethods[object] or {};boundMethods[object]=methods
    assert(not methods[key],'Duplicate drive scope binding: '..name)
    assert(not boundNames[name],'Duplicate drive scope label: '..name)
    methods[key]=true;boundNames[name]=true
    Scope.Wrap(object,key,name,false);M.bindings=M.bindings+1
end
local function Calibrate()
    local count=3000
    local function Identity(a,b,c,d) return a,b,c,d end
    local wrapped={Call=Identity};Scope.Wrap(wrapped,'Call','qa.calibration',false)
    local results={iterations=count,repeats={},clockResolutionMs=1,boundary=boundary}
    local function Run(method,active)
        Scope.active=active;Scope.rows={};Scope.stack={}
        local start=clock();local checksum=0
        for i=1,count do local a,b,c,d=method(i,nil,false,4);assert(b==nil and c==false and d==4);checksum=checksum+a end
        local elapsed=(clock()-start)&0xffffffff;Scope.AssertClosed();Scope.active=false
        assert(checksum==count*(count+1)/2)
        return elapsed
    end
    for i=1,3 do
        results.repeats[i]={directMs=Run(Identity,false),disabledWrapperMs=Run(wrapped.Call,false),
            activeWrapperMs=Run(wrapped.Call,true)}
    end
    Scope.rows={};Scope.stack={};return results
end
local function Install()
    if M.installed then return end
    M.calibration=Calibrate()
    local oldGait=require 'drive.LegGait'
    local oldContact=require 'drive.ContactControl'
    for key,value in pairs(Gait) do oldGait[key]=value end
    for key,value in pairs(Contact) do oldContact[key]=value end
    -- Gait.Step closes over its freshly constructed M table. Wrap that table,
    -- then export the same wrapped function through the production module table.
    Wrap(Gait,'Foothold','gait.foothold');oldGait.Foothold=Gait.Foothold
    local methods={
        {'app.TrialSession',{'Tick','Update','ConsumeWorldEvents','PostUpdate'},'trial'},
        {'combat.BattleController',{'BeforeStep','AfterStep'},'combat'},
        {'drive.TrackWorld',{'Step','CastRay','Hit','Explode'},'world'},
        {'render.CombatView',{'Consume','Update'},'combatView'},
        {'drive.Vehicle',{'Step','StepRotors','PostStep'},'vehicle'},
        {'physics.Space',{'Step','Raycast'},'physics'},
        {'combat.EnemyDriver',{'Step'},'ai'},
        {'combat.CarUnit',{'Flush','SavePose','Spawn','Build','RegenerateStructure'},'unit'},
        {'combat.WeaponSystem',{'Step','Energy','Aim','Tick','Ready','Aligned','Fire','Muzzle','Spend','Beam','Integrate'},'weapons'},
        {'drive.RaySuspension',{'Sample','Apply'},'suspension'},
        {'drive.ChassisStability',{'Step'},'stability'},
        {'drive.HoverControl',{'Step','Motion'},'hover'},
        {'drive.ThrusterControl',{'Step'},'thruster'},
        {'drive.WingControl',{'Step'},'wing'},
        {'drive.LegControl',{'Step','Cast','Clear','Reachable','Target'},'leg'},
        {'drive.LegHitboxes',{'Update'},'legHitboxes'},
        {'combat.EnemyDriverThink',{'Run','Sniper','Route'},'ai.think'},
        {'combat.EnemyDriverNav',{'Nearest','Path','Direct','Visible','Height'},'ai.nav'},
        {'combat.VehicleRay',{'Cast'},'vehicleRay'},
    }
    for _,entry in ipairs(methods) do
        local module=require(entry[1])
        for _,key in ipairs(entry[2]) do Wrap(module,key,entry[3]..'.'..key) end
    end
    assert(M.bindings==57,'Expected exactly 57 unique method wrappers')
    M.installed=true
end
function M.Toggle()
    Scope.AssertClosed()
    if not M.installed then Install() end
    M.enabled=not M.enabled;M.epoch=M.epoch+1
end
function M.BeginFrame(app)
    assert(not M.inFrame,'QA detail frame already open')
    M.inFrame=M.enabled and app and app.trial and not app.loadingFlow.active or false
    if not M.inFrame then Scope.active=false;return end
    Scope.AssertClosed();Scope.rows={};Scope.active=true;M.frame=M.frame+1;M.started=clock()
    Scope.Enter('update.production')
end
function M.EndFrame()
    if not M.inFrame then return end
    Scope.Leave();Scope.AssertClosed();Scope.active=false;M.inFrame=false
    local values={}
    for name,row in pairs(Scope.rows) do
        local id=M.ids[name]
        if not id then id=#M.names+1;M.ids[name]=id;M.names[id]=name end
        values[#values+1]={id,row.calls,row.ms,row.selfMs,row.maxMs}
    end
    if #M.frames<4096 then
        M.frames[#M.frames+1]={frame=M.frame,epoch=M.epoch,startWall=M.started,endWall=clock(),values=values}
    else M.dropped=M.dropped+1 end
end
function M.Emit()
    if #M.frames==0 then return end
    local pending=M.frames;M.frames={}
    -- Two frames per record keep individual console messages bounded even when
    -- every wrapped method is exercised. No print occurs in a simulation step.
    for first=1,#pending,2 do
        local frames={pending[first]};if pending[first+1] then frames[2]=pending[first+1] end
        print('VOX_DRIVE_SECTIONS '..cjson.encode({epoch=M.epoch,names=M.names,frames=frames,dropped=M.dropped,
            sourceIdentity=SOURCE_IDENTITY,boundary=boundary}))
    end
end
function M.Snapshot()
    return {available=true,enabled=M.enabled,installed=M.installed,epoch=M.epoch,frames=M.frame,
        pending=#M.frames,dropped=M.dropped,bindings=M.bindings,calibration=M.calibration,
        sourceIdentity=SOURCE_IDENTITY,installedInactiveRetainsWrapperBranches=M.installed and not M.enabled,boundary=boundary}
end
_G.VOX_QA_DRIVE_SECTIONS=M

-- Real Native scene/model assembly. The surrounding app only replaces UI/storage.
local output='D:/Rino_Project/maker/Vox/VoxelCraft/.tmp/home-switch-perf-20261016/baseline.json'
local rows,active={},nil
local scene
local stack={}
local function Now() return Time:GetSystemTime() end
local function Wrap(module,key,label)
    local original=assert(module[key],label)
    module[key]=function(...)
        stack[#stack+1]=label
        local started=Now();local result=table.pack(original(...))
        stack[#stack]=nil
        if active then
            local row=active.methods[label] or {calls=0,ms=0,maxMs=0};active.methods[label]=row
            local elapsed=Now()-started;row.calls=row.calls+1;row.ms=row.ms+elapsed;row.maxMs=math.max(row.maxMs,elapsed)
        end
        return table.unpack(result,1,result.n)
    end
end
local function Run()
    local args=GetArguments()
    for _,arg in ipairs(args) do local path=arg:match('^%-home%-output=(.+)$');if path then output=path end end
    local BP=require 'construction.Blueprint'
    local Prefab=require 'construction.Prefab'
    local App=require 'app.HangarApp'
    local View=require 'render.VehicleView'
    local Switch=require 'app.HomeVehicleSwitch'
    local Code=require 'storage.BlueprintCode'
    local deps=require 'parts.Dependencies'
    local Joined=require 'render.JoinedMesh'
    local Surface=require 'render.JoinedSurface'
    local Livery=require 'render.LiveryLayer'
    local Rig=require 'render.PartRig'
    local Assets=require 'parts.PartAssets'
    for _,entry in ipairs({{BP,'Load'},{BP,'Add'},{BP,'ToTable'},{BP,'Stats'},{Code,'Validate'},
        {deps,'Ready'},{View,'Rebuild'},{View,'Clear'},{View,'AddPart'},
        {Rig,'Build'},{Assets,'Get'},{Joined,'Update'},{Surface,'Build'},
        {Livery,'Update'},{App,'GroundDisplay'},{App,'DisplayHeight'}}) do
        local name=entry[1]==BP and 'Blueprint' or entry[1]==View and 'VehicleView'
            or entry[1]==App and 'HangarApp' or entry[1]==Code and 'BlueprintCode'
            or entry[1]==deps and 'Dependencies' or entry[1]==Rig and 'PartRig'
            or entry[1]==Assets and 'PartAssets' or entry[1]==Joined and 'JoinedMesh'
            or entry[1]==Surface and 'JoinedSurface' or 'LiveryLayer'
        Wrap(entry[1],entry[2],name..'.'..entry[2])
    end
    scene=Scene();scene:CreateComponent('Octree')
    local old=Prefab.Create(BP.New(),'raceCar')
    local app=setmetatable({blueprint=old,car=View.New(scene),editor={history={},selection={}},
        store={Queue=function() end},mode='hangar',loader={state='ready'},
        camera={maxDist=90,Focus=function() end},hangar={Welcome=function() end}},App)
    app.car:Rebuild(old)
    app.vehicleSwitch=Switch.New(app,app.car.root)
    for _,preset in ipairs({'megaMech','raceCar','megaMech'}) do
        local data=Prefab.Create(BP.New(),preset):ToTable()
        local row={preset=preset,parts=#data.parts,methods={},slices={},sliceDetails={},startedMs=Now()};rows[#rows+1]=row;active=row
        local finished=false
        assert(app.vehicleSwitch:Begin(function() return app:LoadBlueprint(data) end,function(ok,err)
            assert(ok,err);finished=true
        end,deps.FromBlueprint(data)))
        for i=1,10000 do
            local previous={};for name,stats in pairs(row.methods) do previous[name]={ms=stats.ms,calls=stats.calls} end
            local kb=collectgarbage('count')
            local t=Now();app.vehicleSwitch:Update(1/60);local ms=Now()-t
            if ms>0 then row.slices[#row.slices+1]=ms end
            if app.vehicleSwitch:IsAssembling() or ms>=4 then
                local detail={ms=ms,kbBefore=kb,kbAfter=collectgarbage('count'),inside=stack[#stack],methods={}}
                for name,stats in pairs(row.methods) do
                    local oldStats=previous[name] or {ms=0,calls=0}
                    if stats.calls>oldStats.calls then detail.methods[name]={calls=stats.calls-oldStats.calls,ms=stats.ms-oldStats.ms} end
                end
                row.sliceDetails[#row.sliceDetails+1]=detail
            end
            if finished then break end
        end
        assert(finished,'assembly did not complete')
        row.elapsedMs=Now()-row.startedMs;row.maxAssemblyMs=app.vehicleSwitch.maxAssemblyMs
        row.assemblyFrames=app.vehicleSwitch.assemblyFrames
        assert(#app.blueprint:List()==#data.parts,'part count changed')
        assert(#app.car.visuals==0 or app.car.visuals[1]~=nil,'missing first visual')
        row.visibleParts=0;for id in pairs(app.car.visuals) do assert(app.blueprint.parts[id],'ghost visual');row.visibleParts=row.visibleParts+1 end
        assert(row.visibleParts==#data.parts,'visual part count changed')
        active=nil
        app.vehicleSwitch:Finish()
    end
    app.vehicleSwitch:Dispose();app.car:Dispose();scene:Dispose();scene=nil
    return {result='PASS',scope='Native headless actual HomeVehicleSwitch and HangarApp.LoadBlueprint; UI/camera/storage adapters; inclusive timers; no rendered frame guarantee',rows=rows}
end
function Start()
    local ok,result=xpcall(Run,debug.traceback)
    if not ok then result={result='FAIL',error=result,rows=rows};print(result.error) end
    local file=assert(io.open(output,'wb'));file:write(cjson.encode(result));file:close()
    engine:Exit()
end

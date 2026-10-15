local Data=require('core.ResourceData').Read('Salvage/RunData.json')
local BP=require 'construction.Blueprint'
local Parts=require 'parts.Dependencies'
local Run=require 'salvage.Run'
local phase=0
local worker=nil
local testWorld=nil
local testView=nil
local function Cleanup()
    if testView then testView:Dispose();testView=nil end
    if testWorld then
        for _,unit in ipairs(testWorld.units) do unit:Dispose() end
        testWorld.debris:Clear();testWorld.space:Dispose();testWorld.scene:Dispose();testWorld=nil
    end
end
local function Check()
    local live=assert(VOX_HANGAR).app
    -- Isolate the entry preconditions, not its resource enumeration. No real
    -- session, vehicle, currency or platform identity is changed by this probe.
    local app=setmetatable({},getmetatable(live))
    for key,value in pairs(live) do app[key]=value end
    app.blueprint=require('construction.Prefab').Create(BP.New(),'miniHeavy')
    app.lobby='salvage';app.isValidation=true;app.vehicleSwitch=nil
    app.bays={active=1,Slots=function() return {} end}
    app.salvageLobby=require('app.SalvageLobby').New(app)
    local captured=nil
    app.loader={state='ready',Load=function(_,scene,activate,fail,options) captured=options end}
    V.assert(app:EnterTrial('salvage',nil,nil,true),'Actual App.EnterTrial accepts valid source miniHeavy and captures production loader options')
    assert(captured and type(captured.resources)=='function','Actual production resources callback was captured')
    local started=Time:GetSystemTime()
    local original=Run.Dependencies
    Run.Dependencies=function()
        local since=Time:GetSystemTime();local result=original()
        print('[SalvageResources] Actual Run.Dependencies ms='..(Time:GetSystemTime()-since));return result
    end
    local ok,resources=pcall(captured.resources);Run.Dependencies=original;assert(ok,resources)
    local planned={}
    print('[SalvageResources] Actual entry resource enumeration ms='..(Time:GetSystemTime()-started))
    for _,path in ipairs(resources) do planned[path]=true end
    local missing={};local all={};local queue={};local names={}
    for kind in pairs(Data.enemies) do names[#names+1]=kind end;table.sort(names)
    for _,kind in ipairs(names) do for variant,def in ipairs(Data.enemies[kind]) do
        queue[#queue+1]={kind=kind,index=variant,name=def.name}
        local old={};local fast={}
        for _,path in ipairs(Parts.FromBlueprint(def.source)) do fast[path]=true end
        for _,path in ipairs(Parts.For(BP.New():Load(def.source):List())) do
            old[path]=true
            all[path]=true;if not planned[path] then missing[path]=true end
        end
        local equal=true;for path in pairs(old) do if not fast[path] then equal=false end end
        for path in pairs(fast) do if not old[path] then equal=false end end
        V.assert(equal,'Raw versus fully migrated Blueprint dependency sets identical '..kind..':'..variant)
        coroutine.yield()
    end end
    local missingCount=0;for path in pairs(missing) do missingCount=missingCount+1;print('[SalvageResources] MISSING '..path) end
    V.assert(missingCount==0,'Every original enemy variant dependency belongs to actual App.EnterTrial resources')
    local edge=BP.New();local defs=require('parts.Defs').PARTS;local place=0
    for name,def in pairs(defs) do if def.wing or def.rotor or def.mech or def.drill or name=='hover3' then
        for _,rotation in ipairs({0,5,12,23}) do
            edge:Add({type=name,pos={place*50,0,0},rot=rotation,color=0xffffff,g=place%3});place=place+1
        end
    end end
    edge.livery={{s='nono_stamp',p={0,0,0},n={0,1,0},r=0,w=1}}
    local edgeOld={};local edgeRaw={}
    for _,path in ipairs(Parts.For(edge:List())) do edgeOld[path]=true end
    for _,path in ipairs(Parts.FromBlueprint(edge:ToTable())) do edgeRaw[path]=true end
    local edgeEqual=true;for path in pairs(edgeOld) do if not edgeRaw[path] then edgeEqual=false end end
    for path in pairs(edgeRaw) do if not edgeOld[path] then edgeEqual=false end end
    V.assert(edgeEqual,'Raw dependency path preserves grouped rotated hover wing rotor mech drill and independent livery metadata')
    local failed='Parts/Models/96a6a08cd9ad7644de6feefe.bin'
    V.assert(all[failed]==true and planned[failed]==true,'Exact failed miniHeavy Web ambush model is in both original enemy pool and actual entry resources')
    local count=0;for path in pairs(all) do count=count+1;assert(cache:Exists(path),'Native pool dependency missing '..path) end
    V.assert(count>0,'Native original enemy dependencies physically exist before model consumption')
    local gate=require('app.ResourceGate').New();local ready=false
    gate:Start(resources,function(ok) ready=ok end)
    V.assert(ready and gate.state=='ready','Actual ResourceGate accepts captured production entry list before dynamic spawns');gate:Cancel()
    print('[SalvageResources] Actual planned rows='..#resources..' unique enemy assets='..count..' original variants='..#queue)
    local scene=Scene();scene:CreateComponent('Octree')
    local world={scene=scene,space=require('physics.Space').New(scene),time=10,stats={shots=0,hits=0,damage=0,kills=0},units={},viewEvents={},fx={},layout={salvage={gameplay={encounters={}}}}}
    world.NewVehicle=require('drive.TrackWorld').NewVehicle
    world.debris=require('combat.Debris').New(world.space)
    testWorld=world;testView=require('render.CombatView').New(scene)
    local player={Position=function() return {0,0,0} end}
    local run=setmetatable({world=world,session={scene=scene},player=player,entries={{unit=player}},rules={time=10,op=Data.ops[1]}},Run)
    local director=require('salvage.Director').New(run)
    for _,item in ipairs(queue) do
        local entry=assert(director:Add(item.kind,{0,0,0},0,nil,item.index),'Original enemy variant spawn '..item.kind..':'..item.index)
        local unit=entry.unit
        V.assert(unit.alive and unit.vehicle and unit.vehicle.native,'Actual Director.CarUnit.Bullet spawn '..item.kind..':'..item.index..' '..item.name)
        local checkpoints=0
        testView:Consume(world,function() checkpoints=checkpoints+1;if checkpoints%8==0 then coroutine.yield() end end)
        local visual=testView.units[unit]
        V.assert(visual and visual.view and visual.view.root,'Actual CombatView.DriveView.PartRig consumes guarded models '..item.kind..':'..item.index)
        director:Remove(entry);testView:Consume(world)
        V.assert(testView.units[unit]==nil and #run.entries==1 and #world.units==0,'Actual dynamic enemy view and Bullet lifecycle retires '..item.kind..':'..item.index)
        coroutine.yield()
    end
    Cleanup();phase=2;V.finish()
end
V.atFrame(3,function() engine.maxInactiveFps=1000;engine.maxFps=1000 end)
for frame=40,2190 do V.atFrame(frame,function()
    if phase==2 or phase<0 or not VOX_HANGAR or VOX_HANGAR.app.loadingFlow.active then return end
    if not worker then worker=coroutine.create(Check);phase=1 end
    local ok,err=coroutine.resume(worker)
    if not ok then Cleanup();phase=-1;V.assert(false,tostring(err));V.finish() end
end) end
V.atFrame(2195,function() V.assert(phase==2,'All original salvage enemy models consumed through actual entry and production rendering');Cleanup();V.finish() end)

local root='D:/Rino_Project/maker/Vox/VoxelCraft/.tmp/perf-optimization-20261016/'
local rows,checks={},0
local scene
local function Check(v,msg) checks=checks+1;assert(v,msg) end
local function Near(a,b) Check(math.abs(a-b)<1e-8,'numeric mismatch '..a..' / '..b) end
local function Measure(label,n,fn)
    collectgarbage('collect');local t=Time:GetSystemTime()
    for i=1,n do fn(i) end
    local ms=(Time:GetSystemTime()-t)&0xffffffff
    rows[#rows+1]={label=label,count=n,totalMs=ms}
end
local function Run()
    local Effects=require 'render.CombatEffects'
    local Old=assert(loadfile(root..'before/scripts/render/CombatEffects.lua'))()
    local function Capture(module)
        local segments={}
        local batch={Segment=function(_,a,b,width,color,alpha,core,u0,u1)
            segments[#segments+1]={a[1],a[2],a[3],b[1],b[2],b[3],width,alpha,core,u0,u1}
        end}
        return setmetatable({batches={Arc=batch},maxHelix=300},module),segments
    end
    local a,sa=Capture(Old);local b,sb=Capture(Effects)
    local beam={from={1.3,-2.1,4.7},dir={.6,0,.8},phase=.47}
    for i=1,50 do
        local len=i%2==0 and i*.01 or i*3
        local tip={beam.from[1]+beam.dir[1]*len,beam.from[2],beam.from[3]+beam.dir[3]*len}
        a:Helix(beam,tip,len,.3,.04,{1,2,3},.7,i*.13)
        b:Helix(beam,tip,len,.3,.04,{1,2,3},.7,i*.13)
    end
    Check(#sa==#sb,'helix segment count')
    for i,row in ipairs(sa) do for k,value in ipairs(row) do Near(value,sb[i][k]) end end
    local batch={Segment=function() end}
    a.batches.Arc=batch;b.batches.Arc=batch
    for pass=1,4 do
        local order=pass%2==1 and {{'helix-before',a},{'helix-after',b}} or {{'helix-after',b},{'helix-before',a}}
        for _,item in ipairs(order) do Measure(item[1],3000,function(i) item[2]:Helix(beam,{61.3,-2.1,84.7},100,.3,.04,{1,2,3},.7,i*.13) end) end
    end
    local BP=require 'construction.Blueprint';local Prefab=require 'construction.Prefab'
    local Spec=require 'drive.VehicleSpec';local Ranges=require 'construction.TurretRange';local Rotors=require 'construction.Rotors'
    local Vehicle=require 'drive.Vehicle';local Space=require 'physics.Space';local Unit=require 'combat.CarUnit'
    local Drive=require 'render.DriveView';local Sync=require 'combat.PlayerViewSync'
    local OldSync=assert(loadfile(root..'before/scripts/combat/PlayerViewSync.lua'))()
    local Defs=require('parts.Defs').PARTS
    scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene)
    local env={time=0,viewEvents={},fx={},debris={Spawn=function() end},RecordDamage=function() end,RecordKill=function() end,
        NewVehicle=function(_,spec) return Vehicle.New(space,spec) end}
    local names={'raceCar','hawk','megaMech'}
    -- Include an authored rotor car when one exists.
    for name in pairs(Prefab.keys) do
        local bp=Prefab.Create(BP.New(),name)
        for _,p in ipairs(bp:List()) do if Defs[p.type].rotor then names[#names+1]=name;break end end
        if #names>3 then break end
    end
    local specTimes={}
    for _,name in ipairs(names) do
        local bp=Prefab.Create(BP.New(),name)
        local u=Unit.New(env,bp:ToTable(),{name='probe',spawn={pos={0,0,0},yaw=.2},combat=true,externalView=true})
        Check(u.alive,'fixture not alive '..name)
        local va,vb=Drive.New(scene,u.bp,u.vehicle),Drive.New(scene,u.bp,u.vehicle)
        local ca={player=u,world=env,session={view=va,vehicle=u.vehicle,weapons=u.weapons}}
        local cb={player=u,world=env,session={view=vb,vehicle=u.vehicle,weapons=u.weapons}}
        local function EqualViews()
            Check(va.vehicle==u.vehicle and vb.vehicle==u.vehicle,'stale physics reference')
            for id,p in pairs(u.bp.parts) do
                local x,y=va.view.visuals[id],vb.view.visuals[id]
                Check(x and y and x.part==p and y.part==p,'visual part '..id)
                Near(x.node.position.x,y.node.position.x);Near(x.node.position.y,y.node.position.y);Near(x.node.position.z,y.node.position.z)
                Near(x.node.rotation.w,y.node.rotation.w);Near(x.node.rotation.x,y.node.rotation.x);Near(x.node.rotation.y,y.node.rotation.y);Near(x.node.rotation.z,y.node.rotation.z)
            end
            for id in pairs(vb.view.visuals) do Check(u.bp.parts[id]~=nil,'ghost visual') end
            local x,y=va.view:GetWorldBounds(),vb.view:GetWorldBounds()
            Near(x.min.x,y.min.x);Near(x.min.y,y.min.y);Near(x.min.z,y.min.z)
            Near(x.max.x,y.max.x);Near(x.max.y,y.max.y);Near(x.max.z,y.max.z)
        end
        local function Consume()
            OldSync.Update(ca);Sync.Update(cb)
            if u.alive then va:Update(1,0);vb:Update(1,0);EqualViews() end
            env.viewEvents={}
        end
        Consume()
        local ids={};for _,p in ipairs(u.bp:List()) do if Defs[p.type].shape then ids[#ids+1]=p.id end end
        for i=1,math.min(3,#ids) do
            local prior=u.vehicle
            u:Destroy(ids[i]);u:Flush();Check(u.alive,'fixture died on block loss');Check(u.vehicle~=prior,'body not replaced')
            Consume()
            u:RestoreMissing(1);u:Flush();Consume()
        end
        -- A batch may restore a part and destroy it again before presentation.
        local id=ids[1];if u.bp.parts[id] then u:Destroy(id);u:Flush();Consume() end
        u:RestoreMissing(99);if u.bp.parts[id] then u:Destroy(id) end;u:Flush();Consume()
        -- Actual death tears down native body; Spawn produces new bp/weapon/body.
        local core=u.bp:CoreParts()[1];u:Destroy(core.id);u:Flush();Check(not u.alive,'death not reached');Consume()
        Check(not vb.view.root.enabled,'dead visual not hidden')
        u:Spawn();Consume();Check(vb.view.root.enabled,'spawn visual hidden')
        va:Dispose();vb:Dispose();u:Dispose();env.viewEvents={}
        -- Break down fresh range evaluation and part-spec construction on edits.
        local bp2=Prefab.Create(BP.New(),name)
        local totals={name=name,parts=bp2:Size(),rotorsMs=0,rangesMs=0,partsMs=0,count=12}
        local saved=bp2.parts[ids[1]]
        for i=1,12 do
            if saved then if bp2.parts[saved.id] then bp2:Remove(saved.id) else bp2:Add(saved) end end
            local adj=bp2:Graph();local conn=bp2:Connectivity(adj)
            local t=Time:GetSystemTime();local rotors,owner=Rotors.Spec(bp2,adj,conn.reached);totals.rotorsMs=totals.rotorsMs+Time:GetSystemTime()-t
            t=Time:GetSystemTime();Ranges.For(bp2,owner);totals.rangesMs=totals.rangesMs+Time:GetSystemTime()-t
            local parts={};for _,p in ipairs(bp2:List()) do if conn.reached[p.id] then parts[#parts+1]=p end end
            t=Time:GetSystemTime();Spec.BuildParts(parts,0,rotors,owner);totals.partsMs=totals.partsMs+Time:GetSystemTime()-t
        end
        specTimes[#specTimes+1]=totals
    end
    space:Dispose();scene:Dispose();scene=nil
    return {result='PASS',checks=checks,helixSegments=#sa,rows=rows,vehicleCases=names,specTimes=specTimes,
        scope='Real modules, actual Unit damage/repair/death/spawn, helix segment equivalence; headless, not rendered/phone acceptance'}
end
function Start()
    local ok,result=xpcall(Run,debug.traceback)
    if not ok then result={result='FAIL',error=result,checks=checks,rows=rows};print(result.error) end
    local f=assert(io.open(root..'extended-result.json','wb'));f:write(cjson.encode(result));f:close();engine:Exit()
end

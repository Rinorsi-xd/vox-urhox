local Math=require 'core.Math3'
local Coord=require 'core.Coord'
local State=require 'render.EquipmentState'
local Resources=require 'render.EquipmentResources'
local Quality=require('render.Quality').current
local phase='active'
for _,a in ipairs(GetArguments()) do phase=a:match('^%-equipment%-phase=(.+)$') or phase end
---@type HangarApp|nil
local app=nil
---@type table|nil
local trial=nil
engine.maxInactiveFps=120
local function Near(a,b) return math.abs(a-b)<1e-6*math.max(1,math.abs(b)) end
local function Step(n,cmd) for _=1,n do trial:Tick(1/60,cmd or {}) end end
V.atFrame(40,function()
    local f=assert(io.open('tools/migration/source-equipment-fixtures.json','r'));local fixture=cjson.decode(f:read('*a'));f:close()
    for _,case in ipairs(fixture.cases) do
        local power=0
        for i,s in ipairs(case.steps) do
            power=State.Power(power,s.target,s.dt);local ok=Near(power,s.power) and Near(1.5+power*.85,s.emission)
            for j,nozzle in ipairs(case.info.nozzles) do
                local jet=State.Jet(case.info,nozzle,power,s.time,case.seed);local expected=s.jets[j]
                ok=ok and Near(jet.radius,expected.radius) and Near(jet.length,expected.length) and Near(jet.power,expected.power)
            end
            V.assert(ok,'original ThrusterRig '..case.type..' update '..i)
        end
    end
end)
V.atFrame(45,function() app=assert(VOX_HANGAR).app;V.assert(app:EnterTrial(),'equipment trial enters') end)
V.atFrame(90,function()
    trial=assert(app.trial);local t=trial;local v=t.vehicle;local fx=t.view.equipment
    v:Place({0,0,-40},0);t.view:ResetPose();Step(360)
    local kind=#v.spec.hovers>0 and 'hover' or #v.spec.legs>0 and 'leg' or 'thruster'
    if kind=='thruster' then Step(60,{climb=1,throttle=1}) end
    t.yaw=145;t.pitch=kind=='hover' and 8 or 16;t:PostUpdate(1)
    fx:Update(1/60,t.fxContext)
    local visible,contacts=0,0
    for id,item in pairs(fx.items) do
        local s=item.vis.data.segments
        if s.thruster then
            V.assert(item.power>=0 and item.power<=1,'bounded output '..id)
            for i,proxy in pairs(item.proxies) do if proxy.model.enabled then
                visible=visible+1;local n=s.info.nozzles[i];local d=State.Jet(s.info,n,item.power,t.world.time,item.seed)
                local axis=item.vis.rig.housing.worldRotation*Coord.Vec(table.unpack(s.info.exhaustDir))
                local base=item.vis.rig.housing:LocalToWorld(Coord.Vec(table.unpack(n.p)))
                V.assert((proxy.node.worldPosition-base-axis*d.length*.5*.5):Length()<1e-5,'gimballed exhaust origin '..id..'/'..i)
                V.assert((proxy.node.worldRotation*Vector3.FORWARD):DotProduct(axis)>.9999,'exhaust axis '..id..'/'..i)
                V.assert(math.abs(proxy.node.worldScale.z-d.length*.5)<1e-5,'exhaust uses metres '..id..'/'..i..' actual='..proxy.node.worldScale.z..' expected='..d.length*.5)
            end end
        elseif s.hover then
            local state=v.hoverStates[id];V.assert(item.power>0 and state.force>0,'hover powered by physical support '..id)
            for i,proxy in pairs(item.proxies) do if proxy.model.enabled then
                visible=visible+1;local hit=state.emitHits[i]
                local endPoint=proxy.node.worldPosition-proxy.node.worldRotation*Vector3.UP*(proxy.node.worldScale.y*.5)
                V.assert((endPoint-Coord.Vec(table.unpack(hit.point))):Length()<1e-5,'field terminates at ray hit '..id..'/'..i)
            end end
        else if item.planted then contacts=contacts+1 end end
    end
    V.assert(kind=='leg' and contacts>0 or visible>0,'actual equipment geometry is visible')
    V.assert(#fx.particles<=Quality.exhaustParticles,'bounded residual exhaust budget')
    local retained={};for id,item in pairs(fx.items) do retained[id]=item end
    t.view:Bind(app.blueprint,v)
    local continuous=true;for id,item in pairs(fx.items) do continuous=continuous and retained[id]==item end
    V.assert(continuous,'rebind retains power, proxies and contact phase')
    local originalCamera=t.fxContext.camera;local far=t.scene:CreateChild('EquipmentFarTest');far.position=Vector3(10000,10000,10000)
    fx:Update(.01,{camera=far,time=t.world.time});local hidden=true
    for _,item in pairs(fx.items) do for _,p in pairs(item.proxies) do hidden=hidden and not p.model.enabled end end
    V.assert(hidden,'far distance disables volume proxies');far:Dispose()
    fx:Update(.01,t.fxContext)
    if kind=='thruster' then
        Step(1,{cutLift=true});V.assert(#fx.particles>0,'cutoff leaves world-space residual particles')
        Step(40,{cutLift=true});V.assert(#fx.particles==0,'residual particles expire after cutoff')
        for _,item in pairs(fx.items) do if item.vis.data.segments.thruster then V.assert(item.power==0,'cutoff settles to zero '..item.id) end end
    elseif kind=='hover' then
        v:Place({0,35,-40},0);t.view:ResetPose();Step(1)
        local off=true;for _,item in pairs(fx.items) do if item.vis.data.segments.hover then
            off=off and item.power==0;for _,p in pairs(item.proxies) do off=off and not p.model.enabled end
        end end
        V.assert(off,'no hover light without terrain contact')
    else
        Step(1,{jump=true});local glow=false
        for id,item in pairs(fx.items) do if item.vis.data.segments.leg then
            local state=v.legStates[id];glow=glow or state.jumpGlow>0
            for _,model in ipairs(item.vis.emissionModels) do V.assert(Near(model.instanceCustomData.x,2.8+state.jumpGlow*5),'jump emission '..id) end
        end end
        V.assert(glow,'leg jump lights respond to physical jump')
    end
    t:Reset();V.assert(#fx.particles==0,'reset clears trails')
    local reset=true;for _,item in pairs(fx.items) do reset=reset and item.power==0 and not item.planted end
    V.assert(reset,'reset clears power and contact pulse')
    v:Place({0,0,-40},0);t.view:ResetPose();Step(360)
    if kind=='thruster' then Step(60,{climb=1,throttle=1});if phase=='cut' then Step(35,{cutLift=true}) end
    elseif kind=='leg' and phase=='jump' then Step(12,{jump=true}) end
    t.yaw=145;t.pitch=kind=='hover' and 8 or 16;t:PostUpdate(1);fx:Update(0,t.fxContext);t.hud.Update(t)
    t.Update=function() end;t.PostUpdate=function() end
end)
V.atFrame(130,function()
    local fx=trial.view.equipment;local id,item=next(fx.items);local nodes=fx.root:GetNumChildren()
    local removed=0;for _ in pairs(item.proxies) do removed=removed+1 end
    trial.view.view:RemovePart(id);trial.view:Bind(app.blueprint,trial.vehicle)
    V.assert(fx.items[id]==nil and fx.root:GetNumChildren()==nodes-removed,'removed equipment releases volume nodes immediately')
    fx:Update(1/60,trial.fxContext)
end)
V.atFrame(132,function() app:Reload() end)
V.atFrame(175,function()
    V.assert(app.mode=='hangar' and trial.disposed,'return disposes trial')
    V.assert(Resources.users==0 and next(Resources.materials)==nil and Resources.flow==nil,'last vehicle releases shared volume resources')
    V.assert(next(trial.view.equipment.items)==nil and #trial.view.equipment.particles==0,'equipment ownership cleaned up')
    V.finish()
end)

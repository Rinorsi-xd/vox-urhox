local app,session ---@type table?,table?
local stage='boot';local elapsed=0;local steps=0;local peakProjectiles=0;local peakParticles=0
local previousWall=nil ---@type integer?
local label='baseline';local quality=require('render.Quality').current.name
for _,arg in ipairs(GetArguments()) do label=arg:match('^-stress%-label=([%w%-]+)$') or label end
-- Exact pre-optimization formulas from backup 57c414d, outside shipping scripts.
local reference={};local V3=require 'core.Math3'
local function Offset(p,v,k) return V3.Add(p,V3.Scale(v,k)) end
function reference:Segment(a,b,width,color,alpha,core,u0,u1,streak)
    local dir=V3.Normalize(V3.Sub(b,a));local side=V3.Cross(dir,V3.Normalize(V3.Sub(a,self.camera)))
    if V3.Length(side)<.00001 then side={0,1,0} else side=V3.Normalize(side) end
    local length=V3.Length(V3.Sub(b,a));local tip=streak and Offset(b,dir,width*.5) or b
    local points={Offset(a,side,-width*.5),Offset(a,side,width*.5),Offset(tip,side,-width*.5),Offset(tip,side,width*.5)}
    local finish=streak and length+width*.5 or (u1 or 1)
    self:Quad(points,{{streak and 0 or (u0 or 0),-1},{streak and 0 or (u0 or 0),1},{finish,-1},{finish,1}},
        color,alpha,{core or .3,streak and length or 0,streak and width or 0})
end
function reference:Disc(pos,size,color,alpha,right,up,thick)
    local r,u=V3.Scale(right,size*.5),V3.Scale(up,size*.5)
    self:Quad({V3.Sub(V3.Sub(pos,r),u),V3.Add(V3.Sub(pos,u),r),V3.Add(V3.Sub(pos,r),u),V3.Add(V3.Add(pos,r),u)},
        {{-1,-1},{1,-1},{-1,1},{1,1}},color,alpha,{thick or .18,0,0})
end
if label=='baseline' then
    local batch=require 'render.EffectBatch'
    batch.Segment=reference.Segment;batch.Disc=reference.Disc
end
local timings={tick={},physics={},ai={},effects={}};local frameTimes={};local memory={};local allocations={};local batchTimes={}
local function Stats(values)
    table.sort(values);local n=#values
    return {count=n,p50=values[math.max(1,math.ceil(n*.5))] or 0,p95=values[math.max(1,math.ceil(n*.95))] or 0,
        p99=values[math.max(1,math.ceil(n*.99))] or 0,max=values[n] or 0}
end
local function Wrap(object,key,samples)
    local original=object[key]
    object[key]=function(self,...)
        local started=os.clock();local result=original(self,...)
        samples[#samples+1]=(os.clock()-started)*1000;return result
    end
end
engine.maxInactiveFps=120
local function GeometryParity()
    local batch=require 'render.EffectBatch';local actual=batch.New(session.scene,'Glow',300);local expected=batch.New(session.scene,'Glow',300)
    local camera={9,12,-30};local color={2,3,4};actual:Begin(camera,1);expected:Begin(camera,1)
    for i=1,100 do
        local a={math.sin(i)*12,i*.1,math.cos(i)*14};local b={a[1]+i%5,a[2]+i%3,a[3]+i%7}
        if i==1 then b=a end
        if i==2 then a=camera;b={camera[1]+5,camera[2],camera[3]} end
        local width=i%4*.1;local streak=i%2==0
        actual:Segment(a,b,width,color,.7,0,.2,.8,streak);reference.Segment(expected,a,b,width,color,.7,0,.2,.8,streak)
        local right={math.sin(i),.3,math.cos(i)};local up={.2,1,.1}
        actual:Disc(a,.5+i*.01,color,.6,right,up,.2);reference.Disc(expected,a,.5+i*.01,color,.6,right,up,.2)
    end
    actual:Finish();expected:Finish()
    local count=actual.mesh:GetNumVertices(0);V.assert(count==1200 and count==expected.mesh:GetNumVertices(0),'all original particle and ribbon triangles retained')
    local positions,normals,uvs,colors=true,true,true,true
    for i=0,count-1 do
        local a,b=actual.mesh:GetVertex(0,i),expected.mesh:GetVertex(0,i)
        positions=positions and (a.position-b.position).length<.0001
        normals=normals and (a.normal-b.normal).length<.0001
        uvs=uvs and (a.texCoord-b.texCoord).length<.0001;colors=colors and a.color==b.color
    end
    V.assert(positions,'optimized GPU positions match original including zero length and camera-parallel segments')
    V.assert(normals and uvs and colors,'optimized shader parameters UV and HDR colors match original')
    actual:Dispose();expected:Dispose()
end
local function Setup()
    session=app.trial;session.Update=function() end
    if session.intro and not session.intro.done then session.intro:Finish() end
    local b=session.battle;V.assert(#b.entries==8,'pressure test uses production 4v4 native vehicles')
    b.rules:Step(5,b:WorldState());b.rules:Drain()
    for i,e in ipairs(b.entries) do
        local pos={(i%4-1.5)*18,session.world:GroundAt((i%4-1.5)*18,-140+(i<=4 and -20 or 20))+2,-140+(i<=4 and -20 or 20)}
        e.unit.vehicle:Place(pos,i<=4 and 0 or math.pi);e.unit:SavePose();e.unit.previous=e.unit.current
    end
    session.view:ResetPose();session.yaw=0;session.pitch=25;session:PostUpdate(1)
    GeometryParity()
    Wrap(session,'Tick',timings.tick);Wrap(session.world.space,'Step',timings.physics)
    Wrap(b,'BeforeStep',timings.ai);Wrap(session.effects,'Update',timings.effects)
    stage='running'
end
local function BenchmarkBatch()
    local batch=require('render.EffectBatch').New(session.scene,'Glow',256)
    local p={0,3,0};local a={-2,3,0};local z={2,3,0};local color={2,3,4};local right,up={1,0,0},{0,1,0}
    for sample=1,40 do
        collectgarbage('collect');collectgarbage('stop')
        local initial=collectgarbage('count');local started=os.clock()
        batch:Begin({0,8,-10},sample/60)
        for _=1,60 do batch:Disc(p,1,color,.5,right,up);batch:Segment(a,z,.2,color,.5,.3) end
        batch:Finish()
        batchTimes[#batchTimes+1]=(os.clock()-started)*1000
        allocations[#allocations+1]=collectgarbage('count')-initial;collectgarbage('restart')
    end
    batch:Dispose()
end
local function Snapshot()
    local shots=0;local alive=0
    for _,e in ipairs(session.battle.entries) do
        shots=shots+(e.env.stats.shots or 0);if e.unit.alive then alive=alive+1 end
    end
    return {second=elapsed,luaKiB=collectgarbage('count'),resourceBytes=cache:GetTotalMemoryUse(),
        modelBytes=cache:GetMemoryUse(StringHash('Model')),arrayBytes=cache:GetMemoryUse(StringHash('Texture2DArray')),
        batches=renderer.numBatches,primitives=renderer.numPrimitives,alive=alive,shots=shots}
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app;V.assert(app:EnterTrial('crater','conquest'),'pressure test enters production crater through loading gate');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then Setup()
    elseif stage=='running' then
        -- GetSystemTime is a static class binding in this runtime.
        local wall=Time:GetSystemTime();if previousWall then frameTimes[#frameTimes+1]=(wall-previousWall)&0xffffffff end;previousWall=wall
        session.pointer.captured=true
        local player=session.battle.player;local aim=player:Position()
        for _,e in ipairs(session.battle.entries) do if e.unit.alive and e.unit.team~=player.team then aim=e.unit:Position();break end end
        session:Tick(1/60,{throttle=.3,steer=math.sin(elapsed*.5)*.25,firing=true,aim=aim})
        session:PostUpdate(1/60);steps=steps+1;elapsed=steps/60
        peakProjectiles=math.max(peakProjectiles,#session.weapons.projectiles)
        peakParticles=math.max(peakParticles,#session.effects.particles)
        if steps%300==0 then memory[#memory+1]=Snapshot() end
        if steps==1800 then
            BenchmarkBatch();memory[#memory+1]=Snapshot()
            local image=Image:new();graphics:TakeScreenShot(image)
            image:SavePNG('docs/migration/evidence/battle-stress-'..quality..'-'..label..'.png');image:Dispose()
            V.assert(memory[#memory].shots>0,'real bots and player fire through native weapon system')
            V.assert(peakParticles<=session.effects.maxParticles,'particle pressure stays within production cap')
            local report={quality=quality,label=label,simulationSeconds=elapsed,fixedSteps=steps,frameMs=Stats(frameTimes),
                cpuMs={},batchCpuMs=Stats(batchTimes),batchAllocationKiB=Stats(allocations),memory=memory,peakProjectiles=peakProjectiles,peakParticles=peakParticles,
                scope='Windows native fixed-step pressure run; CPU timing is os.clock; frameMs is wall-clock Poll interval including rendering/test overhead. Validation timeStep is synthetic and excluded. Not M1 or real mobile thermal measurement.'}
            for key,samples in pairs(timings) do report.cpuMs[key]=Stats(samples) end
            local file=File('docs/migration/evidence/battle-stress-'..quality..'-'..label..'-metrics.json',FILE_WRITE)
            file:WriteString(cjson.encode(report));file:Flush();file:Dispose()
            app:Reload();stage='return'
        end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active and not app.pendingAssetRelease then
        V.assert(cache:GetMemoryUse(StringHash('Texture2DArray'))==0,'stress return releases both terrain arrays');stage='done';V.finish()
    end
end
for frame=40,3600 do V.atFrame(frame,Poll) end
V.atFrame(3605,function() V.assert(stage=='done','pressure lifecycle completed');V.finish() end)

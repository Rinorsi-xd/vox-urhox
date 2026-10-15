-- Executes both real decision modules. Only engine-facing world queries are adapters.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local A=require 'combat.EnemyDriverMath'
local N=require 'combat.EnemyDriverNav'
local current=require 'combat.EnemyDriver'
local oldN=N
local old
if ENEMY_BEFORE_NAV then
    oldN=assert(loadfile(ENEMY_BEFORE_NAV))()
    local isolated={['combat.EnemyDriverNav']=oldN}
    local env=setmetatable({require=function(name)return isolated[name] or require(name)end},{__index=_G})
    for _,name in ipairs({'EnemyDriverTactics','EnemyDriverThink','EnemyDriverMotion'}) do
        isolated['combat.'..name]=assert(loadfile('scripts/combat/'..name..'.lua','t',env))()
    end
    old=assert(loadfile(ENEMY_BEFORE_MODULE,'t',env))()
else old=assert(loadfile(ENEMY_BEFORE_MODULE))() end
local assertions,steps,oldUnused,newUnused,kept=0,0,0,0,0
local trace={};local activeDriver;local suppressed=false;local side='old'
local function Check(ok,message) assert(ok,message);assertions=assertions+1 end
local function Copy(value,seen)
    if type(value)~='table' then return type(value)~='function' and value or nil end
    seen=seen or {};if seen[value] then return '<cycle>' end;seen[value]=true
    local out={};for k,v in pairs(value) do if type(v)~='function' then out[k]=Copy(v,seen) end end
    seen[value]=nil;return out
end
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local seeded=A.Seeded
A.Seeded=function(seed)
    local random=seeded(seed)
    return function()local value=random();trace[#trace+1]={'rng',value};return value end
end
local edgeCalls={old=0,new=0}
local function Observe(nav)
local height=nav.Height
nav.Height=function(world,x,z,above,exclude)
    local info=debug.getinfo(2,'S');local direct=info.source:gsub('\\','/'):match('/EnemyDriver%.lua$')~=nil
    local v=activeDriver and activeDriver.unit.vehicle
    local unused=direct and activeDriver and (activeDriver.time>=1 or v.capabilities and v.capabilities.totalLoad==0 or v.airdropActive or activeDriver.unit.airdropActive)
    local wasSuppressed=suppressed;suppressed=unused or suppressed
    local value=height(world,x,z,above,exclude);suppressed=wasSuppressed
    if unused then if side=='old' then oldUnused=oldUnused+1 else newUnused=newUnused+1 end
    elseif direct then kept=kept+1 end
    return value
end
local staticRay=nav.StaticRay
nav.StaticRay=function(world,from,dir,length,exclude)
    local value=staticRay(world,from,dir,length,exclude)
    if not suppressed then trace[#trace+1]={'staticRay',Copy(from),Copy(dir),length,Copy(value)} end
    return value
end
local visible=nav.Visible
nav.Visible=function(world,from,to,exclude,target)
    local value=visible(world,from,to,exclude,target)
    trace[#trace+1]={'visible',Copy(from),Copy(to),value};return value
end
local edge=nav.EdgeBetween
nav.EdgeBetween=function(layout,a,b)
    local value=edge(layout,a,b);edgeCalls[side]=edgeCalls[side]+1
    trace[#trace+1]={'edgeBetween',a,b,Copy(value)};return value
end
end
Observe(N);if oldN~=N then Observe(oldN) end
local function State(driver)
    local out={}
    for k,v in pairs(driver) do
        if k~='world' and k~='unit' and k~='nav' and k~='graphCache' and type(v)~='function' then out[k]=Copy(v) end
    end
    return out
end
local function Fixture(module,scenario,variant)
    local f={pos={0,1,0},vel={x=0,y=0,z=0},tp={0,1,35},tv={x=0,y=0,z=0},yaw=0,missingFloor=false}
    local body={translation=function()return {x=f.pos[1],y=f.pos[2],z=f.pos[3]}end,linvel=function()return f.vel end,
        rotation=function()return scenario.mode=='flip' and {x=1,y=0,z=0,w=0} or {x=0,y=0,z=0,w=1}end}
    local vehicle={spec=scenario.spec,body=body,Yaw=function()return f.yaw end,capabilities={totalLoad=10}}
    local unit={vehicle=vehicle,spec=scenario.spec,core={hp=100,max=100},integrity=1,hitAt=-1,alive=true,team='enemy',Position=function()return f.pos end}
    local targetVehicle={spec=scenario.targetSpec,Yaw=function()return 0 end,body={linvel=function()return f.tv end}}
    local target={vehicle=targetVehicle,spec=scenario.targetSpec,Position=function()return f.tp end}
    local weapon={stats={range=250},err=0};local pod={stats={range=350,homing=true,share=.5,lockMin=0,lockRange=350},mphase='ready'}
    local ws={groups={{weapons={weapon},kind='gun'}},Aligned=function()return true end,current=1,energy=100,offline=false,
        Select=function(self,i)self.current=i end,Group=function(self)return self.groups[self.current]end};unit.weapons=ws
    if scenario.mode=='missile' or scenario.mode=='charging' then ws.groups[2]={weapons={pod},kind='missile'} end
    local world={layout={nav=ENEMY_DATA.nav},units={unit}}
    world.CastRay=function(_,p,d,length)
        if d[2]<-.99 then
            local dist=p[2]/-d[2]
            return not f.missingFloor and dist>=0 and dist<=length and {point={p[1],0,p[3]},dist=dist,normal={0,1,0}} or nil
        end
        if scenario.mode=='blocked' and p[3]<60 and d[3]>.1 then return {point=p,dist=2,normal={0,0,-1}} end
    end
    if variant=='space' then world.space={Raycast=function(_,p,d,length)return world:CastRay(p,d,length)end} end
    if scenario.mode=='crowd' then for _,sign in ipairs({1,-1}) do local dir=sign
        world.units[#world.units+1]={alive=true,team='enemy',spec=scenario.targetSpec,vehicle={spec=scenario.targetSpec,yaw=0},Position=function()return {f.pos[1]+dir*1.5,f.pos[2],f.pos[3]+dir*10}end}
    end end
    local shield={active=true,pos={0,1,35},zone={pos={0,0,35},rx=15,rz=12},contains=function(p)return (p[1]/15)^2+((p[3]-35)/12)^2<=1 end,aimPoint=function()return {0,3,23}end}
    trace={};f.driver=module.New(world,unit,scenario.role,scenario.seed,{seed=scenario.seed,tier=scenario.tier});f.initTrace=Copy(trace)
    function f:Step(frame,dt,index,edgeCase)
        self.pos,self.vel,self.tp,self.tv,self.yaw=frame.pos,frame.vel,frame.tp,frame.tv,frame.yaw
        unit.core.hp=frame.hp;unit.hitAt=frame.hitAt;ws.energy=frame.energy;pod.mphase=frame.mphase
        vehicle.airdropActive=frame.airdrop;unit.airdropActive=false;self.missingFloor=false
        vehicle.capabilities={totalLoad=scenario.mode=='disabled' and 0 or 10}
        if edgeCase then
            self.missingFloor=index%11<4;unit.airdropActive=index%19<3;vehicle.airdropActive=index%23<3
            if index%17<2 then vehicle.capabilities=nil elseif index%17<5 then vehicle.capabilities.totalLoad=0 end
            if index==70 then self.driver.time=0 end
            if index==71 then self.driver.time=1-dt end
        end
        local victim=target
        if scenario.mode=='objective' then victim={Position=function()return self.tp end,radius=16,passive=true} end
        if edgeCase and index%37==0 then victim=nil end
        local savedVehicle=unit.vehicle
        if edgeCase and index%41==0 then unit.vehicle=nil end
        trace={};activeDriver=self.driver
        local command,aim,fire,info=self.driver:Step(dt,victim,frame.charge,scenario.mode=='shield' and shield or nil)
        activeDriver=nil;unit.vehicle=savedVehicle
        return {command=Copy(command),aim=Copy(aim),fire=fire,info=Copy(info),state=State(self.driver),current=ws.current},Copy(trace)
    end
    return f
end
local rows={}
for _,variant in ipairs({'fallback','space'}) do
    for _,clock in ipairs({'source-10hz','fixed-60hz','boundaries'}) do
        local before=oldUnused
        for _,scenario in ipairs(ENEMY_DATA.scenarios) do
            side='old';local a=Fixture(old,scenario,variant)
            side='new';local b=Fixture(current,scenario,variant)
            Check(Equal(a.initTrace,b.initTrace),'constructor RNG '..scenario.mode)
            for i,frame in ipairs(scenario.frames) do
                local dt=clock=='source-10hz' and .1 or clock=='fixed-60hz' and 1/60 or ({.3,.15,.05,.5,1/60})[(i-1)%5+1]
                side='old';local ar,at=a:Step(frame,dt,i,clock=='boundaries')
                side='new';local br,bt=b:Step(frame,dt,i,clock=='boundaries')
                local tag=variant..'/'..clock..'/'..scenario.role..'/'..scenario.mode..'/'..i
                Check(Equal(ar,br),'full decision/state '..tag)
                Check(Equal(at,bt),'RNG and retained query sequence '..tag);steps=steps+1
            end
        end
        rows[#rows+1]={world=variant,clock=clock,removedUnusedQueries=oldUnused-before}
    end
end
Check(oldUnused>0,'old actually issued unused probes')
Check(newUnused==0,'new issues no unused probes')
Check(kept>0,'first-second required probes exercised')

-- Existing source-JavaScript golden fixtures, executed against actual production Lua.
local comparedEdgeCalls={old=edgeCalls.old,new=edgeCalls.new}
local goldenAssertions=0
V={atFrame=function(_,f)f()end,assert=function(ok,message)assert(ok,message);goldenAssertions=goldenAssertions+1 end,finish=function()end}
cjson={null=ENEMY_NULL,decode=function()return ENEMY_DATA end}
File=function()return {ReadString=function()return ''end,Dispose=function()end}end
FILE_READ=0
trace={};assert(loadfile('tools/migration/check-enemy-driver.lua'))()
return {result='PASSED',assertions=assertions,goldenAssertions=goldenAssertions,steps=steps,edgeCalls=comparedEdgeCalls,
    removedUnusedQueries=oldUnused,newUnusedQueries=newUnused,requiredProbeCallsIncludingGolden=kept,rows=rows}

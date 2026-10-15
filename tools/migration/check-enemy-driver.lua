local A=require 'combat.EnemyDriverMath'
local N=require 'combat.EnemyDriverNav'
local Driver=require 'combat.EnemyDriver'
local function Near(a,b,key)
    if b==cjson.null then return a==nil or a==cjson.null end
    if type(a)~=type(b) then print('[EnemyGolden] type '..key..' '..tostring(a)..' expected '..tostring(b));return false end
    if type(a)=='number' then if math.abs(a-b)<1e-7*math.max(1,math.abs(b)) then return true end;print('[EnemyGolden] '..key..' '..a..' expected '..b);return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(b) do if not Near(a[k],v,key..'.'..k) then return false end end;return true
end
V.atFrame(40,function()
    local file=File('tools/migration/source-enemy-fixtures.json',FILE_READ);local data=cjson.decode(file:ReadString());file:Dispose()
    for _,row in ipairs(data.rng) do local random=A.Seeded(row.seed);for i,value in ipairs(row.values) do V.assert(Near(random(),value,'rng'),'source seeded RNG '..tostring(row.seed)..'/'..i) end end
    for _,row in ipairs(data.paths) do V.assert(Near(N.Path(data.nav,{0,1,0},{60,1,180},row.width),row.value,'path'),'source width qualified path '..row.width) end
    for _,row in ipairs(data.zones) do local z={pos={0,0,0},rx=20,rz=10};V.assert(N.Inside(z,row.p,4)==row.inside and Near(N.Edge(z,row.p,4,{1,0,1}),row.edge,'zone'),'source ellipse exclusion') end
    for _,scenario in ipairs(data.scenarios) do
        local pos,vel,tp,tv,yaw={0,1,0},{x=0,y=0,z=0},{0,1,35},{x=0,y=0,z=0},0
        local body={translation=function()return {x=pos[1],y=pos[2],z=pos[3]}end,linvel=function()return vel end,rotation=function()return scenario.mode=='flip' and {x=1,y=0,z=0,w=0} or {x=0,y=0,z=0,w=1}end}
        local vehicle={spec=scenario.spec,body=body,Yaw=function()return yaw end,capabilities={totalLoad=10}}
        local unit={vehicle=vehicle,spec=scenario.spec,core={hp=100,max=100},integrity=1,hitAt=-1,alive=true,team='enemy',Position=function()return pos end}
        local targetVehicle={spec=scenario.targetSpec,Yaw=function()return 0 end,body={linvel=function()return tv end}}
        local target={vehicle=targetVehicle,spec=scenario.targetSpec,Position=function()return tp end}
        local weapon={stats={range=250},err=0};local pod={stats={range=350,homing=true,share=.5,lockMin=0,lockRange=350},mphase='ready'}
        local ws={groups={{weapons={weapon},kind='gun'}},Aligned=function()return true end,current=1,energy=100,offline=false,Select=function(self,i)self.current=i end,Group=function(self)return self.groups[self.current]end};unit.weapons=ws
        if scenario.mode=='missile' or scenario.mode=='charging' then ws.groups[2]={weapons={pod},kind='missile'} end
        local world={layout={nav=data.nav},units={unit}}
        world.CastRay=function(_,p,d,length)if d[2]<-.99 then local dist=p[2]/-d[2];return dist>=0 and dist<=length and {point={p[1],0,p[3]},dist=dist} or nil end;if scenario.mode=='blocked' and p[3]<60 and d[3]>.1 then return {point=p,dist=2} end end
        if scenario.mode=='crowd' then for _,side in ipairs({1,-1}) do local dir=side;local ally={alive=true,team='enemy',spec=scenario.targetSpec,vehicle={spec=scenario.targetSpec,yaw=0},Position=function()return {pos[1]+dir*1.5,pos[2],pos[3]+dir*10}end};world.units[#world.units+1]=ally end end
        local shield={active=true,pos={0,1,35},zone={pos={0,0,35},rx=15,rz=12},contains=function(p)return (p[1]/15)^2+((p[3]-35)/12)^2<=1 end,aimPoint=function()return {0,3,23}end}
        local driver=Driver.New(world,unit,scenario.role,scenario.seed,{seed=scenario.seed,tier=scenario.tier})
        for i,frame in ipairs(scenario.frames) do
            pos,vel,tp,tv,yaw=frame.pos,frame.vel,frame.tp,frame.tv,frame.yaw;unit.core.hp=frame.hp;unit.hitAt=frame.hitAt;ws.energy=frame.energy;pod.mphase=frame.mphase;vehicle.airdropActive=frame.airdrop;vehicle.capabilities.totalLoad=scenario.mode=='disabled' and 0 or 10
            local victim=target;if scenario.mode=='objective' then victim={Position=function()return tp end,radius=16,passive=true} end
            local command,aim,fire,out=driver:Step(.1,victim,frame.charge,scenario.mode=='shield' and shield or nil)
            if driver.mode=='landing' then out={command=command,aim=aim,trigger=fire,salvo=false,reset=nil,mode='landing',visible=false} end
            V.assert(Near(out,frame.out,scenario.role..'/'..scenario.mode..'/'..i),'source AI decision '..scenario.role..'/'..scenario.mode..'/'..i)
            V.assert(Near({circle=driver.circle,lane=driver.lane,reaction=driver.reaction,error=driver.error,lag=driver.lag,route=driver.route,goal=driver.goal,life=driver.life,current=ws.current},frame.state,'state'),'source AI retained state '..scenario.role..'/'..scenario.mode..'/'..i)
        end
    end;V.finish()
end)

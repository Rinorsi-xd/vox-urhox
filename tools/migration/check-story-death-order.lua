package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
for _,id in ipairs({'story.MissionData','combat.ArenaData','combat.CarUnit','combat.EnemyDriver','core.Math3','drive.SpawnSpecCache'}) do package.preload[id]=function()return {}end end
local trace={}
package.preload['render.StoryStomp']=function()return {Emit=function(_,pos,k)trace[#trace+1]={kind='stomp',pos=pos,strength=k}end}end
input={GetKeyDown=function()return false end};KEY_G='G'
local Mission=require 'story.Mission'
local Rules=require 'story.MissionRules'
local checks=0
local function Check(ok,label)checks=checks+1;assert(ok,label)end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<1e-10 end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a)do if not Same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
local function Run(case,Class)
    trace={}
    local disposed={0,0,0};local player={alive=true,pos={0,2,0},Position=function(s)return s.pos end,vehicle={speed=0,Yaw=function()return 0 end}}
    local step={kind=case.clear and 'clear' or 'capture',id='scouts',pos={-190,-12,0},trigger=95,timeout=90,fightTitle='fight',enemies={{},{},{}},fleeLines={{'huhu','跑了'}}}
    local r=Rules.New({steps={step,{kind='pickup',intel='log'}},intel={log={drop=true}},spawn={}})
    r.begun=true;r.index=1;r.phase='fight';r.time=2;r.fightAt=0
    local world={units={player},layout={nav={}}};local entries={{unit=player}};local tags={{unit=player},{unit='unrelated'}}
    for i,state in ipairs(case.states)do
        local u={id=i,alive=state=='alive' or state=='flee',pos={i*100,2,i*10},spec={bounds={radius=state=='bossDead' and 8 or 3}},
            Position=function(s)return s.pos end,Integrity=function()return state=='flee' and .2 or 1 end,
            Dispose=function(s)disposed[s.id]=disposed[s.id]+1;s.alive=false end}
        entries[#entries+1]={unit=u,flee=state=='flee' and .5 or nil,boss=state=='bossDead',scripted=state=='scriptedDead' or state=='noBlastDead'}
        world.units[#world.units+1]=u;tags[#tags+1]={unit=u}
    end
    local snapshots,delivered={},{};local stepMethod=r.Step
    r.Step=function(self,dt,snapshot)snapshots[#snapshots+1]=snapshot;if case.clear then return stepMethod(self,dt,snapshot)end end
    local m=setmetatable({rules=r,level=r.level,player=player,world=world,entries=entries,enemyPositions={},
        session={trauma=.1,pointer={captured=false},camera={GetCamera=function()end},hud={overlay={tags=tags}}},
        voice={Talking=function()return false end,Say=function()end},radio={Play=function()end},
        view={Update=function()end,Objective=function()end,AddIntel=function(_,id,pos)delivered[#delivered+1]={id=id,pos=pos}end},
        CarSize=function()return {w=2,below=1.5,above=1.5}end,
        explosion={Explode=function(_,pos,size,big)trace[#trace+1]={kind='explode',pos=pos,size=size,big=big==true}end}},Class)
    local emit=r.Emit
    r.Emit=function(self,kind,props)
        if kind=='say' then trace[#trace+1]={kind=kind,lines=props.lines,urgent=props.urgent==true}
        elseif kind=='banner' then trace[#trace+1]={kind=kind,kick=props.kick,title=props.title,sub=props.sub,style=props.kind,ms=props.ms} end
        return emit(self,kind,props)
    end
    m:AfterStep(1/60)
    local firstTrace=trace;trace={}
    local firstKills=r.stats.kills;local surviving={};for i=2,#entries do surviving[#surviving+1]=entries[i].unit.id end
    local firstLast=r.lastKill;local firstDrop=r.dropPos
    local firstSnapshot=snapshots[1]
    m:AfterStep(1/60)
    local removed=#case.states-#surviving
    local clean=#world.units==#surviving+1 and #tags==#surviving+2 and tags[1].unit==player and tags[2].unit=='unrelated'
    for i,id in ipairs(surviving)do clean=clean and world.units[i+1].id==id and tags[i+2].unit.id==id end
    for i,state in ipairs(case.states)do clean=clean and disposed[i]==(state=='alive' and 0 or 1) end
    return {lastKill=firstLast,kills=firstKills,surviving=surviving,trace=firstTrace,drop=firstDrop,trauma=m.session.trauma,
        once=r.stats.kills==firstKills and #trace==0,clean=clean,positions=firstSnapshot.enemyPositions,enemies=firstSnapshot.enemies,removed=removed,delivered=delivered}
end
local old=assert(load(OLD_MISSION,'old-Mission'))()
local legacyFailures,maskFailures=0,0
for _,case in ipairs(SOURCE.cases)do
    local actual=Run(case,Mission)
    for _,key in ipairs({'lastKill','kills','surviving','trace','drop','trauma'})do Check(Same(actual[key],case[key]),case.name..' source '..key)end
    Check(actual.once,case.name..' removed units processed once')
    Check(actual.clean,case.name..' each removed unit disposed once and world/HUD cleaned')
    Check(actual.enemies==#case.surviving,case.name..' rule snapshot enemy count')
    Check(#actual.positions==#case.surviving,case.name..' rule snapshot live positions')
    Check(#actual.delivered==(case.drop and 1 or 0) and (not case.drop or actual.delivered[1].id=='log' and Same(actual.delivered[1].pos,case.drop)),case.name..' actual Mission.Events delivers exact log once')
    for i,id in ipairs(case.surviving)do Check(Same(actual.positions[i],{id*100,2,id*10}),case.name..' live snapshot preserves spawn order')end
    local before=Run(case,old)
    if not Same(before.lastKill,case.lastKill)or not Same(before.trace,case.trace)then
        legacyFailures=legacyFailures+1;if case.clear then maskFailures=maskFailures+1 end
    end
end
Check(maskFailures==4,'actual old production fails all four simultaneous scout kill masks')
Check(legacyFailures>4,'actual old production also fails mixed death/flee ordering')
return {status='PASS',checks=checks,cases=#SOURCE.cases,scoutMasks=7,legacyFailures=legacyFailures,legacyScoutFailures=maskFailures,
    boundary='Full frozen StoryMission.afterStep/update and original capture onFlee versus actual Mission.AfterStep/Rules with engine objects doubled. No GPU, Web, natural mission completion or phone acceptance.'}

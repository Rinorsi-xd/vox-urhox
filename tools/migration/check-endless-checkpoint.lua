package.path='scripts/?.lua;'..package.path
local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local config={runKey='checkpoint',bossEvery=5,maxTier=5,startTier=1,shieldBase=100,shieldPerWave=10,spawnInvulnerability=3}
package.loaded['endless.Data']={config=config}
for _,name in ipairs({'combat.CarUnit','combat.EnemyDriver','combat.DrillRaiderDriver','combat.ShieldQuery','core.Math3','construction.Blueprint','endless.Random'}) do package.loaded[name]={} end
package.loaded['endless.Records']={Run=function() return true end}
package.loaded['endless.Inventory']={Supplies=function() return {{kind='part',type='laser1'}} end,
    Limited=function() return true end,Validate=function() return {ok=true,errors={}} end,
    Blueprint=function(source) return {ToTable=function() return source end} end}
package.loaded['parts.Defs']={PARTS={laser1={name='激光枪 T1',cat='weapon'}}}
local Run=require 'endless.Run'
local Session=assert(load(sessionSource,'@EndlessSession.lua'))()
local function Owner(state,fail)
    local writes,notices={},{}
    local r=setmetatable({state=state,wave=4,tier=1,queue={},alive={},pendingDrops={},dropOrder={},score=350,damage=0,time=10,
        kills={},seed=1,lives=3,credits=20,repairs=0,weaponDrought=0,shield={},inventory={},blueprint={},events={},supplies={}},Run)
    local app={store={Write=function(_,key,data,validator)
        writes[#writes+1]={key=key,data=data,validator=validator};return not fail,fail and 'storage unavailable' or nil
    end},toasts={Push=function(_,text,tone) notices[#notices+1]={text=text,tone=tone} end}}
    local e=setmetatable({run=r,session={app=app,Pause=function() end,Resume=function() end,ResetCamera=function() end},
        view={Event=function() end},audio={Event=function() end,Play=function() end},Banner=function() end},Session)
    return e,r,writes,notices
end
for _,case in ipairs(onlyFlow and {} or goldens.cases) do
    local e,r,writes,notices=Owner(case.state,case.fail)
    r.Save=function() return {wave=4,score=350} end
    local ok,err=e:Persist()
    Check(#writes==#case.writes,'source write eligibility '..case.state..'/'..tostring(case.fail))
    Check(#notices==#case.notices,'source warning count '..case.state..'/'..tostring(case.fail))
    for i,notice in ipairs(case.notices) do Check(notices[i].text==notice.text and notices[i].tone==notice.tone,'source exact toast '..case.state) end
    if case.state=='rest' then
        Check(ok==not case.fail and (not case.fail or err=='storage unavailable'),'preserve storage return values '..tostring(case.fail))
        Check(writes[1].key==config.runKey and writes[1].data.score==350,'unchanged checkpoint key/payload '..tostring(case.fail))
    end
end
for _,flow in ipairs(onlyFlow and {onlyFlow} or {'clear','supply','edit-return'}) do for _,fail in ipairs(onlyFlow and {true} or {false,true}) do
    local e,r,writes,notices=Owner(flow=='clear' and 'combat' or 'rest',fail)
    if flow=='clear' then r:CheckClear();e:Events()
    elseif flow=='supply' then r.supplies={{kind='part',type='laser1'}};e:ChooseSupply(1)
    else
        r.state='editing';r.beforeEdit='rest'
        e.edit={anchor={pos={0,0,0},yaw=0},Leave=function() end}
        e.player={spec={bounds={min={0,0,0},max={1,1,1}}},vehicle={Place=function() end},Spawn=function() end,SavePose=function() end}
        e.world={time=10};e.spawn={pos={0,0,0},yaw=0};e.spawnPresentation={Rise=function() end};e.SyncPlayer=function() end
        local result=e:ResumeEdit({name='edited',parts={}});Check(result.ok and not e.edit,'actual edit return still completes '..tostring(fail))
    end
    Check(#writes==1 and writes[1].key==config.runKey and writes[1].validator==package.loaded['endless.Records'].Run,'actual '..flow..' writes one validated checkpoint '..tostring(fail))
    local warnings=0;for _,notice in ipairs(notices) do if notice.tone=='warn' then
        Check(notice.text=='本局进度未能写入浏览器存储','actual '..flow..' original warning text');warnings=warnings+1
    end end
    Check(warnings==(fail and 1 or 0),'actual '..flow..' warns only on storage failure '..tostring(fail))
    Check(r.wave==4 and r.credits==20,'actual '..flow..' preserves wave and credits '..tostring(fail))
    if flow=='supply' then Check(r.inventory.laser1==1 and #r.supplies==0,'actual supply reward unchanged '..tostring(fail)) end
end end
return checks

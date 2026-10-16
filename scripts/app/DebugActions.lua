-- User-facing H5 debug commands. QA probes remain independent of this module.
local GarageHud=require("ui.GarageHud")
local MissionData=require("story.MissionData")

local M={}
local names={intro='开场动画',story='剧情关卡',match='竞技对战',endless='无尽模式',drive='试车 / 地图',storyPage='剧情页',salvage='打捞大厅',edit='编辑页',home='机库主页'}
local function Home() return GarageHud.GetState() end
function M.Context(app)
    local s=app.trial
    if app.opening and app.opening.active then return 'intro',s end
    if s then return s.story and 'story' or s.battle and 'match' or s.endless and 'endless' or 'drive',s end
    local h=Home()
    return app.build and 'edit' or h and h.tab=='story' and 'storyPage' or app.lobby=='salvage' and 'salvage' or 'home',nil
end
local function Button(id,label) return {id=id,label=label} end
function M.Sections(app,state)
    local where,s=M.Context(app);local sections={};local function Add(title,buttons) sections[#sections+1]={title=title,buttons=buttons} end
    Add('01 // 开场 · 引导',{
        Button('intro','从头播开场'),Button('introContract','直接签约'),Button('introGate','直接看闸门'),
        Button('tutStart','开始新手引导'),Button('tutStop','结束引导'),Button('tutReset','清引导记录')})
    local tut=app.tutorial
    if tut then local rows={};for _,spec in ipairs(tut.data.steps) do rows[#rows+1]=Button('tutJump:'..spec.id,spec.title) end;Add('引导 · 跳到这步',rows) end
    if where=='story' then
        local m=s.story;local rows={}
        for i,step in ipairs(m.level.steps) do rows[#rows+1]=Button('stGo:'..i,string.format('%02d · %s',i,step.title or step.id)) end
        Add('02 // 剧情关卡',rows)
        rows={Button('stTp','传送到目标点'),Button('stDone','完成当前步'),Button('stHush','跳过通讯'),Button('stKill','打掉所有敌人'),
            Button('stDie','炸一次车（看重新空投）'),Button('stComplete','直接任务完成'),Button('stResult','直接结算面板')}
        if m.convoy then rows[#rows+1]=Button('stTruck','运输车修满');rows[#rows+1]=Button('stTruckHit','运输车 -30%') end
        if m.rules.hold then rows[#rows+1]=Button('stHold20','坚守只剩 20 秒');rows[#rows+1]=Button('stShield','护盾 -30%') end
        Add('剧情操作',rows)
    elseif where=='match' then
        local b=s.battle;local rows={}
        if b.mvpShow then rows[#rows+1]=Button('mResult','结束 MVP · 查看结算')
        elseif b.rules.state~='over' then
            if b.rules.Won then rows={Button('rWin','本回合我方赢'),Button('rLose','本回合对方赢'),Button('rDraw','本回合平局')}
            elseif b.rules.HalfDone then rows={Button('hDone','本半场推到终点'),Button('hTime','本半场时间到')} end
            for _,row in ipairs({{'mWin','整局我方立即获胜'},{'mLose','整局我方立即失败'},{'mDraw','整局平局'},
                {'mResultWin','直接胜利结算'},{'mResultLose','直接失败结算'},{'mResultDraw','直接平局结算'}}) do rows[#rows+1]=Button(row[1],row[2]) end
        end
        Add('02 // 竞技对战',rows)
    end
    if s then
        local rows={}
        for i,spot in ipairs(s.world.layout.teleports or {}) do rows[#rows+1]=Button('tp:'..i,spot.name) end
        rows[#rows+1]=Button('god',state.god and '无敌：开' or '无敌：关');rows[#rows+1]=Button('heal','修满');rows[#rows+1]=Button('die','自爆');rows[#rows+1]=Button('exit','退出到主页')
        Add('03 // 试车 · 地图',rows)
        Add('08 // 战斗移动', {Button('combatRefill','修满车体/结构'),Button('combatHit','测试受伤 10%'),Button('combatEmpty','打空结构')})
    elseif where~='intro' then
        local rows={Button('story','剧情页')}
        for i,level in ipairs(MissionData.levels) do rows[#rows+1]=Button('storyN:'..i,'第 '..level.no..' 关 · '..level.name) end
        for _,row in ipairs({{'mElim','歼灭战'},{'mConq','站点战'},{'mEsc','推车战'},{'mapTest','试车场'},{'mapCrater','坠舰陨坑'},
            {'mapSalvage','打捞地图'},{'salvage','打捞大厅'},{'edit','编辑页'},{'home','机库主页'}}) do rows[#rows+1]=Button(row[1],row[2]) end
        Add('02 // 直接进入',rows)
        if where=='salvage' then Add('03 // 打捞',{Button('svFill','仓库每样 +20'),Button('svCash','+10000 信用点'),Button('svEmpty','清空仓库'),Button('svGo','直接出发')}) end
    end
    Add('09 // 通用',{Button('clrProfile','清签约名字'),Button('clrStory','清剧情记录'),Button('clrSalvage','清打捞仓库')})
    return sections,names[where],where
end
function M.Status(app,fps,state)
    local where,s=M.Context(app);local rows={'界面 '..names[where]..' · '..math.floor(fps+.5)..' fps'}
    if s and s.combat and s.combat.player then local p=s.combat.player
        rows[#rows+1]=string.format('车体 %.0f/%.0f · 结构 %.0f/%.0f',p.bodyHp or 0,p.bodyHpMax or 0,p.struct or 0,p.structMax or 0)
        local pos=p:Position();rows[#rows+1]=string.format('车 %s · 位置 %.0f, %.0f, %.0f%s',p.alive and '存活' or '已损毁',pos[1],pos[2],pos[3],state.god and ' · 无敌' or '')
        if s.story then local r=s.story.rules;rows[#rows+1]=string.format('剧情 %d/%d · %s · %s',r.index,#s.story.level.steps,(r:StepSpec() or {}).id or '完成',r.phase) end
        if s.battle then rows[#rows+1]='对战 · '..s.battle.rules.state end
    end
    return rows
end
local function Strike(s,u,amount,attacker)
    if not u or not u.alive then return false end
    local part=u.bp:CoreParts()[1];if not part then return false end
    local world=s.world;local old,oldEnv,mult=world.attacker,u.env.attacker,u.incomingDamageMultiplier
    world.attacker=attacker;u.env.attacker=attacker;u.incomingDamageMultiplier=1
    local ok,err=pcall(function() u:Damage(part.id,amount,u:Position());u:Flush() end)
    world.attacker=old;u.env.attacker=oldEnv;u.incomingDamageMultiplier=mult
    if u==s.combat.player then s.combat:SyncPlayer() end
    if not ok then error(err,0) end;return true
end
local function KillEnemies(s)
    local me=s.combat.player
    for _,entry in ipairs(s.combat.entries or {}) do local u=entry.unit;if u~=me and u.team~=me.team and u.alive then Strike(s,u,1e9,me) end end
end
local function PlaceStory(m,target,back)
    if not target then return false end;back=back or 0
    m:Place({pos={target[1]+back,target[2]+1,target[3]+back},yaw=math.atan(-back,-back)});return true
end
local function SaveStash(app,change)
    local lobby=app.salvageLobby;if not lobby then return false,'请先进入打捞大厅' end
    local old=lobby.data;local nextData={};for k,v in pairs(old) do nextData[k]=v end
    nextData.items={};for k,v in pairs(old.items) do nextData.items[k]=v end
    change(nextData);lobby.data=nextData;local ok,err=lobby:Save();if not ok then lobby.data=old end
    GarageHud.Refresh();return ok,err
end
local function FinishMvp(b)
    if not b.mvpShow then return false end
    b.mvpShow.done=true;b.mvpShow:Dispose();return true
end
local function StoryResult(m)
    local r=m.rules;local s=r.stats;local par=m.level.par or {420,600}
    r.grade=s.deaths==0 and s.fails==0 and r.time<par[1] and 'S' or s.deaths+s.fails<=1 and r.time<par[2] and 'A' or 'B'
    if m.level.gradePolicy=='truckHp' then local hp=s.truckHp or 1
        if hp<.35 then r.grade='B' elseif hp<.7 and r.grade=='S' then r.grade='A' end
    end
    if m.level.gradePolicy=='shield' and (s.shield or 1)<.3 and r.grade=='S' then r.grade='A' end
    r.finished=true;r:Emit('result',{grade=r.grade,time=r.time});m:Events();return true
end
function M.Execute(app,state,action)
    local id,arg=action:match('^([^:]+):?(.*)$');local _,s=M.Context(app);local h=Home();local p=s and s.combat and s.combat.player
    local m=s and s.story;local b=s and s.battle;local r=m and m.rules
    local tut=app.tutorial
    if id=='intro' or id=='introContract' or id=='introGate' then
        if app.trial then return false,'请先退出当前驾驶' end
        local part=id=='introContract' and 'contract' or id=='introGate' and 'gate' or ''
        if app.opening and app.opening.active then
            app.opening:Finish();state.pendingOpening=part;return true
        end
        return app:StartOpening(part)
    elseif id=='tutStart' then if not tut then return false end;tut:Start();return true
    elseif id=='tutStop' then if not tut then return false end;tut.rules:Stop();return true
    elseif id=='tutReset' then
        if not tut then return false end
        local ok,err=app.store:Write('tutorial-v1',{},nil,true);if ok then tut.rules:Stop();tut.rules.record={};tut.initialized=false end;return ok,err
    elseif id=='tutJump' then
        if not tut then return false end
        for _,path in ipairs({'intro','build','drive'}) do for i,step in ipairs(tut.data.flows[path]) do if step==arg then
            tut.initialized=true;tut.rules:Start(i,path,tut:State());tut.revision=-1;return true
        end end end;return false,'未找到引导步骤'
    elseif id=='stGo' and m then r:Go(math.max(1,math.min(#m.level.steps,tonumber(arg) or 1)));m:Events();return true
    elseif id=='stTp' and m then return PlaceStory(m,r:Target() or (r:StepSpec() or {}).pos,12)
    elseif id=='stHush' and m then m.voice:Hide();return true
    elseif id=='stKill' and m then KillEnemies(s);return true
    elseif id=='stDie' and m then return Strike(s,p,1e9,nil)
    elseif id=='stComplete' and m then r:Go(#m.level.steps+1);m:Events();return true
    elseif id=='stResult' and m then return StoryResult(m)
    elseif id=='stTruck' and m and m.convoy then m.convoy.hp=1;return true
    elseif id=='stTruckHit' and m and m.convoy then m.convoy.hp=math.max(.01,m.convoy.hp-.3);return true
    elseif id=='stHold20' and r and r.hold then r.hold.left=math.min(r.hold.left,20);return true
    elseif id=='stShield' and r and r.hold then r.hold.energy=math.max(.01,r.hold.energy-.3);return true
    elseif id=='stDone' and m then
        local step=r:StepSpec();if not step then return false end
        if step.kind=='clear' then if r.phase~='fight' then PlaceStory(m,step.pos) end;state.pendingKill={session=s,left=.6}
        elseif step.kind=='escort' then KillEnemies(s);m.convoy.d=math.max(m.convoy.d,m.convoy.total-2);PlaceStory(m,m.convoy.pos,10)
        elseif step.kind=='hold' then KillEnemies(s);r.hold.left=math.min(r.hold.left,.5);r.stepT=math.max(r.stepT,step.delay or 0)
        elseif step.kind=='capture' then PlaceStory(m,step.pos);state.pendingCapture={session=s,time=0,phase=0}
        elseif step.kind=='boss' then
            if m.boss and m.boss.rules.state=='fight' then m.boss.rules:Hurt(m.boss.rules.hp+1);m.boss:Events() elseif m.boss then m.boss.skip=true end
        else PlaceStory(m,r:Target() or step.pos,step.kind=='install' and 2 or 0);if step.kind=='install' then state.pendingInteract={session=s,left=3.5} end end
        return true
    elseif id=='tp' and s then local spot=s.world.layout.teleports[tonumber(arg) or 1];if not spot then return false end
        if m then m:Place(spot) else s:ApplyResetSpot(spot);s:ResetCamera() end;return true
    elseif id=='god' and p then state.god=not state.god;p.incomingDamageMultiplier=state.god and 0 or 1;return true
    elseif (id=='heal' or id=='combatRefill') and p and p.alive then p:Heal(1);p:RestoreMissing(math.huge);p:Flush();s.combat:SyncPlayer();return true
    elseif id=='die' and p then return Strike(s,p,1e9,nil)
    elseif id=='combatHit' and p then return Strike(s,p,p.bodyHpMax*.1,nil)
    elseif id=='combatEmpty' and p then p.struct=0;p.structRegen=false;p.hitAt=s.world.time;p.structBrokenAt=s.world.time;return true
    elseif id=='exit' and s then s.wantsReturn=true;return true
    elseif id=='mResult' and b and b.mvpShow then if b.mvpShow.preparing then return false,'MVP 正在准备' end;return FinishMvp(b)
    elseif b and (id=='rWin' or id=='rLose' or id=='rDraw' or id=='hDone' or id=='hTime') then
        if b.rules.state~='prep' and b.rules.state~='live' then return false,'回合间隔中，等下一回合开始' end
        if b.rules.Won then b.rules:Won(id=='rWin' and 'blue' or id=='rLose' and 'red' or nil,id=='rDraw' and 'hp' or 'wipe')
        elseif b.rules.HalfDone then b.rules:HalfDone(id=='hDone') else return false end
        b:AfterStep(0);return true
    elseif b and (id=='mWin' or id=='mLose' or id=='mDraw' or id=='mResultWin' or id=='mResultLose' or id=='mResultDraw') then
        if b.rules.state=='over' then return false,'本局已结算' end
        local winner=id:match('Win$') and 'blue' or id:match('Lose$') and 'red' or nil
        b.rules.state='over';b.rules.winner=winner;b.rules:Emit('matchOver',{winner=winner});b:AfterStep(0)
        if id:match('^mResult') then FinishMvp(b) end;return true
    elseif not s and (id=='story' or id=='storyN') then
        if not h then return false end;h.SetTab('story');if id=='storyN' then return app:EnterTrial('story'..arg) end;return true
    elseif not s and (id=='mElim' or id=='mConq' or id=='mEsc') then return app:EnterBattle(({mElim='elimination',mConq='conquest',mEsc='escort'})[id])
    elseif not s and (id=='mapTest' or id=='mapCrater' or id=='mapSalvage') then return app:EnterTrial(({mapTest='trial',mapCrater='crater',mapSalvage='salvage'})[id])
    elseif id=='edit' and not s then app:EnterBuild();return true
    elseif id=='salvage' and h then h.SetLobby('salvage');return true
    elseif id=='home' and h then if app.build then app:ExitBuild();h=Home() end;if app.lobby=='salvage' then h.SetLobby('arena') else h.SetTab('hangar') end;return true
    elseif id=='svGo' and not s then return app:EnterTrial('salvage')
    elseif id=='svCash' then return SaveStash(app,function(d) d.credits=d.credits+10000 end)
    elseif id=='svEmpty' then return SaveStash(app,function(d) d.items={} end)
    elseif id=='svFill' then return SaveStash(app,function(d) for key in pairs(d.items) do d.items[key]=d.items[key]+20 end end)
    elseif id=='clrProfile' then return app.store:Write('intro-profile',{},nil,true)
    elseif id=='clrStory' then return app.store:Write('story-progress',{},nil,true)
    elseif id=='clrSalvage' then
        if not app.salvageLobby then return false,'打捞仓库尚未初始化' end
        local ok,err=app.salvageLobby.store:Write('stash',{},nil,true)
        if ok then app.toasts:Push('[调试] 打捞仓库已清（刷新生效）','ok') end;return ok,err
    end
    return false,'此操作不适用于当前界面'
end
function M.Update(app,state,dt)
    local _,s=M.Context(app)
    if state.god and s and s.combat and s.combat.player then s.combat.player.incomingDamageMultiplier=0 end
    if state.pendingOpening~=nil and not (app.opening and app.opening.active) then local part=state.pendingOpening;state.pendingOpening=nil;app:StartOpening(part) end
    local kill=state.pendingKill
    if kill then if app.trial~=kill.session then state.pendingKill=nil else kill.left=kill.left-dt;if kill.left<=0 then KillEnemies(kill.session);state.pendingKill=nil end end end
    local hold=state.pendingInteract
    if hold then if app.trial~=hold.session then state.pendingInteract=nil else hold.left=hold.left-dt;hold.session.controls.held.interact=hold.left>0;if hold.left<=0 then state.pendingInteract=nil end end end
    local cap=state.pendingCapture
    if cap then
        if app.trial~=cap.session then state.pendingCapture=nil;return end
        cap.time=cap.time+dt;local r=cap.session.story.rules
        if cap.phase==0 and cap.time>=.5 then KillEnemies(cap.session);cap.phase=1 end
        if cap.phase==1 and cap.time>=1 then if r.cap and r.cap.phase=='cap' then r.cap.p=1 end;cap.phase=2 end
        if cap.phase==2 and cap.time>=1.6 then KillEnemies(cap.session);cap.phase=3 end
        if cap.time>=2.2 then cap.session.controls.held.interact=cap.time<4.8 end
        if cap.time>=4.8 then state.pendingCapture=nil end
    end
end
return M

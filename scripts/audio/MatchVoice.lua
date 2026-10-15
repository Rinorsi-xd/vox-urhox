-- Source matchVoice event queue: bounded, expiring and no consecutive repeats.
local Data=require('core.ResourceData').Read('Combat/Radio.json')
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
function M.New(battle)
    local self=setmetatable({},M);self:init(battle);return self
end
function M:init(battle)
    self.battle=battle;self.time=0;self.busyUntil=0;self.queue={};self.cool={};self.last={};self.marks={};self.contested={};self.streak=0;self.firstBlood=false;self.cart={since=0,still=0}
    self.root=battle.session.scene:CreateChild('BattleRadio');self.source=self.root:CreateComponent('SoundSource');self.source:SetSoundType('VoxMatchVoice')
    self.gate=require('app.ResourceGate').New();self.ready=false;self.disposed=false;self.card=nil
    local paths={};for _,line in pairs(Data.lines) do paths[#paths+1]=line.path end
    self.gate:Start(paths,function(ok)
        if self.disposed then return end;self.ready=ok
        if ok then for _,q in ipairs(self.queue) do q.untilAt=self.time+q.ttl end end
    end)
end
function M:Reset()
    self.queue={};self.cool={};self.marks={};self.contested={};self.streak=0;self.firstBlood=false;self.cart={since=0,still=0};self.card=nil;self.busyUntil=0;self.source:StopImmediate()
end
function M:Say(key)
    local sp=Data.calls[key];if self.disposed or not sp or (self.cool[key] or 0)>self.time then return false end
    if sp.cool then self.cool[key]=self.time+sp.cool end
    if sp.interrupt then self.queue={};self.source:StopImmediate();self.busyUntil=0;self.card=nil end
    self.queue[#self.queue+1]={key=key,ids=sp.ids,pri=sp.pri,ttl=sp.ttl,untilAt=self.time+sp.ttl,at=self.time}
    table.sort(self.queue,function(a,b) return a.pri>b.pri or a.pri==b.pri and a.at<b.at end)
    while #self.queue>5 do table.remove(self.queue) end
    return true
end
function M:Next()
    if not self.ready then return end
    for i=#self.queue,1,-1 do if self.queue[i].untilAt<self.time then table.remove(self.queue,i) end end
    local q=table.remove(self.queue,1);if not q then return end
    local pool={};for _,id in ipairs(q.ids) do if #q.ids==1 or id~=self.last[q.key] then pool[#pool+1]=id end end
    local id=pool[math.random(1,#pool)];local line=Data.lines[id];local sound=cache:GetResource('Sound',line.path)
    self.last[q.key]=id;self.source:StopImmediate();Levels.Play(self.source,sound,0,.7)
    self.busyUntil=self.time+sound.length+.35;self.card={id=id,key=q.key,text=line.text,at=self.time,untilAt=self.time+sound.length+.5}
end
function M:Event(e)
    local key;local blue=e.team=='blue';local id=e.id
    if e.type=='roundPrep' then
        self.streak=0;self.firstBlood=false;self.marks={}
        key=self.battle.mode=='conquest' and 'titleConquest' or e.round==1 and 'titleElimination' or e.final and 'final' or e.round==2 and 'round2' or 'round3'
    elseif e.type=='halfPrep' then self.marks={};self.cart={since=0,still=0};key=e.half==1 and (e.attack=='blue' and 'titleAttack' or 'titleDefend') or (e.attack=='blue' and 'swapAttack' or 'swapDefend')
    elseif e.type=='roundStart' or e.type=='halfStart' then key='go'
    elseif e.type=='suddenDeath' then key='sudden'
    elseif e.type=='overtime' then key='overtime'
    elseif e.type=='roundEnd' then key=not e.winner and 'roundDraw' or e.winner=='blue' and 'roundWin' or 'roundLose'
    elseif e.type=='pointCapturing' and blue then key='capture'..id
    elseif e.type=='pointTaken' then key=(blue and 'taken' or 'enemyTook')..id
    elseif e.type=='pointLost' and blue then key='lost'..id;self.cool['enemyTook'..id]=self.time+12
    elseif e.type=='shieldDown' then key=blue and 'shieldDownUs' or 'shieldDownThem'
    elseif e.type=='shieldUp' then key=blue and 'shieldUpUs' or 'shieldUpThem'
    elseif e.type=='stolen' and blue then key='stole'
    elseif e.type=='checkpoint' and e.attack=='blue' then key='checkpoint'
    elseif e.type=='halfEnd' then key=e.attack=='blue' and (e.done and 'delivered' or 'timeUp') or (e.done and 'enemyDelivered' or 'heldHalf')
    elseif e.type=='matchOver' then key=not e.winner and 'draw' or e.winner=='blue' and 'win' or 'lose' end
    if key then self:Say(key) end
end
function M:Kill(victim,killer)
    local b=self.battle;local p=b.player;if b.rules.state~='live' then return end;local said=false
    if not self.firstBlood and killer and killer.team~=victim.team then self.firstBlood=true
        if victim~=p then self:Say(killer.team=='blue' and 'firstBloodUs' or 'firstBloodThem');said=true end
    end
    if victim==p then self.streak=0;self:Say(b.rules.cfg.respawn and 'deadRespawn' or 'deadOut');return end
    if killer==p and victim.team~=p.team then self.streak=self.streak+1
        local key=self.streak>=4 and 'streak' or self.streak==3 and 'triple' or self.streak==2 and 'double' or not said and 'kill'
        if key then self:Say(key) end
    elseif not said and victim.team=='blue' then self:Say('allyDown')
    elseif not said and killer and killer.team=='blue' and math.random()<.5 then self:Say('teamKill') end
    if b.mode=='elimination' then local alive=b:WorldState().alive
        if victim.team=='red' and alive.red==1 then self:Say('lastEnemy') end
        if victim.team=='blue' and alive.blue==1 and p.alive then self:Say('lastStand') end
    end
end
function M:Once(key,condition)
    if condition and not self.marks[key] then self.marks[key]=true;self:Say(key) end
end
function M:Update(dt)
    if self.disposed then return end;self.time=self.time+math.max(0,dt)
    if not input.focus or input.minimized then self.source:StopImmediate();self.card=nil;return end
    local b=self.battle;local r=b.rules
    if r.state=='live' and not (b.session.intro and not b.session.intro.done) then
        local left=r:TimeLeft();self:Once('min1',left<=60 and left>55);self:Once('sec30',left<=30 and left>25)
        if b.mode=='conquest' then
            for _,p in ipairs(r.points) do if p.contested and not self.contested[p.id] then self:Say('contested'..p.id) end;self.contested[p.id]=p.contested end
            self:Once('scoreHalf',r.score.blue>=50 and r.score.blue<75);self:Once('scoreNear',r.score.blue>=75)
            self:Once('enemyNear',r.score.red>=75 and r.score.red<90);self:Once('enemyClose',r.score.red>=90)
        elseif b.mode=='escort' then
            local c=self.cart;local now=r.contested and 'stop' or r.pushing>0 and 'go' or 'idle'
            if now~=c.state then if now=='go' then c.gap=c.still end;c.state=now;c.since=0 else c.since=c.since+dt end
            c.still=now=='go' and 0 or c.still+dt
            if c.since>=1.5 and c.said~=now then
                if now=='go' and (not c.said or c.gap>=4) then self:Say(r.attack=='blue' and 'cartGo' or 'enemyPush') end
                if now=='stop' then self:Say(r.attack=='blue' and 'cartStop' or 'held') end
                if now~='idle' then c.said=now end
            end
            self:Once('last100',r.attack=='blue' and r.length-r.s<=100)
        end
    end
    if self.card and self.time>=self.card.untilAt then self.card=nil end
    if self.time>=self.busyUntil then self:Next() end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self.gate:Cancel();self.source:StopImmediate();self.root:Dispose();self.queue={};self.card=nil
end
return M

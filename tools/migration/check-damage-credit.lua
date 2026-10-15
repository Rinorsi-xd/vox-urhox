local World=require 'drive.TrackWorld'
local Metrics=require 'drive.TrialMetrics'
local Unit=require 'combat.CarUnit'
V.atFrame(49,function()
    local file=assert(io.open('.tmp/source-damage-credit.json'));local fixture=cjson.decode(file:read('*a'));file:close()
    for i,c in ipairs(fixture.cases) do
        local player,enemy={},{}
        local world=setmetatable({time=4,stats={damage=0,kills=0},fx={},metrics=Metrics.New({}),feedbackPlayer=player},World)
        world.attacker=c.attacker=='player' and player or c.attacker=='enemy' and enemy or nil
        local target=c.target=='player' and player or enemy
        world:RecordDamage(target,25,{1,2,3},c.kind=='normal' and {} or {[c.kind]=true})
        V.assert(world.stats.damage==c.damage,'frozen damage source attribution '..i)
        local feedback=world.metrics.pending[target]
        V.assert((feedback~=nil)==c.feedback,'frozen local HUD source eligibility '..i)
        if feedback then V.assert(feedback[c.kind]==25,'attributed damage retains its HUD category '..i) end
        target.lastHitBy=world.attacker;world.attacker=nil;world:RecordKill(target,{1,2,3})
        V.assert(world.stats.kills==c.kills and #world.fx==1,'frozen kill credit uses the prior actual hit source '..i)
    end
    for i,c in ipairs(fixture.hits) do
        local player,enemy={},{}
        local unit=setmetatable({alive=true,hp={[1]=c.hp},shields={},combat=true,hull=require('combat.ArenaData').hull,
            bodyHp=1000,bodyHpMax=1000,struct=0,lostCells=0,lostMajor=0,lastHitBy=enemy,
            bp={parts={[1]={type='cube',_cells={{0,0,0}}}}},env={time=4,fx={},viewEvents={},RecordDamage=function()end}},Unit)
        unit.env.attacker=c.attacker=='player' and player or c.attacker=='enemy' and enemy or nil
        if c.shield>0 then unit.shields[1]={v=c.shield,hit=0,t=0} end
        unit.ShieldOf=function(self,id) return self.shields[id].v end
        unit:DamageLayers(1,c.amount,{0,0,0},false)
        local by=unit.lastHitBy==nil and 'none' or unit.lastHitBy==player and 'player' or 'enemy'
        V.assert(by==c.lastHitBy,'frozen shield/body hit attribution and rejected-hit continuity '..i)
    end
    V.finish()
end)

-- Frozen RecoveryMix: only real healing/restoration starts the repair field.
local M={};M.__index=M
local function Clamp(h) return math.max(0,math.min(1,h)) end
function M.Rate(h) return .8+.54*Clamp(h) end
function M.Amount(h) return .3+.7*Clamp(h)^1.3 end
function M.New() local self=setmetatable({},M);self:Reset();return self end
function M:Reset()
    self.unit=false;self.dead=false;self.low=false;self.repairing=false;self.healedAt=-math.huge
    self.seen=setmetatable({},{__mode='k'});self.amount=0;self.rate=1
end
function M:Consume(events,unit,emit)
    if not unit then self.amount=0;return end
    if self.unit~=unit then
        self:Reset();self.unit=unit;self.dead=not unit.alive
    end
    local now=unit.env.time;local hp=unit.Life and unit:Life() or unit:Health();local position=unit:Position()
    for _,event in ipairs(events) do if event.unit==unit and not self.seen[event] then
        self.seen[event]=true
        if event.type=='unitKilled' then self.dead=true
        elseif event.type=='unitSpawn' then
            if self.dead then emit('respawn',position,1) end
            self.dead=false;self.low=false;self.repairing=false;self.healedAt=-math.huge
        elseif event.type=='unitHealed' or event.type=='partRestored' then
            self.healedAt=now;self.repairing=true
            if event.type=='partRestored' then emit('part_restore',position,M.Rate(hp)) end
        end
    end end
    if not unit.alive then self.dead=true;self.repairing=false;self.healedAt=-math.huge end
    if hp>.3 then self.low=false end
    if unit.alive and hp<=.25 and not self.low then emit('low_health',nil,1);self.low=true end
    if self.repairing and hp>=.99999 then
        emit('repair_done',position,1);self.repairing=false;self.healedAt=-math.huge
    end
    self.amount=unit.alive and now-self.healedAt<.45 and M.Amount(hp) or 0
    self.rate=M.Rate(hp);self.health=hp;self.position=position
end
return M

-- Frozen storyKinds.hold; simulation supplies live player/enemy snapshots.
local M={};M.__index=M
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
function M.New(step)
    return setmetatable({step=step,left=step.duration,energy=1,healT=0,near=0},M)
end
function M:Update(rules,dt,world)
    local s=self.step
    if rules.stepT<(s.delay or 0) then return false end
    self.left=self.left-dt;rules.progress=1-self.left/s.duration
    local near=0
    -- The source uses horizontal circles: heal inside healR, drain inside drainR.
    -- Height and car width do not enlarge these two gameplay circles.
    for _,p in ipairs(world.enemyPositions or {}) do if Flat(p,s.pos)<s.drainR then near=near+1 end end
    self.near=near;self.energy=self.energy-near*s.drain*dt
    if world.alive and Flat(world.pos,s.pos)<s.healR then
        rules:Emit('heal',{fraction=s.heal*dt})
        self.healT=self.healT+dt
        if self.healT>2.5 then self.healT=0;rules:Emit('restore',{count=1}) end
    end
    rules.retitle=near>0 and ('把海盗赶出要塞（'..near..' 艘在圈里）') or s.title
    if self.energy<=0 then rules:Fail('要塞护盾被打穿了',s.failLines);return false end
    if self.left<=0 then rules.stats.shield=self.energy;return true end
    return false
end
function M:Retry(rules)
    rules:Emit('say',{lines=self.step.retryLines,urgent=true})
    local p=self.step.pos;rules:Emit('place',{at={pos={p[1],p[2]+1,p[3]},yaw=math.pi}})
    rules:Go(rules.index)
end
return M

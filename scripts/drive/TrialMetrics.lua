-- Source trackSim statistics and drag-lane timing, independent of UI/physics.
local M={};M.__index=M
function M.New(drag)
    local self=setmetatable({drag=drag},M);self:Reset();return self
end
function M:Reset()
    self.recent={};self.damage=0;self.dps=0;self.timing={state='idle',t0=0};self.pending={}
end
function M:Damage(time,target,amount,point,killed,opts)
    self.damage=self.damage+amount
    local last=self.recent[#self.recent]
    if last and last.time==time then last.amount=last.amount+amount
    else self.recent[#self.recent+1]={time=time,amount=amount} end
    local unit=type(target)=='table' and target or {}
    local p=self.pending[target] or {amount=0,normal=0,shield=0,pierce=0,age=0,killed=false,cells0=unit.lostCells or 0,major0=unit.lostMajor or 0}
    opts=opts or {}
    local kind=(opts.shield or opts.kind=='shield') and 'shield' or opts.pierce and 'pierce' or 'normal'
    p[kind]=p[kind]+amount
    p.amount=p.amount+amount;p.point=point;p.killed=p.killed or killed;self.pending[target]=p
end
function M:Step(time)
    local total=0
    while self.recent[1] and self.recent[1].time<time-3 do table.remove(self.recent,1) end
    for _,r in ipairs(self.recent) do total=total+r.amount end
    self.dps=total/3
end
function M:Timing(time,pos,speed,prevZ)
    if not prevZ then return end
    local d,tm=self.drag,self.timing
    local inLane=pos[1]>d.x0-2 and pos[1]<d.x1+2
    if tm.state=='running' and (not inLane or pos[3]<d.start-1) then tm.state='idle' end
    if inLane and prevZ<d.start and pos[3]>=d.start and speed>0 then tm.state='running';tm.t0=time end
    if tm.state=='running' and prevZ<d.finish and pos[3]>=d.finish then
        tm.state='idle';tm.last={time=time-tm.t0,speed=speed}
    end
end
function M:Timer(time) return self.timing.state=='running' and time-self.timing.t0 or nil end
return M

-- Frozen storyKinds.js escort contract; positions remain in H5 source metres.
local M={};M.__index=M
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
function M.New(step,nav,ground)
    local self=setmetatable({step=step,points={},lengths={0},total=0,d=0,v=0,hp=1,cp=0,cpD=0,cpHp=1,waitT=-99,hitT=-99},M)
    for i,q in ipairs(step.path) do
        local n=type(q)=='string' and assert(nav.nodes[q],'Unknown convoy road node '..q) or nil
        local x,z,hint,up=n and n[1] or q[1],n and n[3] or q[2],n and n[2] or q[3] or 30,n and 5 or 40
        self.points[i]={x,ground(x,z,hint,up),z}
        if i>1 then self.total=self.total+Flat(self.points[i-1],self.points[i]);self.lengths[i]=self.total end
    end
    self.pos,self.yaw=self:Along(0);return self
end
function M:Along(distance)
    local i=2;while i<#self.points and self.lengths[i]<distance do i=i+1 end
    local a,b=self.points[i-1],self.points[i];local k=math.max(0,math.min(1,(distance-self.lengths[i-1])/math.max(.000001,self.lengths[i]-self.lengths[i-1])))
    return {a[1]+(b[1]-a[1])*k,a[2]+(b[2]-a[2])*k,a[3]+(b[3]-a[3])*k},math.atan(b[1]-a[1],b[3]-a[3])
end
function M:Retry(r)
    self.d=self.cpD;self.hp=math.max(.5,self.cpHp);self.v=0;self.pos=self:Along(self.d)
    r.progress=self.d/self.total
    for k,beat in ipairs(self.step.beats or {}) do if beat.p and beat.p*self.total>self.d then r.beatsFired[k]=nil end end
    local _,yaw=self:Along(self.d)
    r:Emit('place',{at={pos={self.pos[1]-math.sin(yaw)*14,self.pos[2]+1,self.pos[3]-math.cos(yaw)*14},yaw=yaw}})
    r:Emit('say',{lines=self.step.retryLines,urgent=true})
end
function M:Update(r,dt,world)
    local s=self.step
    if self.d>=self.total then return world.alive end
    local block=0;for _,p in ipairs(world.enemyPositions or {}) do if Flat(p,self.pos)<(s.blockR or 30) then block=block+1 end end
    if block>0 then self.hp=self.hp-(s.drain or .01)*block*dt
        if r.time-self.hitT>.35 then self.hitT=r.time;r:Emit('truckHit') end
    end
    self.blocked=block>0;self.far=not world.alive or Flat(world.pos,self.pos)>(s.leash or 60)
    if self.hp<=0 then self.hp=0;r:Fail('运输车被打爆了',s.failLines);return false end
    if (self.far or self.blocked) and r.time-self.waitT>20 and not world.talking then
        self.waitT=r.time;local lines=self.blocked and s.blockLines or s.waitLines;r:Emit('say',{lines={lines[math.random(#lines)]}})
    end
    local want=(self.blocked or self.far) and 0 or s.speed or 5
    self.v=self.v+(want-self.v)*math.min(1,dt*1.6);self.d=math.min(self.total,self.d+self.v*dt)
    local pos,yaw=self:Along(self.d);local delta=yaw-self.yaw
    self.yaw=self.yaw+math.atan(math.sin(delta),math.cos(delta))*math.min(1,dt*2.5);self.pos=pos;r.progress=self.d/self.total
    if self.cp<#s.checkpoints and r.progress>=s.checkpoints[self.cp+1] then
        self.cp=self.cp+1;self.cpD=self.d;self.cpHp=self.hp;r.stats.checkpoints=self.cp
        r.checkpoint={pos={world.pos[1],world.pos[2]+1,world.pos[3]},yaw=self.yaw}
        r:Emit('banner',{title='检查点 '..self.cp,sub=string.format('运输车耐久 %d%% · 已存档',math.floor(self.hp*100+.5))})
        r:Emit('say',{lines=s.cpLines[self.cp]})
    end
    r.retitle=self.blocked and '击退拦截运输车的海盗' or self.far and '跟上运输车（它在等你）' or s.title
    if self.d>=self.total then r.stats.checkpoints=#s.checkpoints+1;r.stats.truckHp=self.hp;return world.alive end
    return false
end
return M

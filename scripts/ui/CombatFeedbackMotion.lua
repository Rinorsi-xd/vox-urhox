-- Frozen combatFeedback.js animation state; at most five hits and 22 cubes.
local M={};M.__index=M
function M.New() local self=setmetatable({},M);self.time=0;self.lastKill=-99;self.streak=0;self:Clear();return self end
function M:Clear()
    self.hits={};self.cubes={};self.flash=0;self.beat=0;self.low=0;self.repairAge=9;self.repairFull=false;self.healAt=-99;self.full=false;self.score=false
end
function M:Hit(angle,strength)
    local s=math.min(1,.3+strength*3);local same
    for _,h in ipairs(self.hits) do if math.abs(math.atan(math.sin(h.a-angle),math.cos(h.a-angle)))<.3 then same=h;break end end
    if same then same.t=0;same.s=math.min(1,math.max(same.s,s)+.06);same.a=angle
    else if #self.hits>=5 then table.remove(self.hits,1) end;self.hits[#self.hits+1]={a=angle,t=0,s=s} end
    if s>.6 then self.flash=math.max(self.flash,.18) end
end
function M:Heal(full)
    if self.time-self.healAt>1.5 then self.repairAge=0;self.repairFull=false end
    self.healAt=self.time
    if full and not self.full then self.repairAge=0;self.repairFull=true end
    self.full=full
end
function M:Kill(name,core,x,y,layout,random)
    random=random or math.random
    self.streak=self.time-self.lastKill<4.5 and self.streak+1 or 1;self.lastKill=self.time
    local base=self.streak>1 and self.score and self.score.target or 0;local n=math.min(self.streak,5);local k=layout.k
    local size=(58+math.min(4,n-1)*6)*k;local top=layout.cy+70*k
    self.score={shown=base,target=base+300,per=300/22,x=layout.cx,y=top+size*.5,size=size,age=0,name=name or '敌方战车',n=n,bump=0}
    if not x or x< -50 or x>layout.width+50 or y< -50 or y>layout.height+50 then x=layout.cx+140*k;y=layout.cy-40*k end
    self.cubes={}
    for i=0,21 do
        local a=random()*math.pi*2;local speed=(260+random()*380)*k
        self.cubes[i+1]={x=x,y=y,vx=math.cos(a)*speed,vy=math.sin(a)*speed-120*k,
            size=(11+random()*10)*k,rot=random()*math.pi*2,vr=(random()-.5)*900*math.pi/180,t=0,fly=.22+i*.022,color=i%5+1,core=core}
    end
end
function M:Update(dt,hp,onScore,realDt)
    self.time=self.time+(realDt or dt);self.repairAge=self.repairAge+dt;self.flash=math.max(0,self.flash-dt)
    if hp<.99 then self.full=false end
    local low=math.max(0,(.3-hp)/.3);self.beat=self.beat+dt*(.9+low*.8)
    self.low=low>0 and math.min(1,.25+low*.75)*(.7+.3*math.max(0,math.sin(self.beat*math.pi*2))) or 0
    for i=#self.hits,1,-1 do local h=self.hits[i];h.t=h.t+dt;if h.t>=1 then table.remove(self.hits,i) end end
    local s=self.score;if not s then return end;s.age=s.age+dt;s.bump=math.max(0,s.bump-dt)
    for i=#self.cubes,1,-1 do local c=self.cubes[i];c.t=c.t+dt
        if c.t<c.fly then c.x=c.x+c.vx*dt;c.y=c.y+c.vy*dt;c.vx=c.vx*math.exp(-dt*5);c.vy=c.vy*math.exp(-dt*5);c.rot=c.rot+c.vr*dt
        else
            local dx,dy=s.x-c.x,s.y-c.y;local distance=math.sqrt(dx*dx+dy*dy)
            local step=math.min(distance,distance*(1-math.exp(-dt*9))+900*dt)
            c.x=c.x+dx/math.max(distance,.0001)*step;c.y=c.y+dy/math.max(distance,.0001)*step;c.rot=c.rot+c.vr*dt*.5
            if distance<10 then table.remove(self.cubes,i);s.shown=math.min(s.target,s.shown+s.per);s.bump=.07;if onScore then onScore() end end
        end
    end
    if #self.cubes==0 then s.shown=s.target end
end
return M

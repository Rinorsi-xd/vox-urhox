-- Port of the frozen driver's road search, steering and firing contract.
local V=require 'core.Math3'
local Data=require 'combat.ArenaData'
local M={};M.__index=M
local function Flat(a,b) local x,z=a[1]-b[1],a[3]-b[3];return math.sqrt(x*x+z*z) end
local function Wrap(a) return math.atan(math.sin(a),math.cos(a)) end
function M.New(world,unit,role,index,member)
    local self=setmetatable({},M);self.world=world;self.unit=unit;self.role=role;self.index=index
    self.nextThink=0;self.route={};self.sampleTime=world.time;self.reverseUntil=0;self.command={throttle=0,steer=0};self.trigger=false
    self.skill=member and member.aimSkill or 1;self.reaction=member and member.reaction or Data.ai.reactionMin
    self.width=unit.spec.bounds.max[1]-unit.spec.bounds.min[1];self.nav=world.layout.nav;self.adj={}
    if self.nav then for _,edge in ipairs(self.nav.edges) do
        if edge[3]>=self.width+1 then
            local a,b=edge[1],edge[2];self.adj[a]=self.adj[a] or {};self.adj[b]=self.adj[b] or {}
            local length=V.Length(V.Sub(self.nav.nodes[a],self.nav.nodes[b]))
            self.adj[a][#self.adj[a]+1]={id=b,cost=length};self.adj[b][#self.adj[b]+1]={id=a,cost=length}
        end
    end end
    return self
end
function M:Nearest(p)
    local best,dist=false,math.huge
    for id in pairs(self.adj) do local d=V.Length(V.Sub(self.nav.nodes[id],p));if d<dist then best=id;dist=d end end
    return best
end
function M:Path(from,to)
    local start,goal=self:Nearest(from),self:Nearest(to);if not start or not goal then return {} end
    local open={[start]=true};local cost={[start]=0};local previous={}
    while next(open) do
        local cur=false;local score=math.huge
        for id in pairs(open) do local s=cost[id]+Flat(self.nav.nodes[id],self.nav.nodes[goal]);if s<score then cur=id;score=s end end
        if cur==goal then
            local out={cur};while previous[out[1]] do table.insert(out,1,previous[out[1]]) end;return out
        end
        open[cur]=nil
        for _,edge in ipairs(self.adj[cur]) do local alt=cost[cur]+edge.cost
            if alt<(cost[edge.id] or math.huge) then cost[edge.id]=alt;previous[edge.id]=cur;open[edge.id]=true end
        end
    end
    return {}
end
function M:Visible(from,to,target)
    local delta=V.Sub(to,from);local length=V.Length(delta)
    if length<.01 then return true end
    local hit=self.world:CastRay(from,V.Scale(delta,1/length),length,self.unit.vehicle.body)
    return not hit or hit.dist>=length-.6 or hit.owner and hit.owner.ref==target
end
function M:Direct(from,to)
    local length=Flat(from,to);if length>65 then return false end
    local steps=math.max(1,math.ceil(length/5));local previous=from[2]+self.unit.spec.bounds.min[2]
    for i=1,steps do local p=V.Add(from,V.Scale(V.Sub(to,from),i/steps))
        local hit=self.world.space:Raycast({p[1],previous+3,p[3]},{0,-1,0},12,self.unit.vehicle.body,nil,true)
        if not hit or math.abs(hit.point[2]-previous)>length/steps*.3+.25 then return false end
        previous=hit.point[2]
    end
    local delta={to[1]-from[1],previous-(from[2]+self.unit.spec.bounds.min[2]),to[3]-from[3]};local len=V.Length(delta)
    if len>.1 then
        local hit=self.world.space:Raycast({from[1],from[2]+self.unit.spec.bounds.min[2]+.5,from[3]},V.Scale(delta,1/len),len-.05,self.unit.vehicle.body,nil,true)
        if hit then return false end
    end
    return true
end
function M:Think(target,charge)
    local u=self.unit;local v=u.vehicle;local pos=u:Position();local p=target and target:Position()
    if not p then self.trigger=false;self.command={throttle=0,steer=0};return end
    local r=Flat(pos,p);local profile=Data.combat.roles[self.role] or Data.combat.roles.assault
    local near,far=profile.near,profile.far;if charge then near=near*.5;far=far*.6 end
    local muzzle=pos[2]+math.max(.6,u.spec.bounds.max[2]*.65)
    local aim={p[1],p[2]+(target.spec.bounds.min[2]+target.spec.bounds.max[2])*.5,p[3]}
    local seen=self:Visible({pos[1],muzzle,pos[3]},aim,target)
    local error=math.sin(self.world.time*1.7+self.index)*Data.ai.aimErrorDegrees*math.pi/180*.65*self.skill
    local bearing=math.atan(aim[1]-pos[1],aim[3]-pos[3])+error
    self.aim={pos[1]+math.sin(bearing)*r,aim[2],pos[3]+math.cos(bearing)*r}
    local range=0;for _,g in ipairs(u.weapons.groups) do for _,w in ipairs(g.weapons) do range=math.max(range,w.stats.range or 0) end end
    self.trigger=not target.passive and seen and r<=range and self.world.time>self.readyAt
    local goal=p;self.mode='approach';self.hold=false
    if target.passive or target.shoot then
        near=target.radius or 12;self.hold=r<near*.65;goal=p;self.mode=target.passive and 'objective' or 'reactor'
    elseif u:Health()<Data.combat.retreatBelow and not charge then
        self.mode='retreat';goal={pos[1]+(pos[1]-p[1])/math.max(1,r)*30,pos[2],pos[3]+(pos[3]-p[3])/math.max(1,r)*30}
    elseif seen and r<near then
        self.mode='backoff';goal={pos[1]+(pos[1]-p[1])/math.max(1,r)*12,pos[2],pos[3]+(pos[3]-p[3])/math.max(1,r)*12}
    elseif seen and r<=far then
        if self.role=='sniper' then self.hold=true;goal=pos;self.mode='snipe'
        else
            self.mode='strafe';local angle=math.atan(pos[1]-p[1],pos[3]-p[3])+(self.index%2==0 and .35 or -.35)
            goal={p[1]+math.sin(angle)*r,pos[2],p[3]+math.cos(angle)*r}
        end
    end
    if self.hold or self:Direct(pos,goal) then self.route={};self.goal=goal
    elseif self.nav then
        local destination=self:Nearest(goal)
        -- Keep the forward waypoint across decisions; restarting at the nearest
        -- node makes vehicles circle a node they have already passed.
        if #self.route==0 or self.destination~=destination then
            local from=#self.route>0 and self.nav.nodes[self.route[1]] or pos
            self.route=self:Path(from,goal);self.destination=destination
        end
        self.goal=nil
    else self.route={};self.goal=goal end
    if self.nav then while #self.route>1 and Flat(pos,self.nav.nodes[self.route[1]])<math.max(5,self.width*.5) do table.remove(self.route,1) end end
end
function M:Step(dt,target,charge)
    local v=self.unit.vehicle;local p=self.unit:Position();local now=self.world.time
    self.readyAt=self.readyAt or now+self.reaction+self.index*.05
    if now>=self.nextThink then self.nextThink=now+Data.ai.thinkInterval;self:Think(target,charge) end
    if self.nav then
        while #self.route>1 do
            local node=self.nav.nodes[self.route[1]];local prev=self.previousNode and self.nav.nodes[self.previousNode]
            local passed=false
            if prev then
                local ex,ez=node[1]-prev[1],node[3]-prev[3];local length=math.sqrt(ex*ex+ez*ez)
                passed=length>.01 and (p[1]-node[1])*ex+(p[3]-node[3])*ez>=0
                    and math.abs((p[1]-node[1])*ez-(p[3]-node[3])*ex)/length<self.width*.5+1
            end
            if Flat(p,node)>=math.max(5,self.width*.5) and not passed then break end
            self.previousNode=table.remove(self.route,1)
        end
    end
    local waypoint=self.nav and self.route[1] and self.nav.nodes[self.route[1]] or self.goal
    local command={throttle=0,steer=0,handbrake=self.hold==true}
    if waypoint and not self.hold then
        local angle=Wrap(math.atan(waypoint[1]-p[1],waypoint[3]-p[3])-v:Yaw())
        local velocity=v.body.linvel();local speed=math.sqrt(velocity.x^2+velocity.z^2)
        command.steer=V.Clamp(angle*1.7,-1,1);command.throttle=math.abs(angle)>1.1 and .12 or math.abs(angle)>.5 and .42 or 1
        local limit=self.mode=='strafe' and (Data.combat.roles[self.role] or Data.combat.roles.assault).speed or 18
        if speed>limit*(math.abs(angle)>.4 and .5 or 1) then command.throttle=-V.Clamp(velocity.x*math.sin(v:Yaw())+velocity.z*math.cos(v:Yaw()),-1,1)*.35 end
        if self.mode=='backoff' and math.abs(angle)>1.9 then command.throttle=-.65;command.steer=-V.Clamp(Wrap(angle-math.pi)*1.7,-1,1) end
    end
    if now-self.sampleTime>=Data.ai.stuckWindow then
        if self.sample and Flat(p,self.sample)<Data.ai.stuckDistance and not self.hold and command.throttle~=0 then self.reverseUntil=now+Data.ai.reverseTime end
        self.sample={p[1],p[2],p[3]};self.sampleTime=now
    end
    if now<self.reverseUntil then command.throttle=-.65;command.steer=self.index%2==0 and .6 or -.6 end
    self.command=command;return command,self.aim,self.trigger==true
end
return M

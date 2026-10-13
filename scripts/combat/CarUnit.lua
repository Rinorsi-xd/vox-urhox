-- shared/combat/carUnit.js rules. Scene construction is injected by TrackWorld;
-- simulation and source fixtures share damage, connectivity and rebuild decisions.
local BP=require "construction.Blueprint"
local Defs=require("parts.Defs").PARTS
local Spec=require "drive.VehicleSpec"
local V=require "core.Math3"
local CELL=require("Config").CELL
local M={WRECK_RATIO=.3,RESPAWN_TIME=5};M.__index=M
local PARK={throttle=0,steer=0,handbrake=false,boost=false}
local function Sorted(set) local out={};for id in pairs(set) do out[#out+1]=id end;table.sort(out);return out end
local function Components(ids,adj)
    local left={};for _,id in ipairs(ids) do left[id]=true end
    local out={}
    for _,id in ipairs(ids) do if left[id] then
        left[id]=nil;local group={id};local i=1
        while i<=#group do
            for _,n in ipairs(Sorted(adj[group[i]] or {})) do if left[n] then left[n]=nil;group[#group+1]=n end end
            i=i+1
        end
        out[#out+1]=group
    end end
    return out
end
function M.New(env,source,config)
    local self=setmetatable({},M);self.env=env;self.source=source;self.name=config.name;self.spawnAt=config.spawn
    self.team=config.team or 'neutral';self.autoRespawn=config.autoRespawn~=false
    self.externalControl=config.externalControl==true;self.combat=config.combat==true;self.externalView=config.externalView==true
    self:Spawn();return self
end
function M:Event(kind,id) self.env.viewEvents[#self.env.viewEvents+1]={type=kind,unit=self,id=id} end
function M:DisposeVehicle()
    if self.vehicle then self.vehicle:Dispose();self.vehicle=nil end
end
function M:Build(spec)
    self.spec=spec;self.vehicle=self.env:NewVehicle(spec,self)
    if self.weapons then self.weapons:Refit(spec) end
end
function M:Spawn()
    self:DisposeVehicle();self.bp=BP.New():Load(self.source)
    local spec=Spec.Build(self.bp)
    if spec.ok then
        local keep={};for _,id in ipairs(spec.partIds) do keep[id]=true end
        for _,p in ipairs(self.bp:List()) do if not keep[p.id] then self.bp:Remove(p.id) end end
    end
    self.original={};self.repairOrder={};self.hp={};self.shields={};self.rawHpMax=0
    local data=self.combat and require('combat.ArenaData') or nil
    self.hull=data and data.hull or nil;self.structure=data and data.structure or nil
    self.partScale=self.hull and self.hull.partScale or 1
    for _,p in ipairs(self.bp:List()) do
        self.original[p.id]=p;self.hp[p.id]=Defs[p.type].hp*self.partScale;self.rawHpMax=self.rawHpMax+Defs[p.type].hp
        self:FillShield(p)
    end
    local adj=self.bp:Graph();local seen={};local queue={}
    for _,p in ipairs(self.bp:CoreParts()) do queue[#queue+1]=p.id;seen[p.id]=true end
    local cursor=1
    while cursor<=#queue do local id=queue[cursor];self.repairOrder[#self.repairOrder+1]=id
        for _,nextId in ipairs(Sorted(adj[id] or {})) do if not seen[nextId] then seen[nextId]=true;queue[#queue+1]=nextId end end
        cursor=cursor+1
    end
    self.bodyHpMax=self.hull and math.max(self.hull.min,math.min(self.hull.max,self.rawHpMax*self.hull.scale)) or self.rawHpMax
    self.bodyHp=self.bodyHpMax;self.structMax=self.structure and self.bodyHpMax*self.structure.base or 0;self.struct=self.structMax
    self.weapons=self.combat and require('combat.WeaponSystem').New(spec) or nil
    self.budget0=self:Budget();self.alive=spec.ok;self.deadAt=-1;self.dirty=false;self.kill=nil
    self.lastDir={0,0,0};self.hitAt=-1
    if not spec.ok then return end
    self:Build(spec);self.vehicle:Place(self.spawnAt.pos,self.spawnAt.yaw);self:SavePose();self.previous=self.current
    self:Event("unitSpawn")
end
function M:Budget() local b=0;for _,p in ipairs(self.bp:List()) do b=b+Defs[p.type].budget end;return b end
function M:Integrity() return self.budget0>0 and self:Budget()/self.budget0 or 1 end
function M:Core()
    local p=self.bp:CoreParts()[1];return {hp=p and self.hp[p.id] or 0,max=Defs.core.hp*self.partScale}
end
function M:Health()
    if not self.alive then return 0 end
    if self.hull then return math.max(0,self.bodyHp/self.bodyHpMax) end
    local hp=0;for _,v in pairs(self.hp) do hp=hp+v end;return hp/math.max(1,self.rawHpMax)
end
function M:FillShield(part)
    if self.combat and Defs[part.type].shield then self.shields[part.id]={v=Defs[part.type].shield.max,t=self.env.time,hit=-math.huge} end
end
function M:ShieldOf(id)
    local s=self.shields[id];local p=self.bp.parts[id];if not s or not p then return 0 end
    local d=Defs[p.type].shield;local from=math.max(s.t,s.hit+(s.broken and d.brokenDelay or d.delay))
    if self.env.time>from then s.v=math.min(d.max,s.v+(self.env.time-from)*d.max/d.refill);s.broken=false end
    s.t=self.env.time;return s.v
end
function M:Heal(fraction)
    if not self.alive or fraction<=0 then return end
    self.bodyHp=math.min(self.bodyHpMax,self.bodyHp+self.bodyHpMax*fraction);self.struct=self.structMax
    for id,p in pairs(self.bp.parts) do self.hp[id]=math.min(Defs[p.type].hp*self.partScale,self.hp[id]+Defs[p.type].hp*self.partScale*fraction) end
end
function M:RegenerateStructure(dt)
    local cfg=self.structure
    if not cfg or not self.alive or self.kill or self.struct>=self.structMax or self.env.time-self.hitAt<cfg.regenDelay then return end
    local v=self.vehicle;local velocity=v.body.linvel();local speed=math.sqrt(velocity.x^2+velocity.z^2)
    local top=v.legMode and (v.telemetry.legSpeedLimit or v.spec.motion.topSpeed) or math.max(v.spec.motion.topSpeed,v.spec.motion.thrusterSpeed or 0)
    if speed<(top>0 and top or 10)*cfg.regenSpeed then return end
    local multiplier=1
    for _,thruster in ipairs(v.spec.thrusters) do multiplier=multiplier*(1+cfg.thrusterBonus*(Defs[thruster.type].wtier or 1)/cfg.tierDivisor) end
    multiplier=math.min(cfg.maxMultiplier,multiplier)
    if next(v.thrusterOutputs) then multiplier=multiplier*cfg.activeMultiplier end
    self.struct=math.min(self.structMax,self.struct+self.structMax*cfg.regenRate*multiplier*dt)
end
function M:RestoreMissing(count)
    if not self.alive or count<=0 then return {} end
    local missing={};for order,id in ipairs(self.repairOrder) do if not self.bp.parts[id] then
        local p=self.original[id];local cat=Defs[p.type].cat
        missing[#missing+1]={id=id,order=order,priority=(cat=='weapon' or cat=='movement') and 0 or 1}
    end end
    table.sort(missing,function(a,b) return a.priority==b.priority and a.order<b.order or a.priority<b.priority end)
    local reached=self.bp:Connectivity(self.bp:Graph()).reached;local restored={};local hp=0;local progress=true
    local want=count*self.rawHpMax*self.partScale*.03
    while progress and (hp<want or #restored<count) do
        progress=false
        for _,entry in ipairs(missing) do local id=entry.id
            if not self.bp.parts[id] then
                local p=self.bp:Add(self.original[id]);local connected=false
                for neighbor in pairs(self.bp:Neighbors(p)) do if reached[neighbor] then connected=true;break end end
                if connected then
                    reached[id]=true;self.hp[id]=Defs[p.type].hp*self.partScale;self:FillShield(p)
                    restored[#restored+1]=id;hp=hp+self.hp[id];self.dirty=true;progress=true;self:Event('partRestored',id)
                    if hp>=want and #restored>=count then break end
                else self.bp:Remove(id) end
            end
        end
    end
    if #restored>0 then self.struct=self.structMax;self.bodyHp=math.min(self.bodyHpMax,self.bodyHp+self.bodyHpMax*hp/math.max(1,self.rawHpMax*self.partScale)) end
    return restored
end
function M:Position()
    if self.vehicle then local p=self.vehicle.body.center();self.pos={p.x,p.y,p.z} end
    return self.pos
end
function M:SavePose()
    if not self.vehicle then return end
    local b=self.vehicle.body;local p=b.translation();self.previous=self.current
    self.current={p={p.x,p.y,p.z},q=b.rotation()}
    self:Position()
end
function M:Step(dt)
    if self.alive then if not self.externalControl then self.vehicle:Step(PARK,dt) end
    elseif self.autoRespawn and self.deadAt>=0 and self.env.time-self.deadAt>=M.RESPAWN_TIME then self:Spawn() end
end
function M:Local(p)
    local b=self.vehicle.body;local t=b.translation();return V.Unrotate(b.rotation(),V.Sub(p,{t.x,t.y,t.z}))
end
function M:PartAt(p)
    local g={p[1]/CELL+.5,p[2]/CELL,p[3]/CELL+.5};local cell,sub={},{}
    for i=1,3 do cell[i]=math.floor(g[i]);sub[i]=math.min(3,math.floor((g[i]-cell[i])*4)) end
    local part=self.bp:PartAtSub(cell,sub);return part and part.id or nil
end
function M:March(p,d,length,skip)
    for s=0,length,CELL*.25 do local id=self:PartAt(V.Add(p,V.Scale(d,s)));if id and (type(skip)=='table' and not skip[id] or type(skip)~='table' and id~=skip) then return id end end
end
function M:HitRay(hit,damage,dir,pierce)
    if not self.alive then return 0 end
    local p=self:Local(hit.point);local d=V.Unrotate(self.vehicle.body.rotation(),dir)
    local id=hit.owner and hit.owner.partId
    if id and not self.bp.parts[id] then id=nil end
    id=id or self:March(p,d,CELL*1.5)
    if not id then return 0 end
    self.lastDir=dir
    if type(pierce)=='table' then
        local seen={};local left=damage;local dealt=0
        for _=1,pierce.depth do
            if not id or left<=1 then break end
            local layer=self.hull and math.max(0,self.bodyHp-self.bodyHpMax*self.hull.shatterAt)+(self.hp[id] or 0)+self.struct or math.huge
            local amount=self:Damage(id,math.min(left,layer),hit.point);dealt=dealt+amount;seen[id]=true
            if (self.hp[id] or 0)>0 or not self.alive or self.kill then break end
            left=math.max(0,left-amount)*pierce.carry;id=self:March(p,d,CELL*6,seen)
        end
        return dealt
    end
    local dealt=self:Damage(id,damage,hit.point)
    if (pierce or 0)>0 then local nextId=self:March(p,d,CELL*3,id);if nextId then dealt=dealt+self:Damage(nextId,damage*pierce,hit.point) end end
    return dealt
end
function M:Explode(point,radius,damage)
    if not self.alive then return 0 end
    local p=self:Local(point);local list={};local total=0
    for _,part in ipairs(self.bp:List()) do
        local best={0,0,0};local distance=math.huge
        for _,c in ipairs(part._cells) do
            local cc={c[1]*CELL,(c[2]+.5)*CELL,c[3]*CELL};local d=V.Length(V.Sub(cc,p))
            if d<distance then distance=d;best=cc end
        end
        local edge=math.max(0,distance-CELL*.5)
        if edge<=radius and self:March(p,V.Normalize(V.Sub(best,p)),distance)==part.id then
            local weight=1-edge/radius*.7;list[#list+1]={id=part.id,weight=weight};total=total+damage*weight
        end
    end
    local scale=total>damage and damage/total or 1;local dealt=0
    for _,entry in ipairs(list) do dealt=dealt+self:Damage(entry.id,damage*entry.weight*scale,point) end
    return dealt
end
function M:Damage(id,amount,point)
    local hp=self.hp[id]
    if not self.alive or self.kill or not hp or hp<=0 or amount<=0 then return 0 end
    if self.combat then
        self.hitAt=self.env.time;local s=self.shields[id]
        if s then local value=self:ShieldOf(id);s.hit=self.env.time
            if value>0 then local a=math.min(value,amount);s.v=value-a;s.broken=s.v<=.001;self.env:RecordDamage(self,a,point);return a end
        end
        local part=self.bp.parts[id]
        if part and not Defs[part.type].plate then
            local absorbed=math.min(amount,self.struct);self.struct=self.struct-absorbed;amount=amount-absorbed
            if absorbed>0 then self.env:RecordDamage(self,absorbed,point) end
            if amount<=0 then return absorbed end
            local before=self.bodyHp;local a=math.min(amount,before)
            self.bodyHp=math.max(0,before-a)
            local localDamage=math.max(0,a-math.max(0,before-self.bodyHpMax*self.hull.shatterAt))
            self.env:RecordDamage(self,a,point)
            if self.bodyHp<=0 then self.kill='车体耐久归零';self.dirty=true
            elseif localDamage>0 then self.hp[id]=math.max(0,hp-localDamage);if self.hp[id]<=.001 then self:Destroy(id) end end
            return absorbed+a
        end
    end
    local a=math.min(hp,amount);self.hp[id]=hp-a;self.hitAt=self.env.time;self.env:RecordDamage(self,a,point)
    if hp-a<=.001 then self:Destroy(id) end
    return a
end
function M:Destroy(id)
    local part=self.bp.parts[id];if not part then return end
    local b=self.vehicle.body;local p=b.translation();local q=b.rotation();local c={0,0,0}
    for _,cell in ipairs(part._cells) do c=V.Add(c,{cell[1]*CELL,(cell[2]+.5)*CELL,cell[3]*CELL}) end
    local w=V.Add(V.Rotate(q,V.Scale(c,1/#part._cells)),{p.x,p.y,p.z})
    self.bp:Remove(id);self.hp[id]=nil;self.dirty=true
    if self.hull then
        self.bodyHp=math.max(0,self.bodyHp-Defs[part.type].hp*self.hull.lossOnBreak)
        if self.bodyHp<=0 then self.kill='车体耐久归零' end
    end
    if part.type=="core" then self.kill="核心被摧毁" end
    self.env.fx[#self.env.fx+1]={type="break",pos=w,color=part.color,cells=#part._cells,dir=self.lastDir}
    self:Event("partRemoved",id)
end
function M:Flush()
    if not self.dirty or not self.alive then return end
    self.dirty=false;local body=self.vehicle.body;local state=self.vehicle:GetState();local pose={p=state.p,q=state.q}
    local function Velocity(pt) local v=body.velocityAtPoint({x=pt[1],y=pt[2],z=pt[3]});return {v.x,v.y,v.z} end
    local d=self.lastDir;local kick={d[1]*2,1.5+d[2]*2,d[3]*2}
    if not self.kill then
        local adj=self.bp:Graph();local floating=self.bp:Connectivity(adj).floating
        for _,group in ipairs(Components(Sorted(floating),adj)) do
            local parts={}
            for _,id in ipairs(group) do parts[#parts+1]=self.bp:Remove(id);self.hp[id]=nil;self:Event("partRemoved",id) end
            self.env.debris:Spawn(parts,pose,Velocity,kick)
        end
        if self:Budget()<self.budget0*(self.combat and .15 or M.WRECK_RATIO) then self.kill="瘫痪" end
    end
    if self.kill then self:Die(pose,Velocity);return end
    local spec=Spec.Build(self.bp)
    if not spec.ok or self.combat and #spec.weapons==0 and #spec.wheels==0 and #spec.hovers==0 and #spec.legs==0 and #spec.thrusters==0 then
        self.kill='无法战斗或移动';self:Die(pose,Velocity);return
    end
    self:DisposeVehicle();self:Build(spec);self.vehicle:SetState(state);self:Event("unitRebuilt")
end
function M:Die(pose,velocity)
    local pos=self:Position();local adj=self.bp:Graph();local random=self.env.random or math.random
    for _,group in ipairs(Components(Sorted(self.bp.parts),adj)) do
        local parts={};for _,id in ipairs(group) do parts[#parts+1]=self.bp.parts[id] end
        self.env.debris:Spawn(parts,pose,velocity,{(random()-.5)*5,3+random()*3,(random()-.5)*5})
    end
    self:DisposeVehicle();self.alive=false;self.deadAt=self.env.time;self.env:RecordKill(self,pos);self:Event("unitKilled")
end
function M:Dispose() self:DisposeVehicle();self.alive=false;self:Event("unitRemoved") end
return M

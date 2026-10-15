-- shared/combat/carUnit.js rules. Scene construction is injected by TrackWorld;
-- simulation and source fixtures share damage, connectivity and rebuild decisions.
local BP=require "construction.Blueprint"
local Defs=require("parts.Defs").PARTS
local Spec=require "drive.VehicleSpec"
local V=require "core.Math3"
local CELL=require("Config").CELL
local M={WRECK_RATIO=.15,RESPAWN_TIME=5};M.__index=M
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
function M.New(env,source,config,checkpoint,retain)
    local self=setmetatable({},M);self.env=env;self.source=source;self.name=config.name;self.spawnAt=config.spawn
    self.team=config.team or 'neutral';self.autoRespawn=config.autoRespawn~=false;self.hpMultiplier=config.hpMultiplier or 1
    self.externalControl=config.externalControl==true;self.combat=config.combat==true;self.externalView=config.externalView==true
    self.spawnSpecCache=config.spawnSpecCache
    -- Loading may suspend inside Spawn; retain the candidate before yielding.
    if retain then retain(self) end
    self:Spawn(checkpoint);return self
end
function M:Event(kind,id,extra)
    local event={type=kind,unit=self,id=id}
    if extra then for key,value in pairs(extra) do event[key]=value end end
    self.env.viewEvents[#self.env.viewEvents+1]=event
end
function M:RecordDamage(amount,point,opts)
    self.env:RecordDamage(self,amount,point,opts)
    self:Event('unitDamaged',nil,{amount=amount,point=point,source=self.env.attacker})
end
function M:DisposeVehicle()
    if self.weapons then self.weapons.drill:Cancel() end
    if self.vehicle then self.vehicle:Dispose();self.vehicle=nil end
end
function M:Build(spec)
    self.spec=spec;self.vehicle=self.env:NewVehicle(spec,self)
    if self.weapons then self.weapons:Refit(spec) end
    self.vehicle.drill=self.weapons and self.weapons.drill
end
function M:Spawn(checkpoint)
    self:DisposeVehicle();self.bp=BP.New():Load(self.source)
    local spec=self.spawnSpecCache and self.spawnSpecCache:Get(self.source)
    if not spec then spec=Spec.Build(self.bp,checkpoint and function(p) checkpoint(p*.75) end or nil) end
    if spec.ok then
        local keep={};for _,id in ipairs(spec.partIds) do keep[id]=true end
        for _,p in ipairs(self.bp:List()) do if not keep[p.id] then self.bp:Remove(p.id) end end
    end
    self.original={};self.repairOrder={};self.hp={};self.shields={};self.rawHpMax=0
    self.cells0=0;self.lostCells=0;self.lostMajor=0
    local data=self.combat and require('combat.ArenaData') or nil
    self.hull=data and data.hull or nil;self.structure=data and data.structure or nil
    self.partScale=(self.hull and self.hull.partScale or 1)*self.hpMultiplier
    for _,p in ipairs(self.bp:List()) do
        self.original[p.id]=p;self.hp[p.id]=Defs[p.type].hp*self.partScale;self.rawHpMax=self.rawHpMax+Defs[p.type].hp
        self.cells0=self.cells0+#p._cells
        self:FillShield(p)
        if checkpoint then checkpoint(.8) end
    end
    local pause=checkpoint and function() checkpoint(.85) end or nil
    local adj=self.bp:Graph(pause);local seen={};local queue={}
    for _,p in ipairs(self.bp:CoreParts()) do queue[#queue+1]=p.id;seen[p.id]=true end
    local cursor=1
    while cursor<=#queue do local id=queue[cursor];self.repairOrder[#self.repairOrder+1]=id
        for _,nextId in ipairs(Sorted(adj[id] or {})) do if not seen[nextId] then seen[nextId]=true;queue[#queue+1]=nextId end end
        cursor=cursor+1
        if pause then pause() end
    end
    self.bodyHpMax=self.hull and math.max(self.hull.min,math.min(self.hull.max,self.rawHpMax*self.hull.scale)) or self.rawHpMax
    self.bodyHpMax=self.bodyHpMax*self.hpMultiplier
    self.bodyHp=self.bodyHpMax;self.structMax=self.structure and self.bodyHpMax*self.structure.base or 0;self.struct=self.structMax
    self.structBrokenAt=-math.huge;self.hullBreachAt=-math.huge
    self.weapons=self.combat and require('combat.WeaponSystem').New(spec) or nil
    self.budget0=self:Budget();self.alive=spec.ok;self.deadAt=-1;self.dirty=false;self.kill=nil
    self.lastDir={0,0,0};self.hitAt=-1
    if not spec.ok then return end
    if checkpoint then checkpoint(.9) end
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
    local hp=0;for _,v in pairs(self.hp) do hp=hp+v end;return hp/math.max(1,self.rawHpMax*self.partScale)
end
function M:Life()
    if not self.alive then return 0 end
    local c=self:Core();local core=c.max>0 and c.hp/c.max or 1
    local wreck=(self:Integrity()-M.WRECK_RATIO)/(1-M.WRECK_RATIO)
    local hull=self.hull and self:Health() or self.hullMin and (self:Health()-self.hullMin)/(1-self.hullMin) or 1
    return math.max(0,math.min(1,core,wreck,hull))
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
    local before=self.bodyHp;local healed=0
    self.bodyHp=math.min(self.bodyHpMax,self.bodyHp+self.bodyHpMax*fraction);self.struct=self.structMax
    for id,p in pairs(self.bp.parts) do
        local hp=self.hp[id];self.hp[id]=math.min(Defs[p.type].hp*self.partScale,hp+Defs[p.type].hp*self.partScale*fraction)
        healed=healed+self.hp[id]-hp
    end
    local amount=self.hull and self.bodyHp-before or healed
    if amount>0 then self:Event('unitHealed',nil,{amount=amount}) end
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
    if self.weapons and self.weapons.drill:ControlsBody() then self.vehicle:SyncDrillPose() end
    local b=self.vehicle.body;local p=b.translation();self.previous=self.current
    self.current={p={p.x,p.y,p.z},q=b.rotation()}
    self:Position()
end
function M:Step(dt)
    if self.alive then if not self.externalControl then
        self.vehicle:StepRotors(nil,false,dt)
        require('drive.RotorMotion').Weapons(self.vehicle.rotors,self.weapons)
        self.vehicle:Step(PARK,dt)
    end
    elseif self.autoRespawn and self.deadAt>=0 and self.env.time-self.deadAt>=M.RESPAWN_TIME then self:Spawn() end
end
function M:Local(p)
    local b=self.vehicle.body;local t=b.translation();return V.Unrotate(b.rotation(),V.Sub(p,{t.x,t.y,t.z}))
end
function M:RestPartAt(p)
    local g={p[1]/CELL+.5,p[2]/CELL,p[3]/CELL+.5};local cell,sub={},{}
    for i=1,3 do cell[i]=math.floor(g[i]);sub[i]=math.min(3,math.floor((g[i]-cell[i])*4)) end
    local part=self.bp:PartAtSub(cell,sub);return part and part.id or nil
end
function M:PartAt(p)
    local rotors=self.vehicle and self.vehicle.rotors or {}
    for _,r in ipairs(rotors) do if r.moved then
        local id=self:RestPartAt(require('construction.Rotors').Inverse(r.pose,p))
        if id and r.ownSet[id] then return id end
    end end
    local id=self:RestPartAt(p)
    if id then for _,r in ipairs(rotors) do if r.moved and r.ownSet[id] then return nil end end end
    return id
end
function M:PartPoint(id,p)
    for _,r in ipairs(self.vehicle and self.vehicle.rotors or {}) do if r.ownSet[id] then return require('construction.Rotors').Apply(r.pose,p) end end
    return p
end
function M:DebrisPose(ids,pose)
    local best=nil ---@type table|nil
    for _,r in ipairs(self.vehicle and self.vehicle.rotors or {}) do if r.moved then
        local inside=true;for _,id in ipairs(ids) do if not r.loadSet[id] then inside=false;break end end
        if inside and (not best or #r.load<#best.load) then best=r end
    end end
    if not best then return pose end
    local t=V.Add({pose.p.x,pose.p.y,pose.p.z},V.Rotate(pose.q,best.pose.t))
    return {p={x=t[1],y=t[2],z=t[3]},q=V.QMul(pose.q,best.pose.q)}
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
        local seen={};local left=damage;local dealt=0;local stopped=false;local lastId=id
        local opts={armor=pierce.armor or 0};local multiplier=self.incomingDamageMultiplier or 1
        for _=1,pierce.depth do
            if not id or left<=1 then break end
            local layer=self.hull and math.max(0,self.bodyHp-self.bodyHpMax*self.hull.shatterAt)+(self.hp[id] or 0)+self.struct or math.huge
            local amount=self:Damage(id,math.min(left,layer/multiplier),hit.point,opts);dealt=dealt+amount;seen[id]=true;lastId=id
            if (self.hp[id] or 0)>0 or not self.alive or self.kill then stopped=true;break end
            left=math.max(0,left-amount/multiplier)*pierce.carry;id=self:March(p,d,CELL*6,seen)
        end
        if not stopped and self.hull and left>1 and self.alive and not self.kill then
            local amount=math.min(left*multiplier,self.bodyHp)
            if amount>0 then self:HurtHull(amount,hit.point);self:RecordDamage(amount,hit.point,{partId=lastId,pierce=true});dealt=dealt+amount end
        end
        if pierce.splash and self.alive and not self.kill then dealt=dealt+self:Explode(V.Sub(hit.point,V.Scale(dir,.6)),pierce.splash.radius,damage*pierce.splash.share,opts) end
        return dealt
    end
    local dealt=self:Damage(id,damage,hit.point)
    if (pierce or 0)>0 then local nextId=self:March(p,d,CELL*3,id);if nextId then dealt=dealt+self:Damage(nextId,damage*pierce,hit.point) end end
    return dealt
end
function M:Explode(point,radius,damage,opts)
    if not self.alive then return 0 end
    local p=self:Local(point);local list={};local total=0
    for _,part in ipairs(self.bp:List()) do
        local best={0,0,0};local distance=math.huge
        for _,c in ipairs(part._cells) do
            local cc=self:PartPoint(part.id,{c[1]*CELL,(c[2]+.5)*CELL,c[3]*CELL});local d=V.Length(V.Sub(cc,p))
            if d<distance then distance=d;best=cc end
        end
        local edge=math.max(0,distance-CELL*.5)
        if edge<=radius and self:March(p,V.Normalize(V.Sub(best,p)),distance)==part.id then
            local weight=1-edge/radius*.7;list[#list+1]={id=part.id,weight=weight};total=total+damage*weight
        end
    end
    local scale=total>damage and damage/total or 1;local dealt=0
    for _,entry in ipairs(list) do dealt=dealt+self:Damage(entry.id,damage*entry.weight*scale,point,opts) end
    return dealt
end
function M:Damage(id,amount,point,opts)
    if not self.alive or self.kill then return 0 end
    amount=amount*(self.incomingDamageMultiplier or 1)
    local armor=opts and opts.armor or 0
    if armor>0 then return self:DamageLayers(id,amount*armor,point,true)+self:DamageLayers(id,amount*(1-armor),point,false) end
    return self:DamageLayers(id,amount,point,false)
end
function M:DamageLayers(id,amount,point,through)
    local hp=self.hp[id]
    if not self.alive or self.kill or not hp or hp<=0 or amount<=0 then return 0 end
    self.lastHitBy=self.env.attacker
    if self.combat then
        self.hitAt=self.env.time;local s=self.shields[id]
        if s and through then s.hit=self.env.time end
        if s and not through then local value=self:ShieldOf(id);s.hit=self.env.time
            if value>0 then
                local a=math.min(value,amount);s.v=value-a;s.broken=s.v<=.001
                if s.broken then self:Event('shieldDown',id,{point=point,strength=.7})
                elseif self.env.time-(self.shieldSoundAt or -1)>=.15 then
                    self.shieldSoundAt=self.env.time;self:Event('shieldHit',id,{point=point,strength=.45})
                end
                self:RecordDamage(a,point,{partId=id,shield=true,kind='shield'});return a
            end
        end
        local part=self.bp.parts[id]
        if part and not Defs[part.type].plate then
            local absorbed=not through and math.min(amount,self.struct) or 0;self.struct=self.struct-absorbed;amount=amount-absorbed
            if absorbed>0 then
                self:RecordDamage(absorbed,point,{partId=id,shield=true,kind='shield'})
                if self.struct<=0 then self.structBrokenAt=self.env.time end
            end
            if amount<=0 then return absorbed end
            local before=self.bodyHp;local a=math.min(amount,before)
            self:HurtHull(a,point)
            local localDamage=math.max(0,a-math.max(0,before-self.bodyHpMax*self.hull.shatterAt))
            self:RecordDamage(a,point,{partId=id,pierce=through,broke=not self.kill and localDamage>=hp})
            if not self.kill and localDamage>0 then self.hp[id]=math.max(0,hp-localDamage);if self.hp[id]<=.001 then self:Destroy(id) end end
            return absorbed+a
        end
    end
    local a=math.min(hp,amount);self.hp[id]=hp-a;self.hitAt=self.env.time;self:RecordDamage(a,point,{partId=id,pierce=through,broke=hp-a<=.001})
    if hp-a<=.001 then self:Destroy(id) end
    return a
end
function M:HurtHull(amount,point)
    if not self.hull or amount<=0 then return end
    local before=self.bodyHp;self.bodyHp=math.max(0,before-amount)
    local threshold=self.bodyHpMax*self.hull.shatterAt
    if before>=threshold and self.bodyHp<threshold then
        self.hullBreachAt=self.env.time
        self:Event('hullBreach',nil,{point=point or self:Position(),strength=self.hull.breachFlash})
    end
    if self.bodyHp<=0 then self.kill=self.kill or '车体HP归零';self.dirty=true end
end
function M:Destroy(id)
    local part=self.bp.parts[id];if not part then return end
    local b=self.vehicle.body;local p=b.translation();local q=b.rotation();local c={0,0,0}
    for _,cell in ipairs(part._cells) do c=V.Add(c,{cell[1]*CELL,(cell[2]+.5)*CELL,cell[3]*CELL}) end
    local w=V.Add(V.Rotate(q,self:PartPoint(id,V.Scale(c,1/#part._cells))),{p.x,p.y,p.z})
    if self.hull then self:HurtHull((self.hp[id] or 0)*self.hull.lossOnBreak) end
    self.bp:Remove(id);self.hp[id]=nil;self.shields[id]=nil;self.dirty=true;self:CountLost(part)
    if part.type=="core" then self.kill="核心被摧毁" end
    self.env.fx[#self.env.fx+1]={type="break",pos=w,color=part.color,cells=#part._cells,dir=self.lastDir}
    self:Event("partRemoved",id,{reason='damage'})
end
function M:CountLost(part)
    if not part then return end
    self.lostCells=(self.lostCells or 0)+#part._cells
    local cat=Defs[part.type].cat
    if cat=='weapon' or cat=='movement' then self.lostMajor=(self.lostMajor or 0)+1 end
end
function M:LostCombatAbility()
    for _,p in ipairs(self.bp:List()) do
        local def=Defs[p.type]
        if def and (def.cat=='weapon' or def.cat=='movement') then return false end
    end
    for _,p in pairs(self.original) do
        if Defs[p.type] and Defs[p.type].cat=='weapon' then return true end
    end
    return false
end
function M:Flush()
    if not self.dirty or not self.alive then return end
    if self.weapons then self.weapons.drill:Cancel() end
    self.dirty=false;local body=self.vehicle.body;local state=self.vehicle:GetState();local pose={p=state.p,q=state.q}
    local function Velocity(pt) local v=body.velocityAtPoint({x=pt[1],y=pt[2],z=pt[3]});return {v.x,v.y,v.z} end
    local d=self.lastDir;local kick={d[1]*2,1.5+d[2]*2,d[3]*2}
    local connected=nil ---@type table|nil
    if not self.kill then
        local adj=self.bp:Graph();local conn=self.bp:Connectivity(adj);local floating=conn.floating
        for _,group in ipairs(Components(Sorted(floating),adj)) do
            local parts={}
            for _,id in ipairs(group) do
                parts[#parts+1]=self.bp:Remove(id)
                self:CountLost(parts[#parts])
                if self.hull then self:HurtHull((self.hp[id] or 0)*self.hull.lossOnBreak) end
                self.hp[id]=nil;self.shields[id]=nil;self:Event("partRemoved",id,{reason='disconnect'})
            end
            self.env.debris:Spawn(parts,self:DebrisPose(group,pose),Velocity,kick)
        end
        local remaining={}
        for id,row in pairs(adj) do if self.bp.parts[id] then
            local neighbors={};for neighbor in pairs(row) do if self.bp.parts[neighbor] then neighbors[neighbor]=true end end
            remaining[id]=neighbors
        end end
        connected={adj=remaining,conn={reached=conn.reached,coreId=conn.coreId,floating={},floatingCount=0}}
        if self:Budget()<self.budget0*M.WRECK_RATIO then self.kill="瘫痪"
        elseif self:LostCombatAbility() then self.kill='失去战斗力' end
    end
    if self.kill then self:Die(pose,Velocity);return end
    local spec=Spec.Build(self.bp,nil,connected)
    if not spec.ok then
        self.kill='无法战斗或移动';self:Die(pose,Velocity);return
    end
    self:DisposeVehicle();self:Build(spec);self.vehicle:SetState(state);self:Event("unitRebuilt")
end
function M:Die(pose,velocity)
    local pos=self:Position();local adj=self.bp:Graph();local random=self.env.random or math.random
    for _,group in ipairs(Components(Sorted(self.bp.parts),adj)) do
        local parts={};for _,id in ipairs(group) do parts[#parts+1]=self.bp.parts[id] end
        self.env.debris:Spawn(parts,self:DebrisPose(group,pose),velocity,{(random()-.5)*5,3+random()*3,(random()-.5)*5})
    end
    self:DisposeVehicle();self.alive=false;self.deadAt=self.env.time;self.env:RecordKill(self,pos);self:Event("unitKilled")
end
function M:Dispose() self:DisposeVehicle();self.spawnSpecCache=nil;self.alive=false;self:Event("unitRemoved") end
return M

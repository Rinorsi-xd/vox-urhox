local Data=require 'combat.ArenaData'
local V=require 'core.Math3'
local Coord=require 'core.Coord'
local Shield=require 'combat.ShieldQuery'
local M={};M.__index=M
local function Other(team) return team=='blue' and 'red' or 'blue' end
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
-- A vehicle touching a zone counts: horizontal radius includes half its bounds,
-- and tall chassis get the source's vertical allowance (both edges are strict).
function M.InPoint(unit,point)
    local radius=unit.spec.bounds.radius or 0
    local pos=unit:Position()
    return Flat(pos,point.pos)<point.radius+radius*.5 and math.abs(pos[2]-point.pos[2])<8+radius
end
function M.New(battle,id)
    local self=setmetatable({battle=battle,world=battle.world,id=id,assignAt={},goals={}},M);local L=self.world.layout
    if id=='conquest' then
        local n=L.nav.nodes;self.points={{id='A',pos=n.wa1,radius=22},{id='B',pos=n.dD1,radius=22},{id='C',pos={0,n.iC1[2],0},radius=22}};self.bases={}
        for _,team in ipairs({'blue','red'}) do
            local core=false;for _,b in ipairs(L.blocks) do if b.kind==(team=='blue' and 'core' or 'enemyCore') then core=b;break end end
            assert(core,'Missing source reactor')
            self.bases[team]={zone=(team=='blue' and L.base or L.enemyBase).shield,aim={core.pos[1],core.pos[2]+core.size[2]/2+4,core.pos[3]}}
        end
    elseif id=='escort' then
        self.tuning=Data.escort;local proxy={spec={bounds={min={0,0,0},max={7,1,1}}}}
        local driver=require('combat.EnemyDriver').New(self.world,proxy,'assault',0)
        local ids=driver:Path(L.nav.nodes.sA,L.nav.nodes.nA);assert(#ids>1,'Source escort route is unreachable')
        self.path={};self.cum={0}
        for i=1,#ids-1 do local a,b=L.nav.nodes[ids[i]],L.nav.nodes[ids[i+1]];local n=math.max(1,math.ceil(Flat(a,b)/2))
            for j=0,n-1 do local p=V.Add(a,V.Scale(V.Sub(b,a),j/n))
                local hit=self.world.space:Raycast({p[1],p[2]+4,p[3]},{0,-1,0},12,nil,nil,true)
                p[2]=hit and hit.point[2] or math.max(p[2],self.world:GroundAt(p[1],p[3]));self.path[#self.path+1]=p
            end
        end
        self.path[#self.path+1]=L.nav.nodes[ids[#ids]]
        for i=2,#self.path do self.cum[i]=self.cum[i-1]+Flat(self.path[i-1],self.path[i]) end
        self.length=self.cum[#self.cum];self:CreatePayload()
    end
    if id~='elimination' then self.view=require('render.ObjectiveView').New(self.world,self) end
    return self
end
function M:Rules()
    if self.id=='conquest' then return require('combat.ConquestRules').New(Data.modes.conquest,Data.conquest)
    elseif self.id=='escort' then return require('combat.EscortRules').New(Data.modes.escort,Data.escort,self.length) end
    return require('combat.EliminationRules').New(Data.modes.elimination)
end
function M:At(distance)
    local d=math.max(0,math.min(self.length,distance));local i=2
    while i<#self.cum and self.cum[i]<d do i=i+1 end
    local a,b=self.path[i-1],self.path[i];local k=(d-self.cum[i-1])/math.max(.001,self.cum[i]-self.cum[i-1])
    return {pos=V.Add(a,V.Scale(V.Sub(b,a),k)),yaw=math.atan(b[1]-a[1],b[3]-a[3])}
end
function M:CreatePayload()
    local bp=require('construction.Blueprint').New():Load(Data.payload);local bounds=require('drive.VehicleSpec').Build(bp).bounds
    self.cart=require('render.VehicleView').New(self.world.scene,'Payload');self.cart:Rebuild(bp);self.bottom=bounds.min[2]
    self.cargo=self.world.scene:CreateChild('PayloadCargo');self.cargoMaterials={}
    local function CargoMaterial(color)
        local m=Material:new();m:SetTechnique(0,cache:GetResource('Technique','Techniques/PBR/PBRNoTexture.xml'))
        m:SetShaderParameter('MatDiffColor',Variant(Color(table.unpack(color))));m:SetShaderParameter('Roughness',Variant(.6));self.cargoMaterials[#self.cargoMaterials+1]=m;return m
    end
    local white,yellow=CargoMaterial({.9,.89,.85}),CargoMaterial({1,.69,0})
    local w,l=bounds.max[1]-bounds.min[1],bounds.max[3]-bounds.min[3]
    for i=0,2 do for _,band in ipairs({false,true}) do
        local node=self.cargo:CreateChild(band and 'Band' or 'Cargo')
        node.position=Coord.Vec((bounds.min[1]+bounds.max[1])/2,bounds.max[2]+.9+(band and .4 or 0),bounds.min[3]+l*(.22+i*.28))
        node.scale=Vector3(w*(band and .63 or .62),band and .35 or 1.8,l*(band and .245 or .24))
        local obj=node:CreateComponent('StaticModel');obj.model=cache:GetResource('Model','Models/Box.mdl');obj.material=band and yellow or white;obj.castShadows=true
    end end
    -- Payload is a kinematic box at source bounds. It blocks all vehicle hulls
    -- while its route position is owned by the rules; shots cannot damage it.
    self.cartBodyNode=self.world.scene:CreateChild('PayloadPhysics')
    self.cartBodyNode:CreateComponent('CollisionShape'):SetBox(Vector3(w,bounds.max[2]-bounds.min[2],l),Coord.Vec((bounds.max[1]+bounds.min[1])/2,(bounds.max[2]+bounds.min[2])/2,(bounds.max[3]+bounds.min[3])/2))
    self.cartBody=self.cartBodyNode:CreateComponent('RigidBody');self.cartBody.kinematic=true;self.cartBody.friction=.6;self.cartBody.collisionLayer=1
    self.world.space:Register(self.cartBody,{type='payload'})
end
function M:PlaceCart()
    if not self.cart then return end
    local at=self:At(self.battle.rules.s);local yaw=self.cartYaw or at.yaw
    self.cartYaw=yaw+math.atan(math.sin(at.yaw-yaw),math.cos(at.yaw-yaw))*.04
    local p=Coord.Vec(at.pos[1],at.pos[2]-self.bottom+.05,at.pos[3]);local q=Quaternion(-self.cartYaw*180/math.pi,Vector3.UP)
    -- Kinematic bodies read their node pose; install it even when physics is paused.
    self.cartBodyNode:SetTransform(p,q);self.cartBody:SetTransform(p,q)
    self.cart.root.position=p;self.cart.root.rotation=q;self.cargo.position=p;self.cargo.rotation=q
end
function M:WorldState(out)
    if self.id=='conquest' then
        out.inPoint={};for _,p in ipairs(self.points) do out.inPoint[p.id]={blue=0,red=0} end
        for _,e in ipairs(self.battle.entries) do if e.unit.alive then
            for _,p in ipairs(self.points) do if M.InPoint(e.unit,p) then out.inPoint[p.id][e.unit.team]=out.inPoint[p.id][e.unit.team]+1 end end
        end end
    elseif self.id=='escort' then
        out.near={blue=0,red=0};local cart=self:At(self.battle.rules.s).pos
        for _,e in ipairs(self.battle.entries) do local u=e.unit;if u.alive then
            if M.InPoint(u,{pos=cart,radius=Data.escort.push}) then out.near[u.team]=out.near[u.team]+1 end
        end end
    end
    return out
end
function M:HomeProtected(unit)
    return self.id=='conquest' and self.battle.rules.shield[unit.team] and Shield.Contains(self.bases[unit.team].zone,unit:Position())
end
function M:Ignore(unit)
    return self:HomeProtected(unit)
end
function M:VolumeHit(unit,from,dir,length,hit)
    if self.id~='conquest' then return hit end
    local team=Other(unit.team);local base=self.bases[team];local rule=self.battle.rules
    if rule.shield[team] then
        local sh=Shield.Contains(base.zone,from) and {dist=0,point=from} or Shield.Ray(base.zone,from,dir,length)
        if sh and (not hit or sh.dist<=hit.dist) then sh.owner={type='shield',team=team};return sh end
    end
    local delta=V.Sub(from,base.aim);local b=V.Dot(delta,dir);local c=V.Dot(delta,delta)-16;local disc=b*b-c
    if disc>=0 then local t=-b-math.sqrt(disc);if t<0 then t=-b+math.sqrt(disc) end
        if t>=0 and t<=(hit and hit.dist or length) then return {dist=t,point=V.Add(from,V.Scale(dir,t)),owner={type='reactor',team=team}} end
    end
    return hit
end
function M:Cast(unit,from,dir,length,excluded)
    return self:VolumeHit(unit,from,dir,length,self.world:CastRay(from,dir,length,excluded))
end
function M:SweepDrill(unit,from,dir,length,excluded,cutters)
    local hit=self.world:SweepDrill(from,dir,length,excluded,cutters)
    return self:VolumeHit(unit,from,dir,length,hit)
end
function M:Hit(unit,hit,damage)
    local o=hit.owner;if self.id~='conquest' or not o then return false end
    if o.type=='shield' then local env=self.battle.session.environment;if env then env.effects.shields[o.team=='blue' and 1 or 2]:Hit(hit.point) end;return true end
    if o.type=='reactor' then self.battle.rules:Steal(unit.team,damage);return true end
    return false
end
function M:Explode(unit,point,radius,damage)
    if self.id~='conquest' then return end
    local team=Other(unit.team);local base=self.bases[team]
    if not self.battle.rules.shield[team] and math.max(0,V.Length(V.Sub(point,base.aim))-4)<radius then
        self.battle.rules:Steal(unit.team,damage*.6)
    end
end
function M:UnitTick(entry,dt)
    local u=entry.unit;local rule=self.battle.rules
    local cfg=rule.cfg;local allow=self.id~='elimination' or not rule.sudden
    entry.regen=allow and self.world.time-u.hitAt>=(cfg.regenDelay or 5)
    if entry.regen then
        u.repairing=u:Health()<.995 or u:Integrity()<.995
        if u:Health()<.999 then u:Heal((cfg.regen or .15)*dt) end
        entry.repair=(entry.repair or 0)+dt
        if entry.repair>=.5 then entry.repair=0;u:RestoreMissing(1) end
    end
    if self.id=='conquest' then
        local home=Shield.Contains(self.bases[u.team].zone,u:Position())
        u.repairing=u.repairing or home and (u:Health()<.995 or u:Integrity()<.995)
        if home then u:Heal(.15*dt);entry.repair=(entry.repair or 0)+dt;if entry.repair>=.4 then entry.repair=0;u:RestoreMissing(1) end end
        if rule.shield[Other(u.team)] and Shield.Contains(self.bases[Other(u.team)].zone,u:Position()) then
            local core=u.bp:CoreParts()[1];if core then u:Damage(core.id,require('parts.Defs').PARTS.core.hp*u.partScale*.04*dt,u:Position()) end
        end
    elseif self.id=='escort' and u.team==rule.attack and M.InPoint(u,{pos=self:At(rule.s).pos,radius=Data.escort.push}) then u:Heal(Data.escort.heal*dt) end
end
function M:Goal(entry,enemy)
    if self.id=='elimination' then return enemy end
    local u=entry.unit;local rule=self.battle.rules;local p=u:Position()
    local distance=enemy and Flat(p,enemy:Position()) or math.huge
    local near=self.id=='conquest' and 90 or u.team==rule.attack and (entry.member.role=='heavy' or entry.member.role=='assault') and 60 or 100
    if enemy and distance<near and entry.driver:Visible(p,enemy:Position(),enemy) then return enemy end
    local pos,radius,shoot
    if self.id=='conquest' then
        local team=u.team
        if self.world.time>=(self.assignAt[team] or 0) then
            self.assignAt[team]=self.world.time+2;local load={0,0,0};local raiders=not rule.shield[Other(team)] and 2 or 0
            for _,e in ipairs(self.battle.entries) do if e.driver and e.unit.alive and e.unit.team==team then
                if raiders>0 then self.goals[e]={reactor=true};raiders=raiders-1
                else local best,cost=1,math.huge
                    for i,q in ipairs(self.points) do local st=rule.points[i]
                        local c=Flat(e.unit:Position(),q.pos)+(st.owner==team and (st.count[Other(team)]>0 and -40 or 260) or st.owner and -30 or 0)+load[i]*120
                        if c<cost then best=i;cost=c end
                    end
                    self.goals[e]={point=best};load[best]=load[best]+1
                end
            end end
        end
        local job=self.goals[entry] or {point=3}
        if job.reactor then pos=self.bases[Other(team)].aim;radius=45;shoot=true else pos=self.points[job.point].pos;radius=self.points[job.point].radius end
    else
        local attack=u.team==rule.attack;local role=entry.member.role
        if attack and (role=='heavy' or role=='assault') or not attack and role~='sniper' then pos=self:At(rule.s).pos;radius=Data.escort.push
        else pos=self:At(rule.s+(attack and 30 or 70)).pos;radius=attack and 14 or 16 end
    end
    return {Position=function() return pos end,passive=not shoot,shoot=shoot,radius=radius,spec={bounds={min={0,0,0},max={0,0,0}}}}
end
function M:Spawn(team,slot)
    if self.id~='escort' then return nil end
    local rule=self.battle.rules
    if rule.state=='live' and team==rule.attack and rule.passed>0 then
        local c=self:At(Data.escort.checkpoints[rule.passed]*self.length-25);local side=(slot-2.5)*8
        return {pos={c.pos[1]+math.cos(c.yaw)*side,c.pos[2]+6,c.pos[3]-math.sin(c.yaw)*side},yaw=c.yaw}
    end
    return nil
end
function M:Update(dt)
    local env=self.battle.session.environment
    if env and not self.shieldsInitialized then
        self.shieldsInitialized=true
        for _,sh in ipairs(env.effects.shields) do sh.node.enabled=self.id=='conquest' end
    end
    if self.view then self.view:Update(dt,self.battle.rules,self.battle.session.camera and self.battle.session.camera:GetNode()) end
end
function M:Event(e)
    if e.type=='shieldDown' or e.type=='shieldUp' then local env=self.battle.session.environment
        if env then local sh=env.effects.shields[e.team=='blue' and 1 or 2];if e.type=='shieldDown' then sh:Down() else sh:Raise() end end
    end
end
function M:Reset()
    self.assignAt={};self.goals={};self.cartYaw=nil
    local env=self.battle.session.environment
    if env and self.id=='conquest' then for _,shield in ipairs(env.effects.shields) do shield:Reset() end end
end
function M:Dispose()
    if self.view then self.view:Dispose() end
    if self.cart then self.cart:Dispose();self.cargo:Dispose();self.world.space:Unregister(self.cartBody);self.cartBodyNode:Dispose()
        for _,m in ipairs(self.cargoMaterials) do m:Dispose() end
    end
end
return M

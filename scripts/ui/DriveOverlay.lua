local UI=require 'urhox-libs/UI'
local Coord=require 'core.Coord'
local Math=require 'core.Math3'
local Marks=require 'ui.UnitMarkState'
local M={};M.__index=M
function M.New(session,root,vitals)
    local self=setmetatable({session=session,pops={},tags={},index=0,vitals=vitals},M)
    self.layer=require('ui.DriveFeedback'){position='absolute',width='100%',height='100%',pointerEvents='none'};self.layer.owner=self;root:AddChild(self.layer)
    self.aim={visible=false}
    self.feedback=require('ui.CombatFeedbackMotion').New()
    self.scoreTick=function() if session.feedbackAudio then session.feedbackAudio:ScoreTick() end end
    self.partCounts=setmetatable({},{__mode='k'})
    self.markGhosts=Marks.New()
    self.tagRefs=setmetatable({},{__mode='k'})
    for _=1,40 do self.pops[#self.pops+1]={t=1} end
    for _,unit in ipairs(session.world.units) do
        self.partCounts[unit]=unit.bp:Size()
        if not unit.externalView then local tag={unit=unit,visible=false};self.tags[#self.tags+1]=tag;self.tagRefs[unit]=tag end
    end
    return self
end
function M:Project(point,margin)
    local camera=self.session.camera:GetCamera();local p=Coord.Vec(table.unpack(point))
    local depth=camera.node:WorldToLocal(p).z
    if depth<=camera.nearClip or depth>camera.farClip then return end
    margin=margin or 0
    local uv=camera:WorldToScreenPoint(p);if uv.x<-margin or uv.x>1+margin or uv.y<-margin or uv.y>1+margin then return end
    local w,h=UI.GetViewportSize();return uv.x*w,uv.y*h
end
function M:Pop(point,amount,killed,opts)
    local x,y=self:Project(point);if not x then return end
    self:PopAt(x,y,amount,killed,opts)
end
function M:PopAt(x,y,amount,killed,opts)
    opts=opts or {}
    self.index=self.index%40+1;local p=self.pops[self.index]
    p.t=0;p.x=x+(opts.jitter==false and 0 or (math.random()-.5)*40);p.y=y;p.amount=amount;p.killed=killed
    p.shield=opts.shield==true;p.pierce=opts.pierce==true;p.broke=opts.broke or 0
    p.text=(p.shield and '抵抗 ' or p.pierce and '穿甲 ' or '')..math.floor(amount+.5)
end
function M:PopDamage(target,p)
    local x,y=self:Project(p.point);if not x then return end
    local lost=(target.lostCells or 0)-(p.cells0 or 0);local major=(target.lostMajor or 0)-(p.major0 or 0)
    local big=major>0 or lost>=math.max(24,(target.cells0 or 0)*.12)
    local broke=big and math.max(1,major) or 0;local dy=0;local jitter=x+(math.random()-.5)*40
    if p.killed then self:PopAt(jitter,y,p.normal+p.pierce,true,{jitter=false});dy=34
    else
        if p.normal>0 then self:PopAt(jitter,y,p.normal,false,{jitter=false,broke=broke});dy=32 end
        if p.pierce>0 then self:PopAt(jitter,y+dy,p.pierce,false,{jitter=false,pierce=true,broke=p.normal>0 and 0 or broke});dy=dy+32 end
    end
    if p.shield>0 then self:PopAt(jitter,y+dy,p.shield,false,{jitter=false,shield=true}) end
end
function M:AimMarker()
    local s=self.session;local w=s.weapons;local part=w.pointing
    if s.combat and not s.combat.player.alive then self.aim.visible=false;return end
    if not part then self.aim.visible=false;return end
    local root=s.view.view.root;local p,q=root.position,root.rotation
    local muzzle=w:Muzzle(part,{pos={-p.x,p.y,p.z},quat={w=q.w,x=q.x,y=-q.y,z=-q.z}})
    local aim=s.aimPoint or s:Aim();local distance=Math.Length(Math.Sub(aim,muzzle.pos))
    local hit=s.world:CastRay(muzzle.pos,muzzle.dir,math.min(500,distance+2),s.vehicle.body)
    local aligned=w:Aligned(part)
    local blocked=aligned and hit and hit.dist<distance-math.max(1.5,distance*.04) and not (s.aimHit and hit.owner and s.aimHit.owner and hit.owner.ref==s.aimHit.owner.ref)
    local state=not aligned and (part.limited and 'limited' or 'turning') or blocked and 'blocked' or 'ok'
    local pos=Math.Add(muzzle.pos,Math.Scale(muzzle.dir,hit and math.min(hit.dist,distance) or distance))
    local x,y=self:Project(pos);self.aim.visible=x~=nil
    if x then self.aim.x=x;self.aim.y=y;self.aim.state=state end
    return state
end
function M:Update(dt)
    local s=self.session;local metrics=s.world.metrics
    self.feedback:Update(dt,s.combat and s.combat.player:Life() or 1,self.scoreTick,s.realFrameDt or dt)
    for target,p in pairs(metrics.pending) do
        if p.seenAmount~=p.amount or p.seenKilled~=p.killed then
            local killed=p.killed or target.alive==false;local previous=self.partCounts[target]
            local broken=target.bp and previous and target.bp:Size()<previous
            if s.feedbackAudio and not (killed and p.seenKilled~=p.killed and target.spec) then s.feedbackAudio:Hit(killed and 'kill' or broken and 'break' or 'hit') end
            if killed and p.seenKilled~=p.killed and target.spec then
                local x,y=self:Project(target:Position());local w,h=UI.GetViewportSize()
                self.feedback:Kill(target.name,target.kill=='核心被摧毁',x,y,require('ui.ReticleState').Layout(w,h))
                if s.feedbackAudio then s.feedbackAudio:Kill(self.feedback.streak) end
                if s.ConfirmKill then s:ConfirmKill(target) end
            end
            if killed or broken or (self.vitals.strongUntil or 0)<=(self.vitals.clock or 0) then
                self.vitals.hitDuration=killed and .55 or broken and .4 or .3
                self.vitals.hit=self.vitals.hitDuration;self.vitals.killed=killed;self.vitals.broken=broken
                if killed or broken then self.vitals.strongUntil=(self.vitals.clock or 0)+.26 end
            end
            p.seenAmount=p.amount;p.seenKilled=p.killed
        end
        if target.bp then self.partCounts[target]=target.bp:Size() end
        p.age=p.age+dt
        if p.age>=.25 or p.killed then self:PopDamage(target,p);metrics.pending[target]=nil end
    end
    for _,p in ipairs(self.pops) do if p.t<1 then
        p.t=math.min(1,p.t+dt/1.1)
    end end
    -- Match the source's current sim.units list, including units spawned mid-run.
    local count=0;local me=s.combat and s.combat.player
    for _,unit in ipairs(s.world.units) do if unit~=me and not unit.externalView then
        local tag=self.tagRefs[unit]
        if not tag then tag={unit=unit,visible=false};self.tagRefs[unit]=tag end
        count=count+1;self.tags[count]=tag
    end end
    for i=#self.tags,count+1,-1 do self.tags[i]=nil end
    for _,t in ipairs(self.tags) do
        local unit=t.unit;local p=unit.alive and Marks.Point(unit)
        local x,y;if p and unit.alive then x,y=self:Project(p,.025) end
        local camera=s.camera:GetNode().position
        t.dist=p and math.sqrt((p[1]+camera.x)^2+(p[2]-camera.y)^2+(p[3]-camera.z)^2) or math.huge
        t.visible=x~=nil and t.dist<=260 and unit~=me
        t.enemy=not me or unit.team~=me.team;t.hit=s.world.time-unit.hitAt<.15;t.health=unit:Life()
        if x then
            t.x=x;t.y=y
            local key=tostring(unit.hitAt)..'|'..tostring(unit.alive)..'|'..unit.bp:Size()
            if t.healthKey~=key then t.healthKey=key;t.integrity=unit:Integrity();t.core=unit:Core() end
            local integrity,core=t.integrity,t.core
            if s.combat then t.text=unit.name..(unit.alive and string.format(' · %.0f%%',unit:Life()*100) or ' · 已击毁')
            else t.text=unit.alive and string.format('完整度 %.0f%% · 核心 %.0f%%',integrity*100,core.hp/core.max*100) or string.format('已击毁 · %d 秒后复原',math.ceil(math.max(0,5-(s.world.time-unit.deadAt)))) end
        end
    end
    self.aimState=self:AimMarker()
    require('ui.ReticleTarget').Update(self,dt)
end
function M:Consume(events)
    for _,e in ipairs(events) do
        if e.type=='unitSpawn' and e.unit then self.partCounts[e.unit]=e.unit.bp:Size() end
    end
    local s=self.session;local me=s.combat and s.combat.player;if not me then return end
    local healed=false
    for _,e in ipairs(events) do if e.unit==me then
        if e.type=='unitHealed' or e.type=='partRestored' then healed=true
        elseif e.type=='unitDamaged' and e.amount>0 then
            local from=e.source and e.source:Position() or e.point
            if from then
                local localPoint=s.camera:GetNode():WorldToLocal(Coord.Vec(table.unpack(from)))
                self.feedback:Hit(math.atan(localPoint.x,localPoint.z),e.amount/math.max(1,me.rawHpMax*me.partScale)*4)
            end
        elseif e.type=='unitSpawn' then self.feedback:Clear() end
    end end
    if healed and me.alive then self.feedback:Heal(me:Life()>=.995 and me.bp:Size()>=#me.repairOrder) end
end
function M:Clear()
    for _,p in ipairs(self.pops) do p.t=1 end
    self.vitals.hit=0
    self.feedback:Clear()
end
return M

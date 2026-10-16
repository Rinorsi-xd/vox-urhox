local Data=require('core.ResourceData').Read('Salvage/RunData.json')
local Unit=require 'combat.CarUnit'
local Driver=require 'combat.EnemyDriver'
local M={};M.__index=M
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
function M.New(run)
    local self=setmetatable({run=run,world=run.world,entries=run.entries,encounters={},timer=0,huntLeft=60},M)
    for _,source in ipairs(run.world.layout.salvage.gameplay.encounters) do
        local e={};for k,v in pairs(source) do e[k]=v end;e.g={-e.x,e.y,e.z};e.state='dormant';e.left={table.unpack(e.squad)};e.units={};self.encounters[#self.encounters+1]=e
    end;return self
end
function M:Surface(x,z,nest)
    local h=self.world.space:Raycast({x,600,z},{0,-1,0},1200,nil,nil,true)
    if not h or h.normal[2]<.75 or not nest and h.point[2]>self.world:GroundAt(x,z)+3 then return nil end;return h.point
end
function M:Add(kind,at,yaw,enc,seed)
    local alive=0;for i=2,#self.entries do if self.entries[i].unit.alive then alive=alive+1 end end
    if alive>=14 or not at then return nil end
    local variants=Data.enemies[kind] or Data.enemies.rat;local def=variants[((seed or 1)-1)%4+1]
    local u=Unit.New(self.world,def.source,{name=def.name,spawn={pos={at[1],at[2]+1.2,at[3]},yaw=yaw},team='red',
        autoRespawn=false,externalControl=true,combat=true,hpMultiplier=def.hp*self.run.rules.op.enemyHp})
    if not u.alive then u:Dispose();return nil end
    self.run:Center(u,u.spawnAt);u.elite=def.elite
    local e={unit=u,def=def,kind=kind,enc=enc,post=at,wp=1,dir=1,hit0=u.hitAt,
        driver=Driver.New(self.world,u,def.ai,#self.entries+1,{tier=def.tier,seed='salvage:'..kind..':'..string.format('%.1f',self.run.rules.time)..':'..(seed or 1)}),env=self.run:Environment(u)}
    e.passive={passive=true,radius=enc and enc.kind=='patrol' and 6 or 5,spec={bounds={min={0,0,0},max={0,0,0}}},Position=function() return e.post end}
    self.entries[#self.entries+1]=e;self.world.units[#self.world.units+1]=u
    if enc then enc.units[#enc.units+1]=e end
    if self.run.session.hud then self.run.session.hud.overlay.tags[#self.run.session.hud.overlay.tags+1]={unit=u,visible=false} end
    return e
end
function M:Alert(enc,why)
    if enc.alerted then return end;enc.alerted=true
    local cine=self.run.cine
    local elite=false
    for _,entry in ipairs(enc.units) do if entry.unit.alive and entry.unit.elite then elite=entry;break end end
    if enc.kind=='elite' and elite then
        cine:Elite(elite.unit);cine:NameCard('精英 · '..elite.def.name,(elite.def.title or '')..' · '..(elite.def.gang or ''),3.4);cine:Flash(.2,.6)
    elseif enc.kind=='ambush' then cine:NameCard('伏击！',enc.name..' · '..#enc.units..' 辆冲出来了',2.4);cine:Flash(.15,.4)
    else
        local alive=0;for _,entry in ipairs(enc.units) do if entry.unit.alive then alive=alive+1 end end
        self.run:Feed(enc.name..' · 被发现',(why and why~='' and why..'，' or '')..alive..' 辆车冲过来了','#ff5a3c')
    end
end
function M:Noise(at,r) for _,e in ipairs(self.encounters) do if e.state=='active' and not e.alerted and Flat(at,e.g)<r then self:Alert(e,'听到动静') end end end
function M:Spawn(enc)
    local types=#enc.left>0 and enc.left or enc.squad;local rand=self.run.rules.rand;enc.units={}
    for i,kind in ipairs(types) do
        local at=false;local yaw=0
        if enc.kind=='nest' then
            local p=enc.posts[(i-1)%#enc.posts+1];local x,z=-p[1],p[2]
            for k=0,7 do
                at=self:Surface(x+(k>0 and (rand()-.5)*12 or 0),z+(k>0 and (rand()-.5)*12 or 0),true)
                if at then break end
            end
            yaw=math.atan(enc.g[1]-x,enc.g[3]-z)+math.pi
        elseif enc.kind=='patrol' then
            local p=enc.route[math.min(#enc.route,i*2-1)];local nextPoint=enc.route[math.min(#enc.route,i*2+1)]
            at=self:Surface(-p[1],p[3],false) or {-p[1],p[2],p[3]}
            yaw=math.atan(-nextPoint[1]+p[1],nextPoint[3]-p[3])
        else
            local ring=enc.ring or {20,50};local a0=rand()*math.pi*2
            for k=0,15 do
                local a=a0+((i-1)+k*.37)/#types*math.pi*2;local radius=ring[1]+rand()*(ring[2]-ring[1])
                at=self:Surface(enc.g[1]+math.sin(a)*radius,enc.g[3]+math.cos(a)*radius,false);if at then break end
            end
            if at then local p=self.run.player:Position()
                yaw=enc.kind=='ambush' and math.atan(p[1]-at[1],p[3]-at[3]) or math.atan(at[1]-enc.g[1],at[3]-enc.g[3])
            end
        end
        if at then local e=self:Add(kind,at,yaw,enc,i)
            if e then e.wp=enc.kind=='patrol' and math.min(#enc.route,i*2+1) or 1 end
        end
    end
    enc.state='active';enc.left={}
end
function M:Remove(entry)
    local u=entry.unit;u:Dispose()
    for i=#self.entries,2,-1 do if self.entries[i]==entry then table.remove(self.entries,i) end end
    for i=#self.world.units,1,-1 do if self.world.units[i]==u then table.remove(self.world.units,i) end end
    local hud=self.run.session.hud
    if hud then for i=#hud.overlay.tags,1,-1 do if hud.overlay.tags[i].unit==u then table.remove(hud.overlay.tags,i) end end end
end
function M:Step(dt)
    local r=self.run.rules;self.huntLeft=self.huntLeft-dt*r.heat/50;self.timer=self.timer+dt
    if r.heat>=35 and self.huntLeft<=0 then
        self.huntLeft=18;local n=0;for _,e in ipairs(self.entries) do if e.hunter then n=n+1 end end
        if n<3 then self:Hunt(r.heat>70 and 2 or 1);self.run:Feed('追兵','热度太高，路边有车追上来了','#ff8a6a') end
    end
    if self.timer<.25 then return end;self.timer=0;local pos=self.run.player:Position();local nearest=false;local nearestDist=math.huge
    for _,e in ipairs(self.encounters) do
        local center=e.kind=='patrol' and e.units[1] and e.units[1].unit.alive and e.units[1].unit:Position() or e.g
        local d=Flat(center,pos)
        if e.state=='dormant' and d<(e.kind=='ambush' and e.triggerR or 380) then
            self:Spawn(e);if e.kind=='ambush' then self:Alert(e) end
        elseif e.state=='active' then
            if not e.hinted and not e.alerted and d<280 then e.hinted=true;self.run:Feed(e.name,e.hint or '',e.kind=='elite' and '#ff5a3c' or '#f0a21c') end
            local alive=0;local hit=false
            for _,entry in ipairs(e.units) do if entry.unit.alive then alive=alive+1;e.lastPos=entry.unit:Position();hit=hit or entry.unit.hitAt>entry.hit0 end end
            if alive==0 then
                e.state='cleared';local tier=math.min(3,e.reward and e.reward~=0 and e.reward or 1)
                local at=e.kind=='patrol' and (e.lastPos or e.g) or e.g
                local loot={table.unpack(Data.crateLoot[tier+1])}
                if e.id=='convoy' then loot[#loot+1]={'ore',2,4};loot[#loot+1]={'cell',1,1,.7} end
                local ground=self:Surface(at[1],at[3],true) or at
                self.run.rules:AddExtra({id='C:'..e.id,kind='cache',tier=tier,name=e.name,g=ground,loot=loot})
                self.run.fx:Loot(ground,({0xc9c1b2,0x3ddc84,0x3ea8ff,0xc46bff})[tier+1],0)
                self.run:Feed('清除 · '..e.name,({'','普通','优良','稀有'})[tier+1]..'补给箱掉在了'..(e.kind=='patrol' and '车队残骸边' or '据点中间'),'#3ddc84')
            elseif not e.alerted and hit then self:Alert(e,'被打了')
            elseif not e.alerted and d<(e.aggroR or 140) then self:Alert(e,'发现了你')
            elseif not e.alerted and d>650 then
                e.left={};for _,entry in ipairs(e.units) do if entry.unit.alive then e.left[#e.left+1]=entry.kind end;self:Remove(entry) end
                e.units={};e.state=#e.left>0 and 'dormant' or 'cleared'
            end
            if e.state=='active' and d<nearestDist then nearest={name=e.name,n=alive,d=d,alerted=e.alerted==true};nearestDist=d end
        end
    end
    self.run.threat=nearest and nearestDist<400 and nearest or nil
end
function M:Target(entry)
    local enc=entry.enc
    if not enc or enc.alerted then return self.run.player end
    if enc.kind=='patrol' then
        local p=enc.route[entry.wp];entry.post={-p[1],p[2],p[3]}
        if Flat(entry.unit:Position(),entry.post)<16 then
            if entry.wp+entry.dir>#enc.route or entry.wp+entry.dir<1 then entry.dir=-entry.dir end;entry.wp=entry.wp+entry.dir
        end
    end;return entry.passive
end
function M:Hunt(n,near)
    local pos=near or self.run.player:Position();local pool={};local fallback={}
    for _,s in ipairs(self.world.layout.salvage.gameplay.enemySpawns) do local g={-s.x,s.y,s.z};local d=Flat(g,pos)
        if d>(near and 140 or 220) and d<(near and 340 or 420) then pool[#pool+1]={s=s,g=g} end
        if d>200 then fallback[#fallback+1]={s=s,g=g,d=d} end
    end
    if #pool==0 then table.sort(fallback,function(a,b) return a.d<b.d end);for i=1,math.min(6,#fallback) do pool[#pool+1]=fallback[i] end end
    if #pool==0 then return end
    for i=1,n do
        local rand=self.run.rules.rand;local o=pool[math.floor(rand()*#pool)+1];local types=Data.regionHunters[o.s.region] or Data.regionHunters['']
        local kind=types[math.floor(rand()*#types)+1]
        if self.run.rules.time>480 then kind=({rat='ratT2',dozer='dozerT3'})[kind] or kind end
        local at=self:Surface(o.g[1],o.g[3],false) or o.g;local playerPos=self.run.player:Position()
        local e=self:Add(kind,at,math.atan(playerPos[1]-at[1],playerPos[3]-at[3]),nil,self.run.rules.kills+i-1)
        if e then e.hunter=true end
    end
end
return M

-- Shared loot ownership: rivals rob unopened crates, carry cargo and extract.
local Loot=require 'salvage.Loot'
local Data=require('core.ResourceData').Read('Salvage/RunData.json')
local M={};M.__index=M
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
function M.New(run)
    local self=setmetatable({},M);self:init(run);return self
end
function M:init(run)
    self.run=run;self.timer=0
    self.squads={{name='野猫打捞队',at=90,types={'racer','ratT2'},color='#ffb21e'},
        {name='黑市回收队',at=300,types={'ironclad','hedgehog','kite'},color='#c46bff'}}
    for _,s in ipairs(self.squads) do s.state='pending';s.units={};s.cargo={};s.crates=0;s.t=0;s.calm=0 end
end
function M:Spawn(s)
    local run=self.run;local points={};local player=run.player:Position()
    for _,p in ipairs(run.world.layout.salvage.gameplay.enemySpawns) do
        local g={-p.x,p.y,p.z};if Flat(g,player)>450 then points[#points+1]={g=g,yaw=p.yaw or 0} end
    end
    if #points==0 then return false end
    local point=points[math.floor(run.rules.rand()*#points)+1]
    for i,kind in ipairs(s.types) do
        local a=(i-1)/#s.types*2*math.pi;local x,z=point.g[1]+math.cos(a)*10,point.g[3]+math.sin(a)*10
        local e=run.director:Add(kind,run.director:Surface(x,z,false) or point.g,point.yaw,nil,6+i)
        if e then e.rival=s;s.units[#s.units+1]=e end
    end
    if #s.units==0 then return false end
    s.state='loot';run:Feed('敌对打捞队',s.name..'（'..#s.units..' 辆）进场了 · 他们也在搜箱子',s.color);return true
end
function M:Fight(s,why)
    if s.state=='fight' then return end
    s.back=s.state;s.state='fight';s.calm=0;self.run:Feed(s.name..' · 盯上你了',why,'#ff5a3c')
end
function M:Noise(at,radius)
    for _,s in ipairs(self.squads) do if s.state=='loot' or s.state=='leave' then
        for _,e in ipairs(s.units) do if e.unit.alive and Flat(e.unit:Position(),at)<radius then self:Fight(s,'听到动静');break end end
    end end
end
function M:Pick(s,pos)
    local rules=self.run.rules;local best,dist=nil,math.huge
    if s.state=='leave' then
        for _,e in ipairs(rules.extracts) do
            if not e.needs and not e.maxWidth and not e.loud and (not e.openAt or rules.time>=e.openAt) then
                local d=Flat(e.g,pos);if d<dist then best=e;dist=d end
            end
        end
    else
        for _,tier in ipairs({1,0}) do
            for _,o in ipairs(rules.objects) do
                if o.kind=='crate' and o.tier>=tier and not o.robbed and not rules.opened[o.id] and not rules.sessions[o.id] and o.ctype~='vault' then
                    local d=Flat(o.g,pos);if d<dist then best=o;dist=d end
                end
            end
            if best then break end
        end
    end
    return best
end
function M:Update(dt)
    self.timer=self.timer+dt;if self.timer<.25 then return end
    local step=self.timer;self.timer=0;local run=self.run;local rules=run.rules;local pos=run.player:Position()
    for _,s in ipairs(self.squads) do
        if s.state=='pending' then
            if rules.time>=s.at and not self:Spawn(s) then s.at=rules.time+20 end
        elseif s.state~='dead' and s.state~='gone' then
            local alive={};local d=math.huge;local hit=false
            for _,e in ipairs(s.units) do if e.unit.alive then alive[#alive+1]=e;d=math.min(d,Flat(e.unit:Position(),pos));hit=hit or e.unit.hitAt>e.hit0 end end
            s.units=alive
            if #alive==0 then s.state='dead';run:Feed(s.name..' · 全灭','他们搜到的货都在掉落箱里','#3ddc84')
            else
                if s.state~='fight' and (hit or d<110 and not run.gear:Hidden()) then self:Fight(s,hit and '被打了' or '撞见了') end
                if s.state=='fight' then
                    s.calm=d>450 and s.calm+step or 0
                    if s.calm>8 then s.state=s.back=='leave' and 'leave' or 'loot';s.goal=nil;for _,e in ipairs(alive) do e.hit0=e.unit.hitAt end end
                else
                    if s.state=='loot' and (s.crates>=6 or rules.time>660) then s.state='leave';s.goal=nil end
                    if s.goal and s.state=='loot' and (s.goal.robbed or rules.opened[s.goal.id] or rules.sessions[s.goal.id]) then s.goal=nil end
                    if not s.goal then s.goal=self:Pick(s,alive[1].unit:Position());s.t=0 end
                    if not s.goal and s.state=='loot' then s.state='leave'
                    elseif s.goal then
                        local nearby=Flat(alive[1].unit:Position(),s.goal.g)<(s.state=='loot' and 12 or s.goal.radius)
                        s.t=nearby and s.t+step or 0
                        if s.state=='loot' and s.t>=3 then
                            s.goal.robbed=true
                            for _,it in ipairs(Loot.FromTable(Data.crateLoot[s.goal.tier+1],rules.rand)) do s.cargo[it.id]=(s.cargo[it.id] or 0)+it.n end
                            s.crates=s.crates+1;s.goal=nil
                            if d<350 then run:Feed(s.name,'撬开了一个箱子 · 车上的货值 '..math.floor(Loot.Value(s.cargo)),s.color) end
                        elseif s.state=='leave' and s.t>=8 then
                            run:Feed(s.name..' · 撤离了','带走了 '..math.floor(Loot.Value(s.cargo))..' 的货','#8a8f98')
                            for _,e in ipairs(s.units) do run.director:Remove(e) end
                            s.units={};s.state='gone'
                        end
                    end
                end
            end
        end
    end
end
function M:Target(e)
    local s=e.rival;if not s or s.state=='fight' then return nil end
    local leader=s.units[1];local at=s.goal and s.goal.g or e.unit:Position()
    if leader and leader~=e then
        local p=leader.unit:Position();local yaw=leader.unit.vehicle:Yaw();local index=1
        for i,unit in ipairs(s.units) do if unit==e then index=i;break end end
        local side=index%2==0 and 1 or -1
        at={p[1]-math.sin(yaw)*9+math.cos(yaw)*6*side,p[2],p[3]-math.cos(yaw)*9-math.sin(yaw)*6*side}
    end
    e.post=at;return e.passive
end
function M:OnKill(e)
    local s=e.rival;local out={};if not s then return out end
    local left=0;for _,other in ipairs(s.units) do if other~=e and other.unit.alive then left=left+1 end end
    for id,n in pairs(s.cargo) do
        local k=left>0 and math.ceil(n/(left+1)) or n
        if k>0 then out[#out+1]={id,k,k,1};s.cargo[id]=n>k and n-k or nil end
    end
    self:Fight(s,'同伴被打爆');return out
end
return M

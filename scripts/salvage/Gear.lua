-- H5 salvageGear final semantics. Inventory settlement belongs to SalvageLobby.
local M={};M.__index=M
M.ORDER={'repair','shieldCell','smokePack','scanner'}
M.CARRY={repair=3,shieldCell=2,smokePack=3,scanner=2}
local Names={'应急维修包','护盾电池','烟雾弹','扫描脉冲'}
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
function M.New(run) local self=setmetatable({},M);self:init(run);return self end
function M:init(run)
    self.run=run;self.pocket={};self.open=false;self.selected=0;self.x=0;self.y=0;self.idle=0;self.shield=0;self.scanTime=0;self.scans={}
end
function M:Count(id) return (self.pocket[id] or 0)+(self.run.rules.cargo[id] or 0) end
function M:Spend(id)
    local bag=(self.pocket[id] or 0)>0 and self.pocket or self.run.rules.cargo
    local left=(bag[id] or 0)-1;bag[id]=left>0 and left or nil
end
function M:Tap()
    if self.open then if self.selected>0 then self:Use(self.selected) else self.open=false end;return end
    self.open=true;self.selected=0;self.x=0;self.y=0;self.idle=0;self.run.session.firing=false;self.run.session.controls.held.fire=false
end
function M:Move(dx,dy)
    if not self.open then return false end
    if dx~=0 or dy~=0 then self.idle=0 end
    self.x=self.x+dx;self.y=self.y+dy;local length=math.sqrt(self.x^2+self.y^2)
    if length>90 then self.x=self.x*90/length;self.y=self.y*90/length end
    if length>26 then self.selected=(math.floor(math.atan(self.x,-self.y)/(math.pi/2)+.5)%4)+1 end
    return true
end
function M:Key(key)
    if not self.open then return false end
    for i,k in ipairs({KEY_1,KEY_2,KEY_3,KEY_4}) do if key==k then self:Use(i);return true end end
    if key==KEY_ESCAPE then self.open=false;return true end
    return false
end
function M:Missing() return self.run.player.bp:Size()<#self.run.player.repairOrder end
function M:Hidden(pos)
    return self.smoke~=nil and Flat(pos or self.run.player:Position(),self.smoke.g)<20
end
function M:Use(index)
    local id=M.ORDER[index];self.open=false
    if not id then return end
    if self:Count(id)<=0 then self.run:Feed(Names[index],'身上没有这个道具','#8a8f98');return end
    local run=self.run;local p=run.player
    if not p.alive or run.rules.finished or run.rules.ex then return end
    if id=='repair' then
        if self.repairing then return end
        if p:Life()>.999 and not self:Missing() then run:Feed(Names[index],'车况完好，不用修');return end
        self.repairing={t=0,hitAt=p.hitAt};run:Feed(Names[index],'停稳 3 秒 · 挨打或开走会打断');return
    end
    self:Spend(id)
    if id=='shieldCell' then self.shield=10;run:Feed(Names[index],'10 秒内受到伤害降至 25%','#3ea8ff')
    elseif id=='smokePack' then self.smoke={g={table.unpack(p:Position())},t=14};run.rules.heat=math.max(0,run.rules.heat-15);run:Feed(Names[index],'待在烟里敌人就看不见你')
    elseif id=='scanner' then
        self.scans={};self.scanTime=25;local crates,wrecks,foes=0,0,0
        for _,o in ipairs(run.rules.objects) do if o.kind~='station' and not run.rules.opened[o.id] and Flat(o.g,p:Position())<120 then
            self.scans[o.id]=o;if o.kind=='crate' then crates=crates+1 else wrecks=wrecks+1 end
        end end
        for i=2,#run.entries do if run.entries[i].unit.alive and Flat(run.entries[i].unit:Position(),p:Position())<180 then foes=foes+1 end end
        run.rules:Heat(4);run:Feed(Names[index],string.format('120 米内箱子 %d · 残骸 %d · 180 米内敌车 %d',crates,wrecks,foes))
    end
end
function M:Update(dt)
    local run=self.run;local p=run.player
    if self.open then self.idle=self.idle+dt;if self.idle>6 or not p.alive or run.rules.ex or run.rules.finished or run.cine.blocking then self.open=false end end
    local r=self.repairing
    if r then
        if not p.alive or run.rules.ex or p.hitAt~=r.hitAt then self.repairing=nil;run:Feed('维修中断','维修包未消耗','#ff8a6a')
        elseif math.abs(p.vehicle.speed)>1.5 then
            r.t=math.max(0,r.t-dt*2)
            if r.t<=0 and r.started then self.repairing=nil;run:Feed('维修中断','车开走了，维修包未消耗','#ff8a6a') end
        else
            r.started=true;r.t=r.t+dt
            if r.t>=3 then
                self.repairing=nil;self:Spend('repair');local back=p:RestoreMissing(16);p:Heal(.4);p:Flush();run:SyncPlayer()
                run:Feed('维修完成','修回 '..#back..' 块方块 · 全车回血 40%','#3ddc84')
            end
        end
    end
    if self.shield>0 then
        self.shield=math.max(0,self.shield-dt)
        if (p.incomingDamageMultiplier or 1)==1 then p.incomingDamageMultiplier=.25 end
        if self.shield==0 and p.incomingDamageMultiplier==.25 then p.incomingDamageMultiplier=1 end
    end
    if self.smoke then self.smoke.t=self.smoke.t-dt;if self.smoke.t<=0 then self.smoke=nil end end
    self.scanTime=math.max(0,self.scanTime-dt);if self.scanTime==0 then self.scans={} end
end
return M

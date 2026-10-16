local Defs=require("parts.Defs")

local Data=require('endless.Data')
local C=Data.config
local Roles=Data.roles
local Inventory=require('endless.Inventory')
local Random=require('endless.Random')
local M={};M.__index=M
local function Copy(t) local out={};for k,v in pairs(t or {}) do out[k]=type(v)=='table' and Copy(v) or v end;return out end
local function Size(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
function M.WavePoints(w) return math.floor(10*(1+.25*(w-1))*1.1^math.floor(w/C.bossEvery)+.5) end
function M.EnemyTier(w) return math.min(C.maxTier,1+math.floor((w-1)/C.bossEvery)) end
function M.UnlockedTier(w) return math.min(C.maxTier,C.startTier+math.floor(w/C.bossEvery)) end
function M.Inside(pos,s) return s and pos[2]>=s.pos[2] and ((pos[1]-s.pos[1])/s.rx)^2+((pos[3]-s.pos[3])/s.rz)^2+((pos[2]-s.pos[2])/s.h)^2<=1 or false end
function M.Plan(seed,wave)
    local random=Random.New(tostring(seed)..':wave:'..wave);local tier=M.EnemyTier(wave);local boss=wave%C.bossEvery==0
    local roles={};for _,r in ipairs({'assault','heavy','sniper','hover'}) do if wave==C.bossEvery and r=='assault' or wave~=C.bossEvery and Roles[r].fromWave<=wave then roles[#roles+1]=r end end
    local counts={};for _,r in ipairs(roles) do counts[r]=0 end;local out={}
    local scale=1+math.max(0,wave-C.lateScalingFromWave)*C.lateScalingPerWave
    local function Make(role,elite)
        return {id='w'..wave..'-'..#out,role=role,tier=math.min(C.maxTier,tier+((role=='boss' or elite) and 1 or 0)),variant=math.floor(random()*2),elite=elite or false,cost=Roles[role].cost*(elite and 2 or 1),hpScale=scale*(elite and tier==C.maxTier and 1.5 or 1),damageScale=scale}
    end
    if boss then out[#out+1]=Make('boss') end
    local left=math.floor(M.WavePoints(wave)*(boss and .5 or 1))
    while left>=1 do
        local count=0;for _,v in pairs(counts) do count=count+v end
        local valid={};local least=math.huge
        for _,role in ipairs(roles) do if Roles[role].cost<=left and (#roles==1 or counts[role]+1<=math.ceil((count+1)*.6)) then valid[#valid+1]=role;least=math.min(least,counts[role]) end end
        if #valid==0 then break end
        local balanced={};for _,r in ipairs(valid) do if counts[r]==least then balanced[#balanced+1]=r end end
        local role=balanced[math.floor(random()*#balanced)+1]
        local elite=wave>=C.eliteFromWave and left>=Roles[role].cost*2 and random()<math.min(C.eliteChanceMax,C.eliteChancePerWave*wave)
        local meta=Make(role,elite);out[#out+1]=meta;counts[role]=counts[role]+1;left=left-meta.cost
    end;return out
end
function M.New(source,seed,saved)
    local self=setmetatable({},M);self:init(source,seed or 1,saved);return self
end
function M:init(source,seed,saved)
    saved=saved or {};self.seed=saved.seed or seed;self.blueprint=Copy(saved.blueprint or Inventory.Blueprint(source):ToTable())
    self.inventory=Copy(saved.inventory or Inventory.Initial(self.blueprint));self.wave=saved.wave or 1;self.tier=saved.tier or C.startTier;self.lives=saved.lives or C.lives
    self.score=saved.score or 0;self.time=saved.time or 0;self.damage=saved.damage or 0;self.kills=Copy(saved.kills or {assault=0,heavy=0,sniper=0,hover=0,boss=0})
    self.state=saved.version and 'rest' or 'countdown';self.countdown=saved.version and 0 or C.initialCountdown;self.waveTime=0;self.queue={};self.alive={};self.events={};self.nextSpawn=0
    self.credits=saved.credits or 0;self.repairs=saved.repairs or 0;self.weaponDrought=saved.weaponDrought or 0;self.supplies=Copy(saved.supplies or {})
    self.pendingDrops={};self.dropOrder={};self.dropSerial=0;self.charge=false;self.shield={};self.random=Random.New(tostring(self.seed)..':rewards:'..self.wave);self:RefreshShield()
end
function M:Emit(kind,data) local e={type=kind};for k,v in pairs(data or {}) do e[k]=v end;self.events[#self.events+1]=e end
function M:Drain() local out=self.events;self.events={};return out end
function M:Step(dt)
    if self.state=='editing' or self.state=='over' then return end
    self.time=self.time+dt
    if self.respawnAt and self.time>=self.respawnAt then self.respawnAt=nil;self:Emit('respawn',{invulnerability=C.spawnInvulnerability}) end
    if self.state=='countdown' then self.countdown=math.max(0,self.countdown-dt);if self.countdown<=0 then self:StartWave(self.wave) end;return end
    if self.state=='combat' then self.waveTime=self.waveTime+dt;if not self.charge and self.waveTime>=C.chargeAfter then self.charge=true;self:Emit('charge',{wave=self.wave}) end end
end
function M:StartWave(wave)
    self.wave=math.max(1,math.floor(wave));self.state='combat';self.waveTime=0;self.waveHurt=false;self.weaponThisWave=false;self.charge=false
    self.queue=M.Plan(self.seed,self.wave);self.alive={};self.nextSpawn=self.time;self.random=Random.New(tostring(self.seed)..':rewards:'..self.wave);self:RefreshShield()
    self:Emit('waveStart',{wave=self.wave,boss=self.wave%C.bossEvery==0,total=#self.queue})
end
function M:TakeSpawn()
    if self.state~='combat' or #self.queue==0 or Size(self.alive)>=C.maxEnemies or self.time<self.nextSpawn then return end
    local meta=table.remove(self.queue,1);self.alive[meta.id]=meta;self.nextSpawn=self.time+C.spawnInterval;return Copy(meta)
end
function M:EnemyKilled(id,parts,pos)
    local meta=self.alive[id];if not meta or self.state~='combat' then return false end
    self.alive[id]=nil;self.kills[meta.role]=(self.kills[meta.role] or 0)+1
    local score=math.floor(Roles[meta.role].cost*10*(1+.1*self.wave)*(meta.elite and 2 or 1)*(meta.role=='boss' and 3 or 1)+.5);self.score=self.score+score
    local function Add(item)
        self.dropSerial=self.dropSerial+1;local drop=Copy(item);drop.id='drop-'..self.dropSerial;drop.pos=Copy(pos or {0,0,0});drop.elite=meta.elite
        self.pendingDrops[drop.id]=drop;self.dropOrder[#self.dropOrder+1]=drop.id;self:Emit('drop',{drop=drop})
        if Size(self.pendingDrops)>C.maxDrops then for _,first in ipairs(self.dropOrder) do if self.pendingDrops[first] then self:PickupDrop(first,'overflow');break end end end
    end
    Add({credits=Inventory.Credits(meta)});for _,item in ipairs(Inventory.Drops(meta,parts or {},self.random)) do Add(item) end
    self:Emit('enemyKilled',{meta=meta,score=score,pos=pos});self:CheckClear();return true
end
function M:CheckClear()
    if self.state~='combat' or #self.queue>0 or next(self.alive) then return end
    self.state='rest';if not self.waveHurt then self.score=self.score+50*self.wave end
    for _,id in ipairs(self.dropOrder) do self:PickupDrop(id,'waveClear') end;self.dropOrder={}
    self.weaponDrought=self.weaponThisWave and 0 or self.weaponDrought+1
    local tier=M.UnlockedTier(self.wave);if tier>self.tier then self.tier=tier;self:Emit('tierUp',{tier=tier}) end
    self:RefreshShield();self.supplies=Inventory.Supplies(self.tier,self.wave,self.inventory,self.blueprint,self.weaponDrought,self.random)
    self:Emit('waveClear',{wave=self.wave,score=self.score,supplies=self.supplies});self:Emit('save',{save=self:Save()})
end
function M:Pickup(kind,count)
    count=math.floor(count or 1);if not Inventory.Limited(kind) or count<=0 then return false end
    self.inventory[kind]=(self.inventory[kind] or 0)+count
    if Defs.PARTS[kind].cat=='weapon' then self.weaponThisWave=true;self.weaponDrought=0 end
    self:Emit('pickup',{partType=kind,count=count,total=self.inventory[kind]});return true
end
function M:PickupDrop(id,reason)
    local drop=self.pendingDrops[id];if not drop then return false end;self.pendingDrops[id]=nil
    if drop.credits then self.credits=self.credits+drop.credits;self:Emit('credits',{amount=drop.credits,total=self.credits}) else self:Pickup(drop.type) end
    self:Emit('dropCollected',{drop=drop,reason=reason or 'near'});return true
end
function M:Buy(kind)
    if not Inventory.Limited(kind) or self.state~='rest' and self.state~='editing' then return {ok=false,reason='现在不能买'} end
    if C.tierLimits and Inventory.Tier(kind)>self.tier then return {ok=false,reason='T'..Inventory.Tier(kind)..' 图纸要打过 Boss 波解锁'} end
    local price=Inventory.Price(kind);if self.credits<price then return {ok=false,reason='金钱不够（'..self.credits..' / '..price..'）'} end
    self.credits=self.credits-price;self:Pickup(kind);self:Emit('bought',{partType=kind,price=price,total=self.credits});self:Emit('save',{save=self:Save()});return {ok=true,price=price}
end
function M:ChooseSupply(index)
    if self.state~='rest' or not self.supplies[index] then return false end
    local choice=self.supplies[index];if choice.kind=='repair' then self.repairs=self.repairs+1 else self:Pickup(choice.type) end
    self.supplies={};self:Emit('supplyChosen',{choice=choice});self:Emit('save',{save=self:Save()});return choice
end
function M:NextWave()
    if self.state~='rest' or #self.supplies>0 or self.respawnAt then return false end
    self.wave=self.wave+1;self.state='countdown';self.countdown=C.nextCountdown;self:Emit('countdown',{wave=self.wave,seconds=self.countdown});return true
end
function M:BeginEdit()
    if self.respawnAt or not (self.state=='rest' or self.state=='countdown' and self.wave==1) then return false end
    self.beforeEdit=self.state;self.state='editing';self:Emit('editStart');return true
end
function M:ResumeEdit(source)
    local result=Inventory.Validate(source,self.tier,self.inventory)
    if self.state~='editing' then result.ok=false;table.insert(result.errors,1,'当前不在改装状态');return result end
    if result.ok then self.blueprint=Copy(Inventory.Blueprint(source):ToTable());self.state=self.beforeEdit or 'rest';self:Emit('editEnd',{blueprint=self.blueprint}) end;return result
end
function M:LoseLife()
    if self.state=='over' or self.respawnAt then return false end
    self.lives=math.max(0,self.lives-1);self.waveHurt=true;self:Emit('lifeLost',{lives=self.lives})
    if self.lives==0 then self:Finish() else self.respawnAt=self.time+C.respawnDelay end;return true
end
function M:Finish() if self.state=='over' then return end;self.state='over';self.queue={};self.respawnAt=nil;self:Emit('gameOver',{result=self:Result()}) end
function M:PlayerHit() self.waveHurt=true;self.lastPlayerHit=self.time end
function M:RecordDamage(amount) self.damage=self.damage+math.max(0,amount) end
function M:RefreshShield() self.shield.max=C.shieldBase+C.shieldPerWave*self.wave;self.shield.hp=self.shield.max;self:Emit('shieldRaise',Copy(self.shield)) end
function M:ShieldHit(amount,point)
    if self.shield.hp<=0 then return 0 end;local taken=math.min(self.shield.hp,math.max(0,amount));self.shield.hp=self.shield.hp-taken
    self:Emit('shieldHit',{amount=taken,point=point,hp=self.shield.hp,max=self.shield.max});if self.shield.hp==0 then self:Emit('shieldDown') end;return taken
end
function M:UseRepair()
    if self.repairs<=0 or self.state=='over' or self.state=='editing' or self.respawnAt then return false end
    self.repairs=self.repairs-1;self:Emit('repair');return true
end
function M:Result() return {wave=self.wave,score=self.score,kills=Copy(self.kills),damage=self.damage,time=self.time,seed=self.seed,blueprint=Copy(self.blueprint)} end
function M:Save()
    local out=self:Result();out.version=1;out.tier=self.tier;out.lives=self.lives;out.credits=self.credits;out.inventory=Copy(self.inventory);out.repairs=self.repairs;out.weaponDrought=self.weaponDrought;out.supplies=Copy(self.supplies);return out
end
return M

local ran=false
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<.000000001 end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function Exercise()
    if ran then return end;ran=true
    local Run=require('endless.Run');local Data=require('endless.Data');local Inventory=require('endless.Inventory')
    local f=File('tools/migration/source-endless-fixtures.json',FILE_READ);local fixtures=cjson.decode(f:ReadString());f:Dispose()
    for _,row in ipairs(fixtures.waves) do
        V.assert(Run.WavePoints(row.wave)==row.points,'source wave budget '..row.wave)
        V.assert(Run.EnemyTier(row.wave)==row.tier and Run.UnlockedTier(row.wave)==row.unlocked,'source enemy and unlocked tier '..row.wave)
        V.assert(Same(Run.Plan(row.seed,row.wave),row.plan),'source seeded wave composition '..tostring(row.seed)..':'..row.wave)
    end
    for _,row in ipairs(fixtures.supplies) do local source=Data.starters[row.starter].source
        local choices=Inventory.Supplies(row.tier,row.wave,Inventory.Initial(source),source,row.drought,require('endless.Random').New(row.seed))
        V.assert(Same(choices,row.choices),'source exact supply selection '..row.seed..':'..row.starter)
    end
    for _,row in ipairs(fixtures.drops) do
        V.assert(Same(Inventory.Drops({role=row.role,elite=row.elite},row.parts,require('endless.Random').New(row.seed)),row.drops),'source surviving part drops '..row.seed..':'..row.role..':'..tostring(row.elite))
    end
    for _,starter in ipairs(Data.starters) do
        local r=Run.New(starter.source,19282);V.assert(r.state=='countdown' and r.countdown==10 and r.lives==3,'source starter countdown and lives')
        local initial=Inventory.Count(starter.source);V.assert(r.inventory.laser1==(initial.laser1 or 0)+1 and r.inventory.steer1==(initial.steer1 or 0)+2,'starter stock includes installed and spare parts')
        V.assert(Inventory.Limits(1).budget==99999,'10 October baseline has no tier budget restriction')
        r:Step(10);V.assert(r.state=='combat' and #r.queue==5,'wave one begins with five assault cars')
        r.nextSpawn=0;local m=r:TakeSpawn();V.assert(m and r.alive[m.id] and r.nextSpawn==r.time+1.5,'spawn consumes queue and locks next interval')
        r:Step(120);V.assert(r.charge,'charge starts at source 120 seconds')
        r.queue={};for id in pairs(r.alive) do r:EnemyKilled(id,{}, {0,0,0}) end
        V.assert(r.state=='rest' and #r.supplies==3 and r.credits>0,'wave clear auto collects credits and gives three supplies')
        V.assert(not r:NextWave(),'unselected supplies block next wave')
        V.assert(r:ChooseSupply(1) and #r.supplies==0,'one supply consumes entire choice')
        V.assert(r:BeginEdit(),'rest permits world pause edit');local time=r.time;r:Step(8);V.assert(time==r.time,'editing freezes run clock')
        V.assert(r:ResumeEdit(starter.source).ok,'same owned starter departs validly')
        local stock=r.inventory.laser1;r.credits=100000;local bought=r:Buy('laser1');V.assert(bought.ok and r.inventory.laser1==stock+1 and r.credits==100000-bought.price,'shop buys exact stock without modifying blueprint')
        local saved=r:Save();local recovered=Run.New(starter.source,99,saved);V.assert(recovered.state=='rest' and recovered.credits==r.credits and recovered.seed==r.seed,'checkpoint recovers rest and seed')
        V.assert(r:NextWave() and r.wave==2 and r.countdown==5,'next wave waits source five seconds')
        r:LoseLife();V.assert(r.lives==2 and r.respawnAt==r.time+5,'life loss waits five seconds')
        V.assert(not r:LoseLife() and r.lives==2,'death cannot consume twice while waiting')
        r:Step(5);r:LoseLife();r:Step(5);r:LoseLife();V.assert(r.state=='over' and r.lives==0 and not r.respawnAt,'third death settles without life restoration')
    end
    V.assert(Same(Inventory.Drops({role='boss',elite=true},{{id=1,type='laser1',hp=10},{id=2,type='laser2',hp=10}},function() error('Elite drops must not consume RNG') end),{{type='laser2',partId=2},{type='laser1',partId=1}}),'elite boss drops two highest budget surviving parts without RNG')
    V.assert(Run.Inside({0,1,0},{pos={0,0,0},rx=10,rz=10,h=10}) and not Run.Inside({0,-1,0},{pos={0,0,0},rx=10,rz=10,h=10}),'hemisphere shield excludes ground below base')
    local r=Run.New(Data.starters[1].source,123);r.state='rest';local record=r:Save();local Records=require('endless.Records');local Cloud=require('storage.CloudStorage')
    V.assert(Records.Run(record) and Records.Best(r:Result()),'source run and best validate for persistent storage')
    local function Envelope(data) return cjson.encode({v=1,generation=1,data=data}) end
    V.assert(Cloud.Decode(Envelope(record),'vox-save-v1-vox-garage-vox.endless.run.v1')~=nil,'cloud accepts real endless checkpoint key')
    record.inventory.laser1=-1;V.assert(not Records.Run(record) and Cloud.Decode(Envelope(record),'vox-save-v1-vox-garage-vox.endless.run.v1')==nil,'cloud refuses corrupt negative stock checkpoint');record.inventory.laser1=1
    record.lives=4;V.assert(not Records.Run(record),'checkpoint cannot restore excess lives');record.lives=3
    record.supplies={{id='fake',kind='part',type='not-a-part',name='fake',tier=1}};V.assert(not Records.Run(record),'checkpoint rejects missing part supply')
    V.assert(Cloud.Decode(cjson.encode({v=1,generation=2,deleted=true}),'vox-save-v1-vox-garage-vox.endless.run.v1')~=nil,'finished run tombstone survives cloud refresh')
end
V.atFrame(40,function() Exercise();V.finish() end)

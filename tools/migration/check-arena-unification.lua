local Objectives=require 'combat.BattleObjectives'
local Controller=require 'combat.BattleController'
local Data=require 'combat.ArenaData'
local Unit=require 'combat.CarUnit'
local scene=nil ---@type Scene?
local world={} ---@type table
local unit=nil ---@type table?
local function Near(a,b) return math.abs(a-b)<1e-7 end
V.atFrame(2,function()
    local f=assert(io.open('.tmp/source-arena-unification.json'));local fixture=cjson.decode(f:read('*a'));f:close()
    V.assert(fixture.baseline=='2b169a9964645f5f346a7158bcb14447f040814a','frozen October 14 source identity')
    V.assert(Data.modes.conquest.respawn==15 and Data.modes.escort.respawn==15,'both respawn schedules use frozen fifteen seconds')
    for i,row in ipairs(fixture.zones) do
        local actor={spec={bounds={radius=row.radius}},Position=function() return row.pos end}
        V.assert(Objectives.InPoint(actor,row.point)==row.inside,'source body contact and height zone boundary '..i)
    end
    local function Actor(team,pos,radius,alive)
        return {team=team,alive=alive,spec={bounds={radius=radius}},Position=function()return pos end}
    end
    local blue=Actor('blue',{24,10,0},6,true)
    local red=Actor('red',{-24,10,0},6,true)
    local dead=Actor('blue',{0,0,0},6,false)
    local outside=Actor('red',{40,0,0},6,true)
    local tallOutside=Actor('blue',{0,14,0},6,true)
    local aggregate=setmetatable({id='conquest',points={{id='A',pos={0,0,0},radius=22}},
        battle={entries={{unit=blue},{unit=red},{unit=dead},{unit=outside},{unit=tallOutside}}}},Objectives)
    local state=aggregate:WorldState({})
    V.assert(state.inPoint.A.blue==1 and state.inPoint.A.red==1,'WorldState counts body-contact teams and excludes dead/outside/strict height edge')
    aggregate.id='escort';aggregate.battle.rules={s=0};aggregate.At=function()return{pos={0,0,0}}end
    state=aggregate:WorldState({})
    V.assert(state.near.blue==1 and state.near.red==1,'payload WorldState shares body-contact and height rules')
    local goalMode=setmetatable({id='conquest',world={time=0},assignAt={blue=1},goals={},
        points={{pos={0,0,0},radius=22}},battle={rules={shield={red=true}}}},Objectives)
    local goalEntry={unit=blue};goalMode.goals[goalEntry]={point=1}
    V.assert(goalMode:Goal(goalEntry,nil).radius==22,'AI conquest goal uses actual capture radius')
    scene=Scene();scene:CreateComponent('Octree')
    local objectiveView=require('render.ObjectiveView').New({scene=scene},{id='conquest',
        points={{pos={0,0,0},radius=22}},bases={blue={aim={0,0,0}},red={aim={0,0,0}}}})
    objectiveView:Update(.1,{points={{v=0,contested=false}},score={blue=0,red=0},shield={blue=true,red=true}},nil)
    local ringRadius=0;local vertexCount=objectiveView.mesh:GetNumVertices(0)
    for i=0,vertexCount-1 do local pos=objectiveView.mesh:GetVertex(0,i).position
        ringRadius=math.max(ringRadius,math.sqrt(pos.x^2+pos.z^2))
    end
    V.assert(vertexCount>0 and math.abs(ringRadius-22)<.0001,'actual ObjectiveView native geometry displays twenty-two metre ring')
    objectiveView:Dispose()
    local Space=require 'physics.Space';local Base=require 'drive.TrackWorld'
    world=setmetatable({scene=scene,space=Space.New(scene),time=10,fx={},viewEvents={},stats={},units={},RecordDamage=function()end,RecordKill=function()end},Base)
    world.env={stats={shots=0},castRay=function()end,lockables=function()return{}end,hit=function()end,explode=function()end}
    world.debris=require('combat.Debris').New(world.space)
    unit=Unit.New(world,Data.prefabs['blue:1:assault:1'],{name='Arena parity',spawn={pos={100,10,100},yaw=0},team='blue',combat=true,externalControl=true,autoRespawn=false})
    V.assert(unit.alive and unit.vehicle.body.native~=nil,'actual CarUnit owns a native Bullet vehicle')
    local heal,restore=unit.Heal,unit.RestoreMissing
    for i,row in ipairs(fixture.recovery) do
        local log={};unit.bodyHp=unit.bodyHpMax*.5;unit.hitAt=10-row.hurtAge;unit.repairing=false
        unit.Heal=function(self,frac) log[#log+1]={'heal',frac};return heal(self,frac) end
        unit.RestoreMissing=function(self,count) log[#log+1]={'restore',count};return restore(self,count) end
        local pos=unit:Position();local basePos=row.home and {table.unpack(pos)} or {0,0,0}
        local rule={cfg=Data.modes[row.mode],sudden=row.sudden,attack='blue',shield={blue=false,red=false},s=0}
        local objective=setmetatable({id=row.mode,world=world,battle={rules=rule},bases={blue={zone={pos=basePos,rx=30,rz=30,h=30}},red={zone={pos={10000,0,10000},rx=30,rz=30,h=30}}},At=function()return{pos=basePos}end},Objectives)
        local entry={unit=unit,repair=row.repairBefore}
        objective:UnitTick(entry,row.dt)
        local equal=#log==#row.log
        for j,want in ipairs(row.log) do equal=equal and log[j] and log[j][1]==want[1] and Near(log[j][2],want[2]) end
        V.assert(equal and Near(entry.repair,row.repairAfter) and entry.regen==row.regen,'source mode recovery order and shared timer '..i)
        local expected=.5;for _,call in ipairs(log) do if call[1]=='heal' then expected=expected+call[2] end end
        V.assert(Near(unit:Health(),expected),'actual CarUnit hull restored by source rate '..i)
    end
    unit.Heal=heal;unit.RestoreMissing=restore
    local weapon=unit.spec.weapons[1].partId;unit:Destroy(weapon);unit:Flush()
    V.assert(not unit.bp.parts[weapon] and unit.alive,'actual mounted weapon removed while vehicle survives')
    local objective=setmetatable({id='escort',world=world,battle={rules={cfg=Data.modes.escort,attack='red',s=0}},At=function()return{pos={0,0,0}}end},Objectives)
    unit.hitAt=world.time-5;local entry={unit=unit,repair=.49};objective:UnitTick(entry,.02);unit:Flush()
    V.assert(unit.bp.parts[weapon]~=nil and #unit.weapons.groups>0,'shared mode recovery rebuilds actual mounted weapons')
    for _,mode in ipairs({'conquest','escort','elimination'}) do
        unit:Spawn();local core=unit.bp:CoreParts()[1];unit.struct=0;unit:Damage(core.id,1e9,unit:Position());unit:Flush()
        V.assert(not unit.alive,'actual core destruction before '..mode..' respawn check')
        local at=world.time;local rule={state='live',cfg=Data.modes[mode],attack='blue',sudden=false}
        local objective={PlaceCart=function()end,UnitTick=function()end,Spawn=function()return{pos={100,10,100},yaw=0}end}
        local session={effects={Consume=function()end},weaponAudio={Consume=function()end},camera={GetNode=function()return{worldPosition=Vector3.ZERO}end}}
        local battle=setmetatable({world=world,mode=mode,rules=rule,player=unit,entries={{unit=unit,slot=1,member={player=true},repair=0,env=world.env}},objectives=objective,voice={Say=function()end},session=session},Controller)
        world.time=at+14.9;battle:BeforeStep(1/60,{throttle=0,steer=0},{0,10,150})
        V.assert(not unit.alive,'no early revival at fourteen point nine seconds '..mode)
        world.time=at+15;battle:BeforeStep(1/60,{throttle=0,steer=0},{0,10,150})
        V.assert(unit.alive==(mode~='elimination'),'fifteen second actual native respawn preserves elimination no-respawn '..mode)
    end
    unit:Dispose();world.debris:Clear();world.space:Dispose();scene:Dispose();unit=nil;scene=nil
    V.finish()
end)

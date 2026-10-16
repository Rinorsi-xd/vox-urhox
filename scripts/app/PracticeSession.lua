-- Frozen TrackSim.setPlayer: practice uses the same damageable player as combat,
-- with parked targets, five-second respawns, and no extra mode repair rules.
local RotorMotion=require("drive.RotorMotion")
local PlayerViewSync=require("combat.PlayerViewSync")

local Unit=require 'combat.CarUnit'
local M={};M.__index=M
function M.New(session,bp)
    local self=setmetatable({},M);self:init(session,bp);return self
end
function M:init(session,bp)
    self.session=session;self.world=session.world;self.entries={}
    session.practice=self;session.combat=self
    self.world:SetUnits(bp,true)
    self.player=Unit.New(self.world,bp:ToTable(),{name=bp.name,spawn=self.world.layout.spawn or self.world.layout.teleports[1],
        team='player',externalControl=true,externalView=true,combat=true})
    assert(self.player.alive,'Invalid practice vehicle')
    table.insert(self.world.units,1,self.player)
    for _,unit in ipairs(self.world.units) do self.entries[#self.entries+1]={unit=unit} end
    print('[PracticeSession] Unified player and '..(#self.entries-1)..' parked targets')
end
function M:BeforeStep(dt,command,aim)
    local u=self.player;u:Flush()
    if not u.alive then return end
    u:RegenerateStructure(dt)
    local v=u.vehicle;v:StepRotors(aim,command.rotorStep==true,dt)
    RotorMotion.Weapons(v.rotors,u.weapons)
    v:Step(command,dt)
    local p,velocity=v.body.translation(),v.body.linvel()
    local eye=self.session.camera:GetNode().worldPosition
    local attacker=self.world.attacker;self.world.attacker=u
    u.weapons:Step(dt,{firing=command.firing==true,live=self.session.pointer.captured,aim=aim,
        pos={p.x,p.y,p.z},quat=v.body.rotation(),vel={velocity.x,velocity.y,velocity.z},body=v.body,
        team=u.team,eye={-eye.x,eye.y,eye.z}},self.world.env)
    self.world.attacker=attacker
    self.session.effects:Consume(u.weapons.fx)
    self.session.weaponAudio:Consume(u.weapons.fx)
end
function M:AfterStep() end
function M:SyncPlayer() PlayerViewSync.Update(self) end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    -- TrackWorld owns disposal of every CarUnit, including the player.
    self.entries={};self.player=nil;self.world=nil;self.session=nil
end
return M

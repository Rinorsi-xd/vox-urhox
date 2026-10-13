local Base=require 'drive.CraterWorld'
local M={};M.__index=M;setmetatable(M,{__index=Base})
function M.New(scene,deferred)
    local self=setmetatable({},M)
    self.scene=scene;self.space=require('physics.Space').New(scene)
    self.visualGround=require('core.HeightField').New('Salvage/Height.bin')
    local gp=require('core.ResourceData').Read('Salvage/Gameplay.json')
    local spawns={}
    for _,s in ipairs(gp.spawns) do spawns[#spawns+1]={name=s.name,pos={-s.x,s.y+.6,s.z},yaw=math.atan(-math.cos(s.yaw),math.sin(s.yaw))} end
    self.layout={size=2048,spawn=spawns[1],teleports=spawns,salvage={spawns=spawns,gameplay=gp},nav=gp.nav,
        unitSpots={},targets={},cones={},drag={x0=9000,x1=9001,start=9000,finish=9100}}
    self.root=scene:CreateChild('SalvagePhysics');self.cones={};self.targets={};self.units={};self.time=0
    self.stats={shots=0,hits=0,damage=0,kills=0};self.metrics=require('drive.TrialMetrics').New(self.layout.drag)
    self.fx={};self.viewEvents={};self.debris=require('combat.Debris').New(self.space)
    self.env={stats=self.stats,killHeight=-300,castRay=function(...) return self:CastRay(...) end,hit=function(...) return self:Hit(...) end,
        lockables=function(...) return self:Lockables(...) end,explode=function(...) return self:Explode(...) end}
    if not deferred then require('drive.SalvagePhysics').Build(self) end
    return self
end
return M

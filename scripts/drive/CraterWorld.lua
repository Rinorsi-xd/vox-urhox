-- Shared trial/combat contract, source crater layout. Physics uses the original
-- 2 m heightfield and authored hulls; visual terrain retains the 1 m detail mesh.
local HeightField=require("core.HeightField")
local CraterLayout=require("drive.CraterLayout")
local TrialMetrics=require("drive.TrialMetrics")
local Debris=require("combat.Debris")
local CraterPhysics=require("drive.CraterPhysics")

local Base=require 'drive.TrackWorld'
local Space=require 'physics.Space'
local Coord=require 'core.Coord'
local M={};M.__index=M;setmetatable(M,{__index=Base})
function M.New(scene,deferred)
    local self=setmetatable({},M)
    self.visualGround=HeightField.New('Crater/VisualHeight.bin')
    self.scene=scene;self.space=Space.New(scene);self.layout=CraterLayout.Begin()
    self.root=scene:CreateChild('CraterPhysics');self.cones={};self.targets={};self.units={};self.time=0
    self.stats={shots=0,hits=0,damage=0,kills=0};self.metrics=TrialMetrics.New(self.layout.drag)
    self.fx={};self.viewEvents={};self.debris=Debris.New(self.space)
    self.env={stats=self.stats,killHeight=-80,castRay=function(...) return self:CastRay(...) end,sweepDrill=function(...) return self:SweepDrill(...) end,hit=function(...) self:Hit(...) end,
        lockables=function(...) return self:Lockables(...) end,explode=function(...) return self:Explode(...) end}
    if not deferred then CraterPhysics.Build(self) end
    return self
end
function M:GroundAt(x,z) return self.visualGround:Sample(x,z) end
function M:Dispose(checkpoint)
    if self.disposed then return end
    if self.visualGround then self.visualGround:Dispose();self.visualGround=nil end
    Base.Dispose(self,checkpoint)
    self.layout=nil
end
return M

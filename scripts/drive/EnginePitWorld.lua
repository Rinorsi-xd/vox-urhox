-- Source EnginePit owns its independent heightfield, landmarks and road graph.
local Space=require("physics.Space")
local CraterLayout=require("drive.CraterLayout")
local EnginePitDeck=require("scene.EnginePitDeck")
local TrialMetrics=require("drive.TrialMetrics")
local Debris=require("combat.Debris")
local CraterPhysics=require("drive.CraterPhysics")

local Base=require 'drive.TrackWorld'
local M={};M.__index=M;setmetatable(M,{__index=Base})
function M.New(scene,deferred)
    local self=setmetatable({},M)
    self.assetNamespace='EnginePit';self.scene=scene;self.space=Space.New(scene)
    self.layout=CraterLayout.Begin('EnginePit');self.root=scene:CreateChild('EnginePitPhysics')
    self.deck=EnginePitDeck.Get(scene,self.layout)
    self.cones={};self.targets={};self.units={};self.time=0;self.stats={shots=0,hits=0,damage=0,kills=0}
    self.metrics=TrialMetrics.New(self.layout.drag);self.fx={};self.viewEvents={}
    self.debris=Debris.New(self.space)
    self.env={stats=self.stats,killHeight=-80,castRay=function(...) return self:CastRay(...) end,sweepDrill=function(...) return self:SweepDrill(...) end,
        hit=function(...) self:Hit(...) end,lockables=function(...) return self:Lockables(...) end,explode=function(...) return self:Explode(...) end}
    if not deferred then CraterPhysics.Build(self) end
    return self
end
function M:GroundAt(x,z)
    local t=self.layout.terrain;local n=t.n;local fx,fz=(x/t.size+.5)*n,(z/t.size+.5)*n
    local i,j=math.max(0,math.min(n-1,math.floor(fx))),math.max(0,math.min(n-1,math.floor(fz)))
    local u,v=math.max(0,math.min(1,fx-i)),math.max(0,math.min(1,fz-j));local k=i*(n+1)+j+1;local h=t.heights
    local a,b,c,d=h[k],h[k+n+1],h[k+n+2],h[k+1]
    return v>=u and a+(c-d)*u+(d-a)*v or a+(b-a)*u+(c-b)*v
end
function M:UnderRoof(x,z,margin)
    margin=margin or 0
    for _,roof in ipairs(self.layout.enginePit.ceilings) do
        if roof.polygon then
            local a,b,d=roof.polygon[1],roof.polygon[2],roof.polygon[4]
            local ux,uz,vx,vz=b[1]-a[1],b[2]-a[2],d[1]-a[1],d[2]-a[2]
            local ul,vl=math.sqrt(ux*ux+uz*uz),math.sqrt(vx*vx+vz*vz)
            local u=((x-a[1])*ux+(z-a[2])*uz)/ul;local v=((x-a[1])*vx+(z-a[2])*vz)/vl
            if u>margin and u<ul-margin and v>margin and v<vl-margin then return roof.id end
        elseif roof.a then
            local dx,dz=roof.b[1]-roof.a[1],roof.b[2]-roof.a[2]
            local t=math.max(0,math.min(1,((x-roof.a[1])*dx+(z-roof.a[2])*dz)/(dx*dx+dz*dz)))
            if math.sqrt((x-roof.a[1]-dx*t)^2+(z-roof.a[2]-dz*t)^2)<roof.r-margin then return roof.id end
        end
    end
end
function M:AttachBlockPhysics(native,definition) self.deck:AttachPhysics(native,definition) end
function M:Reset() self.deck:Reset();Base.Reset(self) end
function M:Dispose()
    if self.disposed then return end
    if self.deck then self.deck:Dispose();self.deck=nil end
    Base.Dispose(self);self.layout=nil
end
return M

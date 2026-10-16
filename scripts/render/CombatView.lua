local PartHitFlash=require("render.PartHitFlash")

local DriveView=require "render.DriveView"
local View=require "render.VehicleView"
local Coord=require "core.Coord"
local WeaponView=require 'render.WeaponView'
local CELL=require("Config").CELL
local M={};M.__index=M
local function Vec(p) return Coord.Vec(table.unpack(p)) end
local function Quat(q) return Quaternion(q.w,q.x,-q.y,-q.z) end
function M.New(scene,spawnCache) return setmetatable({scene=scene,spawnCache=spawnCache,units={},pieces={},hitFlash=PartHitFlash.New(scene)},M) end
function M:Consume(world,checkpoint)
    -- Capture matching live visuals before kill/removal events retire their
    -- owning drive view. Part table identity disambiguates IDs across cars.
    local detached,donors={},{}
    for _,e in ipairs(world.debris.events) do if e.type=='spawn' then
        for _,part in ipairs(e.piece.parts) do detached[part]=true end
    end end
    if next(detached) then for _,drive in pairs(self.units) do
        for _,vis in pairs(drive.view.visuals) do if detached[vis.part] then donors[vis.part]=drive.view end end
    end end
    local prepared={};self.lastTransferred=0
    for _,e in ipairs(world.debris.events) do if e.type=='spawn' then
        local vis=View.New(self.scene,'DetachedParts');prepared[e.piece]=vis
        self.pieces[e.piece]={view=vis,center=Vector3.ZERO,scaleK=1}
        for _,part in ipairs(e.piece.parts) do
            local donor=donors[part]
            if donor and donor:TransferStaticPart(part,vis) then self.lastTransferred=self.lastTransferred+1 end
        end
    end end
    for i,e in ipairs(world.viewEvents) do
        local v=self.units[e.unit]
        if not e.unit.externalView and e.type=="unitSpawn" and e.unit.alive and e.unit.vehicle then
            if v then v:Dispose() end
            self.units[e.unit]=DriveView.New(self.scene,e.unit.bp,e.unit.vehicle,
                checkpoint and function(p) checkpoint((i-1+p)/math.max(1,#world.viewEvents)) end,
                function(view) self.units[e.unit]=view end,self.spawnCache and self.spawnCache:Take(e.unit.bp))
        elseif e.type=="partRemoved" then if v then v.view:RemovePart(e.id) end
        elseif e.type=='partRestored' then if v then v.view:AddPart(e.unit.bp.parts[e.id]) end
        -- A later damage event may kill the unit before this batch is read.
        -- Its kill event still retires the old view; never bind the freed body.
        elseif e.type=="unitRebuilt" then if v and e.unit.alive and e.unit.vehicle then v:Bind(e.unit.bp,e.unit.vehicle) end
        elseif e.type=="unitKilled" or e.type=="unitRemoved" then
            if v then v:Dispose();self.units[e.unit]=nil end
        end
        if checkpoint then checkpoint(i/math.max(1,#world.viewEvents)) end
    end
    self.hitFlash:Consume(world,self.units)
    world.viewEvents={}
    for _,e in ipairs(world.debris.events) do
        if e.type=="spawn" then
            local vis=prepared[e.piece];local count=0;local c={0,0,0}
            for _,p in ipairs(e.piece.parts) do
                if not vis.visuals[p.id] then vis:AddPart(p) end
                for _,cell in ipairs(p._cells) do c[1]=c[1]+cell[1];c[2]=c[2]+cell[2]+.5;c[3]=c[3]+cell[3];count=count+1 end
            end
            vis.joined:Update()
            self.pieces[e.piece]={view=vis,center=Coord.Vec(c[1]/count,c[2]/count,c[3]/count),scaleK=1}
        else
            local d=self.pieces[e.piece];if d then d.view:Dispose();self.pieces[e.piece]=nil end
        end
    end
    world.debris.events={}
end
function M:SavePose() for _,view in pairs(self.units) do view:SavePose() end end
function M:Update(alpha,dt,context)
    for unit,view in pairs(self.units) do
        view:Update(unit.weapons and unit.weapons.drill:Latched() and 1 or alpha,dt,context)
        if unit.weapons then WeaponView.Update(view.view,unit.weapons,alpha,dt,context and context.time or 0) end
        view.view:UpdateIdle(dt,context and context.time or 0,true)
        view.view:UpdateWeaponEffects(dt,context)
    end
    self.hitFlash:Update(dt,self.units)
    for piece,d in pairs(self.pieces) do
        local root=d.view.root;local position=Vec(piece.previous.p):Lerp(Vec(piece.current.p),alpha)
        local rotation=Quat(piece.previous.q):Slerp(Quat(piece.current.q),alpha);root.rotation=rotation
        local k=math.min(1,math.max(.01,(5-piece.age)/.6))
        if d.scaleK~=k then root:SetScale(CELL*k);d.scaleK=k end
        if k<1 then position=position+rotation*(d.center*(CELL*(1-k))) end
        root.position=position
    end
end
function M:Dispose(checkpoint)
    self.hitFlash:Dispose()
    for _,v in pairs(self.units) do v:Dispose();if checkpoint then checkpoint() end end
    for _,d in pairs(self.pieces) do d.view:Dispose();if checkpoint then checkpoint() end end
    self.units={};self.pieces={}
end
return M

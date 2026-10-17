-- 把蓝图渲染出来（对应 H5 three/src/build/vehicleView.js）
-- 每个零件一个节点，节点上挂原生 Model（按材质槽多个 Geometry）。所有车共用引擎缓存的模型和
-- Materials 的共享材质，涂装颜色走 StaticModel.instanceColor，引擎自动把同类零件合成一批绘制。
-- root 节点缩放为 CELL：子节点坐标就是格坐标（与 H5 的 root.scale = CELL 相同）。

local JoinedMesh=require("render.JoinedMesh")
local LiveryLayer=require("render.LiveryLayer")
local WingRig=require("render.WingRig")
local WeaponPresentation=require("render.WeaponPresentation")
local ShellMaterials=require("render.ShellMaterials")
local BuildXray=require("render.BuildXray")
local WeaponEffects=require("render.WeaponEffects")

local Config = require "Config"
local Defs = require "parts.Defs"
local Coord = require "core.Coord"
local Assets = require "parts.PartAssets"
local Rig = require "render.PartRig"
local JoinedSurface=require 'render.JoinedSurface'
local RotorDisc=require 'render.RotorDisc'

---@class PartVisual
---@field node Node
---@field head Node|nil 能转动的炮塔（试车时写入它的旋转）
---@field models StaticModel[]
---@field resources string[]
---@field data table
---@field rig table
---@field variation number
---@field instanced boolean

---@class VehicleView
---@field root Node
---@field visuals table<number, PartVisual>
local VehicleView = {}
VehicleView.__index = VehicleView

---@param parent Node
---@param name string|nil
---@return VehicleView
function VehicleView.New(parent, name)
    local v = setmetatable({}, VehicleView)
    v:init(parent, name)
    return v
end

---@param parent Node
---@param name string|nil
function VehicleView:init(parent, name)
    self.root = parent:CreateChild(name or "Vehicle")
    self.root:SetScale(Config.CELL)
    self.visuals = {}
    self.joined=JoinedMesh.New(self.root)
    self.livery=LiveryLayer.New(self)
end

-- 每个零件稳定的小色差（写进实例色的 alpha，shader 里用作随机数）
local function Variation(id)
    local s = math.sin(id * 12.9898 + 4.1) * 43758.5453
    return s - math.floor(s)
end

--- 零件在 root 下的局部位置（格）：锚点格中心，底面在 y = pos.y
---@param part BlueprintPart
---@return Vector3
function VehicleView.PartLocalPos(part)
    return Coord.CellPos(part.pos[1], part.pos[2] + 0.5, part.pos[3])
end

-- Detached static blocks retain their exact model/material handles. Animated
-- rigs and joined surfaces still take the normal construction path.
function VehicleView:TransferStaticPart(part,target)
    local vis=self.visuals[part.id]
    local def=Defs.PARTS[part.type]
    if not vis or vis.part~=part or vis.joined or self.xray or not def.shape or not def.instanced then return false end
    if vis.weaponMotion or vis.data.segments and vis.data.segments~=cjson.null then return false end
    assert(not target.visuals[part.id],'Duplicate detached visual')
    vis.node:SetParent(target.root)
    vis.node.position=VehicleView.PartLocalPos(part);vis.node.rotation=Coord.RotQuat(part.rot)
    vis.node:SetScale(1);vis.node.enabled=true
    self.visuals[part.id]=nil;target.visuals[part.id]=vis
    self.livery:PartsChanged();target.livery:PartsChanged()
    return true
end

---@param part BlueprintPart
---@return PartVisual
function VehicleView:AddPart(part)
    local def = Defs.PARTS[part.type]
    local node = self.root:CreateChild("P" .. part.id)
    node.position = VehicleView.PartLocalPos(part)
    node.rotation = Coord.RotQuat(part.rot)
    local vis = {node=node,models={},resources={},rig={},shellSlots={},materialSlots={},data={},
        variation=Variation(part.id),instanced=def.instanced==true,part=part}
    -- Retain partial rig ownership before native model/material construction.
    self.visuals[part.id] = vis
    vis.joined=JoinedSurface.IsJoined(part)==true
    if vis.joined then
        vis.rig={};vis.shellSlots={};vis.materialSlots={};vis.data={};self.joined:Add(part)
    else Rig.Build(node,Assets.Get(part.type,part.rot),part,vis) end
    self.livery:PartsChanged()
    self:Repaint(part)
    if self.xray then self.xray:Attach(vis) end
    return vis
end

---@param id integer
function VehicleView:RemovePart(id)
    local vis = self.visuals[id]
    if not vis then return end
    self.joined:Remove(id)
    if vis.rig.wing then WingRig.Dispose(vis) end
    vis.node:Dispose()
    vis.xrayOriginals=nil;vis.materialSlots={}
    if vis.weaponMotion then WeaponPresentation.Dispose(vis) end
    ShellMaterials.Release(vis)
    vis.shellSlots={}
    vis.models={}
    Assets.Release(vis.resources)
    self.visuals[id] = nil
    self.livery:PartsChanged()
    if self.weaponEffects then
        self.weaponEffects.items[id]=nil
        local any=false
        for _,remaining in pairs(self.visuals) do if remaining.weaponMotion then any=true;break end end
        if not any then self.weaponEffects:Dispose();self.weaponEffects=nil end
    end
end

---@param part BlueprintPart
function VehicleView:Repaint(part)
    local vis = self.visuals[part.id]
    if not vis then return end
    vis.part=part
    if vis.joined then self.joined:Repaint(part);return end
    RotorDisc.Bind(vis,part)
    local color = Config.HexLinear(part.color, Variation(part.id))
    for _, sm in ipairs(vis.models) do sm.instanceColor = color end
    if #vis.shellSlots>0 then
        local shell=part.shellColor
        if shell==cjson.null then shell=nil end
        ShellMaterials.Apply(vis,shell)
    end
end

-- Deltas keep unaffected joints, materials and model handles alive. A move has
-- remove/add with the same ID; update its transform without recreating the rig.
function VehicleView:ApplyEdits(ops,bp)
    self.livery:PartsChanged()
    local touched={}
    for _,op in ipairs(ops) do
        if op.ids then for _,id in ipairs(op.ids) do touched[id]=true end
        else touched[op.id or op.data.id]=true end
    end
    for id in pairs(touched) do
        local part,vis=bp.parts[id],self.visuals[id]
        if not part then self:RemovePart(id)
        elseif not vis then self:AddPart(part)
        elseif vis.part.type~=part.type or vis.joined~=(JoinedSurface.IsJoined(part)==true) then
            self:RemovePart(id);self:AddPart(part)
        else
            vis.node.position=self.PartLocalPos(part);vis.node.rotation=Coord.RotQuat(part.rot)
            self:Repaint(part)
        end
    end
end

function VehicleView:Clear()
    if self.rotorJoined then for _,mesh in pairs(self.rotorJoined) do mesh:Dispose() end end
    self.rotorJoined={};self.rotorOwners=nil
    self.livery:Clear()
    if self.weaponEffects then self.weaponEffects:Reset() end
    local ids={}
    for id in pairs(self.visuals) do ids[#ids+1]=id end
    for _,id in ipairs(ids) do self:RemovePart(id) end
    self.visuals = {}
    self.joined:Clear()
end

function VehicleView:Dispose()
    if self.weaponEffects then self.weaponEffects:Dispose();self.weaponEffects=nil end
    self:Clear()
    self.livery:Dispose()
    self.joined:Dispose()
    if self.xray then self.xray:Dispose();self.xray=nil end
    self.root:Dispose()
end

function VehicleView:SetXray(on)
    self.joined:SetXray(on)
    for _,mesh in pairs(self.rotorJoined or {}) do mesh:SetXray(on) end
    if on and not self.xray then
        self.xray=BuildXray.New()
        for _,vis in pairs(self.visuals) do self.xray:Attach(vis) end
    elseif not on and self.xray then
        for _,vis in pairs(self.visuals) do BuildXray.Restore(vis) end
        self.xray:Dispose();self.xray=nil
    end
end

---@param bp Blueprint
function VehicleView:Rebuild(bp,checkpoint,deferSurfaces)
    self:Clear()
    local parts=bp:List()
    for i, part in ipairs(parts) do
        self:AddPart(part)
        if checkpoint then checkpoint(.9*i/math.max(1,#parts)) end
    end
    -- DriveView binds rotor ownership before committing these same surfaces.
    if deferSurfaces then self.livery:Set(bp.livery)
    else self.joined:Update();self.livery:Set(bp.livery);self.livery:Update() end
    if checkpoint then checkpoint(1) end
end

-- Damage/repair replaces the physics vehicle, not every surviving visual.
-- Reconcile against the final blueprint once, even when several events share
-- a fixed step. Spawn/editor rebuilds retain the full Rebuild path.
function VehicleView:SyncBlueprint(bp)
    local removed={}
    for id,vis in pairs(self.visuals) do
        if bp.parts[id]~=vis.part then removed[#removed+1]=id end
    end
    for _,id in ipairs(removed) do self:RemovePart(id) end
    for _,part in ipairs(bp:List()) do
        if not self.visuals[part.id] then self:AddPart(part) end
    end
    -- DriveView:Bind partitions joined surfaces and uploads decals afterwards.
    self.livery:Set(bp.livery)
end

---@param visible boolean
function VehicleView:SetVisible(visible)
    self.root:SetEnabledRecursive(visible)
    if not visible and self.weaponEffects then self.weaponEffects:Reset() end
end

function VehicleView:UpdateIdle(dt,time,skipWings,skipWeapons)
    self.joined:Update()
    for _,mesh in pairs(self.rotorJoined or {}) do mesh:Update() end
    self.livery:Update()
    for _,vis in pairs(self.visuals) do
        if vis.weaponMotion and not skipWeapons then WeaponPresentation.Update(vis,dt,time) end
        if vis.rig.wing and not skipWings then WingRig.Update(vis,nil,time,dt) end
    end
end

function VehicleView:GetWorldBounds()
    self.joined:Update()
    local box=BoundingBox()
    for _,vis in pairs(self.visuals) do
        for _,model in ipairs(vis.models) do box:Merge(model.worldBoundingBox) end
    end
    for _,mesh in pairs(self.joined.meshes) do box:Merge(mesh.geometry.worldBoundingBox) end
    for _,joined in pairs(self.rotorJoined or {}) do for _,mesh in pairs(joined.meshes) do box:Merge(mesh.geometry.worldBoundingBox) end end
    return box
end

function VehicleView:UpdateWeaponEffects(dt,context,emitter)
    if not self.weaponEffects then
        for _,vis in pairs(self.visuals) do if vis.weaponMotion then
            self.weaponEffects=WeaponEffects.New(self);break
        end end
    end
    if self.weaponEffects then self.weaponEffects:Update(dt,context,emitter) end
end

function VehicleView:ResetWeaponPresentation()
    for _,vis in pairs(self.visuals) do if vis.weaponMotion then WeaponPresentation.Reset(vis) end end
    if self.weaponEffects then self.weaponEffects:Reset() end
end

return VehicleView

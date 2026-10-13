-- 把蓝图渲染出来（对应 H5 three/src/build/vehicleView.js）
-- 每个零件一个节点，节点上挂原生 Model（按材质槽多个 Geometry）。所有车共用引擎缓存的模型和
-- Materials 的共享材质，涂装颜色走 StaticModel.instanceColor，引擎自动把同类零件合成一批绘制。
-- root 节点缩放为 CELL：子节点坐标就是格坐标（与 H5 的 root.scale = CELL 相同）。

local Config = require "Config"
local Defs = require "parts.Defs"
local Coord = require "core.Coord"
local Assets = require "parts.PartAssets"
local Rig = require "render.PartRig"

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
    self.livery=require('render.LiveryLayer').New(self)
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

---@param part BlueprintPart
---@return PartVisual
function VehicleView:AddPart(part)
    local def = Defs.PARTS[part.type]
    local mesh = Assets.Get(part.type,part.rot)
    local node = self.root:CreateChild("P" .. part.id)
    node.position = VehicleView.PartLocalPos(part)
    node.rotation = Coord.RotQuat(part.rot)
    local vis = {node=node,models={},resources={},variation=Variation(part.id),instanced=def.instanced==true}
    Rig.Build(node,mesh,part,vis)
    self.visuals[part.id] = vis
    vis.part=part
    self.livery:PartsChanged()
    self:Repaint(part)
    if self.xray then self.xray:Attach(vis) end
    return vis
end

---@param id integer
function VehicleView:RemovePart(id)
    local vis = self.visuals[id]
    if not vis then return end
    vis.node:Dispose()
    vis.xrayOriginals=nil;vis.materialSlots={}
    if vis.weaponMotion then require('render.WeaponPresentation').Dispose(vis) end
    if vis.shellMaterial then vis.shellMaterial:Dispose();vis.shellMaterial=nil end
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
    local color = Config.HexLinear(part.color, Variation(part.id))
    for _, sm in ipairs(vis.models) do sm.instanceColor = color end
    if #vis.shellSlots>0 then
        local shell=part.shellColor
        if shell==cjson.null then shell=nil end
        if shell and not vis.shellMaterial then
            vis.shellMaterial=require('parts.Materials').Get('armorWhite'):Clone()
            for _,slot in ipairs(vis.shellSlots) do require('render.BuildXray').SetBase(vis,slot.model,slot.index,vis.shellMaterial) end
        end
        if vis.shellMaterial then vis.shellMaterial:SetShaderParameter('base_color',Variant(Config.HexLinear(shell or 0xcbd1d7))) end
    end
end

-- Deltas keep unaffected joints, materials and model handles alive. A move has
-- remove/add with the same ID; update its transform without recreating the rig.
function VehicleView:ApplyEdits(ops,bp)
    self.livery:PartsChanged()
    local touched={}
    for _,op in ipairs(ops) do touched[op.id or op.data.id]=true end
    for id in pairs(touched) do
        local part,vis=bp.parts[id],self.visuals[id]
        if not part then self:RemovePart(id)
        elseif not vis then self:AddPart(part)
        else
            vis.node.position=self.PartLocalPos(part);vis.node.rotation=Coord.RotQuat(part.rot)
            self:Repaint(part)
        end
    end
end

function VehicleView:Clear()
    self.livery:Clear()
    if self.weaponEffects then self.weaponEffects:Reset() end
    local ids={}
    for id in pairs(self.visuals) do ids[#ids+1]=id end
    for _,id in ipairs(ids) do self:RemovePart(id) end
    self.visuals = {}
end

function VehicleView:Dispose()
    if self.weaponEffects then self.weaponEffects:Dispose();self.weaponEffects=nil end
    self:Clear()
    self.livery:Dispose()
    if self.xray then self.xray:Dispose();self.xray=nil end
    self.root:Dispose()
end

function VehicleView:SetXray(on)
    if on and not self.xray then
        self.xray=require('render.BuildXray').New()
        for _,vis in pairs(self.visuals) do self.xray:Attach(vis) end
    elseif not on and self.xray then
        for _,vis in pairs(self.visuals) do require('render.BuildXray').Restore(vis) end
        self.xray:Dispose();self.xray=nil
    end
end

---@param bp Blueprint
function VehicleView:Rebuild(bp)
    self:Clear()
    for _, part in ipairs(bp:List()) do self:AddPart(part) end
    self.livery:Set(bp.livery);self.livery:Update()
end

---@param visible boolean
function VehicleView:SetVisible(visible)
    self.root:SetEnabledRecursive(visible)
    if not visible and self.weaponEffects then self.weaponEffects:Reset() end
end

function VehicleView:UpdateIdle(dt,time)
    self.livery:Update()
    for _,vis in pairs(self.visuals) do if vis.weaponMotion then require('render.WeaponPresentation').Update(vis,dt,time) end end
end

function VehicleView:UpdateWeaponEffects(dt,context,emitter)
    if not self.weaponEffects then
        for _,vis in pairs(self.visuals) do if vis.weaponMotion then
            self.weaponEffects=require('render.WeaponEffects').New(self);break
        end end
    end
    if self.weaponEffects then self.weaponEffects:Update(dt,context,emitter) end
end

function VehicleView:ResetWeaponPresentation()
    for _,vis in pairs(self.visuals) do if vis.weaponMotion then require('render.WeaponPresentation').Reset(vis) end end
    if self.weaponEffects then self.weaponEffects:Reset() end
end

return VehicleView

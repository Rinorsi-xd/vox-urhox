-- 蓝图：零件集合 + 占用表 + 连通性 / 属性 / 警告计算（对应 H5 shared/build/blueprint.js）
-- 坐标为蓝图逻辑空间的整数格；序列化格式与 H5 相同：{ v = 1, name, parts = { {type, x, y, z, rot, color}, ... } }

local Config = require "Config"
local Defs = require "parts.Defs"
local Rot = require "core.Rotations"
local Solid = require "parts.Solid"
local Mounts = require "parts.Mounts"
local Clearance = require "construction.BuildClearance"

local PARTS = Defs.PARTS

---@param x number|nil
---@param y number|nil
---@param z number|nil
---@return string
local function Key(x, y, z)
    return x .. "," .. y .. "," .. z
end

---@param type string
---@param pos integer[]
---@param rot integer
---@return integer[][]
local function PartCells(type, pos, rot)
    local def = PARTS[type]
    local out = {}
    local mount=Mounts.HoverInfo(type,rot)
    for i, c in ipairs(mount and mount.cells or def.cells) do
        local r = Rot.ApplyRot(rot, c)
        out[i] = { pos[1] + r[1], pos[2] + r[2], pos[3] + r[3] }
    end
    return out
end

---@class WorldSocket
---@field cell integer[]
---@field dir integer[]

--- 世界坐标下的连接口列表；'all' 表示所有格的所有面
---@return WorldSocket[]|string
local function PartSockets(type, pos, rot)
    local def = PARTS[type]
    if def.sockets == "all" then return "all" end
    local out = {}
    local mount=Mounts.HoverInfo(type,rot)
    for i, s in ipairs(mount and mount.sockets or def.sockets) do
        local c = Rot.ApplyRot(rot, s.c)
        out[i] = { cell = { pos[1] + c[1], pos[2] + c[2], pos[3] + c[3] }, dir = Rot.ApplyRot(rot, s.d) }
    end
    return out
end

---@return WorldSocket[]
local function SocketList(cells, sockets)
    if sockets ~= "all" then return sockets end
    local out = {}
    for _, c in ipairs(cells) do
        for _, d in ipairs(Rot.DIRS) do out[#out + 1] = { cell = c, dir = d } end
    end
    return out
end

---@class BlueprintPart
---@field id integer
---@field type string
---@field pos integer[]
---@field rot integer
---@field color integer
---@field _cells integer[][]
---@field _sockets WorldSocket[]|string
---@field _socketSet table<string, boolean>|nil

---@class Blueprint
---@field parts table<integer, BlueprintPart>
---@field occ table<string, integer>
---@field nextId integer
---@field name string
local Blueprint = {}
Blueprint.__index = Blueprint

Blueprint.Key = Key
Blueprint.PartCells = PartCells
Blueprint.PartSockets = PartSockets

---@return Blueprint
function Blueprint.New()
    local bp = setmetatable({}, Blueprint)
    bp:init()
    return bp
end

function Blueprint:init()
    self.parts = {}
    self.occ = {}
    self.cellIds = {}
    self.legIds = {}
    self.clearIds = {}
    self.nextId = 1
    self.name = "未命名战车"
end

function Blueprint:Clear()
    self.parts = {}
    self.occ = {}
    self.cellIds = {}
    self.legIds = {}
    self.clearIds = {}
    self.nextId = 1
end

---@return integer
function Blueprint:Size()
    local n = 0
    for _ in pairs(self.parts) do n = n + 1 end
    return n
end

--- 按 id 排好序的零件列表（遍历顺序稳定，便于渲染与存档）
---@return BlueprintPart[]
function Blueprint:List()
    local out = {}
    for _, p in pairs(self.parts) do out[#out + 1] = p end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

---@return BlueprintPart|nil
function Blueprint:PartAt(x, y, z)
    local id = self.occ[Key(x, y, z)]
    if id == nil then return nil end
    return self.parts[id]
end

-- Shared-cell damage queries use the same 4 x 4 x 4 solid masks as placement.
function Blueprint:PartAtSub(cell,sub)
    local key=Key(table.unpack(cell));local bit=sub[1]+sub[2]*4+sub[3]*16
    for _,id in ipairs(self.cellIds[key] or {}) do
        local p=self.parts[id];local mask=p._masks[key]
        if mask==nil or ((mask >> bit)&1)~=0 then return p end
    end
end

---@return BlueprintPart[]
function Blueprint:CoreParts()
    local list = {}
    for _, p in ipairs(self:List()) do
        if p.type == "core" then list[#list + 1] = p end
    end
    return list
end

-- ── 放置校验 ──────────────────────────────────

-- Standing-leg occupancy (source authored cells, not the enclosing AABB):
-- [body][mount]   empty space under hip remains buildable
--           \\ [upper] -> [lower] -> [toe]
-- Either placement order must reject a block inside an actual limb cell.
-- Moving a selection ignores all its old IDs, including their standing cells.
function Blueprint:Overlaps(type,pos,rot,cells,ignore)
    cells=cells or PartCells(type,pos,rot)
    local stance=Mounts.LegStance(type,pos,rot)
    if stance or next(self.legIds) then
        local own={};for _,c in ipairs(stance or cells) do own[Key(table.unpack(c))]=true end
        local candidates=stance and self.parts or self.legIds
        for id in pairs(candidates) do if not (ignore and ignore[id]) then
            local p=self.parts[id]
            for _,c in ipairs(p._stanceCells or p._cells) do if own[Key(table.unpack(c))] then return true end end
        end end
    end
    local masks=Solid.Map(type,pos,rot)
    for _,c in ipairs(cells) do
        local key=Key(table.unpack(c))
        for _,id in ipairs(self.cellIds[key] or {}) do
            if not (ignore and ignore[id]) and Solid.Overlap(masks[key],self.parts[id]._masks[key]) then return true end
        end
    end
    return false
end

---@param ignore table<integer, boolean>|nil
---@return { ok: boolean, reason: string, cells: integer[][] }
function Blueprint:Check(type, pos, rot, bounds, ignore, requireConnect)
    if requireConnect == nil then requireConnect = true end
    local def = PARTS[type]
    local cells = PartCells(type, pos, rot)
    if def.leg and Rot.ROTATIONS[rot].up[2]<0.99 then return {ok=false,reason="节足要装在车身侧面",cells=cells} end
    for _, c in ipairs(cells) do
        if bounds and not Config.InBounds(bounds, c[1], c[2], c[3]) then
            return { ok = false, reason = "超出建造区域", cells = cells }
        end
    end
    if self:Overlaps(type,pos,rot,cells,ignore) then return {ok=false,reason='与已有零件重叠',cells=cells} end
    local conflict=Clearance.Conflict(self,type,pos,rot,cells,ignore)
    if conflict then return {ok=false,reason=conflict.reason,cells=cells,blockers=conflict.ids} end
    if def.unique then
        for _, p in pairs(self.parts) do
            if p.type == type and not (ignore and ignore[p.id]) then
                return { ok = false, reason = "只能有一个" .. def.name, cells = cells }
            end
        end
    end
    if not requireConnect then return { ok = true, reason = "", cells = cells } end
    local sockets = SocketList(cells, PartSockets(type, pos, rot))
    local firstCore=type=="core" and self:Size()==0
    if not firstCore and not self:_Touches(cells, sockets, ignore) then
        return { ok = false, reason = "请贴在已有零件的连接面上，地面不能安装零件", cells = cells }
    end
    return { ok = true, reason = "", cells = cells }
end

function Blueprint:_Touches(cells, sockets, ignore)
    local own = {}
    for _, c in ipairs(cells) do own[Key(c[1], c[2], c[3])] = true end
    for _, s in ipairs(sockets) do
        local k = Key(s.cell[1] + s.dir[1], s.cell[2] + s.dir[2], s.cell[3] + s.dir[3])
        if not own[k] then
            for _,id in ipairs(self.cellIds[k] or {}) do
              if not (ignore and ignore[id]) then
                local q = self.parts[id]
                if self:_HasSocket(q, k, Rot.DirIndex({ -s.dir[1], -s.dir[2], -s.dir[3] })) then return true end
              end
            end
        end
    end
    return false
end

---@param part BlueprintPart
function Blueprint:_HasSocket(part, cellKey, di)
    if part._sockets == "all" then return true end
    return part._socketSet ~= nil and part._socketSet[cellKey .. "|" .. di] == true
end

-- ── 增删改 ────────────────────────────────────

---@param spec { type: string, pos: integer[], rot: integer|nil, color: integer|nil, id: integer|nil }
---@return BlueprintPart
function Blueprint:Add(spec)
    local def = PARTS[spec.type]
    ---@type BlueprintPart
    local part = {
        id = spec.id or self.nextId,
        type = spec.type,
        pos = { spec.pos[1], spec.pos[2], spec.pos[3] },
        rot = spec.rot or Rot.IDENTITY,
        color = spec.color~=cjson.null and spec.color or def.color,
        shellColor = spec.shellColor~=cjson.null and spec.shellColor or nil,
    }
    if spec.id == nil then self.nextId = self.nextId + 1 end
    if part.id >= self.nextId then self.nextId = part.id + 1 end
    self:_Index(part)
    self.parts[part.id] = part
    return part
end

---@param part BlueprintPart
function Blueprint:_Index(part)
    part._clear=Clearance.Cells(part.type,part.pos,part.rot)
    for _,c in ipairs(part._clear or {}) do
        local key=Key(table.unpack(c));local ids=self.clearIds[key] or {}
        ids[#ids+1]=part.id;self.clearIds[key]=ids
    end
    part._stanceCells=Mounts.LegStance(part.type,part.pos,part.rot)
    if part._stanceCells then self.legIds[part.id]=true end
    part._masks=Solid.Map(part.type,part.pos,part.rot)
    part._cells = PartCells(part.type, part.pos, part.rot)
    part._sockets = PartSockets(part.type, part.pos, part.rot)
    if part._sockets ~= "all" then
        local set = {}
        for _, s in ipairs(part._sockets --[[@as WorldSocket[] ]]) do
            set[Key(s.cell[1], s.cell[2], s.cell[3]) .. "|" .. Rot.DirIndex(s.dir)] = true
        end
        part._socketSet = set
    end
    for _,c in ipairs(part._cells) do
        local key=Key(c[1],c[2],c[3]);local ids=self.cellIds[key] or {}
        ids[#ids+1]=part.id;self.cellIds[key]=ids;self.occ[key]=ids[1]
    end
end

---@return BlueprintPart|nil
function Blueprint:Remove(id)
    local part = self.parts[id]
    if not part then return nil end
    for _,c in ipairs(part._cells) do
        local key=Key(c[1],c[2],c[3]);local ids=self.cellIds[key]
        for i=#ids,1,-1 do if ids[i]==id then table.remove(ids,i) end end
        self.occ[key]=ids[1];if #ids==0 then self.cellIds[key]=nil end
    end
    self.parts[id] = nil
    self.legIds[id] = nil
    for _,c in ipairs(part._clear or {}) do
        local key=Key(table.unpack(c));local ids=self.clearIds[key]
        for i=#ids,1,-1 do if ids[i]==id then table.remove(ids,i) end end
        if #ids==0 then self.clearIds[key]=nil end
    end
    return part
end

function Blueprint:SetColor(id, color,channel)
    local p = self.parts[id]
    if p then p[channel=='shellColor' and 'shellColor' or 'color']=color end
    return p
end

-- ── 连通性 ────────────────────────────────────

---@param part BlueprintPart
---@return table<integer, boolean>
function Blueprint:Neighbors(part)
    local out = {}
    for _, s in ipairs(SocketList(part._cells, part._sockets)) do
        local k = Key(s.cell[1] + s.dir[1], s.cell[2] + s.dir[2], s.cell[3] + s.dir[3])
        for _,id in ipairs(self.cellIds[k] or {}) do
          if id ~= part.id then
            local q = self.parts[id]
            if self:_HasSocket(q, k, Rot.DirIndex({ -s.dir[1], -s.dir[2], -s.dir[3] })) then out[id] = true end
          end
        end
    end
    return out
end

---@return table<integer, table<integer, boolean>>
function Blueprint:Graph()
    local adj = {}
    for id, p in pairs(self.parts) do adj[id] = self:Neighbors(p) end
    return adj
end

---@return { reached: table<integer, boolean>, floating: table<integer, boolean>, floatingCount: integer, coreId: integer|nil }
function Blueprint:Connectivity(adj)
    adj = adj or self:Graph()
    local cores = self:CoreParts()
    local reached = {}
    if #cores > 0 then
        local stack = { cores[1].id }
        reached[cores[1].id] = true
        while #stack > 0 do
            local id = table.remove(stack)
            for n in pairs(adj[id]) do
                if not reached[n] then
                    reached[n] = true
                    stack[#stack + 1] = n
                end
            end
        end
    end
    local floating, count = {}, 0
    for id in pairs(self.parts) do
        if not reached[id] then
            floating[id] = true
            count = count + 1
        end
    end
    return { reached = reached, floating = floating, floatingCount = count, coreId = cores[1] and cores[1].id or nil }
end

--- 找出“单点连接挂着一大块结构”的桥
function Blueprint:WeakLinks(adj, coreId, minSize)
    minSize = minSize or 8
    if coreId == nil then return {} end
    local disc, low, size = {}, {}, {}
    local out = {}
    local time = 0
    local function Dfs(u, parent)
        disc[u], low[u] = time, time
        time = time + 1
        size[u] = 1
        for v in pairs(adj[u]) do
            if v ~= parent then
                if disc[v] ~= nil then
                    low[u] = math.min(low[u], disc[v])
                else
                    Dfs(v, u)
                    size[u] = size[u] + size[v]
                    low[u] = math.min(low[u], low[v])
                    if low[v] > disc[u] and size[v] >= minSize then out[#out + 1] = { a = u, b = v, count = size[v] } end
                end
            end
        end
    end
    Dfs(coreId, nil)
    local outer={}
    for _,w in ipairs(out) do
        local nested=false
        for _,o in ipairs(out) do
            if w~=o and disc[w.b]>=disc[o.b] and disc[w.b]<disc[o.b]+size[o.b] then nested=true;break end
        end
        if not nested then outer[#outer+1]=w end
    end
    return outer
end

-- ── 属性统计（策划案 v0.2 第 05 节）─────────────

---@class BlueprintStats
---@field budget integer
---@field mass number
---@field load number
---@field L number
---@field topSpeed number
---@field weapons integer
---@field thrusters integer
---@field count integer
---@field dims { L: integer, W: integer, H: integer }
---@field bb { minX: number, maxX: number, minY: number, maxY: number, minZ: number, maxZ: number }
---@field fitTier table|nil
---@field comY number
---@field trackWidth number
---@field loadL number
---@field loadR number

---@return BlueprintStats
function Blueprint:Stats()
    return require("construction.BlueprintStats").Compute(self)
end

-- ── 校验与警告（策划案 4.4）────────────────────

---@class DiagnoseItem
---@field level string error | block | warn
---@field text string
---@field ids integer[]

---@return { list: DiagnoseItem[], stats: BlueprintStats, conn: table, outside: table<integer, boolean> }
function Blueprint:Diagnose(tier)
    return require("construction.BlueprintDiagnostics").Compute(self,tier)
end

-- ── 序列化 ────────────────────────────────────

function Blueprint:ToTable()
    local parts = {}
    for _, p in ipairs(self:List()) do
        parts[#parts + 1] = { p.type, p.pos[1], p.pos[2], p.pos[3], p.rot, p.color, p.shellColor }
    end
    return { v = 1, sizeVersion=1, name = self.name, parts = parts }
end

---@return Blueprint
function Blueprint:Load(data)
    return require("construction.BlueprintMigration").Load(self,data)
end

return Blueprint

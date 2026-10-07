-- 蓝图逻辑空间 ↔ 引擎空间
--
-- 蓝图、零件建模、朝向表都沿用 H5 的右手系（three.js 约定：+X、+Y 上、车头朝 +Z），
-- 这样 H5 的蓝图码、零件尺寸、数值可以原样搬过来。UrhoX 是左手系（+X 右、+Y 上、+Z 前）。
-- 两者只差一个 X 镜像：引擎坐标 = (-x, y, z)。车头仍朝 +Z、上方仍是 +Y，
-- 坐在车里看，H5 的“右侧”(-X) 在这里变成 +X，左右语义也保持一致。
--
-- 网格由 tools/migration/export-parts.cjs 离线翻 X，同时交换三角形后两个顶点
-- （实测 UrhoX 下只翻 X 会整体背面朝外）。

local Rot = require "core.Rotations"

local Coord = {}

--- 逻辑格坐标 → 引擎局部坐标（单位：格）
---@return Vector3
function Coord.CellPos(x, y, z)
    return Vector3(-x, y, z)
end

--- 逻辑空间的向量 → 引擎空间
---@return Vector3
function Coord.Vec(x, y, z)
    return Vector3(-x, y, z)
end

---@type table<integer, Quaternion>
local quatCache = {}

---@param a number[]
---@param sx number
---@return Vector3
local function Axis(a, sx)
    local x, y, z = a[1] or 0, a[2] or 0, a[3] or 0
    return Vector3(x * sx, y * -sx, z * -sx)
end

--- 朝向序号 → 引擎四元数。R_engine = F·R·F（F = diag(-1,1,1)），仍是纯旋转。
--- 它的三列分别是 -F(right)、F(up)、F(fwd)。
---@param ri integer
---@return Quaternion
function Coord.RotQuat(ri)
    local cached = quatCache[ri]
    if cached ~= nil then return cached end
    local e = Rot.ROTATIONS[ri]
    -- -F(v) = (v.x, -v.y, -v.z)；F(v) = (-v.x, v.y, v.z)
    local q = Quaternion(Axis(e.right, 1), Axis(e.up, -1), Axis(e.fwd, -1))
    quatCache[ri] = q
    return q
end

return Coord

-- 24 种 90° 朝向（对应 H5 shared/core/rotations.js，序号完全一致，蓝图码可以互通）
-- 每个朝向由 (up, fwd) 两个整数方向唯一确定：零件本地 +Y → up，本地 +Z → fwd，本地 +X = up × fwd。
-- 这里的向量都在“蓝图逻辑空间”（与 H5 相同的右手系）；换算到引擎坐标见 core/Coord.lua。
-- 朝向序号从 0 开始（与 H5 一致），所以 ROTATIONS 用 0..23 做键。

local R = {}

R.DIRS = {
    { 1, 0, 0 }, { -1, 0, 0 },
    { 0, 1, 0 }, { 0, -1, 0 },
    { 0, 0, 1 }, { 0, 0, -1 },
}

local function Cross(a, b)
    return {
        a[2] * b[3] - a[3] * b[2],
        a[3] * b[1] - a[1] * b[3],
        a[1] * b[2] - a[2] * b[1],
    }
end

local function Dot(a, b)
    return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function Key(up, fwd)
    return up[1] .. "," .. up[2] .. "," .. up[3] .. "|" .. fwd[1] .. "," .. fwd[2] .. "," .. fwd[3]
end

R.Cross = Cross
R.Dot = Dot

---@param a number[]
---@param b number[]
---@return boolean
function R.Eq(a, b)
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

---@param a number[]
---@return number[]
function R.Neg(a)
    return { -a[1], -a[2], -a[3] }
end

--- 方向在 DIRS 里的序号（0..5），找不到返回 -1
---@param d number[]
---@return integer
function R.DirIndex(d)
    for i = 1, 6 do
        local e = R.DIRS[i]
        if e[1] == d[1] and e[2] == d[2] and e[3] == d[3] then return i - 1 end
    end
    return -1
end

---@class RotationEntry
---@field index integer
---@field up number[]
---@field fwd number[]
---@field right number[]
---@field m number[] 行优先 3×3：列分别是 right / up / fwd

---@type table<integer, RotationEntry>
R.ROTATIONS = {}
R.COUNT = 0
local lookup = {}

for _, up in ipairs(R.DIRS) do
    for _, fwd in ipairs(R.DIRS) do
        if Dot(up, fwd) == 0 then
            local right = Cross(up, fwd)
            local m = {
                right[1], up[1], fwd[1],
                right[2], up[2], fwd[2],
                right[3], up[3], fwd[3],
            }
            local index = R.COUNT
            R.ROTATIONS[index] = { index = index, up = up, fwd = fwd, right = right, m = m }
            lookup[Key(up, fwd)] = index
            R.COUNT = R.COUNT + 1
        end
    end
end

---@param up number[]
---@param fwd number[]
---@return integer
function R.RotIndex(up, fwd)
    local i = lookup[Key(up, fwd)]
    if i == nil then return -1 end
    return i
end

R.IDENTITY = R.RotIndex({ 0, 1, 0 }, { 0, 0, 1 })

---@param ri integer
---@param v number[]
---@return number[]
function R.ApplyRot(ri, v)
    local m = R.ROTATIONS[ri].m
    return {
        m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
        m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
        m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
    }
end

local function Mul3(a, b)
    local r = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
    for i = 0, 2 do
        for j = 0, 2 do
            local s = 0
            for k = 0, 2 do s = s + a[i * 3 + k + 1] * b[k * 3 + j + 1] end
            r[i * 3 + j + 1] = s
        end
    end
    return r
end

local function FromMatrix(m)
    return R.RotIndex({ m[2], m[5], m[8] }, { m[3], m[6], m[9] })
end

--- 绕自身 up 轴旋转 90°（steps 为正时逆时针）
---@param ri integer
---@param steps integer|nil
---@return integer
function R.SpinAroundUp(ri, steps)
    local e = R.ROTATIONS[ri]
    local up, fwd = e.up, e.fwd
    local n = ((steps or 1) % 4 + 4) % 4
    for _ = 1, n do fwd = Cross(up, fwd) end
    return R.RotIndex(up, fwd)
end

local RY = { 0, 0, 1, 0, 1, 0, -1, 0, 0 } -- 把 +Z 转到 +X

--- 整体绕世界 Y 轴旋转 90°·steps（用于粘贴时旋转一组零件）
---@param ri integer
---@param steps integer|nil
---@return integer
function R.RotateWorldY(ri, steps)
    local m = R.ROTATIONS[ri].m
    local n = ((steps or 1) % 4 + 4) % 4
    for _ = 1, n do m = Mul3(RY, m) end
    return FromMatrix(m)
end

---@param v number[]
---@param steps integer|nil
---@return number[]
function R.RotateVecY(v, steps)
    local r = { v[1], v[2], v[3] }
    local n = ((steps or 1) % 4 + 4) % 4
    for _ = 1, n do r = { r[3], r[2], -r[1] } end
    return r
end

-- Integer quarter turns around an axis-aligned world normal (editor tilt/sample).
function R.RotateAroundAxis(ri,axis,steps)
    local e=R.ROTATIONS[ri];local up,fwd=e.up,e.fwd
    local function Turn(v)
        local c=Cross(axis,v);local d=Dot(axis,v)
        return {c[1]+axis[1]*d,c[2]+axis[2]*d,c[3]+axis[3]*d}
    end
    for _=1,(steps or 1)%4 do up=Turn(up);fwd=Turn(fwd) end
    return R.RotIndex(up,fwd)
end

-- 关于 x=0 平面的镜像：R' = M·R·M·Fix，M = diag(-1,1,1)。
-- fix 是零件本身的“左右翻转修正”朝向（对左右对称的零件为单位朝向）。
local M = { -1, 0, 0, 0, 1, 0, 0, 0, 1 }

---@param ri integer
---@param fix integer|nil
---@return integer
function R.MirrorRot(ri, fix)
    local r = R.ROTATIONS[ri].m
    local mrm = Mul3(Mul3(M, r), M)
    return FromMatrix(Mul3(mrm, R.ROTATIONS[fix or R.IDENTITY].m))
end

--- 把任意方向向量吸附到最近的轴向
---@return number[]
function R.SnapDir(x, y, z)
    local ax, ay, az = math.abs(x), math.abs(y), math.abs(z)
    local function Sign(v) if v < 0 then return -1 end return 1 end
    if ax >= ay and ax >= az then return { Sign(x), 0, 0 } end
    if ay >= az then return { 0, Sign(y), 0 } end
    return { 0, 0, Sign(z) }
end

return R

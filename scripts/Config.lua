-- 全局配置：网格尺寸、档位、调色板（对应 H5 shared/config.js 与策划案 v0.2 第 03 节）

local Config = {}

local data=require("core.ResourceData").Read("Parts/Catalog.json")
Config.CELL=data.cell
Config.TIERS=data.tiers
Config.BUILD=data.build
Config.MAP_CLEARANCE=data.mapClearance
-- Build volume is shared across tiers; tiers constrain mass, budget and counts.
function Config.TierBounds(tier)
    local hw=(Config.BUILD.W-1)//2
    local hl=(Config.BUILD.L-1)//2
    return {minX=-hw,maxX=hw,minY=0,maxY=Config.BUILD.H-1,minZ=-hl,maxZ=hl}
end

function Config.InBounds(b, x, y, z)
    return x >= b.minX and x <= b.maxX and y >= b.minY and y <= b.maxY and z >= b.minZ and z <= b.maxZ
end

Config.PALETTE = {
    { name = "赛车红", hex = 0xd0182a },
    { name = "烈焰橙", hex = 0xff6a13 },
    { name = "警示黄", hex = 0xffc21a },
    { name = "柠檬绿", hex = 0x8fd13b },
    { name = "翠绿", hex = 0x1f9d55 },
    { name = "电光青", hex = 0x14c4c4 },
    { name = "天空蓝", hex = 0x2f8cff },
    { name = "深海蓝", hex = 0x1b3278 },
    { name = "霓虹紫", hex = 0x7a3cff },
    { name = "樱花粉", hex = 0xff5fa8 },
    { name = "珍珠白", hex = 0xe6e2d8 },
    { name = "钛银", hex = 0xa9adb3 },
    { name = "枪灰", hex = 0x4a4e55 },
    { name = "碳黑", hex = 0x1a1c21 },
    { name = "香槟金", hex = 0xc9a04a },
    { name = "皮革棕", hex = 0x7a4a2a },
}

Config.DEFAULT_COLOR = 0xa9adb3

-- ── 颜色工具 ───────────────────────────────────────
-- 策划与 H5 的颜色都是 sRGB 十六进制。材质 uniform 带 source_color 时引擎自动解码，
-- 实例色（instanceColor）不解码，要先转成线性值再交给 shader。

local function SrgbToLinear(c)
    if c <= 0.04045 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end

---@param hex integer
---@return number, number, number
function Config.HexToRGB(hex)
    return ((hex >> 16) & 0xff) / 255.0, ((hex >> 8) & 0xff) / 255.0, (hex & 0xff) / 255.0
end

---@param hex integer
---@param a number|nil
---@return Color
function Config.HexColor(hex, a)
    local r, g, b = Config.HexToRGB(hex)
    return Color(r, g, b, a or 1.0)
end

---@param hex integer
---@param a number|nil
---@return Color
function Config.HexLinear(hex, a)
    local r, g, b = Config.HexToRGB(hex)
    return Color(SrgbToLinear(r), SrgbToLinear(g), SrgbToLinear(b), a or 1.0)
end

return Config

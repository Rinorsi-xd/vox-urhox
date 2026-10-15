-- 零件材质库（对应 H5 three/src/parts/materials.js）
-- 零件模型按“材质槽”拆分几何体，每个槽对应这里的一种材质。所有材质都是共享的：
-- 跟涂装颜色有关的槽（paint / glassPaint / glowPaint / lampPaint / beamPaint / flag）从实例色取色，
-- 所以同一种零件无论涂成什么颜色都能被引擎自动合批（GPU Instancing）。

local Config = require "Config"

local Materials = {}

local SHADER_DIR = "Shaders/BLGL/"

-- 固定颜色的槽：kind = pbr | coat | glow
local FIXED = {
    metal = { kind = "pbr", color = 0x3b4048, metal = 0.85, rough = 0.36 },
    dark = { kind = "pbr", color = 0x15171b, metal = 0.55, rough = 0.48 },
    chrome = { kind = "pbr", color = 0xe6e8ea, metal = 1.0, rough = 0.22 },
    steel = { kind = "pbr", color = 0x9aa1aa, metal = 1.0, rough = 0.28 },
    gold = { kind = "pbr", color = 0xd9a441, metal = 1.0, rough = 0.24 },
    rubber = { kind = "pbr", color = 0x121314, metal = 0.0, rough = 0.88 },
    graphite = { kind = "pbr", color = 0x2b2f35, metal = 0.6, rough = 0.4 },
    carbon = { kind = "coat", color = 0x1c1e22, metal = 0.3, rough = 0.42, coat = 1.0, coatRough = 0.08 },
    caliper = { kind = "coat", color = 0xd41a24, metal = 0.2, rough = 0.3, coat = 1.0, coatRough = 0.1 },
    armorWhite = { kind = "coat", color = 0xd2d7dd, metal = 0.05, rough = 0.36, coat = 0.35, coatRough = 0.3 },
    glowCyan = { kind = "glow", color = 0x38d8ff, intensity = 3.0 },
    glowOrange = { kind = "glow", color = 0xff7a22, intensity = 3.5 },
    glowRed = { kind = "glow", color = 0xff2330, intensity = 3.0 },
    glowGreen = { kind = "glow", color = 0x36ff8c, intensity = 3.0 },
    glowWhite = { kind = "glow", color = 0xfff1dc, intensity = 3.5 },
    glowBlue = { kind = "glow", color = 0x1a9dff, intensity = 2.8 },
}

-- 光束：沿本地 +Y 渐隐
local BEAMS = {
    beamCyan = { color = 0x38d8ff, strength = 0.35, y0 = 0.05, y1 = 1.45, soft = 0 },
    beamOrange = { color = 0xff8a2a, strength = 0.6, y0 = 1.3, y1 = 2.25, soft = 0 },
    beamPaint = { color = 0xffffff, strength = 0.14, y0 = -0.3, y1 = 2.5, soft = 0.35, instance = true },
}

-- 不投射阴影的槽（光束是半透明发光体）
Materials.NO_SHADOW_SLOTS = { beamCyan = true, beamOrange = true, beamPaint = true, holoPaint=true }

-- 跟涂装颜色有关的槽
Materials.PAINT_SLOTS = { paint = true, glassPaint = true, glowPaint = true, lampPaint = true, beamPaint = true, flag = true }

---@type table<string, Material>
local cache = {}

---@param shader string
---@return Material
local function NewSurface(shader)
    local m = Material:new()
    if not m:SetSurfaceShader(SHADER_DIR .. shader) then
        print("[Materials] SurfaceShader 加载失败: " .. shader)
    end
    m:SetShaderParameter("hemi_sky", Variant(Config.HexLinear(0xb2b7bf)))
    m:SetShaderParameter("hemi_ground", Variant(Config.HexLinear(0x747981)))
    m:SetShaderParameter("hemi_intensity", Variant(1.85))
    local dbg = rawget(_G, "VOX_DEBUG")
    if type(dbg) == "table" and dbg.hemi == false then m:SetShaderParameter("hemi_intensity", Variant(0.0)) end
    return m
end

local function SetColor(m, name, hex)
    m:SetShaderParameter(name, Variant(Config.HexLinear(hex)))
end

local function SetFloat(m, name, v)
    m:SetShaderParameter(name, Variant(v))
end

local function Make(key)
    if key=='shieldCell' or key=='quantumShield' then
        local cell=key=='shieldCell';local m=NewSurface('VoxMechShield.shader')
        SetColor(m,'base_color',cell and 0x0b2c58 or 0x04122a)
        SetColor(m,'emission_color',cell and 0x2b8fff or 0x1a6ee8)
        SetFloat(m,'emission_strength',cell and .85 or 1.25)
        SetFloat(m,'roughness_value',cell and .16 or .3)
        SetFloat(m,'band_base',cell and .55 or .75)
        SetFloat(m,'band_strength',cell and 1.1 or .5)
        return m
    end
    local source=require("parts.Defs").DATA.materials[key]
    if source and key~="armorWhite" and key~="glass" then
        local animated=key=='spinSteel' or key=='spinGlow' or key=='glowBlink' or key=='glowCyan' or key=='glowGreen'
        local m=NewSurface(key=='spinSteel' and 'VoxDecorDouble.shader' or animated and 'VoxDecor.shader' or source.coat>0 and "VoxPBRCoat.shader" or "VoxPBR.shader")
        m:SetShaderParameter("base_color",Variant(Color(source.color[1],source.color[2],source.color[3])))
        SetFloat(m,"roughness_value",source.rough or 0.5)
        SetFloat(m,"metallic_value",source.metal or 0)
        if source.coat>0 then SetFloat(m,"clearcoat_value",source.coat);SetFloat(m,"clearcoat_roughness_value",source.coatRough) end
        if source.emission and source.emission~=cjson.null then
            m:SetShaderParameter("emission_color",Variant(Color(source.emission[1],source.emission[2],source.emission[3])))
            SetFloat(m,"emission_strength",source.intensity)
        end
        if animated then
            SetFloat(m,'spin_speed',(key=='spinSteel' or key=='spinGlow') and .9 or 0)
            SetFloat(m,'blink',key=='glowBlink' and 1 or 0)
            if key=='glowCyan' or key=='glowGreen' then
                SetFloat(m,'emission_strength',2.4);SetFloat(m,'pulse_amount',key=='glowCyan' and .5 or .4)
            end
        end
        return m
    end
    if key=="heatGlow" or key=="chargeGlow" or key=="legJumpGlow" then
        local m=NewSurface("VoxPBR.shader")
        SetColor(m,"base_color",0x050505)
        SetColor(m,"emission_color",key=="heatGlow" and 0xff7a22 or key=="chargeGlow" and 0xfff1dc or 0x1a9dff)
        SetFloat(m,"emission_strength",key=="heatGlow" and 0.3 or key=="chargeGlow" and 2.2 or 2.8)
        return m
    end
    if key=="heavyPaint" or key=="framePaint" then
        local m=NewSurface("VoxPaint.shader")
        SetFloat(m,"metallic_value",key=="heavyPaint" and 0.42 or 0.3)
        SetFloat(m,"roughness_value",key=="heavyPaint" and 0.34 or 0.38)
        SetFloat(m,"clearcoat_value",key=="heavyPaint" and 0.45 or 0.3)
        return m
    end
    if key=='holoPaint' then return NewSurface('VoxHoloPaint.shader') end
    if key=="neonPaint" then
        local m=NewSurface("VoxGlowPaint.shader")
        SetFloat(m,"glow_strength",2.2)
        return m
    end
    local f = FIXED[key]
    if f then
        if f.kind == "glow" then
            local m = NewSurface("VoxPBR.shader")
            SetColor(m, "base_color", 0x050505)
            SetFloat(m, "roughness_value", 0.4)
            SetFloat(m, "metallic_value", 0.0)
            SetColor(m, "emission_color", f.color)
            SetFloat(m, "emission_strength", f.intensity)
            return m
        elseif f.kind == "coat" then
            local m = NewSurface("VoxPBRCoat.shader")
            SetColor(m, "base_color", f.color)
            SetFloat(m, "roughness_value", f.rough)
            SetFloat(m, "metallic_value", f.metal)
            SetFloat(m, "clearcoat_value", f.coat)
            SetFloat(m, "clearcoat_roughness_value", f.coatRough)
            return m
        end
        local m = NewSurface("VoxPBR.shader")
        SetColor(m, "base_color", f.color)
        SetFloat(m, "roughness_value", f.rough)
        SetFloat(m, "metallic_value", f.metal)
        return m
    end

    local b = BEAMS[key]
    if b then
        local m = NewSurface("VoxBeam.shader")
        SetColor(m, "beam_color", b.color)
        SetFloat(m, "use_instance_color", b.instance and 1.0 or 0.0)
        SetFloat(m, "strength", b.strength)
        SetFloat(m, "y0", b.y0)
        SetFloat(m, "y1", b.y1)
        SetFloat(m, "soft_start", b.soft)
        return m
    end

    if key == "paint" or key == "paintBlock" then
        local m = NewSurface("VoxPaint.shader")
        SetFloat(m, "block_edges", key == "paintBlock" and 1.0 or 0.0)
        SetFloat(m, "roughness_value", key == "paintBlock" and 0.56 or 0.54)
        SetFloat(m, "metallic_value", key == "paintBlock" and 0.04 or 0.05)
        return m
    elseif key == "glassPaint" then
        return NewSurface("VoxGlass.shader")
    elseif key == "glowPaint" then
        local m = NewSurface("VoxGlowPaint.shader")
        SetFloat(m, "glow_strength", 1.7)
        SetFloat(m, "roughness_value", 0.2)
        return m
    elseif key == "lampPaint" then
        local m = NewSurface("VoxGlowPaint.shader")
        SetFloat(m, "glow_strength", 3.2)
        SetFloat(m, "roughness_value", 0.3)
        return m
    elseif key == "flag" then
        return NewSurface("VoxFlag.shader")
    end

    print("[Materials] 未知材质槽 " .. tostring(key) .. "，用 metal 代替")
    return Materials.Get("metal")
end

--- 槽位 → 共享材质。instancedBlock = 结构方块（漆面带边缘提亮）
---@param slot string
---@param instancedBlock boolean|nil
---@return Material
function Materials.Get(slot, instancedBlock, shellColor)
    if slot=="armorWhite" then
        return Materials.Coat(shellColor or 0xcbd1d7,0.52,0.28,0.06,0.52)
    end
    local key = slot
    if slot == "paint" and instancedBlock then key = "paintBlock" end
    local m = cache[key]
    if m == nil then
        m = Make(key)
        cache[key] = m
    end
    return m
end

-- One shared variant per emissive slot; per-part intensity lives on StaticModel.
function Materials.DynamicEmission(slot)
    local key='dynamic:'..slot
    if not cache[key] then
        local m=Materials.Get(slot):Clone();m:SetShaderParameter('instance_emission',Variant(1.0));cache[key]=m
    end
    return cache[key]
end
function Materials.Joined(slot,xray)
    local key='joined:'..slot..':'..tostring(xray==true)
    if not cache[key] then
        local m=xray and Materials.New('BuildXray.shader') or Materials.Get(slot):Clone()
        m:SetShaderParameter('use_vertex_color',Variant(1.0))
        if xray then m:SetShaderParameter('tint_color',Variant(Color(1,1,1,.12)))
        elseif slot=='paint' then
            SetFloat(m,'roughness_value',.56);SetFloat(m,'metallic_value',.04)
        elseif slot=='heavyPaint' then SetFloat(m,'clearcoat_roughness_value',.22) end
        cache[key]=m
    end
    return cache[key]
end
function Materials.JoinedOutline()
    local key='joined:outline'
    if not cache[key] then cache[key]=Materials.New('BuildLines.shader') end
    return cache[key]
end

--- 车库等场景物体用的固定色 PBR 材质（按参数缓存）
---@param hex integer
---@param rough number
---@param metal number
---@param emissiveHex integer|nil
---@param emissive number|nil
---@return Material
function Materials.Solid(hex, rough, metal, emissiveHex, emissive)
    local key = string.format("solid:%06x:%.3f:%.3f:%s:%s", hex, rough, metal, tostring(emissiveHex), tostring(emissive))
    local m = cache[key]
    if m then return m end
    m = NewSurface("VoxPBR.shader")
    SetColor(m, "base_color", hex)
    SetFloat(m, "roughness_value", rough)
    SetFloat(m, "metallic_value", metal)
    if emissiveHex then
        SetColor(m, "emission_color", emissiveHex)
        SetFloat(m, "emission_strength", emissive or 1.0)
    end
    cache[key] = m
    return m
end

--- 带清漆层的固定色材质（按参数缓存）
---@return Material
function Materials.Coat(hex, rough, metal, coat, coatRough)
    local key = string.format("coat:%06x:%.3f:%.3f:%.3f:%.3f", hex, rough, metal, coat, coatRough)
    local m = cache[key]
    if m then return m end
    m = NewSurface("VoxPBRCoat.shader")
    SetColor(m, "base_color", hex)
    SetFloat(m, "roughness_value", rough)
    SetFloat(m, "metallic_value", metal)
    SetFloat(m, "clearcoat_value", coat)
    SetFloat(m, "clearcoat_roughness_value", coatRough)
    cache[key] = m
    return m
end

--- 任意 SurfaceShader 材质（不缓存，参数由调用方设置）
---@param shader string SurfaceShader 文件名
---@return Material
function Materials.New(shader)
    return NewSurface(shader)
end

return Materials

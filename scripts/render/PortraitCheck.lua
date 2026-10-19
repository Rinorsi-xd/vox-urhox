-- GPU-side orientation map for comms portraits. Devices disagree on which way up
-- these render targets are shown (desktop and phone WebGPU, two WebGL phones...),
-- and WebGPU has no synchronous readback, so nothing here reads pixels on the CPU.
-- Each portrait writes raw corner markers into its own target (red top-left, blue
-- bottom-left). This 8x8 NanoVG canvas paints a NanoVG reference on the left and
-- the portrait's displayed left corners on the right, exactly as the UI draws
-- them. CommsPortrait.shader samples one row of it next frame: matching colours
-- mean the target is shown upright, otherwise the shader flips its own output.
local M={}
local SIZE=8
local HALF=SIZE/2
local IDLE=1 -- stop repainting this long after the last portrait was prepared
---@class PortraitCheckState
---@field vg NVGContextWrapper
---@field texture Texture2D
---@field node Node
---@field receiver LuaScriptObject
---@field portrait CommsPortrait|nil
---@field lastUse number
---@type PortraitCheckState|nil
local state=nil
local function Now() return Time:GetSystemTime()/1000 end
function M.Render()
    local s=state;if not s then return end
    local portrait=s.portrait
    if not portrait or portrait.disposed or not portrait.ready then return end
    if Now()-s.lastUse>IDLE then return end
    local vg=s.vg
    nvgBeginFrame(vg,SIZE,SIZE,1)
    nvgSave(vg);nvgGlobalCompositeOperation(vg,NVG_COPY)
    nvgBeginPath(vg);nvgRect(vg,0,0,SIZE,SIZE);nvgFillColor(vg,nvgRGBA(0,0,0,0));nvgFill(vg)
    nvgRestore(vg)
    -- Whichever row the shader samples, left and right agree only when upright.
    -- Samples sit at block centres, clear of anti-aliasing fringes.
    nvgBeginPath(vg);nvgRect(vg,0,0,HALF,HALF);nvgFillColor(vg,nvgRGBA(255,0,0,255));nvgFill(vg)
    nvgBeginPath(vg);nvgRect(vg,0,HALF,HALF,HALF);nvgFillColor(vg,nvgRGBA(0,0,255,255));nvgFill(vg)
    portrait:DrawCorner(vg,HALF,0,HALF,false)
    portrait:DrawCorner(vg,HALF,HALF,HALF,true)
    nvgEndFrame(vg)
end
local function Ensure()
    if state then return state end
    local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetSRGB(false)
    assert(texture:SetSize(SIZE,SIZE,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Portrait orientation canvas allocation failed')
    texture:SetFilterMode(FILTER_NEAREST)
    texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
    local vg=assert(nvgCreate(1),'Portrait orientation context unavailable');nvgSetRenderTarget(vg,texture)
    local node=Node()
    local receiver=assert(node:CreateScriptObject('LuaScriptObject'),'Portrait orientation requires a native ScriptObject')
    state={vg=vg,texture=texture,node=node,receiver=receiver,lastUse=0}
    receiver:SubscribeToEvent(vg,'NanoVGRender',function()
        local ok,message=pcall(M.Render)
        if not ok then print('[PortraitCheck] render error '..tostring(message)) end
    end)
    print('[PortraitCheck] orientation map ready api='..tostring(graphics.apiName))
    return state
end
--- The shared orientation map, or nil when it cannot be created (portraits then draw unflipped).
---@return Texture2D|nil
function M.Texture()
    local ok,s=pcall(Ensure)
    if not ok then print('[PortraitCheck] unavailable '..tostring(s));return nil end
    return s.texture
end
--- Mark the portrait currently on screen; its corners feed the map.
---@param portrait CommsPortrait
function M.Use(portrait)
    local s=state;if not s then return end
    s.portrait=portrait;s.lastUse=Now()
end
return M

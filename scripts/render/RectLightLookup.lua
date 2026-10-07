-- Maker's Web engine resource pack cooks the signed floating-point LTC table
-- as a color texture. Preserve its original RGBA16F bytes as non-image data.
local Platform=require 'urhox-libs.Platform.PlatformUtils'
local M={}
---@type Texture2D|nil
local restored=nil
function M.Ensure()
    if not Platform.IsWebPlatform() or restored then return end
    local texture=assert(cache:GetResource('Texture2D','Textures/LTC/LTC_Combined.dds'))
    local source=assert(cache:GetFile('Rendering/RectLightLUT.bin'))
    local bytes=source:Read(source.size);source:Dispose()
    -- File's multiple inheritance cannot be cast directly to Deserializer.
    -- VectorBuffer owns the contiguous bytes and exposes the correct base.
    local ok=texture:Load(tolua.cast(bytes,'Deserializer'));bytes:Clear()
    assert(ok and texture.width==64 and texture.height==128,'Cannot restore rectangle-light lookup')
    restored=texture -- Renderer retains this same resource across scene changes.
    print('[RectLightLookup] Restored lossless floating-point light table')
end
return M

-- Maker's Web engine resource pack cooks the signed floating-point LTC table
-- as a color texture. Preserve its original RGBA16F bytes as non-image data.
local Platform=require 'urhox-libs.Platform.PlatformUtils'
local M={}
---@type Texture2D|nil
local restored=nil
local pending=false
local waiting={}
local function Finish(ok,message)
    local callbacks=waiting;waiting={};pending=false
    for _,done in ipairs(callbacks) do done(ok,message) end
end
function M.Ensure(done)
    done=done or function() end
    if not Platform.IsWebPlatform() or restored then done(true);return end
    waiting[#waiting+1]=done
    if pending then return end
    pending=true
    cache:DownloadResources({'Textures/LTC/LTC_Combined.dds','Rendering/RectLightLUT.bin'},function(success,failed)
        if not success or failed and failed>0 then
            Finish(false,'矩形光 LUT 下载失败')
            return
        end
        local texture=cache:GetResource('Texture2D','Textures/LTC/LTC_Combined.dds')
        local source=cache:GetFile('Rendering/RectLightLUT.bin')
        if not texture or not source then Finish(false,'矩形光 LUT 下载后仍不可用');return end
    local bytes=source:Read(source.size);source:Dispose()
    -- File's multiple inheritance cannot be cast directly to Deserializer.
    -- VectorBuffer owns the contiguous bytes and exposes the correct base.
        local ok=texture:Load(tolua.cast(bytes,'Deserializer'));bytes:Clear()
        if not ok or texture.width~=64 or texture.height~=128 then
            Finish(false,'矩形光 LUT 内容无效')
            return
        end
        restored=texture -- Renderer retains this same resource across scene changes.
        print('[RectLightLookup] Restored lossless floating-point light table')
        Finish(true)
    end)
end
return M

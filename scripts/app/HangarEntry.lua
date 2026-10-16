-- Scene Play and Maker/main.lua share HangarApp; editing never runs this lifecycle.
local HangarApp=require("app.HangarApp")

---@class HangarEntry : LuaScriptObject
---@field app HangarApp|nil
HangarEntry=ScriptObject()
function HangarEntry:DelayedStart()
    if rawget(_G,"VOX_APP_BOOTSTRAP") or self.node.scene:GetVar('VoxPreview'):GetBool() then return end
    self.app=HangarApp.New()
    self.app:Start(self.node.scene)
end
function HangarEntry:Update(dt)
    if self.app then self.app:Update(dt) end
end
function HangarEntry:PostUpdate(dt)
    if self.app then self.app:PostUpdate(dt) end
end
function HangarEntry:Stop()
    if self.app then self.app:Stop();self.app=nil end
end

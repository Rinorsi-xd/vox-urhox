-- Development-only file events. No polling, disk writes, or remote Lua execution.
---@class HotReload
local HotReload={}
HotReload.__index=HotReload
function HotReload.New(reloadScene,replaceMotion)
    local self=setmetatable({},HotReload)
    self:init(reloadScene,replaceMotion)
    return self
end
function HotReload:init(reloadScene,replaceMotion)
    self.reloadScene=reloadScene
    self.replaceMotion=replaceMotion
    self.delay=-1
    self.motion=false
    self.scene=false
end
function HotReload:Changed(path)
    path=path:gsub("\\","/")
    if path:match("scene/HangarMotion%.lua$") then self.motion=true
    elseif path:match("Scenes/OrbitalHangar%.xml$") or path:match("Hangar/Materials/.*%.xml$") then self.scene=true
    else return end
    self.delay=0.35
end
function HotReload:Update(dt)
    if self.delay<0 then return end
    self.delay=self.delay-dt
    if self.delay>0 then return end
    if self.motion then
        -- UrhoX caches LuaFile execution separately from package.loaded.
        -- Compile the local source explicitly, then replace only the stateless behavior.
        local file=cache:GetFile("scene/HangarMotion.lua")
        local lines={}
        if file then
            while not file.eof do lines[#lines+1]=file:ReadLine() end
            file:Dispose()
        end
        local chunk,compileError=load(table.concat(lines,"\n"),"@scene/HangarMotion.lua","t",_G)
        local ok,module=false,compileError
        if chunk then ok,module=pcall(chunk) end
        if not ok or type(module)~="table" or type(module.Update)~="function" then
            print("[HotReload] Kept working animation module: "..tostring(module))
        else
            self.replaceMotion(module)
            print("[HotReload] Animation code replaced without resetting the vehicle")
        end
    end
    if self.scene then self.reloadScene() end
    self.motion,self.scene=false,false
end
return HotReload

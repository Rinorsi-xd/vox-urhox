local path="scripts/scene/HangarMotion.lua"
local original=""
local generation=0
local function Write(text)
    local file=assert(io.open(path,"wb"));file:write(text);file:close()
end
V.atFrame(60,function()
    local file=assert(io.open(path,"rb"));original=file:read("*a");file:close()
    generation=assert(VOX_HANGAR).app.generation
    local modified,count=original:gsub("return M%s*$","M.reloadProbe=20261005\nreturn M\n")
    V.assert(count==1,"motion module has an explicit export")
    Write(modified)
end)
V.atFrame(210,function()
    V.assert(VOX_HANGAR.garage.motion.reloadProbe==20261005,"file save hot-reloads actual Lua module")
    V.assert(VOX_HANGAR.app.generation==generation,"animation update preserves live scene")
    Write(original)
end)
V.atFrame(340,function()
    V.assert(VOX_HANGAR.garage.motion.reloadProbe==nil,"restored source hot-reloads without stale exports")
end)

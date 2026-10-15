-- Packaged and local paths use the same resource API.
local M={}
local function Normalize(value)
    if type(value)=="number" then return math.tointeger(value) or value end
    if type(value)=="table" then for k,v in pairs(value) do value[k]=Normalize(v) end end
    return value
end
function M.Read(path)
    -- Read through the native resource mount (loose, packaged or downloaded),
    -- but decode only once. JSONFile -> ToString -> cjson doubled parsing and
    -- retained a second native DOM for large immutable map layouts.
    local file=assert(cache:GetFile(path),"Missing data: "..path)
    -- File.ReadString performs tiny file reads; bulk-read before scanning UTF-8.
    local ok,buffer=pcall(file.Read,file,file.size)
    file:Dispose();assert(ok,buffer)
    local decoded,text=pcall(buffer.ReadString,buffer)
    buffer:Clear();assert(decoded,text)
    return Normalize(cjson.decode(text))
end
return M

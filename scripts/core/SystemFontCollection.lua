-- NanoVG exposes face zero only. Select an installed TTC face by moving its
-- offset to slot zero in a private cache; all font tables remain byte-identical.
-- Uses documented File APIs, never io/FFI or writes to the system font folder.
local M={}
---@param f File
local function U16(f)
    local n=assert(math.tointeger(f:ReadUShort()));return ((n & 255)<<8)|(n>>8)
end
---@param n integer
local function Swap32(n)
    local bits=assert(math.tointeger(n))
    return ((bits & 255)<<24)|((bits & 65280)<<8)|((bits>>8)&65280)|((bits>>24)&255)
end
---@param f File
local function U32(f) return Swap32(f:ReadUInt()) end
---@param f File
---@param offset integer
---@param wanted string
local function Family(f,offset,wanted)
    if offset<0 or offset+12>f.size then return false end
    f:Seek(offset+4);local tables=U16(f)
    if tables>256 or offset+12+tables*16>f.size then return false end
    for i=1,tables do
        f:Seek(offset+12+(i-1)*16)
        local tag=f:ReadFileID();f:SeekRelative(4)
        local start,length=U32(f),U32(f)
        if tag=='name' and length>=6 and start+length<=f.size then
            f:Seek(start+2);local count,strings=U16(f),U16(f)
            if count>4096 or 6+count*12>length then return false end
            for j=1,count do
                f:Seek(start+6+(j-1)*12)
                local platform,encoding,language,id,bytes,at=U16(f),U16(f),U16(f),U16(f),U16(f),U16(f)
                if id==1 and platform==3 and (encoding==1 or encoding==10) and language==1033
                    and bytes==#wanted*2 and strings+at+bytes<=length then
                    f:Seek(start+strings+at);local match=true
                    for k=1,#wanted do if U16(f)~=wanted:byte(k) then match=false;break end end
                    if match then return true end
                end
            end
        end
    end
    return false
end
---@param f File
local function Offsets(f)
    if not f:IsOpen() or f.size<16 or f.size>64*1024*1024 then return nil end
    f:Seek(0);if f:ReadFileID()~='ttcf' then return nil end
    local version,count=U32(f),U32(f)
    if (version~=65536 and version~=131072) or count<1 or count>64 or 12+count*4>f.size then return nil end
    local offsets={};for i=1,count do offsets[i]=f:ReadUInt() end
    return offsets
end
---@param source string
---@param destination string
---@param family string
---@return string?
function M.Prepare(source,destination,family)
    if not fileSystem:FileExists(source) then return nil end
    local f=File(source,FILE_READ);local offsets=Offsets(f)
    if not offsets then f:Dispose();return nil end
    local selected=0
    for i,offset in ipairs(offsets) do if Family(f,Swap32(offset),family) then selected=i;break end end
    if selected==0 then f:Dispose();return nil end
    if selected==1 then f:Dispose();return source end
    local size=f.size;local stamp=fileSystem:GetLastModifiedTime(source)
    if fileSystem:FileExists(destination) and fileSystem:GetLastModifiedTime(destination)==stamp then
        local cached=File(destination,FILE_READ);local old=Offsets(cached)
        local valid=old and cached.size==size and old[1]==offsets[selected] and Family(cached,Swap32(old[1]),family)
        cached:Dispose();if valid then f:Dispose();return destination end
    end
    local temp=destination..'.pending';local out=File(temp,FILE_WRITE)
    if not out:IsOpen() then out:Dispose();f:Dispose();return nil end
    f:Seek(0);local data=f:Read(size);local written=out:Write(data)
    if written==size then
        out:Seek(12);out:WriteUInt(offsets[selected])
        out:Seek(12+(selected-1)*4);out:WriteUInt(offsets[1]);out:Flush()
    end
    out:Dispose();f:Dispose()
    if written~=size then fileSystem:Delete(temp);return nil end
    -- Private rebuildable cache only. Font source and game assets are untouched.
    if fileSystem:FileExists(destination) then fileSystem:Delete(destination) end
    if not fileSystem:Rename(temp,destination) then fileSystem:Delete(temp);return nil end
    fileSystem:SetLastModifiedTime(destination,stamp)
    return destination
end
-- Unhinted EM advance of an installed fixed-pitch TrueType font. CSS lays out
-- Consolas with fractional advances; FreeType pixel hinting rounds them.
---@param source string
---@return number?
function M.MonoAdvance(source)
    local f=File(source,FILE_READ)
    if not f:IsOpen() or f.size<12 or f.size>64*1024*1024 then f:Dispose();return nil end
    f:Seek(4);local count=U16(f);local tables={}
    if count>256 or 12+count*16>f.size then f:Dispose();return nil end
    for i=1,count do
        f:Seek(12+(i-1)*16);local tag=f:ReadFileID();f:SeekRelative(4)
        local offset,length=U32(f),U32(f)
        if offset+length<=f.size then tables[tag]={offset=offset,length=length} end
    end
    local head,post,hmtx=tables.head,tables.post,tables.hmtx
    if not head or head.length<20 or not post or post.length<16 or not hmtx or hmtx.length<4 then f:Dispose();return nil end
    f:Seek(post.offset+12);local fixed=U32(f)
    f:Seek(head.offset+18);local units=U16(f)
    f:Seek(hmtx.offset);local advance=U16(f);f:Dispose()
    if fixed==0 or units==0 or advance==0 then return nil end
    return advance/units
end
return M

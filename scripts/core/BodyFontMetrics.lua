-- Read selected local/resource body-font metrics once. Keep compact cmap/hmtx
-- buffers, not outlines or a copied system-font asset. No per-frame file I/O.
local M={};M.__index=M
local function U16(b,p)
    assert(p>=0 and p+2<=b.size,'Font table bounds');b:Seek(p)
    local n=math.tointeger(b:ReadUShort());return ((n&255)<<8)|(n>>8)
end
local function U32(b,p)
    assert(p>=0 and p+4<=b.size,'Font table bounds');b:Seek(p)
    local n=math.tointeger(b:ReadUInt())
    return ((n&255)<<24)|((n&65280)<<8)|((n>>8)&65280)|((n>>24)&255)
end
local function S16(b,p) local n=U16(b,p);return n>=32768 and n-65536 or n end
local function Tag(b,p) assert(p>=0 and p+4<=b.size);b:Seek(p);return b:ReadFileID() end
local function Read(f)
    assert(f.size>=12 and f.size<=64*1024*1024,'Font file size')
    local base=0
    if Tag(f,0)=='ttcf' then
        local count=U32(f,8);assert(count>=1 and count<=64 and 12+count*4<=f.size,'Font collection size')
        base=U32(f,12)
    end
    local count=U16(f,base+4);assert(count<=256 and base+12+count*16<=f.size,'Font directory size')
    local tables={}
    for i=1,count do
        local at=base+12+(i-1)*16;local offset,length=U32(f,at+8),U32(f,at+12)
        assert(offset+length<=f.size,'Font table outside file');tables[Tag(f,at)]={offset,length}
    end
    local function Buffer(name)
        local t=assert(tables[name],'Missing font table '..name);assert(t[2]<=4*1024*1024,'Font table too large')
        f:Seek(t[1]);return f:Read(t[2])
    end
    local head,hhea=Buffer('head'),Buffer('hhea');local units=U16(head,18)
    assert(units>0,'Font EM size')
    local self=setmetatable({ascent=S16(hhea,4)/units,descent=-S16(hhea,6)/units,units=units,
        metricCount=U16(hhea,34),cmap=Buffer('cmap'),hmtx=Buffer('hmtx'),kern={},advances={},glyphCache={},cacheCount=0},M)
    assert(self.metricCount>0 and self.metricCount*4<=self.hmtx.size,'Font advances size')
    if tables['OS/2'] and tables['OS/2'][2]>=78 then
        local os2=Buffer('OS/2')
        self.winAscent=U16(os2,74)/units;self.winDescent=U16(os2,76)/units
    end
    local maps=U16(self.cmap,2);assert(maps<=64 and 4+maps*8<=self.cmap.size,'Font cmap directory')
    local best=0
    for i=1,maps do
        local at=4+(i-1)*8;local platform,encoding=U16(self.cmap,at),U16(self.cmap,at+2)
        local offset=U32(self.cmap,at+4);local format=U16(self.cmap,offset)
        if (platform==0 or platform==3 and (encoding==1 or encoding==10)) and (format==4 or format==12) then
            local rank=format==12 and 2 or 1
            if rank>best then self.mapOffset=offset;self.format=format;best=rank end
        end
    end
    assert(best>0,'No Unicode cmap')
    if self.format==12 then
        self.groups=U32(self.cmap,self.mapOffset+12)
        assert(self.groups<=65536 and self.mapOffset+16+self.groups*12<=self.cmap.size,'Font cmap groups')
    else
        self.groups=U16(self.cmap,self.mapOffset+6)//2
        assert(self.groups>0 and self.mapOffset+16+self.groups*8<=self.cmap.size,'Font cmap segments')
    end
    -- Selected Microsoft YaHei UI has no kern feature. Fonts requiring GPOS
    -- shaping keep native advances until that shaping is supported explicitly.
    self.fractional=true
    if tables.GPOS then
        local gpos=Buffer('GPOS');local list=U16(gpos,6);local features=U16(gpos,list)
        assert(features<=4096 and list+2+features*6<=gpos.size,'Font feature directory')
        for i=1,features do if Tag(gpos,list+2+(i-1)*6)=='kern' then self.fractional=false end end
    end
    self.bufferBytes=self.cmap.size+self.hmtx.size;return self
end
function M.Load(source)
    local f=fileSystem:FileExists(source) and File(source,FILE_READ) or cache:GetFile(source)
    if not f then return nil end
    local ok,result=pcall(Read,f);f:Dispose()
    if not ok then print('[BodyFontMetrics] unavailable: '..tostring(result));return nil end
    return result
end
function M:Glyph(cp)
    local b,at=self.cmap,self.mapOffset;local lo,hi=0,self.groups-1
    if self.format==12 then
        while lo<=hi do
            local mid=(lo+hi)//2;local p=at+16+mid*12;local first,last=U32(b,p),U32(b,p+4)
            if cp<first then hi=mid-1 elseif cp>last then lo=mid+1 else return U32(b,p+8)+cp-first end
        end
    elseif cp<65536 then
        local ends=at+14;local starts=ends+self.groups*2+2
        while lo<=hi do
            local mid=(lo+hi)//2
            if cp>U16(b,ends+mid*2) then lo=mid+1 else hi=mid-1 end
        end
        if lo<self.groups then
            local first=U16(b,starts+lo*2)
            if cp>=first then
                local delta=U16(b,starts+self.groups*2+lo*2)
                local p=starts+self.groups*4+lo*2;local range=U16(b,p)
                if range==0 then return (cp+delta)&65535 end
                local glyph=U16(b,p+range+(cp-first)*2);return glyph==0 and 0 or (glyph+delta)&65535
            end
        end
    end
    return 0
end
function M:GetAdvance(char)
    if not self.fractional then return nil end
    local known=self.glyphCache[char];if known~=nil then return known or nil end
    local cp=utf8.codepoint(char)
    if cp>=0x300 and cp<=0x36f or cp>=0xfe00 and cp<=0xfe0f then return nil end
    local glyph=self:Glyph(cp);local advance=glyph>0 and U16(self.hmtx,math.min(glyph,self.metricCount-1)*4)/self.units or false
    if self.cacheCount>=2048 then self.glyphCache={};self.cacheCount=0 end
    self.glyphCache[char]=advance;self.cacheCount=self.cacheCount+1;return advance or nil
end
return M

-- H5 FKZC1 interchange. Export uses its uncompressed JSON fallback; import also
-- accepts raw DEFLATE codes. Bounded RFC1951 decoding needs no native/plugin API.
local M={};local LIMIT=2*1024*1024
local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
local function Encode(s)
    local out={}
    for i=1,#s,3 do
        local a,b,c=s:byte(i,i+2);local n=(a<<16)|((b or 0)<<8)|(c or 0)
        for k=0,(c and 3 or b and 2 or 1) do local j=(n>>(18-k*6))&63;out[#out+1]=alphabet:sub(j+1,j+1) end
    end
    return table.concat(out)
end
local function Decode(s)
    assert(#s<=LIMIT*2 and #s%4~=1,'蓝图码长度无效')
    local out,n,count={},0,0
    for i=1,#s do
        local p=alphabet:find(s:sub(i,i),1,true);assert(p,'蓝图码含无效字符')
        n=(n<<6)|(p-1);count=count+6
        if count>=8 then count=count-8;out[#out+1]=string.char((n>>count)&255);n=n&((1<<count)-1) end
    end
    assert(n==0,'蓝图码末尾无效');return table.concat(out)
end
local function Inflate(s)
    local pos,buffer,count=1,0,0
    local function Bits(n)
        while count<n do assert(pos<=#s,'压缩数据不完整');buffer=buffer|(s:byte(pos)<<count);count=count+8;pos=pos+1 end
        local v=buffer&((1<<n)-1);buffer=buffer>>n;count=count-n;return v
    end
    local function Tree(lengths)
        local counts,nextCode,maps={},{},{}
        for _,n in ipairs(lengths) do if n>0 then counts[n]=(counts[n] or 0)+1 end end
        local code=0
        for n=1,15 do code=(code+(counts[n-1] or 0))<<1;assert(code+(counts[n] or 0)<=1<<n,'无效压缩码表');nextCode[n]=code;maps[n]={} end
        for symbol,n in ipairs(lengths) do if n>0 then
            local v=nextCode[n];nextCode[n]=v+1;local reverse=0
            for _=1,n do reverse=(reverse<<1)|(v&1);v=v>>1 end
            maps[n][reverse]=symbol-1
        end end
        return maps
    end
    local function Symbol(tree)
        local value=0
        for n=1,15 do value=value|(Bits(1)<<(n-1));local symbol=tree[n][value];if symbol then return symbol end end
        error('无效压缩符号')
    end
    local lengthBase={3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
    local lengthBits={0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
    local distanceBase={1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
    local output={};local final=0
    while final==0 do
        final=Bits(1);local kind=Bits(2)
        if kind==0 then
            buffer,count=0,0;local len=Bits(16);assert((len~Bits(16))==65535,'压缩块长度无效')
            assert(#output+len<=LIMIT,'蓝图解压后过大')
            for _=1,len do output[#output+1]=string.char(Bits(8)) end
        else
            assert(kind~=3,'未知压缩块');local literals,distances={},{}
            if kind==1 then
                for i=0,287 do literals[i+1]=i<144 and 8 or i<256 and 9 or i<280 and 7 or 8 end
                for i=1,32 do distances[i]=5 end
            else
                local nl,nd,nc=Bits(5)+257,Bits(5)+1,Bits(4)+4
                assert(nl<=286 and nd<=32,'压缩码表过大')
                local order={16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15};local lens={}
                for i=1,19 do lens[i]=0 end
                for i=1,nc do lens[order[i]+1]=Bits(3) end
                local tree=Tree(lens);local all={}
                while #all<nl+nd do
                    local value=Symbol(tree)
                    if value<16 then all[#all+1]=value
                    else
                        if value==16 then assert(#all>0,'重复码缺少前值') end
                        local repeatCount=value==16 and Bits(2)+3 or value==17 and Bits(3)+3 or Bits(7)+11
                        local previous=value==16 and all[#all] or 0;assert(previous and #all+repeatCount<=nl+nd,'无效重复码')
                        for _=1,repeatCount do all[#all+1]=previous end
                    end
                end
                for i=1,nl do literals[i]=all[i] end;for i=1,nd do distances[i]=all[nl+i] end
            end
            assert(literals[257] and literals[257]>0,'压缩块缺少结束符')
            local lt,dt=Tree(literals),Tree(distances)
            while true do
                local v=Symbol(lt);if v==256 then break end
                if v<256 then assert(#output<LIMIT,'蓝图解压后过大');output[#output+1]=string.char(v)
                else
                    local i=v-256;assert(lengthBase[i],'无效匹配长度');local len=lengthBase[i]+Bits(lengthBits[i])
                    local d=Symbol(dt);assert(d<30,'无效匹配距离')
                    local distance=distanceBase[d+1]+Bits(d<4 and 0 or (d//2-1))
                    assert(distance<=#output and #output+len<=LIMIT,'蓝图匹配越界')
                    for _=1,len do output[#output+1]=output[#output-distance+1] end
                end
            end
        end
    end
    return table.concat(output)
end
function M.Validate(data)
    assert(type(data)=='table' and type(data.parts)=='table' and #data.parts<=5000,'蓝图数据损坏或零件过多')
    assert(data.name==nil or type(data.name)=='string' and #data.name<=160,'蓝图名称无效')
    for k in pairs(data.parts) do assert(type(k)=='number' and k%1==0 and k>=1 and k<=#data.parts,'零件列表无效') end
    for _,row in ipairs(data.parts) do
        assert(type(row)=='table' and type(row[1])=='string','零件数据无效')
        for i=2,5 do assert(type(row[i])=='number' and row[i]%1==0 and math.abs(row[i])<=100000,'零件坐标或朝向无效') end
        assert(row[5]>=0 and row[5]<24,'零件朝向无效')
        for i=6,7 do local c=row[i];assert(c==nil or c==cjson.null or type(c)=='number' and c%1==0 and c>=0 and c<=0xffffff,'涂装颜色无效') end
        local g=row[8];assert(g==nil or g==cjson.null or type(g)=='number' and g%1==0 and g>=0 and g<=1000000000,'连接块组号无效')
    end
    if data.livery~=nil and data.livery~=cjson.null then data.livery=require('construction.LiveryData').Clean(data.livery) end
    return data
end
function M.Encode(data)
    M.Validate(data)
    -- Engine JSON encodes an empty Lua table as {}; H5 requires an array here.
    local text=cjson.encode(data)
    if #data.parts==0 then text=text:gsub('"parts"%s*:%s*{}','"parts":[]',1) end
    if data.livery and #data.livery==0 then text=text:gsub('"livery"%s*:%s*{}','"livery":[]',1) end
    return 'FKZC1:j'..Encode(text)
end
function M.Decode(code)
    assert(type(code)=='string' and #code<=LIMIT*2,'蓝图码过大')
    code=code:match('^%s*(.-)%s*$');assert(code:sub(1,6)=='FKZC1:','蓝图码应以 FKZC1: 开头')
    local kind=code:sub(7,7);assert(kind=='j' or kind=='z','未知蓝图码版本')
    local text=Decode(code:sub(8));if kind=='z' then text=Inflate(text) end
    assert(#text<=LIMIT,'蓝图数据过大');return M.Validate(cjson.decode(text))
end
return M

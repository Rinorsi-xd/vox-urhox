local Blueprint=require 'build.Blueprint'
local Config=require 'Config'
local Rot=require 'core.Rotations'
local function Keys(set)
    local out={};for id in pairs(set) do out[#out+1]=id end;table.sort(out);return out
end
local function Normalize(value)
    if value==cjson.null then return nil end
    if value==math.huge then return 'Infinity' end
    if value==-math.huge then return '-Infinity' end
    if type(value)~='table' then return value end
    local out={};for k,v in pairs(value) do out[k]=Normalize(v) end;return out
end
local function Warnings(list)
    local out={}
    for _,w in ipairs(list) do
        local ids={table.unpack(w.ids)};table.sort(ids)
        out[#out+1]={level=w.level,text=w.text,ids=ids}
    end
    -- Graph traversal differs between JS Set and Lua tables; warning order is
    -- presentation only. Keep text, severity, IDs and duplicate counts exact.
    table.sort(out,function(a,b)
        local x,y=a.level..a.text..table.concat(a.ids,','),b.level..b.text..table.concat(b.ids,',')
        return x<y
    end)
    return out
end
return function(f,Equal)
    local failed={}
    local function Check(a,b,label)
        a,b=Normalize(a),Normalize(b)
        local ok=Equal(a,b);V.assert(ok,label)
        if not ok and #failed<30 then failed[#failed+1]={label=label,actual=a,expected=b} end
    end
    for _,c in ipairs(f.cases) do
        local bp=Blueprint.New():Load(c.data)
        Check(bp:ToTable(),c.loaded,'source migration data '..c.name)
        Check({bp.dropped,bp.migrationWarnings},{c.dropped,c.warnings},'source migration notices '..c.name)
        for i,tier in ipairs(Config.TIERS) do
            local d=bp:Diagnose(tier);local expected=c.diagnostics[i]
            Check(Warnings(d.list),Warnings(expected.list),'source diagnostics '..c.name..'/'..i)
            Check(Keys(d.outside),expected.outside,'source highlighted parts '..c.name..'/'..i)
            local stats=d.stats
            table.sort(stats.fire,function(a,b)return a.kind<b.kind end)
            table.sort(expected.stats.fire,function(a,b)return a.kind<b.kind end)
            table.sort(stats.badHovers);table.sort(expected.stats.badHovers)
            Check(stats,expected.stats,'source vehicle stats '..c.name..'/'..i)
            Check({reached=Keys(d.conn.reached),floating=Keys(d.conn.floating),coreId=d.conn.coreId},
                {reached=expected.reached,floating=expected.floating,coreId=expected.coreId},'source connectivity '..c.name..'/'..i)
        end
    end
    for i,c in ipairs(f.overlaps) do
        local bp=Blueprint.New();bp:Add({type=c.type,pos={0,6,0},rot=c.rot})
        local reverse=Blueprint.New();reverse:Add({type='cube',pos=c.pos,rot=Rot.IDENTITY})
        Check({bp:Overlaps('cube',c.pos,Rot.IDENTITY),reverse:Overlaps(c.type,{0,6,0},c.rot),bp:Overlaps('cube',c.pos,Rot.IDENTITY,nil,{[1]=true})},
            {c.forward,c.reverse,c.ignored},'source standing-leg collision '..i)
    end
    local file=assert(io.open('.tmp/blueprint-rule-differences.json','w'));file:write(cjson.encode(failed));file:close()
end

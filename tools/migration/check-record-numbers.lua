local Numbers=require('storage.RecordNumbers')
local Store=require('storage.BlueprintStore')
local Cloud=require('storage.CloudStorage')
local Stash=require('salvage.StashRules')
local Sync=require('storage.CloudSync')
local function Write(path,text)
    local file=File(path,FILE_WRITE);assert(file:IsOpen());file:WriteString(text);file:Flush();file:Dispose()
end
V.atFrame(30,function()
    local nan=string.unpack('<d',string.char(0,0,0,0,0,0,248,127))
    local inf=string.unpack('<d',string.char(0,0,0,0,0,0,240,127))
    local values={nan,inf,-inf,-1,.5,0,1,9007199254740991,9007199254740992,'1',false}
    for i,n in ipairs(values) do
        V.assert(Numbers.Count(n)==(i==6 or i==7 or i==8),'finite unsigned safe integer '..i)
        V.assert(Numbers.Generation(n)==(i==7 or i==8),'finite positive generation '..i)
    end
    local data={v=1,credits=8000,items={scrap=36}}
    local namespace='vox-validation-record-numbers-'..os.time()..'-'..math.random(1,100000000)
    local store=Store.New(namespace);V.assert(store:Write('stash',data,Stash.Valid),'valid local stash saved before corrupt restore')
    local before,generation=store:Read('stash',Stash.Valid)
    local malformed={
        {generation=nan},{generation=inf},{generation=-inf},{generation=-1},{generation=.5},{generation=0},{generation=9007199254740992},
        {generation=1,time=nan},{generation=1,time=inf},{generation=1,time=-inf},{generation=1,time=-1},{generation=1,time=9007199254740992},
        {generation=1,deleted=false},{generation=1,capture='wrong'},
    }
    for i,patch in ipairs(malformed) do
        local record={v=1,data=data};for k,v in pairs(patch) do record[k]=v end
        V.assert(not Numbers.Metadata(record),'corrupt record metadata rejected '..i)
        V.assert(not Store.Hydrate(namespace,'stash',record),'corrupt hydration rejected before local file writes '..i)
        local restored,gen=store:Read('stash',Stash.Valid)
        V.assert(restored and restored.credits==before.credits and gen==generation,'rejected corrupt restore preserves previous local generation '..i)
    end
    local raws={
        '{"v":1,"generation":NaN,"data":{"v":1,"credits":1,"items":{}}}',
        '{"v":1,"generation":Infinity,"data":{"v":1,"credits":1,"items":{}}}',
        '{"v":1,"generation":1e309,"data":{"v":1,"credits":1,"items":{}}}',
        '{"v":1,"generation":9007199254740992,"data":{"v":1,"credits":1,"items":{}}}',
        '{"v":1,"generation":1,"time":NaN,"data":{"v":1,"credits":1,"items":{}}}',
        '{"v":1,"generation":1,"time":1e309,"data":{"v":1,"credits":1,"items":{}}}',
    }
    for i,raw in ipairs(raws) do
        local ok,decoded=pcall(Cloud.Decode,raw,'vox-save-v1-vox-salvage-stash')
        V.assert(not ok or decoded==nil,'actual cloud decoder rejects invalid numeric metadata '..i)
        local other=namespace..'-stash-'..(generation%2==1 and 'b' or 'a')..'.json';Write(other,raw)
        local restored,gen=store:Read('stash',Stash.Valid)
        V.assert(restored and restored.credits==before.credits and gen==generation,'local reader skips corrupt alternate generation '..i)
        local transport={Read=function(_,keys,events) events.ok({key=raw}) end,Write=function() error('corrupt session must never upload') end}
        local sync=Sync.New{transport=transport,identity=function() return 'fixture' end,user='fixture',keys={'key'},allowed={key=true},
            decode=function(text) return Cloud.Decode(text,'vox-save-v1-vox-salvage-stash') end}
        local hydrated=false;sync:Start(function(records) hydrated=records~=nil end)
        V.assert(not hydrated and sync.state=='blocked' and not sync:Queue('key','defaults'),'corrupt cloud restore blocks default upload '..i)
    end
    V.assert(Numbers.Metadata({v=1,generation=1,time=1700000000000.25}) and Numbers.Metadata({v=1,generation=2,deleted=true}),'valid timestamp and deletion schemas remain supported')
    local maxRecord={v=1,generation=Numbers.MAX_INTEGER,data=data}
    V.assert(Store.Hydrate(namespace,'stash',maxRecord),'safe maximum generation can restore')
    V.assert(not store:Write('stash',data,Stash.Valid),'generation exhaustion refuses unsafe integer increment')
    local restored,gen=store:Read('stash',Stash.Valid)
    V.assert(restored.credits==before.credits and gen==Numbers.MAX_INTEGER,'exhausted generation preserves previous valid save')
    V.finish()
end)

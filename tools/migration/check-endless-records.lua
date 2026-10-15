local function Copy(t)
    local out={};for key,value in pairs(t) do out[key]=type(value)=='table' and Copy(value) or value end;return out
end
local function Exercise()
    local Run=require('endless.Run');local Records=require('endless.Records')
    local source=require('endless.Data').starters[1].source
    local run=Run.New(source,123);run.state='rest';local record=run:Save()
    local Cloud=require('storage.CloudStorage');local key='vox-save-v1-vox-garage-vox.endless.run.v1'
    V.assert(Records.Run(record) and Records.Best(run:Result()),'actual source checkpoint and best remain valid')
    local decoded=Cloud.Decode(cjson.encode({v=1,generation=1,data=record}),key)
    V.assert(decoded~=nil,'actual source checkpoint still decodes through production cloud validator')
    local nan=string.unpack('<d',string.pack('<I8',0x7ff8000000000000))
    local infinity=string.unpack('<d',string.pack('<I8',0x7ff0000000000000))
    local bad={nan,infinity,-infinity,-1,9007199254740992}
    for _,field in ipairs({'wave','score','damage','time','seed','tier','lives','credits','repairs','weaponDrought'}) do
        for index,value in ipairs(bad) do local candidate=Copy(record);candidate[field]=value
            V.assert(not Records.Run(candidate),'checkpoint rejects invalid '..field..' '..index)
        end
    end
    for index,value in ipairs(bad) do
        local candidate=Copy(record);candidate.inventory.laser1=value
        V.assert(not Records.Run(candidate),'checkpoint rejects invalid inventory count '..index)
        candidate=Copy(record);candidate.kills.assault=value
        V.assert(not Records.Run(candidate) and not Records.Best(candidate),'checkpoint and best reject invalid kill count '..index)
        candidate=Copy(record);candidate.supplies={{id='laser1',kind='part',type='laser1',name='test',tier=value}}
        V.assert(not Records.Run(candidate),'checkpoint rejects invalid supply tier '..index)
    end
    for _,field in ipairs({'wave','credits','repairs','weaponDrought'}) do local candidate=Copy(record);candidate[field]=1.5
        V.assert(not Records.Run(candidate),'checkpoint rejects fractional '..field)
    end
    local best=run:Result();best.time=.25;best.damage=.5;best.score=10.25
    V.assert(Records.Best(best),'finite fractional score damage and elapsed time are preserved')
    local candidate=Copy(record);candidate.score=9007199254740991
    V.assert(Records.Run(candidate),'safe integer upper bound remains accepted for numeric records')
    candidate=Copy(record);candidate.inventory.laser1=9007199254740992
    V.assert(Cloud.Decode(cjson.encode({v=1,generation=1,data=candidate}),key)==nil,'cloud decode rejects unsafe checkpoint number before restore')
    V.finish()
end
engine.maxInactiveFps=1000;engine.maxFps=1000
V.atFrame(3,Exercise)

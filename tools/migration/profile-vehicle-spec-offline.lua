local BP=require 'construction.Blueprint'
local Spec=require 'drive.VehicleSpec'
local Rotors=require 'construction.Rotors'
local Turret=require 'construction.TurretRange'
local sources=require('combat.ArenaData').prefabs
local stats={}
local function Wrap(object,name,label)
    local original=object[name]
    object[name]=function(...)
        local at=os.clock();local result=table.pack(original(...))
        local elapsed=(os.clock()-at)*1000
        local row=stats[label] or {calls=0,ms=0,maxMs=0};stats[label]=row
        row.calls=row.calls+1;row.ms=row.ms+elapsed;row.maxMs=math.max(row.maxMs,elapsed)
        return table.unpack(result,1,result.n)
    end
end
Wrap(BP,'Load','Load');Wrap(BP,'Graph','Graph');Wrap(BP,'Connectivity','Connectivity')
Wrap(Rotors,'Spec','Rotors');Wrap(Turret,'For','TurretRange')
Wrap(Spec,'BuildParts','BuildParts');Wrap(Spec,'MergeBoxes','MergeBoxes')
local cases={}
for tier=1,5 do for _,role in ipairs({'assault','heavy','hover','sniper'}) do
    local key='red:'..tier..':'..role..':0';local source=sources[key]
    if source then
        stats={};collectgarbage('collect')
        local start=os.clock();local bp=BP.New():Load(source);local spec=Spec.Build(bp)
        assert(spec.ok,key..' spec invalid')
        cases[key]={parts=#source.parts,totalMs=(os.clock()-start)*1000,stages=stats}
    end
end end
return cases

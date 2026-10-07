local Blueprint=require 'build.Blueprint'
local Garage=require 'build.Garage'
local function Clone(v) return cjson.decode(cjson.encode(v)) end
local function MemoryStore()
    local s={slots={}}
    function s:LoadSlot(i) return self.slots[i] and Clone(self.slots[i]) end
    function s:SaveSlot(i,bp) if self.fail=='slot' then return false,'write failed' end;self.slots[i]=bp:ToTable();return true end
    function s:DeleteSlot(i) self.slots[i]=nil;return true end
    function s:SaveGarageState(active) if self.fail=='state' then return false,'state failed' end;self.active=active;return true end
    function s:LoadGarageState() return {active=self.active or false} end
    function s:Queue(bp) self.pending=bp end
    function s:Flush() if self.fail=='draft' then return false,'draft failed' end;self.draft=self.pending:ToTable();return true end
    return s
end
return function()
    local file=assert(io.open('tools/migration/source-garage-fixtures.json'));local f=cjson.decode(file:read('*a'));file:close()
    local bp=Blueprint.New():Load(f.initial);local store=MemoryStore()
    local garage=Garage.New(bp,store,function(data) bp:Load(data);return true end,false)
    for i,c in ipairs(f.cases) do
        if c.op=='save' then garage:Save(c.args[1])
        elseif c.op=='rename' then garage:Rename(c.args[1])
        elseif c.op=='new' then local data=Clone(f.initial);data.name=c.args[1];garage:CreateVehicle(data)
        elseif c.op=='open' then garage:Open(c.args[1])
        elseif c.op=='delete' then garage:Delete(c.args[1]) end
        local e=c.expected
        V.assert(bp.name==e.name and bp:Size()==e.count,'source bay vehicle '..i)
        V.assert(garage.active==e.active and garage.unsaved==e.unsaved,'source bay active/draft '..i)
        local same=true
        for slot,expected in ipairs(e.slots) do
            local actual=store:LoadSlot(slot)
            if expected then same=same and actual and actual.name==expected.name and #actual.parts==expected.count else same=same and not actual end
        end
        V.assert(not not same,'source occupied bays '..i)
    end
    local oldName=bp.name;garage:Rename('必须保留');store.fail='slot'
    V.assert(not garage:Open(1) and bp.name=='必须保留' and garage.unsaved,'save failure cancels switch and preserves edits')
    V.assert(not garage:CreateVehicle('empty') and bp.name=='必须保留','save failure cancels new vehicle')
    store.fail=nil;garage:Rename(oldName);garage:Save()
    local restored=Garage.New(bp,store,function() return true end,true)
    V.assert(restored.active==garage.active and not restored.unsaved,'active bay restored without spurious edits')
    local active=garage.active;local name=bp.name
    for _,failure in ipairs({'state','draft'}) do
        store.fail=failure
        V.assert(not garage:Open(1) and garage.active==active and bp.name==name,'failed '..failure..' write rolls back visible switch')
    end
    store.fail=nil
    local imported=Clone(f.initial);imported.name='独立导入'
    for _,failure in ipairs({'state','draft'}) do
        store.fail=failure
        V.assert(not garage:Import(imported) and garage.active==active and bp.name==name,'failed import '..failure..' preserves visible vehicle and bay')
    end
    store.fail=nil
    local saved=store:LoadSlot(active)
    V.assert(not garage:Import({parts='broken'}) and bp.name==name,'invalid import leaves current vehicle intact')
    V.assert(garage:Import(imported) and garage.active==false and garage.unsaved and bp.name=='独立导入','successful import becomes unslotted draft')
    V.assert(store:LoadSlot(active).name==saved.name,'successful import preserves occupied slot')
    V.assert(not garage:Rename('   ') and not garage:Rename(string.rep('车',41)),'reject empty and oversized names')
    local native=require('storage.BlueprintStore').New('vox-garage-rules-test')
    V.assert(native:SaveSlot(1,bp) and native:DeleteSlot(1) and not native:LoadSlot(1),'native delete writes tombstones')
    local _,generation=native:Read('slot1')
    local corrupt=File(native.prefix..'slot1'..(generation%2==1 and '-a.json' or '-b.json'),FILE_WRITE);corrupt:WriteString('{broken');corrupt:Dispose()
    V.assert(not native:LoadSlot(1),'corrupt newest tombstone cannot resurrect deleted car')
    V.assert(native:SaveSlot(1,bp) and native:LoadSlot(1).name==bp.name,'deleted slot can be reused')
    local data,_,stamp=native:LoadSlot(1)
    V.assert(type(stamp)=='number' and math.abs(stamp/1000-os.time())<5 and data.savedTime==nil,'save date persists outside exchange blueprint')
    local before=bp.name;bp.name='较新的车位内容'
    V.assert(native:SaveSlot(1,bp),'write newer dated generation')
    local _,latest=native:Read('slot1')
    local damaged=File(native.prefix..'slot1'..(latest%2==1 and '-a.json' or '-b.json'),FILE_WRITE);damaged:WriteString('{broken');damaged:Dispose()
    local recovered,_,oldStamp=native:LoadSlot(1)
    V.assert(recovered.name==before and oldStamp==stamp,'corruption recovers matching vehicle and save date together')
    bp.name=before
    native:Write('slot2',bp:ToTable())
    local legacy,_,legacyStamp=native:LoadSlot(2)
    V.assert(legacy.name==bp.name and legacyStamp==nil,'undated legacy slot remains readable without invented date')
    local Card=require 'ui.SourceLibraryCard'
    local fixture={parts={1,2},savedTime=os.time({year=2026,month=10,day=6,hour=10,min=5,sec=0})*1000}
    V.assert(Card.Metadata(fixture)=='2 个零件 · 10/6 10:05','library date matches source zh-CN month/day and minute format')
    V.assert(Card.Metadata(legacy)==#legacy.parts..' 个零件','undated legacy UI omits date')
    fixture.savedTime='bad';V.assert(Card.Metadata(fixture)=='2 个零件','malformed metadata cannot break library rendering')
    V.assert(native:SaveGarageState(false) and native:LoadGarageState().active==false,'unslotted state survives native storage')
    for _,key in ipairs({'slot1','slot2','garage-state'}) do for _,suffix in ipairs({'-a.json','-b.json'}) do local p=native.prefix..key..suffix;if fileSystem:FileExists(p) then fileSystem:Delete(p) end end end
end

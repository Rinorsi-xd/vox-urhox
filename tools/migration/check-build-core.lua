local Blueprint=require 'build.Blueprint'
local Editor=require 'build.BuildEditor'
local Placement=require 'build.Placement'
local Ray=require 'build.GridRay'
local Rot=require 'core.Rotations'
local Finish=require 'parts.Finish'
local function Equal(a,b)
    if a==cjson.null then a=nil end;if b==cjson.null then b=nil end
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<1e-7 end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k,v in pairs(b) do if not Equal(a[k],v) then return false end end
    return true
end
V.atFrame(45,function()
    local file=assert(io.open('tools/migration/source-build-fixtures.json'));local f=cjson.decode(file:read('*a'));file:close()
    for i,c in ipairs(f.placements) do
        local actual=Placement.For(c.type,{normal=c.normal},c.pos,{.3,0,.95},c.spin)
        V.assert(Equal(actual,c.expected),'source mounting '..c.type..'/'..i)
    end
    for i,c in ipairs(f.mirrors) do V.assert(Equal(Placement.Mirror(c.type,c.pos,c.rot),c.expected),'source mirrored occupancy '..c.type..'/'..i) end
    for i,c in ipairs(f.rotations) do V.assert(Rot.RotateAroundAxis(c.rot,c.axis,c.step)==c.expected,'source sampled rotation '..i) end
    for _,c in ipairs(f.paint) do
        V.assert(Equal(Finish.Field({type=c.type},'shell'),c.shell),'source primary paint channel '..c.type)
        V.assert(Equal(Finish.Field({type=c.type},'accent'),c.accent),'source accent paint channel '..c.type)
    end
    for _,c in ipairs(f.rays) do
        local bp=Blueprint.New():Load(c.data)
        for i,r in ipairs(c.samples) do V.assert(Equal(Ray.Cast(r.origin,r.direction,bp,40,false),r.expected),'source subcell pick '..c.type..'/'..i) end
    end
    local bp=Blueprint.New():Load(f.commands.initial);local editor=Editor.New(bp);local eventCount=0
    local changed=editor.history.onChange
    editor.history.onChange=function(...) changed(...);eventCount=eventCount+1 end
    local differences={}
    for i,s in ipairs(f.commands.steps) do
        local a=s.args;local op=s.op
        if op=='place' then
            editor.type=a[1];editor.preview={type=a[1],pos=a[2],rot=a[3],res=bp:Check(a[1],a[2],a[3],editor.bounds),normal={0,1,0},mirror=Placement.Mirror(a[1],a[2],a[3])};editor:Place()
        elseif op=='select' then editor.selection={};for _,id in ipairs(a) do editor.selection[id]=true end
        elseif op=='move' then editor:MoveSelection(a)
        elseif op=='lift' then editor:Lift(a)
        elseif op=='copy' then editor:Copy()
        elseif op=='paste' then editor.pasteSpin=a.spin;local items=editor:PasteItems(a.pos);local ok=true;for _,it in ipairs(items) do ok=ok and it.res.ok end;editor.preview={paste=items,ok=ok};editor:CommitPaste()
        elseif op=='paint' then editor.tool='paint';editor.hit={partId=a.id};editor.color=a.color;editor.paintChannel=a.channel;editor:Paint()
        elseif op=='remove' then editor:Remove({partId=a})
        elseif op=='delete' then editor:DeleteSelection()
        elseif op=='undo' then editor:Undo()
        elseif op=='redo' then editor:Redo() end
        local selection={};for id in pairs(editor.selection) do selection[#selection+1]=id end;table.sort(selection)
        local parts={};for _,p in ipairs(bp:List()) do parts[#parts+1]=require('build.EditHistory').Snapshot(p) end
        table.sort(s.parts,function(x,y)return x.id<y.id end)
        local matches=Equal(parts,s.parts) and Equal(selection,s.selection) and #editor.history.undoStack==s.undo and #editor.history.redoStack==s.redo
        V.assert(matches,'source edit history '..i..'/'..op)
        if not matches and #differences<3 then differences[#differences+1]={step=i,op=op,actual={parts=parts,selection=selection,undo=#editor.history.undoStack,redo=#editor.history.redoStack},expected={parts=s.parts,selection=s.selection,undo=s.undo,redo=s.redo}} end
    end
    local diff=assert(io.open('.tmp/build-history-differences.json','w'));diff:write(cjson.encode(differences));diff:close()
    V.assert(eventCount>300 and #editor.history.undoStack==300,'bounded history emits real edits')
    local empty=Editor.New(Blueprint.New());empty:SelectType('core');empty:Trace({0,10,0},{0,1,0})
    V.assert(empty.hit.anchor and empty.preview.pos[2]==4 and empty:Place(),'empty blueprint offers floating core, not floor attachment')
    local before=empty.bp:Size();empty:SelectType('cube');empty:Trace({10,10,10},{0,-1,0})
    V.assert(empty.hit==nil and not empty:Place() and empty.bp:Size()==before,'floor cannot accept detached blocks')
    V.assert(not Ray.Cast({0,0,0},{0,0,0},empty.bp,160,false).hit,'zero-length ray terminates safely')
    local Code=require 'storage.BlueprintCode'
    local exports={}
    for i,c in ipairs(f.codes) do
        V.assert(Equal(Code.Decode(c.code),c.data),'H5 raw/fixed/dynamic deflate import '..i)
        V.assert(Equal(Code.Decode(Code.Encode(c.data)),c.data),'native blueprint code round trip '..i)
        exports[#exports+1]=Code.Encode(c.data)
    end
    for _,code in ipairs({'garbage','FKZC1:qAA','FKZC1:z_w','FKZC1:jW10','FKZC1:zAw'}) do
        V.assert(not pcall(Code.Decode,code),'reject malformed blueprint code '..code)
    end
    local export=assert(io.open('.tmp/native-build-codes.json','w'));export:write(cjson.encode(exports));export:close()
    dofile('tools/migration/check-blueprint-rules.lua')(f.rules,Equal)
    local Inventory=require 'build.Inventory';local inv=Inventory.New()
    for i,c in ipairs(f.inventory.lists) do
        inv.category=c.cat;inv.material=c.mat;inv.query=c.query
        local ids={};for _,d in ipairs(inv:List()) do ids[#ids+1]=d.id end
        V.assert(Equal(ids,c.expected),'source inventory filter '..i)
    end
    for i,s in ipairs(f.inventory.steps) do
        if s.name=='assignSlot' then inv:Assign(s.args[1]+1,s.args[2])
        elseif s.name=='clearSlot' then inv:Clear(s.args[1]+1)
        elseif s.name=='pickPart' then inv:Pick(s.args[1])
        elseif s.name=='selectSlot' then inv:Select(s.args[1]+1) end
        V.assert(Equal(inv.hotbar,s.hotbar) and inv.active==s.active,'source hotbar assignment '..i)
    end
    V.finish()
end)

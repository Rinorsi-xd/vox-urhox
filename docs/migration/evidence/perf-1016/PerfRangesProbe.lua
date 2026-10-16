local root='D:/Rino_Project/maker/Vox/VoxelCraft/.tmp/perf-optimization-20261016/'
local checks,rows=0,{}
local function Eq(a,b,path)
    checks=checks+1;assert(type(a)==type(b),'type '..path)
    if type(a)=='table' then
        for k,v in pairs(a) do Eq(v,b[k],path..'.'..tostring(k)) end
        for k in pairs(b) do assert(a[k]~=nil,'extra '..path..'.'..tostring(k)) end
    else assert(a==b,'value '..path..' '..tostring(a)..' '..tostring(b)) end
end
local function Run()
    local BP=require 'construction.Blueprint';local Prefab=require 'construction.Prefab'
    local New=require 'construction.TurretRange'
    local Old=assert(loadfile(root..'before/scripts/construction/TurretRange.lua'))()
    local Defs=require('parts.Defs').PARTS
    local count=0
    for _,name in ipairs({'raceCar','hawk','megaMech','scorpion','miniHeavy'}) do
        local bp=Prefab.Create(BP.New(),name);local owner={}
        local original=bp:List()
        local function Compare()
            Eq(Old.For(bp,owner),New.For(bp,owner),name);count=count+1
        end
        Compare()
        for i=1,math.min(30,#original) do
            local p=original[i];bp:Remove(p.id);Compare();bp:Add(p);Compare()
        end
        -- New distant part, nearby part, changed owner, moved/rotated same id.
        local block
        for _,p in ipairs(original) do if Defs[p.type].shape then block=p;break end end
        local added=bp:Add{type=block.type,pos={100,100,100},rot=block.rot,color=block.color}
        Compare();bp:Remove(added.id);Compare()
        for _,p in ipairs(original) do if Defs[p.type].weapon then
            local added=bp:Add{type=block.type,pos={p.pos[1],p.pos[2]+1,p.pos[3]+1},rot=block.rot,color=block.color}
            Compare();owner[added.id]=1;Compare();owner[p.id]=1;Compare()
            bp:Remove(added.id);Compare();owner[p.id]=nil;owner[added.id]=nil;Compare()
            local copy={id=p.id,type=p.type,pos={p.pos[1]+1,p.pos[2],p.pos[3]},rot=p.rot,color=p.color}
            bp:Remove(p.id);bp:Add(copy);Compare();bp:Remove(p.id);bp:Add(p);Compare()
            break
        end end
        local sequence={}
        for _,p in ipairs(original) do if Defs[p.type].shape then sequence[#sequence+1]=p end end
        for pass=1,4 do
            local order=pass%2==1 and {{'before',Old},{'after',New}} or {{'after',New},{'before',Old}}
            for _,item in ipairs(order) do
                local fixture=Prefab.Create(BP.New(),name);local parts=fixture:List();local blocks={}
                for _,p in ipairs(parts) do if Defs[p.type].shape then blocks[#blocks+1]=p end end
                item[2].For(fixture,{}) -- warm cached immutable sample geometry
                collectgarbage('collect');local t=Time:GetSystemTime()
                for i=1,40 do
                    local p=blocks[(i-1)%#blocks+1]
                    fixture:Remove(p.id);item[2].For(fixture,{})
                    fixture:Add(p);item[2].For(fixture,{})
                end
                rows[#rows+1]={name=name,variant=item[1],pass=pass,calls=80,totalMs=Time:GetSystemTime()-t}
            end
        end
    end
    return {result='PASS',checks=checks,states=count,rows=rows}
end
function Start()
    local ok,result=xpcall(Run,debug.traceback)
    if not ok then result={result='FAIL',error=result,checks=checks,rows=rows};print(result.error) end
    local f=assert(io.open(root..'ranges-result.json','wb'));f:write(cjson.encode(result));f:close();engine:Exit()
end

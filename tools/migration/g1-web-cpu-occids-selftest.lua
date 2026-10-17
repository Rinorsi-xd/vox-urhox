local original,candidate,options=...
local defs={gun={weapon=true,aim={pitch={-15,60}}},wall={},drill={weapon=true,drill=true}}
local assets={Get=function() return {weapon={pivot={0,0,0},muzzle={0,0,2}}} end}
local rotations={ROTATIONS={[0]={m={1,0,0,0,1,0,0,0,1}},[1]={m={-1,0,0,0,1,0,0,0,-1}}}}
function rotations.ApplyRot(rot,v) return {rot==1 and -v[1] or v[1],v[2],rot==1 and -v[3] or v[3]} end
local vector={}
function vector.Add(a,b) return {a[1]+b[1],a[2]+b[2],a[3]+b[3]} end
function vector.Sub(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
function vector.Scale(a,b) return {a[1]*b,a[2]*b,a[3]*b} end
function vector.Length(a) return math.sqrt(a[1]^2+a[2]^2+a[3]^2) end
local modules={['parts.Defs']={PARTS=defs},['parts.PartAssets']=assets,['core.Rotations']=rotations,['core.Math3']=vector}
local function module(source)
    return assert(load(source,'TurretRange','t',setmetatable({require=function(name) return assert(modules[name]) end,
        _G=options and {G1_WEB_CPU_LOCAL_SECTIONS=options.probe} or _G},{__index=_G})))()
end
local a,b=module(original),module(candidate)
local function equal(x,y,where)
    if type(x)~='table' or type(y)~='table' then assert(x==y,where);return end
    for k,v in pairs(x) do equal(v,y[k],where..'.'..tostring(k)) end
    for k in pairs(y) do assert(x[k]~=nil,where..': extra key '..tostring(k)) end
end
local function part(id,kind,x,y,z,cells)
    return {id=id,type=kind,rot=0,pos={x,y,z},_cells=cells or {{x,y,z}}}
end
local bp={parts={}}
function bp:List() local out={};for _,p in pairs(self.parts) do out[#out+1]=p end;table.sort(out,function(x,y) return x.id<y.id end);return out end
bp.parts[1]=part(1,'gun',0,0,0)
bp.parts[2]=part(2,'gun',20,0,0)
bp.parts[3]=part(3,'drill',0,3,0)
bp.parts[10]=part(10,'wall',0,0,1)
bp.parts[11]=part(11,'wall',0,0,1)
bp.parts[12]=part(12,'wall',0,1,1,{{0,1,1},{0,2,1},{0,1,2},{0,2,2}})
bp.parts[90]=part(90,'wall',100,0,100)
local owner={[1]=1,[2]=2,[3]=1,[10]=1,[11]=1,[12]=1,[90]=1}
local function upvalue(fn,name)
    for i=1,100 do local key,value=debug.getupvalue(fn,i);if key==name then return value end;if not key then break end end
    error('Missing upvalue '..name)
end
if not (options and options.skipOccIds) then
local prepared=upvalue(b.Compute,'Prepare')(bp:List(),bp.parts[1],owner)
local expected={};for _,id in pairs(prepared.occ) do expected[id]=true end
equal(expected,prepared.occIds,'exact final occupancy id set')
assert(not prepared.occIds[10] and prepared.occIds[11] and prepared.occIds[12],'overlap final winner and multi-cell part')
for mask=0,15 do
    local invalidated={};for i,id in ipairs({10,11,12,99}) do if mask & (1 << (i-1)) ~= 0 then invalidated[id]=true end end
    local x,y=true,true
    for _,id in pairs(prepared.occ) do if invalidated[id] then x=false;break end end
    for id in pairs(prepared.occIds) do if invalidated[id] then y=false;break end end
    assert(x==y,'all invalidation subset predicates')
end
end
local count=0
local function check(label)
    count=count+1
    local ca,cb=0,0
    math.randomseed(1016,count)
    local ra=a.For(bp,owner,function() ca=ca+1 end);local tailA=math.random()
    math.randomseed(1016,count)
    local rb=b.For(bp,owner,function() cb=cb+1 end);local tailB=math.random()
    equal(ra,rb,label);assert(ca==cb,label..': checkpoint calls');assert(tailA==tailB,label..': RNG tail')
end
check('initial overlapping winner and same-id multi-cell')
bp.parts[10]=nil;check('remove overlapping loser preserves winner')
bp.parts[90]=nil;check('remove far nonintersecting part')
bp.parts[11]=nil;check('remove overlapping winner intersects occupancy')
bp.parts[10]=part(10,'wall',0,0,1);check('repair same id at overlap')
owner[12]=2;check('owner changes remove local obstruction')
owner[12]=1;check('owner changes restore local obstruction')
bp.parts[1].rot=1;check('weapon rotates')
bp.parts[1].rot=0;check('weapon rotates back')
bp.parts[1].pos[1]=1;check('weapon moves')
bp.parts[1].pos[1]=0;check('weapon moves back')
for i=1,24 do
    local id=100+i
    bp.parts[id]=part(id,'wall',i%3-1,i%2,1+i%3);owner[id]=1;check('repeated add '..i)
    if i>2 then bp.parts[id-2]=nil;check('repeated damage '..i) end
end
bp.parts[150]=part(150,'wall',1024,0,0);owner[150]=1;check('out of hash domain far cell')
bp.parts[151]=part(151,'wall',.5,0,1);owner[151]=1;check('fractional occupancy fallback')
for id in pairs(bp.parts) do if id~=1 and id~=2 and id~=3 then bp.parts[id]=nil end end
check('empty occupancy')
check('unchanged repeated call')
return {status='PASS',comparisons=count,invalidationSubsets=not options and 16 or 0,exactFinalOccupancySet=not options,boundary='Offline adapters only; no runtime or performance acceptance.'}

local baseline,variant=...
local modules={
 ['construction.Rotors']={},['construction.TurretRange']={},['Config']={CELL=.75},['parts.Defs']={PARTS={}},
 ['core.Rotations']={},['parts.PartAssets']={},['combat.WeaponLoadout']={},['core.Math3']={},
 ['core.ResourceData']={Read=function()return {rotations={}}end},['parts.MechIK']={},
}
local function module(source)
 return assert(load(source,'VehicleSpec','t',setmetatable({require=function(name)return assert(modules[name],name)end},{__index=_G})))()
end
local a,b=module(baseline),module(variant)
local function exact(x,y)
 assert(type(x)==type(y),'Type changed')
 if type(x)=='number' then
  assert(math.type(x)==math.type(y),'Number subtype changed')
  assert(string.pack('d',x)==string.pack('d',y),'Number bits changed')
 elseif type(x)=='table' then
  for k,v in pairs(x)do exact(v,y[k])end
  for k in pairs(y)do assert(x[k]~=nil,'Added key')end
 else assert(x==y,'Value changed')end
end
local function copy(x)
 if type(x)~='table'then return x end
 local out={};for k,v in pairs(x)do out[k]=copy(v)end;return out
end
local function add(cells,x,y,z,mass,key)
 cells[key or x..','..y..','..z]={pos={x,y,z},mass=mass}
 return cells
end
local tests={{name='empty',cells={}}}
for _,mass in ipairs({0,.5,1,2,4,-1,math.huge})do
 tests[#tests+1]={name='single '..mass,cells=add({},-2,0,3,mass)}
end
for scenario=1,64 do
 local cells={}
 for x=-4,4 do for y=-2,2 do for z=-3,3 do
  if (x*x+y*3+z*7+scenario*11)%7<5 then
   local mass=({0,.125,.5,1,2,4})[(x+y+z+scenario)%6+1]
   add(cells,x,y,z,mass)
  end
 end end end
 tests[#tests+1]={name='sparse '..scenario,cells=cells}
end
for _,item in ipairs({
 {name='boundary x2',v={1,2,4,.5}},
 {name='boundary epsilon',v={1,2+2^-40,.5-2^-40,.5+2^-40}},
 {name='negative masses',v={-1,-2,-.5,0}},
 {name='sum rounding',v={1e-20,2e-20,1e-20,2e-20}},
})do
 local cells={};for i,m in ipairs(item.v)do add(cells,i-3,-2,0,m)end
 tests[#tests+1]={name=item.name,cells=cells}
end
tests[#tests+1]={name='float coordinates',cells=add(add({},0.0,0.0,0.0,1),1,0,0,1)}
tests[#tests+1]={name='fractional coordinates',cells=add(add({},.5,0,0,1),1.5,0,0,1)}
tests[#tests+1]={name='int float aliases',cells=add(add({},0,0,0,1),0.0,0.0,0.0,2)}
tests[#tests+1]={name='noncanonical key',cells=add(add({},0,0,0,1,'unused'),1,0,0,1)}
tests[#tests+1]={name='same-position alias',cells=add(add({},0,0,0,1),0,0,0,2,'other')}
tests[#tests+1]={name='signed float zero',cells=add(add({},-0.0,0.0,0.0,1),0.0,0.0,0.0,2)}
tests[#tests+1]={name='nil mass',cells={['0,0,0']={pos={0,0,0}}}}
local comparisons=0
for repeatIndex=1,3 do
 for _,test in ipairs(tests)do
  local cells=test.cells;local before=copy(cells)
  local ca,cb={},{}
  math.randomseed(1016+repeatIndex)
  local x=a.MergeBoxes(cells,function()ca[#ca+1]=math.random(1,1000000)end)
  local ra={};for i=1,32 do ra[i]=math.random()end
  math.randomseed(1016+repeatIndex)
  local y=b.MergeBoxes(cells,function()cb[#cb+1]=math.random(1,1000000)end)
  local rb={};for i=1,32 do rb[i]=math.random()end
  exact(x,y);exact(ca,cb);exact(ra,rb);exact(cells,before)
  exact(a.MergeBoxes(cells),b.MergeBoxes(cells))
  comparisons=comparisons+1
 end
end
return {status='PASS',cases=#tests,comparisons=comparisons,
 boundary='Real MergeBoxes offline exact numeric bits/subtypes, box ordering, input immutability, checkpoints, RNG; dependency adapters only. No runtime timing.'}

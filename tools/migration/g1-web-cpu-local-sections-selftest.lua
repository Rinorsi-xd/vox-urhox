local baseline,variant=...
local modules={
 ['construction.Rotors']={},['construction.TurretRange']={},['Config']={CELL=1},['parts.Defs']={PARTS={}},
 ['core.Rotations']={},['parts.PartAssets']={},['combat.WeaponLoadout']={},['core.Math3']={},
 ['core.ResourceData']={Read=function()return {rotations={}}end},['parts.MechIK']={},
}
local events={};local calls={};local stack={}
local probe={}
function probe.Begin(name) events[#events+1]='+'..name;stack[#stack+1]=name;return name end
function probe.Finish(name) assert(table.remove(stack)==name);events[#events+1]='-'..name;calls[name]=(calls[name]or 0)+1 end
local function module(source)
 return assert(load(source,'VehicleSpec','t',setmetatable({require=function(name)return assert(modules[name],name)end,_G={G1_WEB_CPU_LOCAL_SECTIONS=probe}},{__index=_G})))()
end
local a,b=module(baseline),module(variant)
local function equal(x,y)
 if type(x)~='table'or type(y)~='table'then assert(x==y);return end
 for k,v in pairs(x)do equal(v,y[k])end;for k in pairs(y)do assert(x[k]~=nil)end
end
local tests={ {}, {['0,0,0']={pos={0,0,0},mass=1}} }
for scenario=1,32 do
 local cells={}
 for x=-3,3 do for y=-2,2 do for z=-3,3 do
  if (x*x+y*3+z*7+scenario*11)%7<5 then
   local mass=({.5,1,2,4})[(x+y+z+scenario)%4+1]
   cells[x..','..y..','..z]={pos={x,y,z},mass=mass}
  end
 end end end
 tests[#tests+1]=cells
end
for _,cells in ipairs(tests)do
 local ca,cb=0,0
 math.randomseed(1016);local x=a.MergeBoxes(cells,function()ca=ca+1 end);local ra=math.random()
 math.randomseed(1016);local y=b.MergeBoxes(cells,function()cb=cb+1 end);local rb=math.random()
 equal(x,y);assert(ca==cb and ra==rb)
 assert(#stack==0)
end
for _,name in ipairs({'MergeBoxes.Index','MergeBoxes.Sort','MergeBoxes.Sweep'})do assert(calls[name]==#tests)end
assert(#events==#tests*6)
return {status='PASS',cases=#tests,probe=probe,calls=calls,boundary='Fake geometry compilation and exact output/checkpoint/RNG equivalence only; no timing.'}

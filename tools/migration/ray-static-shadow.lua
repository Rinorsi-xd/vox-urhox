-- Same synchronous Native query, exact original result retained. Not a timer.
local M={}
local function Bits(a,b,label)
 assert(type(a)==type(b),'Shadow type '..label)
 if type(a)=='number' then assert(string.pack('<d',a)==string.pack('<d',b),'Shadow number '..label)
 elseif type(a)=='table' then
  for k,v in pairs(a)do Bits(v,b[k],label..'.'..tostring(k))end
  for k in pairs(b)do assert(a[k]~=nil,'Shadow extra '..label..'.'..tostring(k))end
 else assert(a==b,'Shadow value '..label)end
end
local function Hit(a,b)
 assert((a==nil)==(b==nil),'Shadow hit presence')
 if not a then return end
 assert(a.body==b.body,'Shadow hit body')
 Bits(a.dist,b.dist,'distance');Bits(a.normal,b.normal,'normal')
 Bits(a.point,b.point,'point');Bits(a.partId,b.partId,'partId')
 for k in pairs(a)do assert(k=='body'or k=='dist'or k=='normal'or k=='point'or k=='partId','Unexpected original hit field '..tostring(k))end
 for k in pairs(b)do assert(k=='body'or k=='dist'or k=='normal'or k=='point'or k=='partId','Unexpected candidate hit field '..tostring(k))end
end
function M.New(candidate)
 local self={queries=0,cold=0,warm=0,hits=0,rotorQueries=0,restored=false,vehicles=0}
 local states=setmetatable({},{__mode='k'});local original=false;local module=false;local replacement=false
 function self:Restore()
  if original then assert(module.Cast==replacement,'Shadow ownership changed');module.Cast=original;original=false end
  self.restored=true
 end
 function self:Install(ray)
  assert(not original);module=ray;original=ray.Cast
  replacement=function(vehicle,origin,direction,length)
   assert(collectgarbage('isrunning'),'Shadow requires normal automatic GC')
   assert(self.queries<8192,'Shadow query limit')
   local state=states[vehicle]
   if not state then state={};states[vehicle]=state;self.vehicles=self.vehicles+1 end
   local before=vehicle.rayBounds;local privateBefore=vehicle.rayStaticBounds
   local actual=original(vehicle,origin,direction,length);local after=vehicle.rayBounds
   vehicle.rayBounds=before;vehicle.rayStaticBounds=state.cache
   local ok,result=xpcall(function()return candidate.Cast(vehicle,origin,direction,length)end,tostring)
   state.cache=vehicle.rayStaticBounds;local candidateBounds=vehicle.rayBounds
   vehicle.rayBounds=after;vehicle.rayStaticBounds=privateBefore
   assert(ok,result);Hit(actual,result);Bits(after,candidateBounds,'bounds')
   assert(vehicle.rayBounds==after and vehicle.rayStaticBounds==privateBefore,'Shadow vehicle state restored')
   self.queries=self.queries+1
   if before then self.warm=self.warm+1 else self.cold=self.cold+1 end
   if actual then self.hits=self.hits+1 end
   if vehicle.rotors and #vehicle.rotors>0 then self.rotorQueries=self.rotorQueries+1 end
   return actual
  end
  module.Cast=replacement;self.restored=false
 end
 function self:Report()
  assert(self.restored and not original,'Restore original Cast before reporting')
  return {status='ACTUAL_RAY_SHADOW_PASS',queries=self.queries,cold=self.cold,warm=self.warm,hits=self.hits,
   vehicles=self.vehicles,rotorQueries=self.rotorQueries,restored=self.restored,collectorRunning=collectgarbage('isrunning'),
   boundary='Actual Native synchronous original/candidate Cast queries with actual bodies and Bullet scene; exact hit presence/body/part/distance/normal/point and post-bounds bits. Original result and vehicle cache state restored per query; original Cast restored at end. Normal automatic GC; double query/observer overhead invalid for timing. Rotor/destruction coverage is limited to reported actual queries.'}
 end
 return self
end
return M

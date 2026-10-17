-- Actual Native input recorder, not a timing observer. All floats retain bits.
local M={}
local function Hex(bytes)return (bytes:gsub('.',function(c)return string.format('%02x',string.byte(c))end))end
local function Vec(v)return Hex(string.pack('<ddd',v[1],v[2],v[3]))end
local function Quat(q)return q and Hex(string.pack('<dddd',q.x,q.y,q.z,q.w))or false end
local function Bounds(b)return b and {Vec(b.center),Vec(b.half)}or false end
local function Shapes(list)
 local out={};for i,s in ipairs(list or {})do out[i]={Vec(s.center),Vec(s.half),Quat(s.quat),s.partId or false,s.rotor or false}end
 return out
end
function M.New(env)
 local self={units=assert(env.units),records={},specs={},specKeys={},coldByRotor={},restored=false,
  maxQueries=env.maxQueries or 2048,maxShapes=env.maxShapes or 262144,maxBytes=env.maxBytes or 33554432,
  shapes=0,bytes=0,cold=0,warm=0,vehicleSeen={}}
 local original=false;local module=false;local replacement=false
 function self:Restore()
  if not original then self.restored=true;return end
  assert(module.Cast==replacement,'Query capture restoration ownership changed')
  module.Cast=original;original=false;self.restored=true
 end
 function self:Install(ray)
  assert(not original and #self.records==0);module=ray;original=ray.Cast
  replacement=function(vehicle,origin,direction,length)
   assert(#self.records<self.maxQueries,'Actual query capture record limit')
   local unitIndex=false
   for i,unit in ipairs(self.units)do if unit.vehicle==vehicle then unitIndex=i;break end end
   assert(unitIndex,'Query vehicle is outside actual eight-car roster')
   local spec={Shapes(vehicle.spec.boxes),Shapes(vehicle.spec.hulls),Shapes(vehicle.spec.sensors)}
   local key=cjson.encode(spec);local specId=self.specKeys[key]
   if not specId then
    specId=#self.specs+1;self.specKeys[key]=specId;self.specs[specId]=spec
    self.shapes=self.shapes+#spec[1]+#spec[2]+#spec[3];self.bytes=self.bytes+#key
   end
   local legs=Shapes(vehicle.legHitboxes and vehicle.legHitboxes.items)
   local mech=Shapes(vehicle.mechHitboxes and vehicle.mechHitboxes.items)
   self.shapes=self.shapes+#legs+#mech
   local wheels={}
   for i,w in ipairs(vehicle.wheels)do
    wheels[i]={Vec(w.center),Vec(w.conn),w.down and Vec(w.down)or false,Vec(w.axle),
     Hex(string.pack('<ddd',w.drop,w.radius,w.width)),w.track==true,w.partId or false}
   end
   local p,q=vehicle.body.translation(),vehicle.body.rotation()
   local record={vehicle=unitIndex,spec=specId,rotors=#(vehicle.rotors or {}),
    legs=legs,mech=mech,wheels=wheels,origin=Vec(origin),direction=Vec(direction),
    length=Hex(string.pack('<d',length)),p=Vec({p.x,p.y,p.z}),q=Quat(q),preBounds=Bounds(vehicle.rayBounds)}
   if vehicle.rayBounds then self.warm=self.warm+1 else
    self.cold=self.cold+1;local k=tostring(record.rotors);self.coldByRotor[k]=(self.coldByRotor[k]or 0)+1
   end
   local hit=original(vehicle,origin,direction,length)
   record.expected=hit and {Hex(string.pack('<d',hit.dist)),Vec(hit.normal),hit.partId or false,Vec(hit.point),hit.body==vehicle.body}or false
   record.postBounds=Bounds(vehicle.rayBounds)
   local encoded=cjson.encode(record);self.bytes=self.bytes+#encoded
   assert(self.shapes<=self.maxShapes and self.bytes<=self.maxBytes,'Actual query capture shape/byte limit')
   self.records[#self.records+1]=record;self.vehicleSeen[unitIndex]=true
   return hit
  end
  module.Cast=replacement;self.restored=false
 end
 function self:Report()
  assert(self.restored and not original,'Restore actual query recorder before reporting')
  local seen=0;for _ in pairs(self.vehicleSeen)do seen=seen+1 end
  return {status='ACTUAL_RAY_QUERY_CAPTURE_PASS',floatEncoding='little-endian-double-hex',records=self.records,specs=self.specs,
   cold=self.cold,warm=self.warm,coldByRotor=self.coldByRotor,vehicleCount=seen,restored=self.restored,
   storedBytes=self.bytes,storedShapes=self.shapes,
   boundary='Actual Native calls and original return values; all floats retain exact IEEE754 bits. Complete static shape arrays are snapshotted on every query before content deduplication, including rotor-bearing vehicles. Dynamic legs/mech/wheels, body pose and pre/post rayBounds are recorded. Recorder overhead changes execution and is invalid for timing. No altered ray arithmetic or additional RNG draws.'}
 end
 return self
end
return M

local mode,failStep,scenario=...
G1_WEB_CPU_CONFIG={seed=1016,mode=mode,scenario=scenario or'lanes',warmup=2,steps=60,snapshotEvery=60}
local now,calls=0,{vehicle=0,physics=0,ray=0,rotors=0}
Time={GetSystemTime=function()return now end}
function SubscribeToEvent(event,handler)assert(event=='Update'and handler=='G1WebCpuUpdate')end
function Vector3(x,y,z)return {x=x,y=y,z=z}end
local function Node()return {CreateChild=function()return Node()end,CreateComponent=function(_,kind)
 if kind=='CollisionShape'then return {SetBox=function()end}end
 return {}
end,Dispose=function()end}end
function Scene()return Node()end
local BP={New=function()return {Load=function(self)return self end}end}
local Data={prefabs={}};for _,team in ipairs({'blue','red'})do for _,role in ipairs({'assault','heavy','sniper'})do Data.prefabs[team..':3:'..role..':0']={}end end
local Spec={Build=function()return {ok=true,legs={}}end}
local Gait,Legs,Suspension={},{},{}
for _,module in ipairs({Gait,Legs,Suspension})do for _,key in ipairs({'Step','Foothold','Cast','Clear','Reachable','Target','Sample','Apply'})do module[key]=function()return nil,false,4 end end end
local Space={};Space.__index=Space
function Space.New(scene)return setmetatable({scene=scene,cars={},bodies={}},Space)end
function Space:Register()end
function Space:Raycast(origin,direction,length,excluded,skip,fixed,mask)
 calls.ray=calls.ray+1;return {dist=length/2,point={1,2,3},normal={0,1,0},owner={type='ground'}}
end
function Space:Step()
 now=now+1;calls.physics=calls.physics+1;for _,v in ipairs(self.cars)do v:PostStep()end
end
function Space:Dispose()end
package.loaded['drive.CraterWorld']={New=function(scene,deferred)
 assert(deferred==true)
 return {space=Space.New(scene),layout={terrain={n=32},blocks={}},boulderCount=2,cameraObstacleCount=0,
  GroundAt=function()return 0 end,Dispose=function()end}
end}
package.loaded['drive.CraterPhysics']={Build=function(world,checkpoint)
 world.space.bodies={a={},b={},c={}};checkpoint()
end}
local Vehicle={};Vehicle.__index=Vehicle
function Vehicle.New(space,spec)
 local v=setmetatable({space=space,mass=1,wheels={},legHitboxes={items={}},telemetry={contact=0},body={},x=0},Vehicle)
 space.cars[#space.cars+1]=v;return v
end
function Vehicle:Place(p)self.x=p[1]end
function Vehicle:StepRotors()calls.rotors=calls.rotors+1 end
function Vehicle:Step(cmd,dt)
 calls.vehicle=calls.vehicle+1;now=now+1
 if failStep and calls.vehicle==8 then error('controlled fixed step failure')end
 local hit=self.space:Raycast({self.x,1,0},{0,-1,0},2,self.body,nil,false,1)
 assert(hit.dist==1);self.x=self.x+cmd.throttle*dt;Gait.Step();Legs.Step();Suspension.Sample();Suspension.Apply()
end
function Vehicle:PostStep()end
function Vehicle:GetState()return {p={self.x,0,0},q={x=0,y=0,z=0,w=1},lv={0,0,0},av={0,0,0}}end
function Vehicle:Dispose()end
for name,module in pairs({['construction.Blueprint']=BP,['combat.ArenaData']=Data,['drive.VehicleSpec']=Spec,
 ['drive.Vehicle']=Vehicle,['physics.Space']=Space,['drive.LegGait']=Gait,['drive.LegControl']=Legs,['drive.RaySuspension']=Suspension})do package.loaded[name]=module end
return calls

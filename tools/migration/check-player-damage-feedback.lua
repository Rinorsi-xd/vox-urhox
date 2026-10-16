package.path='scripts/?.lua;'..package.path
Vector3=setmetatable({FORWARD={x=0,y=0,z=1}},{__call=function(_,x,y,z)return {x=x,y=y,z=z}end})
package.preload['urhox-libs/UI']=function()return {}end
package.preload['core.Coord']=function()return {Vec=function(x,y,z)return Vector3(-x,y,z)end}end
package.preload['core.ResourceData']=function()return {Read=function(path)return READ_RESOURCE(path)end}end
local Overlay=assert(loadfile(OVERLAY_MODULE))()
local Motion=require 'ui.CombatFeedbackMotion'
local Unit=assert(loadfile(UNIT_MODULE))()
local checks,failures={},{}
local function Check(ok,label)checks[#checks+1]=label;if not ok then failures[#failures+1]=label end end
local function Near(a,b)return a==b or type(a)=='number' and type(b)=='number' and math.abs(a-b)<1e-9 end
local function Dot(a,b)return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]end
for _,scenario in ipairs(fixtures.scenarios)do
 local c=scenario.camera;local me={rawHpMax=5000,partScale=.6,feedbackOriginalHp=scenario.hp,alive=true,bp={Size=function()return 1 end}}
 local node={worldPosition=Vector3(-c.position[1],c.position[2],c.position[3]),
  worldRotation=setmetatable({},{__mul=function()return Vector3(-c.forward[1],c.forward[2],c.forward[3])end})}
 node.WorldToLocal=function(_,p)
  local d={-p.x-c.position[1],p.y-c.position[2],p.z-c.position[3]}
  return Vector3(Dot(d,c.right),Dot(d,c.up),Dot(d,c.forward))
 end
 local session={combat={player=me},world={time=0},camera={GetNode=function()return node end},trauma=scenario.initialTrauma}
 local hits={};local motion=Motion.New()
 local feedback={Hit=function(_,angle,strength)hits[#hits+1]={angle=angle,strength=strength};motion:Hit(angle,strength)end,Heal=function()end,Clear=function()end}
 local overlay=setmetatable({session=session,feedback=feedback,partCounts={}},Overlay)
 for index,e in ipairs(scenario.events)do
  local event={unit=e.other and {} or me,type=e.killed and 'unitKilled' or 'unitDamaged',amount=e.amount,point=e.point,
   source=e.source and {Position=function()return e.source end} or nil}
  hits={};session.world.time=e.time;overlay:Consume({event})
  local label=scenario.name..'/'..index
  Check(Near(session.trauma,e.expected.trauma),'trauma '..label)
  Check(Near(session.hurtShakeAt,e.expected.hurtShakeAt),'throttle '..label)
  Check(#hits==#e.expected.hits,'hit count '..label)
  for i,h in ipairs(e.expected.hits)do
   Check(hits[i] and Near(math.atan(math.sin(hits[i].angle-h.angle),math.cos(hits[i].angle-h.angle)),0),'horizontal angle '..label)
   Check(hits[i] and Near(hits[i].strength,h.strength),'strength '..label)
  end
 end
 Check(#motion.hits<=5,'actual shared feedback remains bounded '..scenario.name)
end
for index,c in ipairs(fixtures.restores)do
 local p={id=1,type='cube',pos={0,0,0},rot=0,_cells={{0,0,0}}};local parts=c.missing and {} or {[1]=p}
 local bp={parts=parts,Graph=function()return {}end,Connectivity=function()return {reached=c.connected and {[7]=true} or {}}end,
  Add=function(_,part)parts[part.id]=part;return part end,Remove=function(_,id)parts[id]=nil end,Neighbors=function()return c.connected and {[7]=true} or {}end}
 local unit=setmetatable({alive=c.alive,repairOrder={1},original={[1]=p},bp=bp,hp={},shields={},rawHpMax=c.rawHpMax,partScale=c.partScale,
  feedbackOriginalHp=c.initial,bodyHp=10,bodyHpMax=100,structMax=30,env={viewEvents={}},FillShield=function()end},Unit)
 local restored=unit:RestoreMissing(c.count);local n=0;for _ in pairs(parts)do n=n+1 end
 Check(Near(unit.feedbackOriginalHp,c.expected.hp),'restore cache timing '..index)
 Check(#restored==c.expected.restored and n==c.expected.parts,'restoration unchanged '..index)
end
for index,c in ipairs(fixtures.spawns)do
 local unit=setmetatable({source={parts={}},hpMultiplier=1,env={viewEvents={}},feedbackOriginalHp=c.initial},Unit)
 unit:Spawn();unit:Spawn()
 Check(Near(unit.feedbackOriginalHp,c.expected),'actual repeated spawn preserves lazy cache '..index)
end
return {passed=#failures==0,checks=#checks,failures=failures}

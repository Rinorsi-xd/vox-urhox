-- Logical H5 world coordinates. Camera adapters reflect X using core.Coord.
local M={}
M.sortie={spawn={62,-176},easyAt={66,-130},easyIndex=5,hold=10,damage=.12,enemyDamage=2,
 briefFrom={98,-212,13},briefLook={46,-140,2}}
function M.Cast(data,ground)
 local result={};local X=44
 for i,r in ipairs(data.actors.invaders) do
  local x=X+r.x*1.15;local z=-124-r.z*1.3
  result[i]={source=r.blueprint,name=r.role..' T'..r.tier,spawn={pos={x,ground(x,z)+1.2,z},yaw=math.pi},team='enemy',autoRespawn=false,externalControl=true}
 end
 return result
end
-- Target ---- static hull/rock ---- camera: raise by 0.5m until the sightline
-- clears, at most 10m. Vehicle actors do not lift the cinematic camera.
function M.SafeCamera(at,look,cast,previousLift)
 local lift=0
 for _=1,20 do
  local dx,dy,dz=at[1]-look[1],at[2]+lift-look[2],at[3]-look[3]
  local length=math.sqrt(dx*dx+dy*dy+dz*dz)
  if length<=.000001 then break end
  local hit=cast(look,{dx/length,dy/length,dz/length},length)
  if not hit or hit.dist>length-.6 or hit.owner and hit.owner.ref then break end
  lift=lift+.5
 end
 lift=math.max(lift,(previousLift or 0)-.15)
 return {at[1],at[2]+lift,at[3]},lift
end
function M.BeginPayslip(I,target,cast)
 local p=target and target:Position() or {30,0,-170}
 local x,z=p[1]+8,p[3]-12
 local at=M.SafeCamera({x,I.host.GroundAt(x,z)+2.5,z},{p[1],p[2]+1,p[3]},cast)
 I.payslipShot={target=target,at=at}
end
function M.Camera(id,t,I)
 if id=='payslip' then
  local shot=assert(I.payslipShot,'Payslip requires its entry camera pose')
  local p=shot.target and shot.target:Position() or {30,0,-170}
  return {shot.at[1]-t*2,shot.at[2],shot.at[3]},{p[1],p[2]+1.5,p[3]},44
 end
 local ground=I.host.GroundAt or function()return 0 end
 local status=I.host.SortieStatus and I.host.SortieStatus(I) or {}
 local p=status.pos or {66,ground(66,-174)+1.5,-174};local yaw=status.yaw or 0
 local f={math.sin(yaw),math.cos(yaw)};local r={-math.cos(yaw),math.sin(yaw)}
 if id=='sortie-brief' then
  return {98-t*.8,ground(98,-212)+13-t*.15,-212+t*.6},{46,ground(46,-140)+2,-140},50
 elseif id=='sortie-countdown' then
  local k=math.min(1,t/1.8);k=k<.5 and 4*k^3 or 1-(-2*k+2)^3/2
  local start=assert(I.sortieCountdownFrom,'Countdown requires the last presented brief camera pose')
  local from={start[1],start[2],start[3]};local look={46,ground(46,-140)+2,-140}
  local to={p[1]-f[1]*9,p[2]+3.6,p[3]-f[2]*9};local target={p[1]+f[1]*10,p[2]+1.2,p[3]+f[2]*10}
  for n=1,3 do from[n]=from[n]+(to[n]-from[n])*k;look[n]=look[n]+(target[n]-look[n])*k end
  return from,look,50+6*k
 elseif id=='m-drive' then
  local k=math.min(1,t/((I.voiceDuration or 3.12)+.3));local side=26-7*k;local ahead=4+10*k
  local x=p[1]+r[1]*side+f[1]*ahead;local z=p[3]+r[2]*side+f[2]*ahead
  return {x,math.max(p[2]+2.6,ground(x,z)+1.6),z},{p[1]+f[1]*2,p[2]+1.8,p[3]+f[2]*2},50
 elseif id=='m-missile' then
  local target=status.target or {66,ground(66,-104)+1,-104}
  if not status.missileLaunched or t-(status.missileLaunchAt or t)<.5 then
   local dx,dz=target[1]-p[1],target[3]-p[3];local len=math.max(.001,math.sqrt(dx*dx+dz*dz))
   return {p[1]-dx/len*20+dz/len*6,p[2]+8,p[3]-dz/len*20-dx/len*6},{(p[1]+target[1])*.5,p[2]+6,(p[3]+target[3])*.5},50
  end
  local mx=p[1]+(target[1]-p[1])*.55;local mz=p[3]+(target[3]-p[3])*.55
  return {mx+44,ground(mx+44,mz)+9,mz-8},{mx-4,5,mz+8},56
 elseif id=='m-salvage' then
  local a=2.4+t*.4;local x=p[1]+math.sin(a)*24;local z=p[3]+math.cos(a)*24
  return {x,math.max(p[2]+3,ground(x,z)+1.6),z},{p[1],p[2]+2.4,p[3]},46
 elseif id=='recruit' or id=='peacekeeper' or id=='master' or id=='mechanic' or id=='motto' or id=='disclaimer' then
  local age=I.recruitAt and I.time-I.recruitAt or t;local a=4+age*.06;local x=p[1]+math.sin(a)*21;local z=p[3]+math.cos(a)*21
  return {x,math.max(p[2]+3+age*.2,ground(x,z)+1.6),z},{p[1],p[2]+3,p[3]},40
 end
end
return M

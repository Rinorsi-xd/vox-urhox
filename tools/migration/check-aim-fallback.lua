package.path='scripts/?.lua;'..package.path
package.preload['core.ResourceData']=function()return {Read=function(p)return assert(resources[p],p)end}end
local V=require 'core.Math3'
local Weapons=require 'combat.WeaponSystem'
local AimReach=require 'combat.AimReach'
local Assist=require 'combat.AimAssist'
local Fallback=require 'combat.AimFallback'
local q={x=0,y=0,z=0,w=1}
local checks={}
local function Check(ok,name)assert(ok,name);checks[#checks+1]=name end
local function Body(pos)return{translation=function()return{x=pos[1],y=pos[2],z=pos[3]}end,rotation=function()return q end,linvel=function()return{x=0,y=0,z=0}end}end
local function Setup()
 local mount={partId=1,type='laser3',pivot={0,2.01066667678443,.06},off={0,0,2.115746406084182},quat=q,muzzle={0,2.01066667678443,2.175746406084182},dir={0,0,1}}
 local ws=Weapons.New({weapons={mount}})
 local vehicle={body=Body({0,0,0})}
 local player={team='blue',pos={0,0,0},vehicle=vehicle}
 local enemy={team='red',pos={0,0,5},alive=true,vehicle={body=Body({0,0,5}),spec={bounds={min={-.5,0,-.5},max={.5,3,.5}}}},
  bp={parts={[7]={id=7,_cells={{0,0,0}}}}}}
 return ws,player,enemy,AimReach.New(ws,vehicle)
end
local origin={0,3,-5};local dir=V.Normalize({0,-2.75,10})
local stats={range=200,assist={angle=2*math.pi/180,slow=.6}}
local ws,player,enemy,reach=Setup()
local rays=0
local function Cast(o,d,length,excluded)
 Check(excluded==player.vehicle.body,'visibility excludes own chassis')
 rays=rays+1
 local distance=(5-o[3])/d[3]
 return{dist=distance,point=V.Add(o,V.Scale(d,distance)),owner={ref=enemy},partId=7}
end
local old=Assist.Apply(origin,dir,nil,player,{player,enemy},Cast,stats)
Check(old.point[2]<.251 and not reach(old.point),'before: soft assist selects unreachable foot')
rays=0
local fixed=Assist.Apply(origin,dir,nil,player,{player,enemy},Cast,stats,1,reach)
Check(fixed.ref==enemy and fixed.point[2]>.251 and reach(fixed.point),'fallback selects reachable point on same enemy')
Check(rays<=5,'one original and at most four fallback visibility rays')
local actual=ws.groups[1].weapons[1]
Check(actual.yaw==0 and actual.pitch==0 and actual.prevYaw==0 and actual.prevPitch==0 and actual.err==0 and not actual.limited,'probe leaves live turret unchanged')
Check(ws.energy==100 and #ws.fx==0 and #ws.projectiles==0,'probe does not spend energy or fire')
local direct={dist=10,point={0,.25,5},owner={ref=enemy}}
local directProbe=0
local exact=Assist.Apply(origin,dir,direct,player,{player,enemy},function()error('direct hit must not cast')end,stats,1,function()directProbe=directProbe+1;return false end)
Check(exact.point==nil and exact.ref==enemy and directProbe==0,'direct reticle hit remains exact and skips reachability')
local clear=Assist.Apply(origin,dir,nil,player,{player,enemy},Cast,stats,1,function()return true end)
Check(clear.point[2]<.251,'already reachable original point is preserved')
local baselineCalls=0
local blocked=Assist.Apply(origin,dir,nil,player,{player,enemy},function(o,d,length,exclude)
 baselineCalls=baselineCalls+1
 if baselineCalls==1 then return Cast(o,d,length,exclude)end
 return{dist=1,point={0,2,-4},owner={type='wall'}}
end,stats,1,reach)
Check(blocked.ref==enemy and blocked.point[2]<.251,'wall hides fallback and original feedback remains')
Check(baselineCalls<=5,'occluded fallback ray budget is bounded')
local other={team='red',pos={0,0,5},alive=true,vehicle=enemy.vehicle,bp=enemy.bp}
local switched=0
local kept=Assist.Apply(origin,dir,nil,player,{player,enemy},function(o,d,length,exclude)
 switched=switched+1
 if switched==1 then return Cast(o,d,length,exclude)end
 return{dist=1,point={0,2,-4},owner={ref=other}}
end,stats,1,reach)
Check(kept.ref==enemy and kept.point[2]<.251,'fallback never switches to intervening enemy')
Check(not reach({0,2.01066667678443,.5}),'target behind long barrel is unreachable')
Check(not reach({0,.25,5}),'existing pitch limit remains enforced')
Check(reach({0,.75,5}),'reachable upper point respects pitch limit')
actual.range={free=false,lo=-.1,hi=.1,stuck=true,pmin={},pmax={}}
Check(not reach({0,3,10}),'stuck barrel remains blocked')
actual.range={free=false,lo=-.1,hi=.1,pmin={},pmax={}}
for i=1,72 do actual.range.pmin[i]=-.25;actual.range.pmax[i]=math.pi/2 end
Check(not reach({10,3,10}),'yaw restriction remains enforced')
actual.range.free=true
for i=1,72 do actual.range.pmin[i]=.2 end
Check(not reach({0,2.1,10}),'actual sampled self-clearance remains enforced')
actual.range=nil;ws.offline=true
Check(not reach({0,3,10}),'offline weapon cannot drive fallback')
ws.offline=false
local empty=Weapons.New({weapons={}})
Check(not AimReach.New(empty,player.vehicle)({0,1,10}),'empty weapon group is safely unreachable')
local fixedSystem=Weapons.New({weapons={{partId=1,type='mg3',muzzle={0,1,1},dir={0,0,1}}}})
Check(not AimReach.New(fixedSystem,player.vehicle)({0,1,10}),'nonpivot fixed weapon safely skips fallback')
Check(fixedSystem.groups[1].weapons[1].err==0,'nonpivot fixed weapon error state remains intact')
local projectile=Weapons.New({weapons={{partId=1,type='mg3',pivot={0,1,0},off={0,0,1},muzzle={0,1,1},dir={0,0,1},quat=q}}})
local projectileWeapon=projectile.groups[1].weapons[1]
projectileWeapon.bloom=.5;projectileWeapon.spin=.8
Check(AimReach.New(projectile,player.vehicle)({0,1,20}),'ordinary projectile weapon remains mechanically reachable')
Check(projectileWeapon.bloom==.5 and projectileWeapon.spin==.8 and #projectile.projectiles==0 and #projectile.fx==0,'projectile probe preserves bloom spin and firing state')
local loft=Weapons.New({weapons={{partId=1,type='missile3',pivot={0,1,0},off={0,0,1},muzzle={0,1,1},dir={0,0,1},quat=q}}})
local loftWeapon=loft.groups[1].weapons[1];loftWeapon.mphase='raise'
Check(not AimReach.New(loft,player.vehicle)({0,1,20}),'homing loft mechanism is excluded from bullet soft-lock fallback')
Check(loftWeapon.mphase=='raise' and loftWeapon.yaw==0 and loftWeapon.pitch==0,'loft probe leaves launch phase and turret intact')
local probes,visibility=0,0
local many={}
for i=1,1000 do many[i]={unit=enemy,id=i+10,point={0,.25+i*.01,5},ang=0}end
Fallback.Find(origin,dir,math.huge,player,{unit=enemy,id=7,point={0,.25,5}},many,function(o,d)
 visibility=visibility+1;return{point={123,.25,5},owner={ref=enemy}}
end,stats,1,function(point)probes=probes+1;return point[1]~=123 end)
Check(probes<=11 and visibility==4,'1000-part candidate list is limited to seven starts plus four hit probes')
local DriveAim=require 'controls.DriveAim'
local liveSystem,livePlayer,liveEnemy=Setup()
local retiredVehicle=false
local oldVehicle=livePlayer.vehicle;local originalPosition=oldVehicle.body.translation
oldVehicle.body.translation=function()assert(not retiredVehicle,'READ_RETIRED_BODY');return originalPosition()end
local session={weapons=liveSystem,vehicle=oldVehicle,app={touchPrefs={assist=true}},combat={player=livePlayer},world={combatUnits={livePlayer,liveEnemy}}}
session.world.CastRay=function(_,o,d,length,excluded)
 Check(excluded==session.vehicle.body,'resolved soft aim excludes current vehicle body')
 local distance=(5-o[3])/d[3]
 return{dist=distance,point=V.Add(o,V.Scale(d,distance)),owner={ref=liveEnemy},partId=7}
end
Check(DriveAim.Resolve(session,origin,dir,nil)~=nil,'initial real Resolve initializes reachable soft assist')
local firstCallback=session.aimReach
session.vehicle={body=Body({0,0,0})};livePlayer.vehicle=session.vehicle;retiredVehicle=true
Check(DriveAim.Resolve(session,origin,dir,nil)~=nil,'vehicle rebuild uses new live body instead of retired body')
Check(session.aimReach~=firstCallback and session.aimReachVehicle==session.vehicle,'vehicle rebuild refreshes callback owner')
local secondCallback=session.aimReach
local replacement=Setup()
session.weapons=replacement
liveSystem.Group=function()error('READ_RETIRED_WEAPON')end
Check(DriveAim.Resolve(session,origin,dir,nil)~=nil,'respawn uses replacement weapon system')
Check(session.aimReach~=secondCallback and session.aimReachSystem==replacement,'weapon replacement refreshes callback owner')
DriveAim.Clear(session)
Check(session.aimReach==nil and session.aimReachVehicle==nil and session.aimReachSystem==nil,'session cleanup releases callback and both retained owners')
return checks

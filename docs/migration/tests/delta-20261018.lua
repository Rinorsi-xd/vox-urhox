-- Run with Lua 5.4 and ResourceData.Read pointing at the project's JSON assets.
local total=0
local function check(value,message) assert(value,message);total=total+1 end
local Boost=require 'drive.GroundBoost'
local tuning=Boost.Tuning(2)
check(tuning.duration==2.2 and tuning.speed==2.4,'two-thruster reference')
check(Boost.Tuning(1).speed==1.7,'single thruster half bonus')
check(Boost.Tuning(3).speed<Boost.Tuning(4).speed and Boost.Tuning(100).speed<=2.68,'diminishing returns bounded')
local forces={};local vehicle={spec={thrusters={{partId=1},{partId=2}},wings={},motion={topSpeed=20,thrusterSpeed=15}},wheels={{}},suspension={states={{grounded=true}}},hoverStates={},mass=100,thrusterOutputs={},body={addForce=function(f) forces[#forces+1]=f end}}
local frame={up={0,1,0},fwd={0,0,1},vel={0,0,15}}
local boost=Boost.New(2);local command={groundBoost=true,throttle=1,climb=0,steer=1,strafe=1}
local adjusted=boost:Prepare(vehicle,command,.2,frame);local t=boost:Apply(vehicle,frame)
check(t.groundBoost and math.abs(t.groundBoostLeft-2)<1e-8 and adjusted.steer<1,'start grounded; reserve burns; handling softened')
vehicle.suspension.states[1].grounded=false;frame.fwd={0,.6,.8}
boost:Prepare(vehicle,command,.1,frame);boost:Apply(vehicle,frame);check(forces[#forces].y>0,'ground-start burst continues airborne')
command.groundBoost=false;boost:Prepare(vehicle,command,.1,frame);local saved=boost.left
boost:Prepare(vehicle,command,.5,frame);check(boost.left==saved and not boost.active,'release conserves reserve and delays charge')
boost:Prepare(vehicle,command,6,frame);check(boost.left==2.2,'reserve fully recharges')
command.groundBoost=true;boost:Prepare(vehicle,command,.1,frame);check(not boost.active,'cannot initiate in air')
command.groundBoost=false;boost:Prepare(vehicle,command,.01,frame);vehicle.suspension.states[1].grounded=true
command.groundBoost=true;boost:Prepare(vehicle,command,3,frame);boost:Prepare(vehicle,command,7,frame)
check(not boost.active and boost.left==2.2,'empty tank does not retrigger while held')
local clone=Boost.New(1);clone:Restore(boost:Snapshot());check(clone.left<=1.1,'damage/rebuild cannot restore excess reserve')
local Input=require 'controls.DriveInput';local controls=Input.New();vehicle.telemetry={};vehicle.Yaw=function()return 0 end;vehicle.body.angvel=function()return {y=0}end
local cmd={shift=true,space=false,throttle=1,steer=0,strafe=0}
controls:Command(cmd,vehicle,0,0);check(cmd.groundBoost and cmd.climb==0,'ground Shift boosts instead of descends')
vehicle.spec.wings={{}};controls:Command(cmd,vehicle,0,0);check(not cmd.groundBoost and cmd.climb==-1,'wing Shift still descends');vehicle.spec.wings={}
local Gear=require 'salvage.Gear'
local events={};local player={alive=true,hitAt=0,repairOrder={1,2,3},bp={Size=function()return 2 end},vehicle={speed=0},Life=function()return .5 end,Position=function()return {0,0,0}end,
 RestoreMissing=function(_,n)check(n==16,'repair restores up to 16');return {1}end,Heal=function(_,f)check(f==.4,'repair heals 40 percent')end,Flush=function()end}
local run={player=player,rules={cargo={repair=2,shieldCell=1,scanner=1,smokePack=1},heat=20,objects={},opened={},Heat=function(self,n)self.heat=self.heat+n end},cine={},session={controls={held={}}},entries={},Feed=function(_,a,b) events[#events+1]={a,b} end,SyncPlayer=function()end}
local gear=Gear.New(run);gear.pocket={repair=1}
gear:Use(1);gear:Update(1);player.hitAt=1;gear:Update(.1)
check(not gear.repairing and gear:Count('repair')==3,'hit interrupts without spending')
gear:Use(1);gear:Update(1);player.vehicle.speed=3;gear:Update(1)
check(not gear.repairing and gear:Count('repair')==3,'driving away cancels repair')
player.vehicle.speed=0;gear:Use(1);gear:Update(3)
check(not gear.repairing and gear.pocket.repair==nil and run.rules.cargo.repair==2,'consume pocket before cargo')
gear:Use(2);gear:Update(.1);check(player.incomingDamageMultiplier==.25,'shield reduces damage')
gear:Update(10);check(player.incomingDamageMultiplier==1,'shield expires')
run.rules.cargo.shieldCell=1;player.incomingDamageMultiplier=0;gear:Use(2);gear:Update(.1)
check(player.incomingDamageMultiplier==0,'shield preserves invulnerability')
gear:Use(3);check(run.rules.heat==5 and gear:Hidden(),'smoke lowers heat and hides player');check(not gear:Hidden({21,0,0}),'smoke only inside radius')
gear:Update(14);check(not gear:Hidden(),'smoke expires')
run.rules.objects={{id='a',kind='crate',g={20,0,0}},{id='b',kind='wreck',g={130,0,0}}};gear:Use(4)
check(gear.scans.a and not gear.scans.b and run.rules.heat==9,'scanner radius and heat');gear:Update(25);check(next(gear.scans)==nil,'scan expires')
gear:Tap();gear:Move(0,-40);check(gear.selected==1,'wheel upper slot');gear:Update(6.1);check(not gear.open,'wheel idle timeout')
local Rules=require 'salvage.RunRules';local Data=require('core.ResourceData').Read('Salvage/RunData.json')
local r=Rules.New({loot={},wrecks={},extracts={}},Data.ops[1],function()return .5 end)
local box={id='drop',kind='kill',name='敌车',tier=1,g={0,0,0},loot={{'scrap',2,2,1}}};r:AddExtra(box)
-- Saturate all 20 cargo slots with existing valid stack counts.
local Loot=require 'salvage.Loot';r.cargo={scrap=Loot.Stack('scrap')*20}
r:Open(box);for _=1,30 do r:SearchStep(1,{hold=false,swap=false}) end
check(r.search.done and not r.opened.drop,'full cargo leaves drop searchable')
check(r:Target({0,0,0})==box,'remaining drop can be revisited')
r.cargo={};r:SearchStep(.1,{hold=false,swap=true});check(r.opened.drop,'fully collected drop is removed')
local robbed={id='robbed',kind='crate',ctype='electronics',tier=1,g={0,0,0},robbed=true}
r:Open(robbed);check(#r.search.items==0,'robbed crate contains no duplicated loot')
local station={id='station',kind='station',name='维修站',g={0,0,0}};r.objects={station};r.search=nil;r.cargo={cell=1}
local state={alive=true,pos={0,0,0},width=1,speed=0,hold=true,stationBlocked=function()return nil end}
for _=1,4 do r:Step(1,state) end
check(r.opened.station and r.cargo.cell==nil,'station spends exactly one battery once')
local count=0;for _,e in ipairs(r:Drain())do if e.type=='repairStation' then count=count+1 end end
r:Step(5,state);for _,e in ipairs(r:Drain())do if e.type=='repairStation' then count=count+1 end end
check(count==1,'station cannot be reused')
local Rivals=require 'salvage.Rivals'
run.rules=r;run.world={layout={salvage={gameplay={enemySpawns={}}}}};run.gear=gear
local rivals=Rivals.New(run);local s=rivals.squads[1];local unit={alive=true,hitAt=0,Position=function()return {0,0,0}end,vehicle={Yaw=function()return 0 end}};local e={unit=unit,hit0=0,rival=s};s.units={e};s.state='loot';s.cargo={scrap=7}
local other={unit={alive=true},rival=s};s.units[2]=other
local drops=rivals:OnKill(e);check(drops[1][2]==4 and s.cargo.scrap==3,'rival death splits cargo without duplication')
unit.alive=false;local last=rivals:OnKill(other);check(last[1][2]==3 and next(s.cargo)==nil,'last rival drops all remaining cargo')
-- Real lobby transaction methods with only the disk boundary injected.
local Lobby=require 'app.SalvageLobby'
local lobby=setmetatable({data={items={repair=3,shieldCell=2},stats={raids=0}},Save=function()return false,'disk full' end},Lobby)
local original=lobby.data
check(not lobby:BeginRun('run-1',{repair=2}) and lobby.data==original,'failed begin leaves inventory untouched')
lobby.Save=function()return true end
check(lobby:BeginRun('run-1',{repair=2}) and lobby.data.items.repair==1,'begin deducts carried gear atomically')
check(lobby:BeginRun('run-1',{repair=2}) and lobby.data.items.repair==1 and lobby.data.stats.raids==1,'begin retry is idempotent')
original=lobby.data;lobby.Save=function()return false,'disk full' end
local result={ok=true,cargo={scrap=4},pocket={repair=1}}
check(not lobby:CommitRun('run-1',result,{}) and lobby.data==original,'failed extraction leaves inventory untouched')
lobby.Save=function()return true end
check(lobby:CommitRun('run-1',result,{}) and lobby.data.items.repair==2 and lobby.data.items.scrap==4,'successful extraction refunds unused pocket and credits cargo')
check(lobby:CommitRun('run-1',result,{}) and lobby.data.items.repair==2 and lobby.data.items.scrap==4,'extraction retry cannot duplicate cargo')
check(not lobby:BeginRun('run-2',{repair=9}) and lobby.data.items.repair==2,'cannot deploy nonexistent gear')
lobby:BeginRun('run-2',{repair=2});lobby:CommitRun('run-2',{ok=false,keepCar=false,cargo={},pocket={repair=2}}, {})
check(lobby.data.items.repair==0,'death loses pocket')
-- Full rival loot -> extraction progression, not only split-drop arithmetic.
run.player.Position=function()return {900,0,900}end
run.director={Remove=function(_,entry)entry.removed=true end}
r.objects={{id='fresh',kind='crate',ctype='supply',tier=1,g={0,0,0}}};r.opened={};r.sessions={};r.time=100
r.extracts={{id='exit',g={0,0,0},radius=20}};s=rivals.squads[1];s.state='loot';s.goal=nil;s.crates=0;s.cargo={};s.t=0
unit.alive=true;e.hit0=unit.hitAt;s.units={e}
for i=1,12 do rivals:Update(.25) end
check(r.objects[1].robbed and s.crates==1 and next(s.cargo)~=nil,'rivals rob unopened crate after three seconds')
r.time=700;for i=1,36 do rivals:Update(.25) end
check(s.state=='gone' and e.removed,'rivals choose exit and extract with cargo')
local Chase=require 'controls.ChaseState';local chase=Chase.New();chase:Reset({0,0,0},3);chase.minY=-math.huge
local cast=function(o,d,l) if d[2]>.5 then return math.min(l,.3) elseif d[3]<-.5 then return math.min(l,.8) end end
local pose=chase:Pose(.1,{0,0,0},0,0,cast)
check(pose.target[2]<=.271,'low ceiling constrains lifted pivot')
check(pose.distance<1.2 and pose.position[3]>-1.2,'camera can retract inside legacy minimum distance')
local before=chase.curDist;chase:Pose(.1,{0,0,0},0,0,function()return nil end)
check(chase.curDist>before and chase.curDist<chase.dist,'camera recovers smoothly after wall clears')
local Math=require 'core.Math3';local Drill=require 'combat.DrillAttack'
local system={Muzzle=function(_,w,state)return {pos=state.pos,dir=Math.RotateUnit(state.quat,{0,0,1})}end}
local drill=Drill.New(system);local muzzle,q=drill:LaunchPose({}, {pos={0,0,0},quat={x=0,y=0,z=0,w=1},aim={20,100,20}})
check(math.abs(math.asin(muzzle.dir[2])-math.pi/12)<1e-6,'drill launch elevation capped at 15 degrees')
check(math.abs(muzzle.dir[1])<1e-6,'drill assist preserves nose yaw rather than snapping to target')
local specBuilder=require 'drive.VehicleSpec';local bp=require 'construction.Blueprint'
local count=0
for kind,variants in pairs(Data.enemies) do for i,variant in ipairs(variants) do
 check(specBuilder.Build(bp.New():Load(variant.source)).ok,'valid enemy blueprint '..kind..':'..i);count=count+1
end end
print('PASS enemy variants: '..count)
print('PASS delta behavior assertions: '..total)

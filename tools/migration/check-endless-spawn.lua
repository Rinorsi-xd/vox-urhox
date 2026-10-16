package.path='scripts/?.lua;'..package.path
local checks={}
local function Check(value,name) assert(value,name);checks[#checks+1]=name end
local function Near(a,b,name) Check(math.abs(a-b)<1e-10,name) end
local vector={}
vector.__index=vector
function vector.__add(a,b) return Vector3(a.x+b.x,a.y+b.y,a.z+b.z) end
function vector.__sub(a,b) return Vector3(a.x-b.x,a.y-b.y,a.z-b.z) end
function Vector3(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
local rotation=setmetatable({},{__mul=function(_,v) return v end})
local Spawn=require 'endless.SpawnPresentation'
for _,row in ipairs(goldens) do
    local motion=Spawn.New();motion:Rise(row.started)
    local offset,on=motion:Sample(row.now,row.height,row.invulnerableUntil)
    Near(offset,row.offset,'source offset '..row.name)
    Check(on==row.visible,'source blink '..row.name)
end
local function Node(on)
    local n={enabled=on~=false,position=Vector3(2,19.25,7),rotation=rotation,children={}}
    setmetatable(n,{__index=function(self,key) if key=='worldPosition' then return self.position elseif key=='worldRotation' then return self.rotation elseif key=='worldScale' then return Vector3(1,1,1) end end})
    function n:GetChildren() return self.children end
    function n:SetTransform(position,rotation,scale) self.position=position;self.rotation=rotation;self.scale=scale end
    function n:SetEnabledRecursive(value) self.enabled=value;for _,c in ipairs(self.children) do c:SetEnabledRecursive(value) end end
    return n
end
local motion=Spawn.New();local root=Node();motion:Rise(0)
motion:Apply(root,0,20.5,3);Near(root.position.y,-3.25,'giant visual begins below ground')
motion:Apply(root,0,20.5,3);Near(root.position.y,-3.25,'repeated presentation is idempotent')
motion:Restore();Near(root.position.y,19.25,'restore exposes original camera/physics-derived pose')
motion:Restore();Near(root.position.y,19.25,'repeated restore is idempotent')
local fresh=Node();motion:Apply(root,.3,20.5,3);motion:Apply(fresh,.3,1,3)
Near(root.position.y,19.25,'changing roots restores retired presentation')
Near(fresh.position.y,17.75,'replacement root uses new height')
motion:Restore();motion:Apply(root,.6,20.5,3)
Check(motion.root==nil and motion.basePosition==nil,'finished rise retains no native root')

package.loaded['endless.Data']={config={spawnInvulnerability=3,runKey='run'}}
local nextEvents={}
local run={blueprint={},state='rest',shield={hp=10},Drain=function() local out=nextEvents;nextEvents={};return out end,
    ResumeEdit=function() return {ok=true} end,Save=function() return {} end}
package.loaded['endless.Run']={New=function() return run end}
local player={alive=true,spec={bounds={min={-1,-.5,-2},max={1,20,2}}},previous={},current={},
    vehicle={Place=function() end},SavePose=function() end,Spawn=function(self) self.spawns=(self.spawns or 0)+1 end}
package.loaded['combat.CarUnit']={New=function() return player end}
package.loaded['combat.EnemyDriver']={};package.loaded['combat.DrillRaiderDriver']={}
package.loaded['combat.ShieldQuery']={};package.loaded['core.Math3']={};package.loaded['construction.Blueprint']={}
package.loaded['endless.Audio']={New=function() return {Event=function() end,Dispose=function() end} end}
package.loaded['endless.View']={New=function() return {Event=function() end,Dispose=function() end} end}
package.loaded['endless.Records']={}
package.loaded['drive.SpawnSpecCache']={New=function() return {Dispose=function(self) self.disposed=true end} end}
local Endless=require 'app.EndlessSession'
local world={time=72.37,layout={base={shield={pos={0,0,0}}},spawn={pos={0,1,0},yaw=0}},units={},RecordDamage=function() end}
local s={world=world,map={},scene={},app={store={Write=function() return true end}},
    Resume=function(self) self.resumed=true end,ResetCamera=function(self) self.resets=(self.resets or 0)+1 end}
local e=Endless.New(s,{name='source'},nil)
Near(e.spawnPresentation.riseUntil,72.97,'actual constructor starts source rise')
Near(e.invulnerableUntil,75.37,'actual constructor keeps source protection duration')
e.SyncPlayer=function(self) self.synced=(self.synced or 0)+1 end
world.time=90;nextEvents={{type='respawn',invulnerability=3}};e:Events()
Near(e.spawnPresentation.riseUntil,90.6,'actual respawn event restarts rise')
Check(player.spawns==1 and e.synced==1 and s.resets==1,'actual respawn retains spawn/view/camera sequence')
world.time=100;e.edit={anchor={pos={0,1,0},yaw=0},Leave=function() end}
Check(e:ResumeEdit({}).ok and s.resumed,'actual editing return resumes retained world')
Near(e.spawnPresentation.riseUntil,100.6,'actual editing return restarts rise')
Near(e.invulnerableUntil,103,'actual editing return retains protection duration')

local active=Node();local disabled=Node(false);root=Node();root.children={active,disabled}
local flashChild=Node();local flash=Node();flash.children={flashChild}
s.view={view={root=root}};s.restoreFlash={root=flash,items={1}};s.firstPerson=false;s.endless=e
e.player=player;player.alive=true;world.time=100.08
local physics={y=19.25};s.vehicle={com={0,0,0},spec=player.spec,body=physics}
e:Present();Check(root.enabled and active.enabled and not disabled.enabled,'blink on preserves authored disabled children')
Check(flash.enabled,'repair flash follows visible model')
Near(flash.position.y,root.position.y,'independent repair shells follow rising vehicle world pose')
e:RestorePresentation();Near(root.position.y,19.25,'next update removes visual offset')
world.time=100.2;e:Present();Check(not root.enabled and not active.enabled and not flash.enabled,'blink off recursively hides model and repair flash')
active.enabled=true;e:Present();Check(not active.enabled,'animation cannot expose parts during blink off')
world.time=100.32;s.firstPerson=true;e:Present()
Check(not root.enabled and not active.enabled and not flash.enabled,'scope remains hidden during blink on')
s.firstPerson=false;e:Present()
Check(root.enabled and active.enabled and not disabled.enabled,'scope release restores original child mask')
Near(physics.y,19.25,'presentation leaves native physics owner unchanged')
player.alive=false;e:RestorePresentation();require('render.NodeVisibility').Set(root,false,true);e:Present()
Check(not root.enabled,'dead player is not resurrected by protection blink')
player.alive=true;e.edit={};e:Present();Check(not root.enabled,'editor keeps battle player hidden');e.edit=nil

for _,name in ipairs({'controls.ChaseState','render.DriveView','controls.DriveInput','ui.DriveHud','render.WeaponView',
    'render.CombatEffects','render.CombatView','render.TargetFeedback'}) do package.loaded[name]={} end
package.loaded['core.Coord']={Vec=function(x,y,z) return Vector3(-x,y,z) end}
package.loaded['urhox-libs/UI']={}
package.loaded['ui.DialogHost']={}
local cameraPositions={}
package.loaded['controls.ChaseCamera']={Apply=function() cameraPositions[#cameraPositions+1]=root.position.y end}
local Trial=require 'app.TrialSession'
setmetatable(s,Trial)
s.combat=e;s.weapons={Group=function() return nil end,drill={}};s.scope=false
s.camera={GetNode=function() return {} end,GetCamera=function() return {fov=48} end}
s.target={};s.yaw=0;s.pitch=0;s.frameDt=1/60;s.currentFov=48;s.fxContext={}
s.chase={Pose=function(_,_,center) Near(center[2],19.25,'actual chase targets unshifted visual pose');return {} end}
s.drillSpeed={Update=function() end};s.pointer={captured=false};s.speedFov={Step=function() return 48 end}
s.cameraFeedback={Flush=function(_,center) Near(center[2],19.25,'camera feedback sees unshifted pose') end,Apply=function() end}
s.environment={Update=function() Near(root.position.y,19.25,'environment update precedes spawn presentation') end}
world.time=100.2;root.position=Vector3(2,19.25,7);e.spawnPresentation:Rise(100)
s:PostUpdate(1/60)
Check(cameraPositions[1]==19.25 and root.position.y<19.25,'actual PostUpdate applies rise after camera')
Check(not root.enabled and not flash.enabled,'actual PostUpdate final mask preserves blink over ordinary scope mask')
s:PostUpdate(1/60)
Near(cameraPositions[2],19.25,'repeated actual PostUpdate never shifts camera')
Near(root.position.y,4.25,'repeated actual PostUpdate does not accumulate rise')
s.app.loadingFlow={active=true};s:Update(1/60)
Near(root.position.y,19.25,'actual Update restores pose before loading early return')
e:Present();e.run.state='editing';s:PostUpdate(1/60)
Near(root.position.y,19.25,'editing PostUpdate restores before early return')
e.run.state='rest';e:Present();e:Dispose()
Check(e.spawnPresentation==nil and e.player==nil and e.session==nil,'dispose drops all presentation/native owner references')

local rebuilt=Node();local authoredOff=Node(false);root=Node();root.children={Node()}
local u={alive=true,vehicle={},weapons={},bp={},spec=player.spec}
local host={view={view={root=root,Rebuild=function() root.children={rebuilt,authoredOff} end},Bind=function() end},
    restoreFlash={root=Node(),items={}},firstPerson=false}
local controller=setmetatable({session=host,player=u,world={time=.12,viewEvents={{type='unitRebuilt',unit=u}}},
    spawnPresentation=Spawn.New(),invulnerableUntil=3},Endless)
controller.spawnPresentation:Rise(0)
require('render.NodeVisibility').Set(root,false,true)
controller:SyncPlayer()
Check(host.vehicle==u.vehicle and host.weapons==u.weapons and root.enabled,'actual PlayerViewSync binds final rebuilt owner')
controller:Present()
Check(not root.enabled and not rebuilt.enabled and not authoredOff.enabled,'rebuilt model cannot escape active protection blink')
controller:RestorePresentation();controller.world.time=.24;controller:Present()
Check(root.enabled and rebuilt.enabled and not authoredOff.enabled,'rebuilt child mask returns faithfully on next blink')
return {checks=checks}

package.path='scripts/?.lua;'..package.path
local checks={};local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
local function Noop()end
package.loaded['construction.Blueprint']={New=function()return{Load=function(self,source)self.source=source;return self end,List=function(self)return self.source.parts end}end}
package.loaded['core.Coord']={Vec=function(x,y,z)return{x=x,y=y,z=z}end}
package.loaded['core.ResourceData']={Read=function(name)return assert(RESOURCE_DATA[name],name)end}
package.loaded['parts.Dependencies']={For=function()return{'parts-a','parts-b','parts-a'}end}
package.loaded['ui.WeaponIconResources']={For=function()return{'icon-a','parts-a'}end}
for _,name in ipairs({'WeaponAudio','DrivingAudio','CombatFeedbackAudio'})do
 package.loaded['audio.'..name]={Dependencies=function()return{'audio-'..name}end}
end
package.loaded['app.DriveMaps']={crater={scene='Scenes/Crater.xml',resources='Crater/Resources.json'}}
package.loaded['app.SceneLoader']={New=function()return{Update=Noop,Cancel=Noop}end}
package.loaded['scene.Crater']={Release=Noop}
local requests={}
package.loaded['app.ResourceGate']={New=function()return{Start=function(_,paths)requests[#requests+1]=paths end,Cancel=Noop}end}
local Host=assert(loadfile(HOST_PATH))()
local Old=assert(loadfile(OLD_HOST_PATH))()
local intro=RESOURCE_DATA['Intro/Intro.json']
local app={blueprint={ToTable=function()return intro.actors.hero end}}
local old=Old.Dependencies(app,intro);local actual=Host.Dependencies(app,intro)
local missiles=require('render.MissileView').Dependencies()
local oldSet={};for _,name in ipairs(old)do oldSet[name]=true end
for index,name in ipairs(old)do Check(actual[index]==name,'Every original dependency remains in order '..index)end
Check(#actual==#old+#missiles,'Only the four MissileView paths extend dependencies')
for index,name in ipairs(missiles)do
 Check(not oldSet[name],'Historical missing missile dependency '..name)
 Check(actual[#old+index]==name,'Actual MissileView dependency appended '..name)
end
local prefetch=Host.New(app);prefetch.Prefetch({data=intro},Noop,Noop)
Check(#requests==1,'Opening prefetch creates one raw request')
local prefetched={};for _,name in ipairs(requests[1])do prefetched[name]=true end
for _,name in ipairs(missiles)do Check(prefetched[name],'Missile raw bytes requested before scene construction '..name)end

local strikeCases={}
for _,case in ipairs(STRIKE_REFERENCE.cases)do
 local now=0;local point={62,2,-176};local made={};local sounds={};local killed=0
 local player={alive=true,Position=function()return point end}
 package.loaded['intro.IntroStrike']={New=function(_,pos)
  local record={at=now,point={table.unpack(pos)},ages={}};made[#made+1]=record
  return{Update=function(_,_,age)record.ages[#record.ages+1]=age end,Dispose=Noop}
 end}
 local host=Host.New({});host.state.scene={};host.state.session={combat={player=player,Kill=function(_,u)u.alive=false;killed=killed+1 end},
  camera={GetCamera=function()return{node={position={}},fov=48}end}}
 local I={ready=true,playing=false,shot='fixture',time=0,audio={Sfx=function(_,id) sounds[#sounds+1]={id=id,at=now}end}}
 host.SortieStep(4,I)
 Check(#made==0,'No beam is constructed at lock entry, speed '..case.speed)
 for _,at in ipairs({.2,.7,1.2,1.79,1.8,1.9,2.05})do
  now=at;I.time=at;point={62+case.speed*at,2,-176+case.speed*at};host.Update(.01,I)
  Check(#made==(at<1.8 and 0 or 1),'Beam begins once at authored firing boundary '..case.speed..'/'..at)
 end
 local fired=made[1];Check(fired.at==case.fireAt,'Source lock duration retained '..case.speed)
 for axis=1,3 do
  Check(math.abs(fired.point[axis]-case.point[axis])<1e-9,'Source post-lock target position '..case.speed..'/'..axis)
  Check(case.beam.to[axis]==case.point[axis]-(axis==2 and 1 or 0),'Executed source beam endpoint follows post-lock point '..case.speed..'/'..axis)
 end
 local beeps,laser=0,0;for _,sound in ipairs(sounds)do if sound.id=='blip'then beeps=beeps+1 elseif sound.id=='laser_big'then laser=laser+1;Check(sound.at==1.8,'Laser cue begins with beam')end end
 Check(beeps>=3 and laser==1,'Lock beeps and exactly one firing cue retained '..case.speed)
 host.SortieStep(5,I);Check(killed==1,'Authored stage-five destruction retained '..case.speed)
 strikeCases[#strikeCases+1]={speed=case.speed,point=fired.point,at=fired.at,beeps=beeps,laser=laser}
end
for _,deadAt in ipairs({.2,.7,1.79})do
 local now=0;local made=0;local laser=0;local player={alive=true,Position=function()return{62,2,-176}end}
 package.loaded['intro.IntroStrike']={New=function()made=made+1;return{Update=Noop,Dispose=Noop}end}
 local host=Host.New({});host.state.scene={};host.state.session={combat={player=player}}
 local I={ready=true,playing=false,shot='fixture',time=0,audio={Sfx=function(_,id)if id=='laser_big'then laser=laser+1 end end}}
 host.SortieStep(4,I);player.alive=false;now=deadAt;I.time=now;host.Update(.01,I);I.time=1.8;host.Update(.01,I)
 Check(made==0 and laser==0,'Death during lock prevents a stale visual strike '..deadAt)
end
for _,phase in ipairs({'pending','fired'})do
 local made,disposed,laser=0,0,0
 local player={alive=true,Position=function()return{62,2,-176}end,vehicle={Place=Noop}}
 package.loaded['intro.IntroStrike']={New=function()made=made+1;return{Update=Noop,Dispose=function()disposed=disposed+1 end}end}
 local host=Host.New({});host.state.scene={};host.state.sortieStarted=true
 host.state.session={Pause=Noop,ResetCamera=Noop,view={ResetPose=Noop,Update=Noop},
  combat={player=player,EndSortie=Noop,montage={Activate=function()return player end}}}
 local I={ready=true,playing=false,shot='fixture',time=0,audio={Sfx=function(_,id)if id=='laser_big'then laser=laser+1 end end}}
 host.SortieStep(4,I)
 if phase=='fired'then I.time=1.8;host.Update(.01,I)end
 local beforeMade,beforeLaser=made,laser;host.EndSortie();I.time=2;host.Update(.01,I);host.EndSortie()
 Check(not host.state.strike and not host.state.strikePending and not host.state.strikeAt,'Sortie exit clears all strike ownership '..phase)
 Check(made==beforeMade and laser==beforeLaser,'Sortie exit cannot fire a late beam or cue '..phase)
 Check(disposed==(phase=='fired'and 1 or 0),'Sortie exit disposes active beam once '..phase)
end
local Shots=assert(loadfile(SHOTS_PATH))()
local cameraCases={}
local function near(actual,expected,label)
 for n=1,3 do Check(math.abs(actual[n]-expected[n])<1e-8,label..'/'..n)end
end
for _,size in ipairs({{1600,900},{840,378},{1024,768}})do
 graphics={GetWidth=function()return size[1]end,GetHeight=function()return size[2]end}
 for _,case in ipairs(STRIKE_REFERENCE.cameraCases)do
  local presented={x=0,y=0,z=0};local beginCount=0
  local host=Host.New({car={SetVisible=Noop},graphicsSettings={SetSceneVisible=Noop}})
  host.state.hallActor={SetVisible=Noop}
  host.state.session={camera={GetCamera=function()return{node={position=presented}}end},combat={BeginSortie=function()beginCount=beginCount+1 end}}
  host.GroundAt=function(x,z)return x*.01-z*.02 end
  host.SortieStatus=function()return{pos={62,host.GroundAt(62,-176)+1.5,-176},yaw=0}end
  local I={host=host,time=0,sortieCountdownFrom={999,999,999}}
  host.Shot('sortie-brief',I);Check(I.sortieCountdownFrom==nil,'New brief clears previous countdown snapshot')
  local brief=Shots.Camera('sortie-brief',case.wait,I);near(brief,case.from,'Source brief pose after wait '..case.wait)
  presented={x=-brief[1],y=brief[2],z=brief[3]}
  host.Shot('sortie-countdown',I);near(I.sortieCountdownFrom,case.from,'Host reflects actual last presented camera once')
  presented.x=12345;presented.y=23456;presented.z=34567
  for _,frame in ipairs(case.frames)do
   local p,look,fov=Shots.Camera('sortie-countdown',frame.age,I)
   near(p,frame.position,'Executed source countdown position '..case.wait..'/'..frame.age)
   near(look,frame.look,'Executed source countdown look '..case.wait..'/'..frame.age)
   Check(math.abs(fov-frame.fov)<1e-8,'Executed source countdown FOV '..frame.age)
   near(I.sortieCountdownFrom,case.from,'Countdown frames never mutate saved start')
  end
  -- An interrupted countdown may return to a new brief on the same owner.
  host.Shot('sortie-brief',I);Check(I.sortieCountdownFrom==nil and beginCount==2,'Cancellation and reentry cannot retain old snapshot')
  local again=Shots.Camera('sortie-brief',2.2,I);presented={x=-again[1],y=again[2],z=again[3]}
  host.Shot('sortie-countdown',I);near(Shots.Camera('sortie-countdown',0,I),again,'Reentry inherits replacement presented pose')
  cameraCases[#cameraCases+1]={wait=case.wait,viewport=size,from=case.from}
 end
end
return{count=#checks,checks=checks,missileDependencies=missiles,oldDependencyCount=#old,newDependencyCount=#actual,strikes=strikeCases,cameras=cameraCases}

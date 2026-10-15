local SceneWorld=require 'drive.CraterWorld'
local BP=require 'construction.Blueprint'
local Pool=require 'intro.IntroMontagePool'
local function Count(values)local n=0;for _ in pairs(values)do n=n+1 end;return n end
V.atFrame(2,function()
 local scene=Scene();scene:CreateComponent('Octree')
 local world=SceneWorld.New(scene,true);local source=require('construction.Prefab').BuildRaceCar(BP.New()):ToTable()
 local data=require('intro.IntroSession').Data();local camera=scene:CreateChild('FixtureCamera')
 local session={scene=scene,world=world,fxContext={camera=camera,time=0,fov=60}}
 local practice=require('app.PracticeSession').New(session,BP.New():Load(source))
 local placeholder=practice.player;local placeholderBody=placeholder.vehicle.body;world.feedbackPlayer=placeholder
 local battle=require('intro.IntroBattle').New(session,data,source)
 V.assert(session.practice==nil and practice.disposed and practice.session==nil and practice.world==nil and practice.player==nil,'opening detaches the actual previous practice controller before replacing its roster')
 V.assert(not placeholderBody.isValid() and not placeholder.alive and world.feedbackPlayer==battle.player,'opening retires the actual placeholder body and transfers damage attribution to the new teaching player')
 session.vehicle=battle.player.vehicle;session.weapons=battle.player.weapons
 session.view=require('render.DriveView').New(scene,battle.player.bp,session.vehicle)
 V.assert(#world.units==9 and #battle.entries==9 and session.combat==battle,'real original roster and cancellation ownership established before pool')
 local initialBodies=Count(world.space.bodies);local checkpoints=0
 local pool=Pool.New(session,battle,data.actors.hero,function()checkpoints=checkpoints+1 end)
 local hero,view=pool.unit,pool.view;local native=hero.vehicle.native;local body=hero.vehicle.body
 V.assert(hero.bp:Size()==431 and hero.source==data.actors.hero and checkpoints>=431,'exact frozen431hero prepared using shared per-part checkpoints')
 V.assert(#world.units==9 and #battle.entries==9 and Count(world.space.bodies)==initialBodies+1,'standby hero never enters active actor or driver rosters')
 V.assert(not native.enabled and not view.view.root.enabled and hero.externalView and hero.externalControl and not hero.autoRespawn,'standby native body and actual view disabled with source control contracts')
 local noEvents=true;for _,event in ipairs(world.viewEvents)do noEvents=noEvents and event.unit~=hero end
 V.assert(noEvents,'held actor has no spawn event for shared renderer or audio to consume')
 local p=body.translation();for i=1,12 do world.space:Step(1/60)end;local q=body.translation()
 V.assert(math.abs(p.y-q.y)<.000001,'disabled actual Bullet hero cannot fall or integrate during teaching')
 local hits=world.space.world:Raycast(Ray(native.position+Vector3(0,100,0),Vector3.DOWN),200)
 local isolated=true;for _,hit in ipairs(hits)do isolated=isolated and hit.body~=native end
 V.assert(isolated,'standby actual compound body absent from native Bullet ray hits')
 local ids={};for id,vis in pairs(view.view.visuals)do ids[id]=vis.node end
 pool:SetWarmVisible(true);V.assert(view.view.root.enabled and not native.enabled,'shader prewarm enables real original visuals without enabling physics')
 pool:SetWarmVisible(false);V.assert(not view.view.root.enabled and not native.enabled,'prewarm exit restores held visual and physical isolation')
 local old=battle.player;local oldBody=old.vehicle.body;battle:Kill(old)
 V.assert(not old.alive and not oldBody.isValid(),'actual source teaching destruction retires old player body')
 world.viewEvents={};local before=Count(world.space.bodies);local active=pool:Activate()
 V.assert(active==hero and session.view==view and active.vehicle.body==body and native.enabled,'montage activates the exact prepared431hero view and native body')
 V.assert(world.units[1]==hero and battle.entries[1].unit==hero and battle.player==hero and world.feedbackPlayer==hero and #world.units==9 and #battle.entries==9,'all actual active roster and hit-feedback ownership transfers atomically')
 V.assert(session.vehicle==hero.vehicle and session.weapons==hero.weapons and Count(world.space.bodies)==before,'activation reuses existing actual weapons and physics without another spawn')
 local same=true;for id,vis in pairs(session.view.view.visuals)do same=same and ids[id]==vis.node end
 V.assert(same and Count(ids)==431,'every original hero model node identity survives the real cut')
 local newSpawn=false;for _,event in ipairs(world.viewEvents)do newSpawn=newSpawn or event.unit==hero and event.type=='unitSpawn' end
 V.assert(not newSpawn and pool:Activate()==hero,'activation cannot trigger shared PlayerViewSync rebuild and is idempotent')
 local attacker;world.Hit=function(w)attacker=w.attacker end
 battle.entries[1].env.hit({owner={type='car',ref=battle.easy}},1,{0,0,1},0)
 V.assert(attacker==hero,'new weapon environment records new hero as attacker instead of destroyed teaching player')
 pool:Dispose();V.assert(body.isValid() and session.view==view,'disposed transferred pool cannot destroy session-owned live hero')
 local baseline=Count(world.space.bodies);local children=#scene:GetChildren(true)
 local ok,err=pcall(Pool.New,session,battle,data.actors.hero,function()error('fixture-cancel-at-original-part')end)
 V.assert(not ok and tostring(err):find('fixture%-cancel%-at%-original%-part') and battle.montage.view,'real per-part prepare cancellation retains partially built view ownership')
 battle.montage:Dispose()
 V.assert(Count(world.space.bodies)==baseline and #scene:GetChildren(true)==children and body.isValid(),'cancelling held preparation releases body and partial models while preserving live session')
 local held=Pool.New(session,battle,data.actors.hero);local heldBody=held.unit.vehicle.body
 battle:Dispose();V.assert(not heldBody.isValid() and Count(world.space.bodies)==baseline,'ordinary battle shutdown also releases an unactivated full pool exactly once')
 session.view:Dispose();world:Dispose();V.assert(not body.isValid(),'transferred hero finally disposes through ordinary shared world ownership')
 scene:Dispose();V.finish()
end)

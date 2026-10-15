local Director=require('salvage.Director')
local Data=require('core.ResourceData').Read('Salvage/RunData.json')
local function Near(a,b) return math.abs(a-b)<1e-7 end
V.atFrame(10,function()
    local pos={200,0,0};local spawned={};local events={};local feed={};local calls=0
    local player={Position=function() return pos end}
    local run={player=player,entries={{unit=player}},rules={time=10,heat=0,kills=3,rand=function() return .5 end,
        AddExtra=function(_,object) events[#events+1]=object end},Feed=function(_,a,b) feed[#feed+1]={a,b} end,
        cine={NameCard=function() end,Flash=function() end}}
    local d=setmetatable({run=run,entries=run.entries,world={layout={salvage={gameplay={enemySpawns={}}}}},encounters={},timer=0,huntLeft=60},Director)
    d.Surface=function(_,x,z) return {x,0,z} end
    d.Add=function(_,kind,at,yaw,enc,seed)
        local u={alive=true,hitAt=0,Position=function() return at end}
        local e={unit=u,post=at,kind=kind,enc=enc,yaw=yaw,seed=seed,hit0=0}
        d.entries[#d.entries+1]=e;if enc then enc.units[#enc.units+1]=e end;spawned[#spawned+1]=e;return e
    end
    local patrol={kind='patrol',g={0,0,0},left={'rat','rat'},units={},route={{0,0,0},{-10,0,5},{-20,0,10},{-30,0,5},{-40,0,0}}}
    d:Spawn(patrol)
    V.assert(#spawned==2 and spawned[1].wp==3 and spawned[2].wp==5,'source patrol spawns at alternating route points and targets next points')
    V.assert(Near(spawned[1].yaw,math.atan(20,10)) and Near(spawned[2].yaw,math.atan(20,-10)),'source patrol spawn yaw follows route instead of aiming at player')
    local nest={kind='nest',g={0,0,0},left={'rat'},units={},posts={{-20,0}}}
    d.Surface=function(_,x,z) calls=calls+1;if calls<3 then return nil end;return {x,0,z} end
    d:Spawn(nest)
    V.assert(calls==3 and #nest.units==1 and Near(nest.units[1].yaw,math.atan(-20,0)+math.pi),'source nest retries safe surface samples and faces away from center')
    d.Surface=function(_,x,z) return {x,0,z} end
    local camp={kind='camp',g={0,0,0},left={'rat','rat'},units={},ring={20,50}}
    d:Spawn(camp)
    V.assert(#camp.units==2 and Near(camp.units[1].post[3],-35) and Near(camp.units[2].post[3],35),'source ring distributes camp guards around encounter')
    V.assert(Near(camp.units[1].yaw,math.atan(camp.units[1].post[1],camp.units[1].post[3])),'source camp guard faces outward before alert')
    local ambush={kind='ambush',name='伏击',g={0,0,0},left={'rat'},units={},ring={20,50}}
    d:Spawn(ambush)
    V.assert(ambush.alerted and Near(ambush.units[1].yaw,math.atan(pos[1]-ambush.units[1].post[1],pos[3]-ambush.units[1].post[3])),'source ambush faces player and alerts immediately')
    local convoy={kind='patrol',id='convoy',name='车队',g={0,0,0},state='active',units={},reward=2}
    d.encounters={convoy};d:Step(.25)
    local reward=events[#events];local loot=reward.loot;local n=#Data.crateLoot[3]
    V.assert(convoy.state=='cleared' and reward.id=='C:convoy' and #loot==n+2,'source convoy clear adds cache plus original extra reward rows')
    V.assert(loot[n+1][1]=='ore' and loot[n+1][2]==2 and loot[n+1][3]==4 and loot[n+2][1]=='cell' and loot[n+2][4]==.7 and #Data.crateLoot[3]==n,'convoy extra ore/cell does not mutate shared crate rewards')
    local guard={unit={alive=true,hitAt=0,Position=function() return {0,0,0} end},hit0=0}
    local encounter={kind='camp',id='camp',name='据点',g={0,0,0},state='active',units={guard},aggroR=100}
    d.encounters={encounter};d:Step(.25)
    V.assert(run.threat and run.threat.n==1 and run.threat.d==200 and not run.threat.alerted,'unnoticed encounter reports calm nearest threat')
    guard.unit.hitAt=1;d:Step(.25)
    V.assert(encounter.alerted and run.threat.alerted,'real hit timestamp alerts encounter and updates threat state')
    pos={500,0,0};d:Step(.25);V.assert(run.threat==nil,'threat disappears beyond source 400 meter range')
    d.encounters={};run.rules.heat=80;d.huntLeft=0;local hunters=0;d.Hunt=function(_,n) hunters=n end;d:Step(.25)
    V.assert(hunters==2 and feed[#feed][1]=='追兵','source high heat spawns two hunters and reports reinforcement feed')
    local rules=require('salvage.RunRules').New({loot={},wrecks={},extracts={}},Data.ops[1])
    rules.objects={{id='near',kind='wreck',model='core',name='近核心',g={10,0,0}},{id='far',kind='wreck',model='core',name='远核心',g={20,0,0}}}
    rules.extracts={{id='A',name='近撤离',g={5,0,0},openAt=600},{id='B',name='远撤离',g={30,0,0}}}
    local target=rules:Objective({0,0,0})
    V.assert(target.text=='核心件 · 近核心' and target.dist==10,'source early empty cargo objective chooses nearest unopened core')
    rules.opened.near=true;target=rules:Objective({0,0,0})
    V.assert(target.text=='核心件 · 远核心','objective ignores searched core')
    rules.cargo={scrap=require('salvage.Loot').Stack('scrap')*15};target=rules:Objective({0,0,0})
    V.assert(target.text=='撤离 B · 远撤离','75 percent cargo directs to currently open extraction, ignores locked one')
    rules.cargo={};rules.time=600;target=rules:Objective({0,0,0})
    V.assert(target.text=='核心件 · 远核心','source exact 10 minute boundary still permits core objective')
    rules.time=600.1;target=rules:Objective({0,0,0})
    V.assert(target.text=='撤离 A · 近撤离' and target.dist==5,'source after 10 minutes objective chooses nearest open exit')
    rules.objects={};rules.extracts={};V.assert(rules:Objective({0,0,0})==nil,'missing objective hides arrow instead of inventing a target')
    rules.objects={{id='core',kind='wreck',model='core',name='核心',g={0,0,0}}};rules.time=0;rules.heat=0
    rules:Step(1,{alive=true,pos={0,0,0},speed=0,width=5,hold=true})
    V.assert(rules.heat==1 and rules.prompt.sub=='拆卸中…' and rules.act.t==1,'source held dismantling raises heat continuously and shows actual progress label')
    rules:Step(5,{alive=true,pos={0,0,0},speed=0,width=5,hold=true})
    local coreEvent=false;for _,e in ipairs(rules:Drain()) do if e.type=='core' then coreEvent=true end end
    V.assert(rules.opened.core and coreEvent,'completed core emits original name-card and flash event')
    local scene=Scene();scene:CreateComponent('Octree')
    rules.objects={};rules.extracts={{id='locked',g={0,0,0},radius=14,openAt=600},{id='open',g={30,0,0},radius=20}};rules.time=0
    local view=require('render.SalvageView').New({session={scene=scene},world={physicsData={lootModels={}}},rules=rules})
    V.assert(view.exits[1].node.enabled and view.exits[1].state=='closed' and view.exits[2].state=='open','original locked red signal remains visible beside open cyan signal')
    local geom=view.exits[1].node:GetComponent('CustomGeometry');local bounds=geom.worldBoundingBox
    V.assert(geom:GetNumVertices(0)==528,'source 24-segment beam and 64-segment ring are preserved without extra tessellation')
    V.assert(math.abs(bounds.min.y+2)<.001 and math.abs(bounds.max.y-258)<.001,'source extraction beam covers original ground-to-260-meter world span')
    rules.time=601;view:Update();V.assert(view.exits[1].state=='open','real extraction view opens locked signal at source timestamp')
    rules.ex={e=rules.extracts[2]};view:Update();V.assert(view.exits[2].state=='extracting','real extraction view turns active extraction green')
    local fx=require('render.SalvageFx').New(scene,function() return .5 end)
    local run=setmetatable({rules=rules,fx=fx,session={scene=scene},audio={Event=function() end},cine={Flash=function() end,NameCard=function() end},director={Noise=function() end,Hunt=function() end},Feed=function() end},require('salvage.Run'))
    rules.events={};rules.search=nil
    rules:Emit('worldLoot',{at={3,0,0},color=0xffb21e,n=3});run:Events()
    V.assert(fx.bi==2 and fx.ci==4 and fx.beams[1].node.position.x==-3,'actual Run event consumer dispatches grouped world loot into source visual pools')
    rules:Emit('reveal',{item={id='scrap',n=1,r=4},taken=1,worldBatch=true,at={4,0,0}});run:Events()
    V.assert(fx.bi==2 and fx.ci==4,'grouped wreck reveal cannot duplicate source rare beam or pickup flights')
    local wreckRules=require('salvage.RunRules').New({loot={},wrecks={},extracts={}},Data.ops[1],function() return .5 end)
    wreckRules.objects={{id='w',kind='wreck',model='core',name='核心',g={0,0,0}}}
    wreckRules:Step(6,{alive=true,pos={0,0,0},speed=0,width=5,hold=true})
    local grouped=0;local got=0;for _,event in ipairs(wreckRules:Drain()) do if event.type=='worldLoot' then grouped=grouped+1;got=event.n end end
    V.assert(grouped==1 and got>0,'actual wreck dismantling emits one grouped visual event for successfully taken items')
    local blocked=require('salvage.RunRules').New({loot={},wrecks={},extracts={}},Data.ops[1],function() return .5 end)
    blocked.objects={{id='w',kind='wreck',model='core',name='核心',g={0,0,0}}};blocked.cargo={scrap=require('salvage.Loot').Stack('scrap')*20}
    blocked:Step(6,{alive=true,pos={0,0,0},speed=0,width=5,hold=true})
    local phantom=false;for _,event in ipairs(blocked:Drain()) do phantom=phantom or event.type=='worldLoot' end
    V.assert(not phantom and not blocked.opened.w,'zero cargo capacity prevents phantom pickup visual and consumed wreck')
    fx:Dispose()
    view:Dispose();scene:Dispose()
    V.finish()
end)

local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
package.path='scripts/?.lua;'..package.path
package.loaded['core.ResourceData']={Read=function(path) return resources[path] end}
package.loaded['combat.CarUnit']={};package.loaded['salvage.Drops']={}
package.loaded['ui.SourceDraw']={}
local Loot=require 'salvage.Loot'
local Rules=require 'salvage.RunRules'
local Run=require 'salvage.Run'
local Motion=require 'ui.SalvageLootMotion'
local function New()
    return Rules.New({loot={},wrecks={},extracts={}},{vaults=0},function() return 0 end)
end
local function Search(r,item)
    r.search={o={g={0,0,0}},title='test',items={item},i=1,p=0,wait=0,value=0}
end
local function Count(events,kind)
    local list={};for _,e in ipairs(events) do if e.type==kind then list[#list+1]=e end end;return list
end
local function Consume(r)
    local events=r:Drain();r.events=events
    local run=setmetatable({rules=r,session={stompV=0},audio={Event=function() end},feed={},view={Crate=function() end,Hide=function() end}},Run)
    run:Events();return run,events
end
local r=New();Search(r,{id='scrap',n=2,r=0,t=1,state='scan'})
r:SearchStep(1,{pos={0,0,0}})
local run,events=Consume(r)
Check(r.cargo.scrap==2,'normal reveal takes actual two scrap')
Check(#Count(events,'cargoPickup')==1,'normal reveal emits one pickup')
Check(math.abs(run.session.stompV+(.25+16/40))<1e-9,'normal pickup uses exact source mass impulse')
Check(#run.lootFlights==1 and run.lootFlights[1].row==1 and run.lootFlights[1].at==.12,'normal reveal keeps one delayed row flight')
r=New();r.cargo.scrap=400;Search(r,{id='alloy',n=2,left=2,r=1,t=1,state='full'});r.search.i=2;r.search.done=true;r.search.doneAt=0
r:SearchStep(0,{swap=true,pos={7,8,9}})
run,events=Consume(r)
Check(r.cargo.scrap==380 and r.cargo.alloy==2,'real full cargo swap preserves exact dropped and taken counts')
local pickups=Count(events,'cargoPickup');local drops=Count(events,'cargoDropped')
Check(#pickups==1 and pickups[1].swap and pickups[1].items[1][2]==2,'swap pickup records actual added amount')
Check(#drops==1 and drops[1].items[1][1]=='scrap' and drops[1].items[1][2]==20,'swap emits exact dropped stack')
Check(#Count(events,'reveal')==0 and not run.lootPulse,'swap does not repeat reveal or jackpot')
Check(#run.lootFlights==1 and run.lootFlights[1].row==nil and run.lootFlights[1].at==0,'swap flies once immediately from screen center')
Check(math.abs(run.session.stompV+(.25+12/40))<1e-9,'swap presses by incoming alloy weight only')
Check(#run.feed==1 and run.feed[1].title=='丢掉' and run.feed[1].text=='废金属 × 20 丢在了原地','swap shows exact discarded goods notification')
local box=r.objects[1]
Check(box.kind=='cache' and box.g[1]==7 and box.g[2]==7.2 and box.g[3]==9,'dropped cache stays at source player position minus 0.8 m')
r:Open(box)
Check(r.search.items[1].id=='scrap' and r.search.items[1].n==20,'real dropped cache reopens with all discarded stock')
r=New();r.cargo.scrap=400;Search(r,{id='scrap',n=1,left=1,r=0,t=1,state='full'});r.search.i=2;r.search.done=true;r.search.doneAt=0
r:SearchStep(0,{swap=true,pos={0,0,0}});run,events=Consume(r)
Check(#Count(events,'cargoPickup')==0 and #Count(events,'cargoDropped')==0 and run.session.stompV==0,'impossible same-item swap emits no false feedback')
r=New();r.objects={{id='W',kind='wreck',model='core',name='core',g={0,0,0}}}
r:Step(6,{alive=true,pos={0,0,0},speed=0,width=1,hold=true})
events=r:Drain();local batch=Count(events,'cargoPickup')
Check(#batch==1 and batch[1].worldBatch,'wreck emits one aggregate pickup event')
local mass=0;for _,row in ipairs(batch[1].items) do mass=mass+(resources['UI/Outgame.json'].items[row[1]].mass or 1)*row[2] end
-- Exclude independent core cinematic/noise consumers from this isolated feedback check.
r.events={};for _,e in ipairs(events) do if e.type=='reveal' or e.type=='cargoPickup' then r.events[#r.events+1]=e end end
run=Consume(r)
Check(math.abs(run.session.stompV+math.min(1.6,.25+mass/40))<1e-9,'wreck sums all actual masses before one source cap')
Check(#run.lootFlights==math.min(6,#batch[1].items),'wreck caps flights to six actual picked item kinds')
for i,f in ipairs(run.lootFlights) do
    Check(math.abs(f.at-(6+.26+(i-1)*.11))<1e-9 and f.row==nil,'wreck staggered source timeline '..i)
end
local noSpring={rules={time=0,Drain=function() return {{type='cargoPickup',items={{'scrap',400}}}} end},session={},audio={Event=function() end}}
Run.Events(noSpring)
Check(noSpring.session.stompV==nil,'pickup preserves source missing-spring guard')
local large={rules={time=0,Drain=function() return {{type='cargoPickup',items={{'scrap',400}}}} end},session={stompV=2},audio={Event=function() end}}
Run.Events(large)
Check(math.abs(large.session.stompV-.4)<1e-9,'heavy pickup uses 1.6 cap without resetting spring velocity')
return checks

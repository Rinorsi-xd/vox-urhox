const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const port=Number(process.env.VOX_QA_PORT||4271),base='http://127.0.0.1:'+port;
const gp=require('../../assets/Salvage/Gameplay.json'),delay=ms=>new Promise(r=>setTimeout(r,ms));
const flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
const {NaturalProgress}=require('./salvage-natural-progress.cjs');
const {RoadFollower,assertNetResult,assertSavedInventory,assertCountdown}=require('./salvage-natural-navigation.cjs');
function sourceRoadRoute(from,to,options={}){
 const nodes=gp.nav.nodes,ids=Object.keys(nodes),adj=new Map(ids.map(id=>[id,[]]));
 for(const [a,b,width] of gp.nav.edges){if(!nodes[a]||!nodes[b])continue;const rise=Math.abs(nodes[a][1]-nodes[b][1]),run=flat(nodes[a],nodes[b]);if(options.maxSlope&&Math.atan2(rise,run)>options.maxSlope*Math.PI/180)continue;const center=nodes[a].map((v,i)=>(v+nodes[b][i])/2),threat=options.avoidThreats&&gp.encounters.some(e=>flat(center,[-e.x,e.y,e.z])<(e.aggroR||140));const cost=Math.hypot(...nodes[a].map((v,i)=>v-nodes[b][i]))+(threat?160:0);adj.get(a).push([b,cost,width]);adj.get(b).push([a,cost,width]);}
 const near=(p)=>ids.reduce((best,id)=>flat(nodes[id],p)+Math.abs(nodes[id][1]-p[1])*3<flat(nodes[best],p)+Math.abs(nodes[best][1]-p[1])*3?id:best,ids[0]);
 const start=near(from),end=near(to),distance=new Map([[start,0]]),previous=new Map(),widths=new Map(),done=new Set();
 while(done.size<ids.length){let next;for(const [id,d] of distance)if(!done.has(id)&&(!next||d<distance.get(next)))next=id;if(!next)break;if(next===end)break;done.add(next);
  for(const [id,cost,width]of adj.get(next)){const d=distance.get(next)+cost;if(d<(distance.get(id)??Infinity)){distance.set(id,d);previous.set(id,next);widths.set(id,width);}}
 }
 assert.ok(distance.has(end),'Original road graph connects loot to extraction');const route=[];
 for(let id=end;id;id=previous.get(id)){route.unshift({id,g:nodes[id],width:widths.get(id)||16});if(id===start)break;}
 const length=route.slice(1).reduce((sum,p,i)=>sum+Math.hypot(...p.g.map((v,k)=>v-route[i].g[k])),0);
 return {distance:length,weightedCost:distance.get(end),start,end,points:route};
}
function sourceRaidRoute(from){
 const point=o=>[-o.x,o.y,o.z],candidates=[];
 const crates=gp.loot.filter(o=>o.tier===0&&Math.abs(o.y-from[1])<15).sort((a,b)=>flat(point(a),from)-flat(point(b),from)).slice(0,6);
 for(const crate of crates)for(const exit of gp.extracts.filter(o=>o.id==='E1'||o.id==='E3')){
  let road,approachRoad;try{road=sourceRoadRoute(point(crate),point(exit),{maxSlope:35,avoidThreats:true});}catch{try{road=sourceRoadRoute(point(crate),point(exit));road.steepFallback=true;}catch{continue;}}
  try{approachRoad=sourceRoadRoute(from,point(crate));}catch{}
  const direct=flat(from,point(crate));
  if(approachRoad&&approachRoad.distance>direct*1.6+50)approachRoad=null;
  const approach=approachRoad?flat(from,approachRoad.points[0].g)+approachRoad.distance+flat(approachRoad.points.at(-1).g,point(crate)):flat(from,point(crate));
  const sampleCount=Math.ceil(approach/20)+1;
  const approachPoints=approachRoad?.points||Array.from({length:sampleCount},(_,i)=>({g:from.map((v,k)=>v+(point(crate)[k]-v)*i/Math.max(1,sampleCount-1))}));
  const exposed=[...approachPoints,...road.points].filter(p=>gp.encounters.some(e=>flat(p.g,point(e))<(e.aggroR||140))).length,score=road.distance+approach*2+exposed*80+(road.steepFallback?10000:0);
  candidates.push({crate:{...crate,g:point(crate)},exit:{...exit,g:point(exit)},road,approachRoad,exposed,approach,score});
 }
 assert.ok(candidates.length,'A source-connected raid route exists');return candidates.sort((a,b)=>a.score-b.score)[0];
}
async function run(){
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa);
 const out=path.resolve('docs/migration/evidence/salvage-natural-'+path.basename(identity.manifest_path,'.json')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log('Evidence: '+out);
 const browserOptions={headless:true,channel:'chrome',args:['--use-angle=d3d11']};
 const profile=process.env.VOX_NATURAL_PROFILE&&path.resolve(process.env.VOX_NATURAL_PROFILE);
 const profileExistedBefore=Boolean(profile&&fs.existsSync(profile));
 const browser=profile?await chromium.launchPersistentContext(profile,{...browserOptions,viewport:{width:1600,height:900}}):await chromium.launch(browserOptions);
 const page=profile?await browser.newPage():await browser.newPage({viewport:{width:1600,height:900}}),prefix='salvage-natural-web';
 let state,seq=0,inventoryBefore,mouseX=800;const held=new Set();
 const aimDriven=()=>Object.keys(inventoryBefore?.installed||{}).some(id=>/^part:(mech|leg|hover)\d/.test(id));
 const report={identity,result:'RUNNING',shutdown:'PENDING',checks:[],errors:[],probeErrors:[],samples:[],boundary:'Only F8 reads QA state. Route uses held W/A/D/Space and E, no teleport, cargo, death or clock fixture. Parallel functional run, not isolated performance measurement.',startedAt:new Date().toISOString()};
 report.economyBoundary='UI/SalvageRules.json in the frozen package sets testFill:999; existing stock and purchase flow are functional evidence, not real-account economy or earned-stock evidence.';
 report.browser={persistent:Boolean(profile),profile:profile||null,profileExistedBefore,network:{requests:0,responses:0,diskCacheResponses:0,cacheResponses:0,serviceWorkerResponses:0,encodedBytes:0}};
 function persist(){report.lastState=state;fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));}
 persist();await page.bringToFront();
 const network=await page.context().newCDPSession(page),cached=new Set();await network.send('Network.enable');
 network.on('Network.requestWillBeSent',()=>report.browser.network.requests++);
 network.on('Network.requestServedFromCache',e=>{cached.add(e.requestId);report.browser.network.cacheResponses=cached.size;});
 network.on('Network.responseReceived',e=>{const n=report.browser.network;n.responses++;if(e.response.fromDiskCache){n.diskCacheResponses++;cached.add(e.requestId);n.cacheResponses=cached.size;}if(e.response.fromServiceWorker)n.serviceWorkerResponses++;});
 network.on('Network.loadingFinished',e=>report.browser.network.encodedBytes+=e.encodedDataLength);
 fs.writeFileSync(path.join(out,prefix+'.log'),'');
 page.on('console',m=>{const t=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),t+'\n');const at=t.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(t.slice(at+14));if(state.loading)report.latestLoading=structuredClone(state.loading);seq++;}catch(e){report.probeErrors.push({message:e.message,length:t.length});persist();}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t)){report.errors.push(t);persist();}});
 page.on('pageerror',e=>{report.errors.push(e.stack||e.message);persist();});
 page.on('crash',()=>{report.errors.push('Browser page crashed');persist();});
 async function wait(fn,label,limit=240000){const start=Date.now();let probe=0;while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(state?.loadingFlow?.failed)throw Error('Actual loading failure: '+state.loadingFlow.error);if(Date.now()-start>limit)throw Error('Timeout '+label);if(Date.now()-probe>800){probe=Date.now();await page.keyboard.press('F8');}await delay(100);}return state;}
 async function dump(){const before=seq;await page.keyboard.press('F8');await wait(()=>seq>before,'fresh state',15000);return state;}
 const widgets=()=>Array.isArray(state?.widgets)?state.widgets:[];
 const position=()=>state.vehicle.center||state.vehicle.position;
 async function click(text,match){let b;const begun=Date.now();while(!b){await dump();b=widgets().filter(w=>!w.disabled&&(!w.entrance||w.entrance.opacity>.9)&&(match?match(w):w.text===text)).at(-1);if(!b){assert.ok(Date.now()-begun<20000,'Actual visible button '+text);await delay(160);}}const r=b.rect,c=await page.locator('canvas').boundingBox();await page.mouse.click(c.x+(r[0]+r[2]/2)*c.width/state.width,c.y+(r[1]+r[3]/2)*c.height/state.height);await delay(500);}
 async function keys(next=[]){for(const k of held)if(!next.includes(k)){await page.keyboard.up(k);held.delete(k);}for(const k of next)if(!held.has(k)){await page.keyboard.down(k);held.add(k);}}
 const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);persist();};
 async function shot(name){persist();await page.screenshot({path:path.join(out,prefix+'-'+name+'.png'),timeout:15000});}
 function settlementInventory(){
  assert.ok(inventoryBefore&&state.salvageInventory,'Actual read-only before/after inventory is available');
  const before=inventoryBefore,after=state.salvageInventory,result=state.salvageRun.result;
  const all=new Set([...Object.keys(before.items),...Object.keys(after.items)]);
  for(const id of all){const expected=result.ok?(before.items[id]||0)+(result.cargo[id]||0):Math.max(0,(before.items[id]||0)-(result.keepCar?0:(before.installed[id]||0)));assert.equal(after.items[id]||0,expected,'Natural settlement actual stock '+id);}
  check(true,result.ok?'Natural extraction adds exactly committed cargo to real stash':'Natural death deducts every original installed part and discards all cargo');
  check(after.stats.raids===before.stats.raids&&after.stats[result.ok?'extracted':'lost']===(before.stats[result.ok?'extracted':'lost']||0)+1,'Natural settlement counts outcome once without double counting raid start');
  check(after.lastRun===after.lastStartedRun,'Natural settlement saves the actual started run transaction');report.inventoryAfter=structuredClone(after);
 }
 async function drive(target,seconds=150,passing=false){const started=Date.now(),progress=new NaturalProgress();
  while(Date.now()-started<seconds*1000){await dump();if(passing?.extract&&state.salvageRun.cine.name==='extract')return;checkAlive();const p=position(),d=flat(p,target),speed=Math.abs(state.vehicle.speed||0);
   if(passing&&d<(passing.radius||Math.min(6,passing.width*.2)))return;
   const mech=aimDriven();
   if(d<11&&speed<1){await keys(mech?[]:['Space']);await delay(400);await keys();await dump();checkAlive();if(flat(position(),target)<13)return;}
   const reversing=progress.update(p,Date.now());
   const angle=wrap(Math.atan2(target[0]-p[0],target[2]-p[2])-state.vehicle.yaw);
   const throttle=reversing?'s':'w';const steeringAngle=throttle==='s'?-angle:angle;
   const turn=Math.abs(steeringAngle)>.12?(steeringAngle>0?'a':'d'):null;
   if(mech){const wanted=-Math.atan2(target[0]-p[0],target[2]-p[2]),error=wrap(wanted-state.camera.yaw*Math.PI/180),dx=Math.max(-300,Math.min(300,error/.0024));mouseX+=dx;await page.mouse.move(mouseX,450);}
   const targetSpeed=passing?Math.max(2,Math.min(10,passing.width*.4)*(1-.7*Math.min(1,Math.abs(angle)/1.2))):Math.max(2,Math.min(16,Math.sqrt(d)*2));
   const braking=throttle==='w'&&((!passing&&d<11)||speed>targetSpeed);
   await keys(braking?(mech?[]:['Space']):[throttle,...(!mech&&turn?[turn]:[])]);report.samples.push({at:Date.now()-started,pos:p,yaw:state.vehicle.yaw,speed,distance:d,angle,keys:[...held],hp:state.reticle.hp,enemies:state.salvageRun.enemies});await delay(d<35?160:350);
  }throw Error('Natural route did not reach '+JSON.stringify(target));
 }
 async function roadDrive(route,label){
  const follower=new RoadFollower(route.points),progress=new NaturalProgress(),started=Date.now();
  // This is a tool watchdog. The production 900-second raid limit is untouched.
  const budget=Math.min(720,Math.max(120,route.distance/4+60))*1000;
  let previous,previousAt,index=-1;
  while(Date.now()-started<budget){
   await dump();checkAlive();const now=Date.now(),p=position();
   const observed=previous?flat(p,previous)/Math.max(.001,(now-previousAt)/1000):0;
   const speed=Math.max(Math.abs(state.vehicle.speed||0),observed),step=follower.update(p,speed);
   previous=[...p];previousAt=now;
   report[label+'Passed']=follower.passed;
   if(step.done){await keys();persist();return;}
   report[label+'At']=step.point.id;
   if(index!==step.index){index=step.index;persist();}
   const target=step.target,angle=wrap(Math.atan2(target[0]-p[0],target[2]-p[2])-state.vehicle.yaw),mech=aimDriven();
   const reversing=progress.update(p,now),throttle=reversing?'s':'w',steer=throttle==='s'?-angle:angle;
   if(mech){const wanted=-Math.atan2(target[0]-p[0],target[2]-p[2]),error=wrap(wanted-state.camera.yaw*Math.PI/180);mouseX+=Math.max(-300,Math.min(300,error/.0024));await page.mouse.move(mouseX,450);}
   const targetSpeed=Math.max(2,Math.min(13,(step.point.width||16)*.6)*(1-.65*Math.min(1,Math.abs(angle)/1.2)));
   const braking=!reversing&&speed>targetSpeed;
   await keys(braking?(mech?[]:['Space']):[throttle,...(!mech&&Math.abs(steer)>.12?[steer>0?'a':'d']:[])]);
   report.samples.push({stage:label,node:step.point.id,at:now-started,gameTime:state.salvageRun.time,pos:p,yaw:state.vehicle.yaw,speed,observedSpeed:observed,distance:step.distance,angle,keys:[...held],hp:state.reticle.hp,enemies:state.salvageRun.enemies});
   await delay(160);
  }
  throw Error('Natural continuous road watchdog '+label+' at '+report[label+'At']);
 }
 async function extractHold(exit){
  const started=Date.now();report.extractionHold=[];
  while(Date.now()-started<60000){
   await dump();checkAlive();
   report.cargoBeforeExtraction=structuredClone(state.salvageRun.cargo);
   if(state.salvageRun.cine.name==='extract')return;
   const distance=flat(position(),exit.g),ex=state.salvageRun.extraction;
   report.extractionHold.push({wallMs:Date.now()-started,gameTime:state.salvageRun.time,distance,id:ex?.id,left:ex?.left,prompt:state.salvageRun.prompt,cine:state.salvageRun.cine.name});
   if(distance>exit.radius*.6){await drive(exit.g,30,{width:exit.radius*2,radius:exit.radius*.5,extract:true});}
   await keys(aimDriven()?[]:['Space']);await delay(160);
  }
  throw Error('Natural extraction did not complete its original countdown');
 }
 function checkAlive(){if(state.salvageRun?.result)throw Error('Natural route ended '+JSON.stringify(state.salvageRun.result));if(!state.vehicle||!state.vehicle.position)throw Error('Natural vehicle destroyed during route; await actual death settlement');if(report.errors.length)throw Error(report.errors.join('\n'));}
 try{
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'hall');
  await click('打捞行动');await wait(s=>s.tab==='salvage'&&!s.loadingFlow?.active&&!s.vehicleLoading?.busy,'salvage');
  if(process.env.VOX_NATURAL_STRONG==='1'){
   const originalVehicle=process.env.VOX_NATURAL_VEHICLE||'量产机兵 · 突击';assert.ok(require('../../assets/UI/Workshop.json').prefabs.some(v=>v.name===originalVehicle),'Vehicle exists in frozen source workshop');
   const existing=state.garage.slots.findIndex(v=>v&&v.name===originalVehicle);
   if(existing>=0){
    if(state.blueprint!==originalVehicle){await click('车库');await click(originalVehicle);await wait(s=>s.blueprint===originalVehicle&&!s.vehicleLoading?.busy,'actual existing garage vehicle selection');}
    check(state.blueprint===originalVehicle&&state.garage.active===existing+1,'Original vehicle legitimately restored and selected from actual local garage');await shot('reused-original-vehicle');
   }else{
   const used=state.garage.used,starterParts=state.parts;await click('创意工坊');await wait(()=>widgets().some(w=>w.text==='查看全部'&&w.entrance?.opacity>.9),'actual workshop visible feature shelf',20000);check(state.workshop.caption.elapsed>0&&state.workshop.shelf.elapsed>0,'Actual nested workshop source animation clocks and visible shelf advance');
   if(!widgets().some(w=>w.text===originalVehicle)){await click('查看全部');await wait(s=>s.workshop?.view==='browse','actual full source workshop',20000);const sourceVehicle=require('../../assets/UI/Workshop.json').prefabs.find(v=>v.name===originalVehicle);const groupLabels={mech:'机甲',wheel:'轮式',track:'履带',plane:'飞机',pirate:'海盗',blank:'底盘'};if(groupLabels[sourceVehicle.group]){await click(groupLabels[sourceVehicle.group]);await wait(s=>s.workshop.group===sourceVehicle.group,'actual original vehicle group',20000);}}
   await wait(()=>widgets().some(w=>w.text===originalVehicle),'existing official vehicle card',20000);
   await click(originalVehicle);await wait(s=>s.workshop?.view==='detail'&&!s.vehicleLoading?.busy,'actual official vehicle detail');await delay(900);
   await click('购买整车');await wait(s=>s.dialog&&widgets().some(w=>w.text==='购买整车'),'actual vehicle purchase');
   await click('use original stock',w=>w.text.startsWith('用仓库里的零件拼'));
   await wait(s=>!s.dialog&&!s.vehicleLoading?.busy&&s.garage.used===used+1&&widgets().some(w=>w.text==='拆掉这辆车'),'actual purchased vehicle garage');
   check(state.blueprint===originalVehicle&&state.parts>starterParts,'Original vehicle bought and selected through actual workshop/garage UI');await shot('selected-original-vehicle');
   }
   await click('整备');await wait(()=>widgets().some(w=>w.text==='出发'),'actual selected vehicle loadout');
  }
  await click('出发');
  await wait(s=>s.salvageRun&&!s.loadingFlow?.active,'loaded actual raid',600000);report.loadingAtEntry=structuredClone(state.loading||report.latestLoading);report.loadingFlowAtEntry=structuredClone(state.loadingFlow);report.networkAtEntry=structuredClone(report.browser.network);await shot('drop');
  inventoryBefore=structuredClone(state.salvageInventory);report.inventoryBefore=inventoryBefore;
  await wait(s=>s.salvageRun&&!s.salvageRun.cine.playing,'natural drop completion',60000);await page.bringToFront();await page.mouse.click(800,450);await wait(s=>s.pointer.captured,'actual input capture');
  check(Number.isFinite(state.vehicle.yaw),'Actual vehicle yaw available for observed keyboard steering');
  if(process.env.VOX_NATURAL_SAFE_ROUTE==='1')check(Array.isArray(state.vehicle.center),'Read-only actual center of mass is available for source interaction and navigation');
  const start=position();const crates=gp.loot.filter(o=>o.tier===0&&Math.abs(o.y-start[1])<15).map(o=>({...o,g:[-o.x,o.y,o.z]})).sort((a,b)=>flat(a.g,start)-flat(b.g,start));
  const plan=process.env.VOX_NATURAL_SAFE_ROUTE==='1'?sourceRaidRoute(start):null;
  const crate=plan?plan.crate:crates[0];assert.ok(crate);report.target={id:crate.id,g:crate.g};
  if(plan){
   report.sourcePlan={crate:crate.id,exit:plan.exit.id,roadDistance:plan.road.distance,steepFallback:Boolean(plan.road.steepFallback),approach:plan.approach,exposed:plan.exposed,boundary:'Offline original-road search prefers edges at most 35 degrees; actual terrain clearance, enemy damage and extraction remain runtime checks.'};
   report.approachRoute=plan.approachRoad||{boundary:'Original roads are disconnected or exceed the short approach detour limit; actual off-road approach remains unverified.'};
   if(plan.approachRoad)await roadDrive(plan.approachRoad,'approach');
  }
  await drive(crate.g);await shot('near-crate');
  check(flat(position(),start)>30,'Held keyboard commands move actual player through map');
  await page.keyboard.press('e');await wait(s=>s.salvageRun.search,'natural E search',20000);await wait(s=>s.salvageRun.used>0,'natural source loot enters cargo',30000);await shot('looted');
  check(state.salvageRun.used>0&&state.salvageRun.opened>=0,'Actual nearby crate search reveals and collects source loot');
  check(state.salvageRun.objective?.text,'Original core/extraction guide is visible in running raid');
  if(process.env.VOX_NATURAL_DEATH==='1'){
   const threat=state.salvageRun.threat;
   if(threat&&!threat.alerted){const encounter=gp.encounters.find(e=>e.name===threat.name);if(encounter){report.engage=encounter.id;await drive([-encounter.x,encounter.y,encounter.z],120,{width:20,radius:Math.max(40,(encounter.aggroR||140)*.65)});}}
   await keys();report.cargoBeforeLoss=structuredClone(state.salvageRun.cargo);
   await wait(s=>s.salvageRun.cine.name==='death','actual enemy caused death cinematic',240000);await shot('natural-death-cinematic');
   check(!state.salvageRun.result&&!state.salvageRun.committed,'Enemy damage death plays original cinematic before settlement');
   await wait(s=>s.salvageRun.result,'actual natural enemy death settlement',45000);
   check(!state.salvageRun.result.ok&&!state.salvageRun.result.keepCar&&state.salvageRun.committed,'Actual enemy death commits cargo and original car loss');settlementInventory();
  }else if(process.env.VOX_NATURAL_EXTRACT==='1'){
   const p=position(),exits=state.salvageRun.extracts.filter(e=>!e.openAt||e.openAt<=state.salvageRun.time).filter(e=>!e.needs||state.salvageRun.cargo[e.needs]>0).sort((a,b)=>flat(a.g,p)-flat(b.g,p));
   assert.ok(exits.length,'Open exit');const exit=plan?exits.find(e=>e.id===plan.exit.id):exits[0];assert.ok(exit,'Planned source extraction remains actually open');report.exit=exit.id;
   if(process.env.VOX_NATURAL_ROADS==='1'){
    try{report.roadRoute=sourceRoadRoute(p,exit.g,{maxSlope:35,avoidThreats:true});}catch{report.roadRoute=sourceRoadRoute(p,exit.g);report.roadRoute.steepFallback=true;}
    await roadDrive(report.roadRoute,'road');
   }
   report.cargoBeforeExtraction=structuredClone(state.salvageRun.cargo);
   await drive(exit.g,240,{width:exit.radius*2,radius:exit.radius*.5,extract:true});await keys(aimDriven()?[]:['Space']);
   await extractHold(exit);await keys();await shot('extract');
   report.countdown=assertCountdown(report.extractionHold,exit,process.env.VOX_NATURAL_STRICT==='1');
   if(report.countdown.samples)check(true,'Observed original extraction countdown decreases without reset');
   await wait(s=>s.salvageRun.result,'natural extraction result',45000);check(state.salvageRun.result.ok&&state.salvageRun.committed,'Natural extraction commits cargo');
   report.expectedNet=assertNetResult(state.salvageRun.result,report.cargoBeforeExtraction,exit,require('../../assets/UI/Outgame.json').items);
   check(true,'Natural success result independently matches gross cargo, one exit ticket and exact net value');settlementInventory();
  }else{
   await keys();await page.keyboard.press('t');await wait(s=>s.salvageRun?.result,'actual abandonment',20000);
   check(!state.salvageRun.result.ok&&state.salvageRun.result.keepCar&&state.salvageRun.committed,'Actual early return records cargo loss and keeps original car');
  }
  await shot('result');await click('回大厅');await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active&&!s.mouse.overlay,'actual result return and overlay release');await shot('returned');
  check(state.lobby==='salvage'&&!state.mouse.overlay,'Natural route releases result overlay and restores original salvage lobby');check(report.errors.length===0,'No runtime errors on natural route');
  if(report.inventoryAfter){assert.deepEqual(state.salvageInventory.items,report.inventoryAfter.items);check(state.salvageInventory.lastRun===report.inventoryAfter.lastRun,'Actual return keeps committed inventory without another settlement');}
  if(process.env.VOX_NATURAL_EXTRACT==='1'){
   await dump();
   if(state.salvageInventory?.saved||process.env.VOX_NATURAL_STRICT==='1'){
    report.savedGeneration=assertSavedInventory(state.salvageInventory);report.readback={status:'PASS',generation:report.savedGeneration};
    check(true,'Returned lobby actual validated store readback equals committed cargo, statistics and transaction');
   }else report.readback={status:'OPEN',reason:'Old package probe exposes live inventory only; actual saved store readback is unavailable.'};
   report.persistenceBoundary='Same WASM session actual local file readback only; browser refresh, cloud recovery and real-account economy remain unverified.';
  }
  report.result='PASS';
 }catch(e){
  report.result='FAIL';report.failure=e.stack;persist();await shot('failure').catch(()=>{});
  if(!report.errors.length&&state.salvageRun&&state.reticle.hp<.15){
   await keys();
   try{
    await wait(s=>s.salvageRun?.result,'natural enemy damage death after failed extraction route',45000);
    report.deathState=state;await shot('natural-death-result');
    check(!state.salvageRun.result.ok&&!state.salvageRun.result.keepCar&&state.salvageRun.committed,'Actual enemy damage death cinematic commits original cargo/car loss');settlementInventory();
    await click('回大厅');await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active&&!s.mouse.overlay,'natural death actual lobby return');
    await shot('natural-death-returned');check(state.lobby==='salvage','Actual natural death returns to original salvage lobby');
   }catch(deathError){report.deathFailure=deathError.stack;persist();}
  }
 }
 finally{
  report.finishedAt=new Date().toISOString();persist();
  await keys().catch(()=>{});persist();
  try{try{await page.close();}finally{await browser.close();}report.shutdown='CLOSED';}
  catch(error){report.shutdown='FAILED';report.shutdownError=error.stack;throw error;}
  finally{persist();}
 }
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,errors:report.errors.length,target:report.target}));if(report.result!=='PASS')throw Error(report.failure);
}
module.exports={sourceRoadRoute,sourceRaidRoute};
if(require.main===module)run().catch(e=>{console.error(e);process.exitCode=1;});

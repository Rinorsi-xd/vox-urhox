const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const port=Number(process.env.VOX_QA_PORT||4271),base='http://127.0.0.1:'+port;
let gp=require('../../assets/Salvage/Gameplay.json');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
const {NaturalProgress}=require('./salvage-natural-progress.cjs');
const {RoadFollower,assertNetResult,assertSavedInventory,assertCountdown}=require('./salvage-natural-navigation.cjs');
const {aimDelta}=require('./check-destruction-web.cjs');
const {isRuntimeFatal,recordRuntimeFatal,createRuntimeWatchdog,guardPage,closeRuntime}=require('./salvage-runtime-watchdog.cjs');
const {assertReturnedSurface,assertLobbyRoundTrip,assertResultInReturnedHall,assertResultAcknowledgement}=require('./salvage-return-acceptance.cjs');
const settlement=s=>s?.salvageReturn||s?.salvageRun;
function observedUniqueDeath(before,after,name){
 const named=s=>(s.aimTargets||[]).filter(t=>t.team==='red'&&t.name===name);
 return named(before).length===1&&named(after).length===0&&after.salvageRun.kills>before.salvageRun.kills;
}
function assertEnemySearchPickup(before,after,search,name){
 assert.equal(search.title,name+' 残骸箱','Search is the defeated enemy cache, not nearby map loot');
 assert.equal(search.done,true,'Actual enemy cache search finished');
 assert.ok(search.items.length>0,'Real generated enemy drop table is nonempty');
 const picked={};
 for(const item of search.items){
  assert.ok(Number.isInteger(item.n)&&item.n>0,'Generated drop quantity is positive');
  assert.ok(item.state==='shown'||item.state==='full','Every drop has passed real search reveal');
  const left=item.left||0;assert.ok(Number.isInteger(left)&&left>=0&&left<=item.n,'Actual leftover is bounded');
  if(item.n>left)picked[item.id]=(picked[item.id]||0)+item.n-left;
 }
 assert.ok(Object.values(picked).some(n=>n>0),'At least one real enemy drop was collected');
 for(const id of new Set([...Object.keys(before),...Object.keys(after),...Object.keys(picked)]))
  assert.equal(after[id]||0,(before[id]||0)+(picked[id]||0),'Cargo contains exactly enemy search pickup '+id);
 return picked;
}
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
 const combatLoot=process.argv.includes('--combat-loot');
 const returnOnly=process.argv.includes('--return-only');
 const heapSparse=process.argv.includes('--heap-sparse');
 const heapDiagnostics=process.argv.includes('--heap-diagnostics')||heapSparse,heapWindow=process.argv.includes('--heap-window');
 assert.ok(!heapSparse||(!heapWindow&&!returnOnly&&!combatLoot),'Sparse OOM diagnostic uses the unchanged natural route');
 assert.ok(!heapWindow||heapDiagnostics,'--heap-window requires --heap-diagnostics');
 assert.ok(!heapWindow||(!combatLoot&&!process.env.VOX_NATURAL_EXTRACT&&!process.env.VOX_NATURAL_DEATH),'Bounded heap window cannot claim natural loot/extraction/death acceptance');
 assert.ok(!returnOnly||(!heapWindow&&!combatLoot&&!process.env.VOX_NATURAL_EXTRACT&&!process.env.VOX_NATURAL_DEATH),'Return-only window cannot claim natural loot/extraction/death acceptance');
 const combatKills=Number(process.env.VOX_NATURAL_COMBAT_KILLS||2);
 assert.ok(Number.isInteger(combatKills)&&combatKills>=2&&combatKills<=4,'Combat consumer check requires two to four deaths');
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa);
 const reference=require('./salvage-frozen-reference.cjs').loadFrozenReference(identity);gp=reference.gameplay;
 if(heapDiagnostics)assert.equal(identity.monitorDisabled,true,'Heap diagnosis requires separate explicit monitor-disabled QA build');
 const out=path.resolve('docs/migration/evidence/salvage-natural-'+path.basename(identity.manifest_path,'.json')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log('Evidence: '+out);
 const heapHttpIdentity=heapDiagnostics?await require('./verify-heap-http.cjs').verifyHeapHttp(base,identity):null;
 if(heapHttpIdentity)fs.writeFileSync(path.join(out,'heap-http-identity.json'),JSON.stringify(heapHttpIdentity,null,2));
 const browserOptions={headless:true,channel:'chrome',args:['--use-angle=d3d11']};
 const profile=process.env.VOX_NATURAL_PROFILE&&path.resolve(process.env.VOX_NATURAL_PROFILE);
 const profileExistedBefore=Boolean(profile&&fs.existsSync(profile));
 const browser=profile?await chromium.launchPersistentContext(profile,{...browserOptions,viewport:{width:1600,height:900}}):await chromium.launch(browserOptions);
 const rawPage=profile?await browser.newPage():await browser.newPage({viewport:{width:1600,height:900}}),prefix='salvage-natural-web';
 let state,seq=0,inventoryBefore,mouseX=800,mouseY=450,firing=false;const held=new Set();
 const aimDriven=()=>Object.keys(inventoryBefore?.installed||{}).some(id=>/^part:(mech|leg|hover)\d/.test(id));
 const report={identity,result:'RUNNING',shutdown:'PENDING',checks:[],errors:[],probeErrors:[],samples:[],boundary:'Only F8 reads QA state. Route uses held W/A/D/Space and E, no teleport, cargo, death or clock fixture. Parallel functional run, not isolated performance measurement.',startedAt:new Date().toISOString()};
 report.reference=reference.audit;
 if(heapDiagnostics)report.heap={stage:'startup',samples:0,successful:0,unavailable:0,maxDurationMs:0,intervalMs:5000,boundedWindow:heapWindow,httpIdentity:heapHttpIdentity,boundary:'Default-OFF browser QA only. Actual Module.__heapInfo raw dlmalloc bytes; no arbitrary heap offsets, forced GC, allocator hooks, heap growth or gameplay mutation. Aggregate bytes do not attribute allocation owners.'};
 if(combatLoot)report.combatLoot={result:'RUNNING',requiredDeaths:combatKills,deaths:[],pickups:[],samples:[],boundary:'Optional --combat-loot uses real mouse aiming and held firing, then E search of observed enemy remnant caches. No QA damage, teleport, inventory injection or clock edits. Sequential observed consumers; not proof of simultaneous death ordering, kill attribution, natural win rate or performance.'};
 report.economyBoundary='UI/SalvageRules.json in the frozen package sets testFill:999; existing stock and purchase flow are functional evidence, not real-account economy or earned-stock evidence.';
 report.browser={persistent:Boolean(profile),profile:profile||null,profileExistedBefore,network:{requests:0,responses:0,diskCacheResponses:0,cacheResponses:0,serviceWorkerResponses:0,encodedBytes:0}};
 function persist(){report.lastState=state;fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));}
 const watchdog=createRuntimeWatchdog({onFatal:event=>recordRuntimeFatal(report,event,persist)}),page=guardPage(rawPage,watchdog);
 let sparseShutdown=null,sparseTotalDeadline=null,sparseRaidDeadline=null;
 function closeSparse(reason){
  if(!heapSparse)return;
  if(reason&&!watchdog.fatal)watchdog.fail('sparse-deadline',reason);
  if(!sparseShutdown)sparseShutdown=closeRuntime(rawPage,browser);
  return sparseShutdown;
 }
 if(heapSparse){
  report.heap.mode='sparse';report.heap.intervalMs=null;report.heap.allocatorLimit=4;
  report.heap.boundary+=' Capacity-only RAF observations; allocator only loaded/raid80/raid140/returned. All sample frames excluded; this diagnostic run is not an FPS baseline. 180s raid wall deadline and 300s total wall deadline.';
  sparseTotalDeadline=setTimeout(()=>closeSparse('Sparse heap diagnostic total wall deadline 300s'),300000);
 }
 async function observeNetwork(){
 const network=await watchdog.operation('network.session',()=>rawPage.context().newCDPSession(rawPage)),cached=new Set();await watchdog.operation('network.enable',()=>network.send('Network.enable'));
 network.on('Network.requestWillBeSent',()=>report.browser.network.requests++);
 network.on('Network.requestServedFromCache',e=>{cached.add(e.requestId);report.browser.network.cacheResponses=cached.size;});
 network.on('Network.responseReceived',e=>{const n=report.browser.network;n.responses++;if(e.response.fromDiskCache){n.diskCacheResponses++;cached.add(e.requestId);n.cacheResponses=cached.size;}if(e.response.fromServiceWorker)n.serviceWorkerResponses++;});
 network.on('Network.loadingFinished',e=>report.browser.network.encodedBytes+=e.encodedDataLength);
 }
 fs.writeFileSync(path.join(out,prefix+'.log'),'');
 rawPage.on('console',m=>{const t=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),t+'\n');const at=t.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(t.slice(at+14));if(state.loading)report.latestLoading=structuredClone(state.loading);seq++;}catch(e){report.probeErrors.push({message:e.message,length:t.length});persist();}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t)){report.errors.push(t);persist();}if(isRuntimeFatal(t))watchdog.fail('console',t);});
 rawPage.on('pageerror',e=>{const message=e.stack||e.message;report.errors.push(message);persist();if(isRuntimeFatal(message))watchdog.fail('pageerror',message);});
 if(heapDiagnostics)rawPage.on('console',m=>{const text=m.text(),prefix='VOX_HEAP_SAMPLE ';if(!text.startsWith(prefix))return;try{
  const sample=JSON.parse(text.slice(prefix.length)),observed=state?.performance,row={...sample,receivedAt:new Date().toISOString(),stage:report.heap.stage,gameTime:state?.salvageRun?.time??null,mode:state?.mode??null,
   lastQaState:{receivedSequence:seq,luaKiB:observed?.luaKiB??null,resourceBytes:observed?.resourceBytes??null,battleObjects:observed?.battleObjects??null},stateBoundary:'Last F8 snapshot, not an atomic allocator/resource snapshot. Lua and resources overlap WASM totals; do not sum.'};
  fs.appendFileSync(path.join(out,'heap-samples.jsonl'),JSON.stringify(row)+'\n');report.heap.samples++;
  if(sample.status==='OK'){report.heap.successful++;report.heap.latest=row;}else if(sample.kind==='sample')report.heap.unavailable++;
  report.heap.maxDurationMs=Math.max(report.heap.maxDurationMs,sample.durationMs||0);persist();
 }catch(error){report.probeErrors.push({heap:true,message:error.message});persist();}});
 if(heapSparse)rawPage.on('console',m=>{const message=m.text(),prefix='VOX_SPARSE_HEAP ';if(message.startsWith(prefix)){try{fs.appendFileSync(path.join(out,'heap-capacity-and-markers.jsonl'),message.slice(prefix.length)+'\n');}catch(error){report.probeErrors.push({sparseHeap:true,message:error.message});}}if(isRuntimeFatal(message))closeSparse();});
 rawPage.on('crash',()=>{report.errors.push('Browser page crashed');watchdog.fail('crash','Browser page crashed');if(heapSparse)closeSparse();});
 if(heapSparse)rawPage.on('pageerror',error=>{if(isRuntimeFatal(error.stack||error.message))closeSparse();});
 async function wait(fn,label,limit=240000){const start=Date.now();let probe=0;while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(state?.loadingFlow?.failed)throw Error('Actual loading failure: '+state.loadingFlow.error);if(Date.now()-start>limit)throw Error('Timeout '+label);if(Date.now()-probe>800){probe=Date.now();await page.keyboard.press('F8');}await delay(100);}return state;}
 async function dump(){const before=seq;await page.keyboard.press('F8');await wait(()=>seq>before,'fresh state',15000);return state;}
 const widgets=()=>Array.isArray(state?.widgets)?state.widgets:[];
 const position=()=>state.vehicle.center||state.vehicle.position;
 async function click(text,match){let b;const begun=Date.now();while(!b){await dump();b=widgets().filter(w=>!w.disabled&&(!w.entrance||w.entrance.opacity>.9)&&(match?match(w):w.text===text)).at(-1);if(!b){assert.ok(Date.now()-begun<20000,'Actual visible button '+text);await delay(160);}}const r=b.rect,c=await page.locator('canvas').boundingBox();await page.mouse.click(c.x+(r[0]+r[2]/2)*c.width/state.width,c.y+(r[1]+r[3]/2)*c.height/state.height);await delay(500);}
 async function keys(next=[]){for(const k of held)if(!next.includes(k)){await page.keyboard.up(k);held.delete(k);}for(const k of next)if(!held.has(k)){await page.keyboard.down(k);held.add(k);}}
 const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);persist();};
 async function shot(name){persist();await page.screenshot({path:path.join(out,prefix+'-'+name+'.png'),timeout:15000});}
 async function heapSample(stage){if(!heapDiagnostics||heapSparse&&stage!=='returned')return;report.heap.stage=stage;return watchdog.operation('heap.sample.'+stage,()=>rawPage.evaluate(({tag,sparse})=>sparse?window.__voxSparseHeap.returned():window.__voxHeapProbe.sample(tag),{tag:stage,sparse:heapSparse}));}
 async function installHeap(){
  if(!heapDiagnostics)return;
  await watchdog.operation('heap.install.script',()=>rawPage.addScriptTag({path:path.join(__dirname,'wasm-heap-diagnostics.js')}));
  if(heapSparse){
   await watchdog.operation('heap.sparse.script',()=>rawPage.addScriptTag({path:path.join(__dirname,'sparse-heap-observer.js')}));
   await watchdog.operation('heap.sparse.install',()=>rawPage.evaluate(()=>{window.__voxSparseHeap=window.VoxSparseHeapObserver.create(window);}));
   return;
  }
  await watchdog.operation('heap.install',()=>rawPage.evaluate(()=>{window.__voxHeapProbe=window.VoxWasmHeapDiagnostics.createProbe(window,{enabled:true,intervalMs:5000});}));
  const first=await heapSample('hall');
  assert.equal(first.status,'OK','Actual Runtime emitted a validated raw allocator sample: '+first.reason);
  await watchdog.operation('heap.start',()=>rawPage.evaluate(()=>window.__voxHeapProbe.start()));
 }
 async function verifyReturnedInput(resultBefore){
  await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'actual result return',60000);await dump();
  const before=structuredClone(state);report.returnInput={result:'PENDING',before};persist();
  if(resultBefore)report.resultAcknowledgement=assertResultAcknowledgement(resultBefore,before);
  assertReturnedSurface(before);
  await click('车库');await wait(s=>s.salvage?.tab==='garage','real returned garage mouse input',15000);await dump();
  const garage=structuredClone(state);report.returnInput.garage=garage;persist();
  await click('整备');await wait(s=>s.salvage?.tab==='loadout','real returned loadout mouse input',15000);await dump();
  report.returnInput={...report.returnInput,...assertLobbyRoundTrip(before,garage,state),result:'PASS',loadout:structuredClone(state)};persist();
 }
 function settlementInventory(){
  assert.ok(inventoryBefore&&state.salvageInventory,'Actual read-only before/after inventory is available');
  const before=inventoryBefore,after=state.salvageInventory,result=settlement(state).result;
  const all=new Set([...Object.keys(before.items),...Object.keys(after.items)]);
  for(const id of all){const expected=result.ok?(before.items[id]||0)+(result.cargo[id]||0):Math.max(0,(before.items[id]||0)-(result.keepCar?0:(before.installed[id]||0)));assert.equal(after.items[id]||0,expected,'Natural settlement actual stock '+id);}
  check(true,result.ok?'Natural extraction adds exactly committed cargo to real stash':result.keepCar?'Natural abandonment preserves original stock and discards all cargo':'Natural death deducts every original installed part and discards all cargo');
  check(after.stats.raids===before.stats.raids&&after.stats[result.ok?'extracted':'lost']===(before.stats[result.ok?'extracted':'lost']||0)+1,'Natural settlement counts outcome once without double counting raid start');
  check(after.credits===before.credits,'Settlement keeps source credit balance; carried goods are not automatically sold');
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
 async function combatDrops(){
  check(Array.isArray(state.aimTargets)&&state.camera?.position&&state.reticle.groups>0,'Actual enemy and armed vehicle observers available for combat loot');
  const defs=reference.runData.enemies;
  const names=kind=>defs[kind]?.[0]?.name;
  const encounters=gp.encounters.filter(e=>e.squad.length>=combatKills&&new Set(e.squad.map(names)).size===e.squad.length&&e.kind!=='elite').sort((a,b)=>flat(position(),[-a.x,a.y,a.z])-flat(position(),[-b.x,b.y,b.z]));
  assert.ok(encounters.length,'Source encounter has multiple distinct observable enemy names');
  const encounter=encounters[0],at=[-encounter.x,encounter.y,encounter.z];
  report.combatLoot.encounter=encounter.id;
  await drive(at,240,{width:40,radius:Math.max(50,(encounter.aggroR||140)*.65)});await keys();
  await wait(s=>s.aimTargets?.some(t=>t.team==='red'),'actual source encounter spawn',30000);
  await page.keyboard.press('1');await dump();
  const initialShots=state.weapons.shots,initialKills=state.salvageRun.kills,started=Date.now();
  while(report.combatLoot.deaths.length<combatKills&&Date.now()-started<300000){
   await dump();checkAlive();
   const red=state.aimTargets.filter(t=>t.team==='red');
   const target=red.filter(t=>red.filter(v=>v.name===t.name).length===1&&!report.combatLoot.deaths.some(v=>v.name===t.name)).sort((a,b)=>flat(position(),a.pos)-flat(position(),b.pos))[0];
   assert.ok(target,'Unique living source enemy is available; name-only observer cannot certify ambiguous duplicates');
   let previous=structuredClone(state),last=structuredClone(target),killed=false;
   const fight=Date.now();
   try{
    while(Date.now()-fight<120000){
     const current=state.aimTargets.find(t=>t.team==='red'&&t.name===target.name);
     if(!current){killed=observedUniqueDeath(previous,state,target.name);break;}
     last=structuredClone(current);
     const delta=aimDelta(state.camera,current,[0,-.5,-1,.5][Math.floor((Date.now()-fight)/5000)%4]);
     mouseX+=delta.mouseX;mouseY+=delta.mouseY;await page.mouse.move(mouseX,mouseY,{steps:2});
     if(!firing){await page.mouse.down();firing=true;}
     previous=structuredClone(state);await delay(250);await dump();checkAlive();
     report.combatLoot.samples.push({time:state.salvageRun.time,name:target.name,pos:last.pos,parts:current.parts,kills:state.salvageRun.kills,shots:state.weapons.shots,hits:state.weapons.hits,hp:state.reticle.hp});
     if(observedUniqueDeath(previous,state,target.name)){killed=true;break;}
     if(state.weapons.energy<5){await page.mouse.up();firing=false;await delay(1200);await dump();}
    }
   }finally{if(firing){await page.mouse.up();firing=false;}}
   check(killed,'Observed unique enemy disappears with actual Run kill counter: '+target.name);
   report.combatLoot.deaths.push({name:target.name,lastPosition:last.pos,kills:state.salvageRun.kills,boundary:'Last observed living pose; cache interaction below independently confirms defeated enemy remnant.'});
   await shot('enemy-death-'+report.combatLoot.deaths.length);
   const cargoBefore=structuredClone(state.salvageRun.cargo),expected=target.name+' 残骸箱';
   await drive(last.pos,120);await keys();
   await wait(s=>s.salvageRun.prompt?.title===expected,'actual generated enemy remnant prompt '+expected,20000);
   await page.keyboard.press('e');
   await wait(s=>s.salvageRun.search?.title===expected,'actual E enemy cache search',15000);
   let completed;const searchStarted=Date.now();
   while(Date.now()-searchStarted<30000){await dump();checkAlive();if(state.salvageRun.search?.title===expected&&state.salvageRun.search.done){completed=structuredClone(state.salvageRun.search);break;}await delay(100);}
   assert.ok(completed,'Actual generated enemy search reaches done before auto-close');
   const picked=assertEnemySearchPickup(cargoBefore,state.salvageRun.cargo,completed,target.name);
   report.combatLoot.pickups.push({name:target.name,picked,search:completed,before:cargoBefore,after:structuredClone(state.salvageRun.cargo)});
   check(true,'Real enemy drop reveal enters cargo with exact quantity and leftovers: '+target.name);await shot('enemy-loot-'+report.combatLoot.pickups.length);
   if(!completed.items.some(item=>item.state==='full'))await wait(s=>!s.salvageRun.search,'actual enemy search auto-close',15000);
  }
  check(report.combatLoot.deaths.length>=combatKills&&state.salvageRun.kills>=initialKills+combatKills,'Multiple real enemy deaths create searchable remnant caches');
  check(state.weapons.shots>initialShots,'Public held mouse fire actually emitted weapon shots');
  check(report.combatLoot.pickups.length===report.combatLoot.deaths.length,'Every confirmed enemy remnant yielded actual cargo pickup');
  report.combatLoot.result='CONSUMERS_PASS_RETURN_PENDING';persist();
 }
 try{
  persist();await observeNetwork();await page.bringToFront();
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'hall');
  await installHeap();
  await click('打捞行动');await wait(s=>s.tab==='salvage'&&!s.loadingFlow?.active&&!s.vehicleLoading?.busy,'salvage');
  if(process.env.VOX_NATURAL_STRONG==='1'){
   const originalVehicle=process.env.VOX_NATURAL_VEHICLE||'量产机兵 · 突击';assert.ok(reference.workshop.prefabs.some(v=>v.name===originalVehicle),'Vehicle exists in frozen source workshop');
   const existing=state.garage.slots.findIndex(v=>v&&v.name===originalVehicle);
   if(existing>=0){
    if(state.blueprint!==originalVehicle){await click('车库');await click(originalVehicle);await wait(s=>s.blueprint===originalVehicle&&!s.vehicleLoading?.busy,'actual existing garage vehicle selection');}
    check(state.blueprint===originalVehicle&&state.garage.active===existing+1,'Original vehicle legitimately restored and selected from actual local garage');await shot('reused-original-vehicle');
   }else{
   const used=state.garage.used,starterParts=state.parts;await click('创意工坊');await wait(()=>widgets().some(w=>w.text==='查看全部'&&w.entrance?.opacity>.9),'actual workshop visible feature shelf',20000);check(state.workshop.caption.elapsed>0&&state.workshop.shelf.elapsed>0,'Actual nested workshop source animation clocks and visible shelf advance');
   if(!widgets().some(w=>w.text===originalVehicle)){await click('查看全部');await wait(s=>s.workshop?.view==='browse','actual full source workshop',20000);const sourceVehicle=reference.workshop.prefabs.find(v=>v.name===originalVehicle);const groupLabels={mech:'机甲',wheel:'轮式',track:'履带',plane:'飞机',pirate:'海盗',blank:'底盘'};if(groupLabels[sourceVehicle.group]){await click(groupLabels[sourceVehicle.group]);await wait(s=>s.workshop.group===sourceVehicle.group,'actual original vehicle group',20000);}}
   await wait(()=>widgets().some(w=>w.text===originalVehicle),'existing official vehicle card',20000);
   await click(originalVehicle);await wait(s=>s.workshop?.view==='detail'&&!s.vehicleLoading?.busy,'actual official vehicle detail');await delay(900);
   await click('购买整车');await wait(s=>s.dialog&&widgets().some(w=>w.text==='购买整车'),'actual vehicle purchase');
   await click('use original stock',w=>w.text.startsWith('用仓库里的零件拼'));
   await wait(s=>!s.dialog&&!s.vehicleLoading?.busy&&s.garage.used===used+1&&widgets().some(w=>w.text==='拆掉这辆车'),'actual purchased vehicle garage');
   check(state.blueprint===originalVehicle&&state.parts>starterParts,'Original vehicle bought and selected through actual workshop/garage UI');await shot('selected-original-vehicle');
   }
   await click('整备');await wait(()=>widgets().some(w=>w.text==='出发'),'actual selected vehicle loadout');
  }
  await heapSample('loadout');
  if(heapDiagnostics)report.heap.stage='loading';
  await click('出发');
  await wait(s=>s.salvageRun&&!s.loadingFlow?.active,'loaded actual raid',600000);
  if(heapSparse){
   sparseRaidDeadline=setTimeout(()=>closeSparse('Sparse heap diagnostic raid wall deadline 180s'),180000);
   report.heap.raidLoadedAt=new Date().toISOString();report.heap.stage='loaded';persist();
   const first=await watchdog.operation('heap.sparse.loaded',()=>rawPage.evaluate(()=>window.__voxSparseHeap.loaded()));
   assert.equal(first.status,'OK','Actual Runtime emitted a validated sparse allocator sample: '+first.reason);
  }
  report.loadingAtEntry=structuredClone(state.loading||report.latestLoading);report.loadingFlowAtEntry=structuredClone(state.loadingFlow);report.networkAtEntry=structuredClone(report.browser.network);await shot('drop');
  inventoryBefore=structuredClone(state.salvageInventory);report.inventoryBefore=inventoryBefore;
  await wait(s=>s.salvageRun&&!s.salvageRun.cine.playing,'natural drop completion',60000);await page.bringToFront();await page.mouse.click(800,450);await wait(s=>s.pointer.captured,'actual input capture');
  await heapSample('live');
  check(Number.isFinite(state.vehicle.yaw),'Actual vehicle yaw available for observed keyboard steering');
  if(process.env.VOX_NATURAL_SAFE_ROUTE==='1')check(Array.isArray(state.vehicle.center),'Read-only actual center of mass is available for source interaction and navigation');
  const start=position();let plan=null;
  if(heapWindow||returnOnly){
   const seconds=returnOnly?5:30;
   const window={startedAt:new Date().toISOString(),startGameTime:state.salvageRun.time,seconds,boundary:'Held W and left mouse for explicit bounded window, then original abandonment. Not eleven-car stress, kill/drop acceptance or allocation-owner attribution.'};
   if(heapDiagnostics)report.heap.window=window;report.returnWindow=window;
   try{await keys(['w']);await page.mouse.down();const begun=Date.now();while(Date.now()-begun<seconds*1000){await delay(1000);await dump();checkAlive();}}
   finally{if(!watchdog.fatal){await keys();await page.mouse.up();}}
   window.finishedAt=new Date().toISOString();window.endGameTime=state.salvageRun.time;await heapSample('live-end');
  }
  else if(combatLoot)await combatDrops();
  else{
  const crates=gp.loot.filter(o=>o.tier===0&&Math.abs(o.y-start[1])<15).map(o=>({...o,g:[-o.x,o.y,o.z]})).sort((a,b)=>flat(a.g,start)-flat(b.g,start));
  plan=process.env.VOX_NATURAL_SAFE_ROUTE==='1'?sourceRaidRoute(start):null;
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
  }
  check(state.salvageRun.objective?.text,'Original core/extraction guide is visible in running raid');
  if(process.env.VOX_NATURAL_DEATH==='1'){
   const threat=state.salvageRun.threat;
   if(threat&&!threat.alerted){const encounter=gp.encounters.find(e=>e.name===threat.name);if(encounter){report.engage=encounter.id;await drive([-encounter.x,encounter.y,encounter.z],120,{width:20,radius:Math.max(40,(encounter.aggroR||140)*.65)});}}
   await keys();report.cargoBeforeLoss=structuredClone(state.salvageRun.cargo);
   await wait(s=>s.salvageRun.cine.name==='death','actual enemy caused death cinematic',240000);await shot('natural-death-cinematic');
   check(!state.salvageRun.result&&!state.salvageRun.committed,'Enemy damage death plays original cinematic before settlement');
   await wait(s=>settlement(s)?.result,'actual natural enemy death settlement',45000);
   check(!settlement(state).result.ok&&!settlement(state).result.keepCar&&settlement(state).committed,'Actual enemy death commits cargo and original car loss');
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
   await wait(s=>settlement(s)?.result,'natural extraction result',45000);check(settlement(state).result.ok&&settlement(state).committed,'Natural extraction commits cargo');
   report.expectedNet=assertNetResult(settlement(state).result,report.cargoBeforeExtraction,exit,reference.catalogue.items);
   check(true,'Natural success result independently matches gross cargo, one exit ticket and exact net value');
  }else{
   await keys();await page.keyboard.press('t');await wait(s=>settlement(s)?.result,'actual abandonment',60000);
   check(!settlement(state).result.ok&&settlement(state).result.keepCar&&settlement(state).committed,'Actual early return records cargo loss and keeps original car');
  }
  await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active&&s.dialog&&s.salvageReturn?.shown,'actual hall-owned result after battle disposal',90000);await dump();
  report.resultPresentation=assertResultInReturnedHall(state);report.resultState=structuredClone(state);settlementInventory();
  check(true,'Original result appears only in restored hall after old trial resources are disposed');
  await shot('result');await click('回大厅');await verifyReturnedInput(report.resultState);await shot('returned');
  await heapSample('returned');
  check(report.returnInput.result==='PASS','Natural route releases owned result modal and original lobby accepts garage/loadout mouse input');check(report.errors.length===0,'No runtime errors on natural route');
  if(report.inventoryAfter){assert.deepEqual(state.salvageInventory.items,report.inventoryAfter.items);check(state.salvageInventory.lastRun===report.inventoryAfter.lastRun,'Actual return keeps committed inventory without another settlement');}
  if(process.env.VOX_NATURAL_EXTRACT==='1'||combatLoot){
   await dump();
   if(state.salvageInventory?.saved||process.env.VOX_NATURAL_STRICT==='1'){
    report.savedGeneration=assertSavedInventory(state.salvageInventory);report.readback={status:'PASS',generation:report.savedGeneration};
    check(true,'Returned lobby actual validated store readback equals committed cargo, statistics and transaction');
   }else report.readback={status:'OPEN',reason:'Old package probe exposes live inventory only; actual saved store readback is unavailable.'};
   report.persistenceBoundary='Same WASM session actual local file readback only; browser refresh, cloud recovery and real-account economy remain unverified.';
  }
  if(combatLoot){report.combatLoot.result='PASS';check(true,'Enemy drop consumers complete actual settlement and return without duplicate inventory mutation');}
  report.result='PASS';
 }catch(e){
  if(combatLoot){report.combatLoot.result='FAIL';report.combatLoot.failure=e.stack;}
  report.result='FAIL';report.failure=e.stack;persist();
  if(!watchdog.fatal)await shot('failure').catch(error=>{report.failureScreenshotError=error.stack;persist();});
  else{report.failureScreenshotSkipped='Runtime fatal; renderer may be unresponsive. Existing screenshots preserved.';persist();}
  if(!watchdog.fatal&&!report.errors.length&&state?.salvageRun&&state.reticle.hp<.15){
   await keys();
   try{
    await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active&&s.salvageReturn?.shown,'natural enemy damage death after failed extraction route',90000);
    report.deathState=state;await shot('natural-death-result');
    assertResultInReturnedHall(state);
    check(!settlement(state).result.ok&&!settlement(state).result.keepCar&&settlement(state).committed,'Actual enemy damage death cinematic commits original cargo/car loss');settlementInventory();
    const deathResult=structuredClone(state);await click('回大厅');await verifyReturnedInput(deathResult);
    await shot('natural-death-returned');check(state.lobby==='salvage','Actual natural death returns to original salvage lobby');
   }catch(deathError){report.deathFailure=deathError.stack;persist();}
  }
 }
 finally{
  clearTimeout(sparseTotalDeadline);clearTimeout(sparseRaidDeadline);
  if(heapDiagnostics&&!watchdog.fatal){try{await watchdog.operation('heap.dispose',()=>rawPage.evaluate(sparse=>sparse?window.__voxSparseHeap?.dispose():window.__voxHeapProbe?.dispose(),heapSparse));report.heap.disposed=true;}catch(error){report.heap.disposeError=error.message;}}
  report.finishedAt=new Date().toISOString();persist();
  report.inputCleanup='Closing the disposable browser/context releases input; no renderer acknowledgement awaited after failure.';
  report.shutdown='CLOSING';persist();
  report.shutdownDetails=await (sparseShutdown||closeRuntime(rawPage,browser));report.shutdown=report.shutdownDetails.status;
  if(report.shutdown!=='CLOSED'){report.result='FAIL';report.failure=report.failure||'Runtime cleanup '+report.shutdown;}
  persist();
 }
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,errors:report.errors.length,target:report.target}));if(report.result!=='PASS')throw Error(report.failure);
}
module.exports={sourceRoadRoute,sourceRaidRoute,observedUniqueDeath,assertEnemySearchPickup};
if(require.main===module)run().catch(e=>{console.error(e);process.exit(1);});

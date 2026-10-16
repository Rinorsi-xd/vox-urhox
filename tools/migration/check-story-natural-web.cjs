const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const memoryProbe=require('./web-memory-probe.cjs');
const naturalInput=require('./story-natural-input.cjs');
const {bossPlan}=require('./story-boss-natural-input.cjs');
const levelNo=Number(process.env.VOX_STORY_LEVEL||1),limit=Number(process.env.VOX_STORY_SECONDS||360);
const entryOnly=process.env.VOX_STORY_ENTRY_ONLY==='1';
const ambienceCheck=process.env.VOX_STORY_AMBIENCE==='1';
const logOnly=process.env.VOX_STORY_LOG_ONLY==='1';
const convoyCheck=process.env.VOX_STORY_CONVOY==='1';
const battleTimingCheck=process.env.VOX_STORY_BATTLE_TIMING==='1';
const spawnDiagnostic=process.env.VOX_STORY_SPAWN_DIAGNOSTIC==='1';
const convoyAcceptance=require('./story-convoy-acceptance.cjs');
const {findRoadConnector,evaluateTerrainConnector}=require('./story-road-connector.cjs');
assert(!logOnly||levelNo===1&&!entryOnly,'Log acceptance requires level1 and full natural entry');
assert(!convoyCheck||levelNo===2&&!entryOnly&&!logOnly,'Convoy acceptance requires full natural S2');
assert(!spawnDiagnostic||battleTimingCheck&&!entryOnly&&!logOnly&&!convoyCheck,'Spawn diagnostic requires explicit F15 timing and full natural entry without other acceptance modes');
const base=process.env.VOX_QA_BASE||'http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4283);
const level=require('../../assets/Story/Mission/Level'+levelNo+'.json').level;
const layout=require('../../assets/'+(levelNo===5?'EnginePit':'Crater')+'/Layout.json');
const sleep=ms=>new Promise(r=>setTimeout(r,ms)),flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
function observeLog(run,s,check){
 if(!run.baseline&&s.index>0&&s.index<6)run.baseline={kills:s.stats.kills};
 if(s.step==='scouts'&&s.phase==='fight'){
  run.fight??={time:s.time,kills:s.stats.kills,enemies:s.enemies};
  if(s.enemies===3)run.threeEnemiesObserved=true;
 }
 if(s.step==='log'&&!run.drop){
  check(!!run.baseline&&!!run.fight&&run.threeEnemiesObserved,'Actual authored three-scout encounter observed');
  check(s.stats.kills-run.baseline.kills===3&&s.enemies===0,'Three actual scout kills; timeout retreat cannot pass');
  check(s.stats.intel===2&&s.stats.collectors===2,'Log drop occurs after two authored intel and collector objectives');
  check(Array.isArray(s.target)&&s.target.length===3&&s.target.every(Number.isFinite),'Actual dropped log has a finite target');
  run.drop={time:s.time,target:[...s.target],stats:structuredClone(s.stats)};
 }
 if(s.step==='east'&&!run.picked){
  check(!!run.drop,'Actual log target observed before pickup');
  check(s.stats.intel===3&&s.stats.collectors===2&&s.stats.kills-run.baseline.kills===3,'Real pickup adds exactly one intel and advances to east collector');
  run.picked={time:s.time,stats:structuredClone(s.stats)};run.result='PASS';return true;
 }
 return false;
}
function loadRoadTerrain(roads,assetRoot=path.resolve(__dirname,'../../assets')){
 const heights=[];
 for(const part of roads.dataParts?.parts||[]){
  if(part.field!=='heights')continue;
  const values=JSON.parse(fs.readFileSync(path.join(assetRoot,part.path),'utf8'));
  assert.equal(values.length,part.count,'Authored terrain chunk length '+part.path);
  for(let i=0;i<values.length;i++)heights[part.first-1+i]=values[i];
 }
 assert.equal(heights.length,(roads.terrain.n+1)**2,'Complete source terrain heightfield');
 for(let i=0;i<heights.length;i++)assert(Number.isFinite(heights[i]),'Finite authored terrain height '+i);
 roads.terrain.heights=heights;return roads;
}
function roadRoute(from,to,roads=layout,options={}){
 const nodes=roads.nav.nodes,ids=Object.keys(nodes),adj=new Map(ids.map(id=>[id,[]]));
 for(const [a,b,width]of roads.nav.edges){if(!nodes[a]||!nodes[b])continue;const cost=Math.hypot(...nodes[a].map((v,i)=>v-nodes[b][i]));adj.get(a).push([b,cost,width]);adj.get(b).push([a,cost,width]);}
 const near=p=>ids.reduce((best,id)=>flat(nodes[id],p)+Math.abs(nodes[id][1]-p[1])*5<flat(nodes[best],p)+Math.abs(nodes[best][1]-p[1])*5?id:best,ids[0]);
 let start=near(from);const end=near(to);
 if(options.terrainConnector){
  const limits=options.connectorLimits||{},selected=findRoadConnector(from,roads,limits);
  const rejected=selected?.rejected||ids.map(id=>{const distance=flat(from,nodes[id]);if(distance>(limits.maxDistance??Infinity))return {id,reason:'beyond-max-distance',distance};const probe=evaluateTerrainConnector(from,nodes[id],roads.terrain,limits);return {id,reason:probe.reason,maxSlopeDeg:probe.maxSlopeDeg,nodeHeightError:probe.nodeHeightError};});
  options.onConnector?.({result:selected?'SELECTED':'NO_REACHABLE_ENTRY',selected:selected&&{id:selected.id,pos:selected.pos,distance:selected.distance,maxSlopeDeg:selected.profile.maxSlopeDeg},rejected,limits});
  if(!selected)return null;
  start=selected.id;
 }
 const cost=new Map([[start,0]]),prev=new Map(),done=new Set();
 while(done.size<ids.length){let current;for(const [id,d]of cost)if(!done.has(id)&&(!current||d<cost.get(current)))current=id;if(!current||current===end)break;done.add(current);for(const [id,w]of adj.get(current)){const d=cost.get(current)+w;if(d<(cost.get(id)??Infinity)){cost.set(id,d);prev.set(id,current);}}}
 if(!cost.has(end))return [];
 const route=[];for(let id=end;id;id=prev.get(id)){route.unshift({id,pos:nodes[id]});if(id===start)break;}
 return route;
}
function advanceRoute(route,p){
 const passed=[];
 while(route.length&&flat(p,route[0].pos)<6&&Math.abs(p[1]-route[0].pos[1])<8)passed.push(route.shift());
 return passed;
}
function navigationProgress(progress,goal,d,now){
 // A new waypoint has its own distance baseline and cancels the old recovery.
 if(progress.goal!==goal){progress.goal=goal;progress.best=Infinity;progress.stuckAt=now;progress.reverseUntil=0;}
 if(d<progress.best-1){progress.best=d;progress.stuckAt=now;}
 if(now-progress.stuckAt>8000&&now>progress.reverseUntil){progress.reverseUntil=now+1800;progress.stuckAt=now;}
 return now<progress.reverseUntil;
}
function routeHeightError(from,to,p){
 const dx=to[0]-from[0],dz=to[2]-from[2],length=dx*dx+dz*dz;
 const t=length?Math.max(0,Math.min(1,((p[0]-from[0])*dx+(p[2]-from[2])*dz)/length)):1;
 return p[1]-(from[1]+(to[1]-from[1])*t);
}
function needsRoad(from,to,enemy){return flat(from,to)>80||enemy&&flat(from,to)>25&&Math.abs(from[1]-to[1])>6;}
function navigationCommand({enemy,distance,speed,goalDistance,reversing,angle,routeFollowing=false}){
 const throttle=reversing?'s':'w',steer=reversing?-angle:angle;
 const turning=Math.abs(steer)>.12?(steer>0?'a':'d'):null;
 const engaging=enemy&&!routeFollowing;
 const desired=engaging?12:Math.min(15,Math.sqrt(goalDistance)*2);
 const braking=engaging&&distance<25||Math.abs(speed)>desired;
 return [braking?'Space':throttle,...(turning?[turning]:[])];
}
async function configureBattleTiming(enabled,dispatch,observe,record){
 if(!enabled){record({requested:false,result:'NOT_REQUESTED',keyRequests:0});return;}
 record({requested:true,result:'REQUESTED',keyRequests:1});
 await dispatch('F15');
 const observed=await observe(s=>s.performance?.battleTiming?.enabled===true,'explicit F15 CPU timing acknowledgement',20000);
 assert.equal(observed.performance.battleTiming.enabled,true,'Actual probe acknowledged F15 CPU timing');
 record({requested:true,result:'OBSERVED',keyRequests:1,observed:structuredClone(observed.performance.battleTiming)});
}
function observeSpawnDiagnostic(run,observed,wall,timingAcknowledgement){
 assert.equal(timingAcknowledgement.result,'OBSERVED','Spawn diagnostic requires actual F15 acknowledgement');
 assert.equal(observed.performance?.battleTiming?.enabled,true,'Detailed timing must remain enabled throughout diagnostic');
 const enemies=observed.story?.enemies;
 assert(Number.isInteger(enemies)&&enemies>=0,'Actual nonnegative enemy count required');
 const snapshot=()=>structuredClone({wall,story:observed.story,
  state:observed.performance.battleTiming,timings:Object.fromEntries(Object.entries(observed.performance.updateTiming||{}).filter(([label])=>label.startsWith('battle.')))});
 if(!run.zero&&enemies===0){run.zero=snapshot();run.result='WAITING_SPAWN';}
 if(!run.firstSpawn&&run.previousEnemies===0&&enemies>0){
  run.firstSpawn=snapshot();run.result='SAMPLING';
 }
 run.previousEnemies=enemies;
 if(run.firstSpawn&&wall-run.firstSpawn.wall>=12000){
  run.end=snapshot();run.elapsedWallMs=wall-run.firstSpawn.wall;run.result='CAPTURED';return true;
 }
 return false;
}
function captureBattleObjects(request,observed,sequence){
 if(!request||request.snapshot||sequence<=request.afterSequence||observed.mode!=='trial'||observed.story?.id!==request.storyId)return null;
 const objects=observed.performance?.battleObjects;if(!objects?.scene?.sampled)return null;
 return structuredClone({stage:request.stage,observedAt:Date.now(),story:{id:observed.story.id,index:observed.story.index,
  step:observed.story.step,phase:observed.story.phase,time:observed.story.time},objects});
}
function recordBattleObjects(request,observed,sequence,report,persist){
 const captured=captureBattleObjects(request,observed,sequence);if(!captured)return;
 captured.result='OBSERVED';request.snapshot=captured;report.objectSamples.push(captured);persist();
}
async function main(){
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa);
 if(process.env.VOX_EXPECT_MANIFEST)assert.equal(identity.servedManifest,process.env.VOX_EXPECT_MANIFEST,'Expected immutable manifest');
 const root=path.resolve(__dirname,'../..'),production={};
 const referenceRoot=path.resolve(process.env.VOX_STORY_REFERENCE||path.join(root,'scripts'));
 for(const name of ['story/Mission.lua','story/MissionRules.lua']){
  const sha=crypto.createHash('sha256').update(fs.readFileSync(path.join(referenceRoot,name))).digest('hex');
  assert.equal(identity.identity.scripts[name],sha,'Frozen actual mission payload '+name);production[name]=sha;
 }
 const observerPrefix=identity.storyRoute?fs.readFileSync(path.join(__dirname,'story-route-observer.lua'),'utf8')+'\n':'';
 const probeSha=crypto.createHash('sha256').update(observerPrefix).update(fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'))).digest('hex');
 assert.equal(identity.probeSha256,probeSha,'Actual server uses current read-only observer');
 const out=path.resolve('docs/migration/evidence/story-natural-s'+levelNo+'-'+path.basename(identity.manifest_path,'.json')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log('Evidence: '+out);
 const report={identity,production,referenceRoot,toolSha256:crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex'),inputHelperSha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,'story-natural-input.cjs'))).digest('hex'),level:level.id,entryOnly,logOnly,sharedGpu:process.env.VOX_QA_SHARED_GPU==='1',result:'RUNNING',checks:[],errors:[],probeErrors:[],samples:[],objectSamples:[],transitions:[],routes:[],battleTiming:{requested:battleTimingCheck,result:battleTimingCheck?'PENDING':'NOT_REQUESTED',keyRequests:0,samples:[]},startedAt:new Date().toISOString(),
  boundary:'Actual source story selection and keyboard/mouse operation. F8 reads compact state; F14 reads scene counts once at trial/story screenshots and immediately freezes the actual sample. No teleport, phase/clock/HP changes, enemy destruction, voice skipping or synthetic completion. Automated road following may fail; that alone is not proof of a gameplay defect. Functional run, not isolated performance or physical mobile evidence.'};
 if(report.sharedGpu)report.boundary+=' Shared-machine concurrent GPU functional route: frame rate and loading duration are not isolated measurements and must not be used for performance comparison.';
 if(identity.storyRoute)report.boundary+=' Explicit story-route QA projection preserves complete story, controls, camera, targets, route and memory counters; unrelated UI/weapon diagnostic fields are omitted. Not a complete UI/HUD audit.';
 if(battleTimingCheck)report.boundary+=' VOX_STORY_BATTLE_TIMING=1 requests real F15 CPU instrumentation. Inclusive nested wall milliseconds include instrumentation and scheduling; do not sum or use as GPU, isolated benchmark or mobile performance evidence. At most five units are sampled; combat vehicle views are wrapped without scanning parts. New/rebuilt objects bind on the next QA update.';
 if(spawnDiagnostic){report.spawnDiagnostic={result:'WAITING_ZERO',durationWallMs:12000};report.boundary+=' First-spawn diagnostic only: requires an actual zero-to-positive enemy observation after F15 acknowledgement, then at least 12 wall-clock seconds of normal commands and normal return. PASS is diagnostic capture and terrain release, never whole-mission completion or performance acceptance.';}
 if(logOnly){report.logAcceptance={result:'NOT_REACHED'};report.boundary+=' Log-only route checks natural three kills, visible target state and actual pickup. It cannot observe exact within-frame last-death ordering or prove pixel appearance; the offline death-order oracle and screenshot review remain separate. No filesystem memory scan. Does not claim complete mission.';}
 if(convoyCheck){report.convoyAcceptance=convoyAcceptance.create(level);report.boundary+=' S2 functional acceptance requires both real non-default dialogue choices, two checkpoint states and complete transport delivery. Enemy counts in progress windows are diagnostic only: a surviving enemy can cross windows. Three-wave identity and presentation remain OPEN even when this functional run passes.';}
 report.bossInputHelperSha256=crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,'story-boss-natural-input.cjs'))).digest('hex');
 const persist=()=>fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2));persist();
 if(levelNo===4){loadRoadTerrain(layout);report.roadConnector={enabled:true,scope:'S4 source terrain entry only; original graph edges and target selection unchanged',helperSha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,'story-road-connector.cjs'))).digest('hex'),heights:layout.terrain.heights.length};persist();}
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:{width:1600,height:900}});const objectInput=await page.context().newCDPSession(page);let state,seq=0,objectRequest;const held=new Set();let firing=false;
 page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(line.slice(at+14));seq++;recordBattleObjects(objectRequest,state,seq,report,persist);}catch(e){report.probeErrors.push(e.message);}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);});
 page.on('pageerror',e=>{report.errors.push(e.message);persist();});page.on('crash',()=>{report.errors.push('Renderer crashed');persist();});
 async function wait(fn,label,timeout=240000){const start=Date.now();let probe=0;while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-start>timeout)throw Error('Timeout '+label);if(Date.now()-probe>800){probe=Date.now();await readKey();}await sleep(20);}return state;}
 async function readKey(){
  if(report.errors.length)throw Error(report.errors.join('\n'));
  let deadline;
  try{await Promise.race([page.keyboard.press('F8'),new Promise((_,reject)=>{deadline=setTimeout(()=>reject(Error('Read-only F8 input stalled after 15 seconds')),15000);})]);}
  finally{clearTimeout(deadline);}
 }
 async function dump(){const before=seq;await readKey();return wait(()=>seq>before,'fresh state',20000);}
 async function keys(next=[]){for(const key of held)if(!next.includes(key)){await page.keyboard.up(key);held.delete(key);}for(const key of next)if(!held.has(key)){await page.keyboard.down(key);held.add(key);}}
 async function fire(value){if(value===firing)return;firing=value;if(value)await page.mouse.down();else await page.mouse.up();}
 async function click(text){await dump();await wait(s=>Array.isArray(s.widgets)&&s.widgets.some(w=>w.text===text&&w.rect[2]>0&&w.rect[3]>0),'button '+text,30000);const b=state.widgets.find(w=>w.text===text),[x,y,w,h]=b.rect;await page.mouse.click((x+w/2)/state.width*1600,(y+h/2)/state.height*900);}
 async function sampleBattleObjects(name){
  if(state?.mode!=='trial'||!state.story)return;
  const request={stage:name,storyId:state.story.id,afterSequence:seq};assert(!objectRequest,'Only one explicit scene request may be pending');objectRequest=request;
  let deadline;const started=Date.now();
  try{
   await Promise.race([(async()=>{
    if(report.errors.length)throw Error(report.errors.join('\n'));
    const event={key:'F14',code:'F14',windowsVirtualKeyCode:125,nativeVirtualKeyCode:125};
    await objectInput.send('Input.dispatchKeyEvent',{type:'rawKeyDown',...event});await sleep(40);
    await objectInput.send('Input.dispatchKeyEvent',{type:'keyUp',...event});
    while(!request.snapshot){if(objectRequest!==request)throw Error('Explicit F14 request ended');if(report.errors.length)throw Error(report.errors.join('\n'));await sleep(20);}
   })(),new Promise((_,reject)=>{deadline=setTimeout(()=>reject(Error('Explicit F14 scene sample stalled after 15 seconds: '+name)),15000);})]);
   const sample=request.snapshot;assert(sample.objects.scene.supported,'Explicit F14 scene API failed: '+sample.objects.scene.error);
   sample.result='PASS';sample.requestElapsedMs=Date.now()-started;persist();
  }catch(error){
   const sample=request.snapshot||{stage:name,observed:null};sample.result='FAIL';sample.error=String(error);sample.requestElapsedMs=Date.now()-started;
   if(!request.snapshot)report.objectSamples.push(sample);persist();throw error;
  }
  finally{clearTimeout(deadline);if(objectRequest===request)objectRequest=null;}
 }
 async function shot(name){persist();await sampleBattleObjects(name);
  if(battleTimingCheck&&state?.performance?.battleTiming){
   const timings=Object.fromEntries(Object.entries(state.performance.updateTiming||{}).filter(([label])=>label.startsWith('battle.')));
   report.battleTiming.samples.push(structuredClone({stage:name,observedAt:Date.now(),state:state.performance.battleTiming,timings}));persist();
  }
  if(!logOnly){report.memory??=[];report.memory.push({stage:name,...await memoryProbe.read(page)});persist();}await page.screenshot({path:path.join(out,name+'.png'),timeout:15000});
 }
 const check=(value,label)=>{assert.ok(value,label);report.checks.push(label);};
 async function ambience(id,label){
  await wait(s=>{const a=s.performance?.ambience;return a?.chosen===id&&a.current===id&&a.playing&&a.amount>0;},label,45000);
  report.ambience??=[];report.ambience.push({stage:label,...structuredClone(state.performance.ambience)});
  check(true,label+' uses actual prepared playing SoundSource');persist();
 }
 try{
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow.active,'hall');if(!logOnly)report.initialMemory=await memoryProbe.install(page);
  if(ambienceCheck){await page.mouse.click(800,450);await ambience('amb_hangar','initial hall ambience');}
  await click('出战');await click('剧情模式');
  await wait(s=>s.tab==='story'&&s.story?.ready,'story selector');await click(level.no+'  '+level.name);await click('开始任务');
  await wait(s=>s.mode==='trial'&&s.story?.id===level.id&&!s.loadingFlow.active,'real mission');await page.mouse.click(800,450);await wait(s=>s.pointer.captured,'actual pointer capture');
  await configureBattleTiming(battleTimingCheck,async key=>{
   assert.equal(key,'F15');const event={key,code:key,windowsVirtualKeyCode:126,nativeVirtualKeyCode:126};
   await objectInput.send('Input.dispatchKeyEvent',{type:'rawKeyDown',...event});await sleep(40);
   await objectInput.send('Input.dispatchKeyEvent',{type:'keyUp',...event});
  },wait,value=>{Object.assign(report.battleTiming,value);persist();});
  check(state.sceneVisible&&state.loadingFlow.warmFrames>=2,'real mission revealed after source loading and rendered warmup');await shot('entered');
  if(ambienceCheck)await ambience('amb_crater','captured mission ambience');
  if(entryOnly){check(state.story.alive&&state.vehicle,'source mission entry has live player vehicle and original rules');report.result='PASS';report.boundary+=' Entry-only run: does not claim mission completion.';}
 const begun=Date.now();let transition='',route=[],progress={},routeAnchor,mouseX=800,mouseY=450,aimTracking={},bossTargetKey,completedCampaign=false;
  while(!entryOnly&&Date.now()-begun<limit*1000){
   await dump();const s=state.story;if(!s)throw Error('Story session disappeared');
   const current=s.step+':'+s.phase+':'+(s.cap?.phase||'')+':'+(s.boss?.flow||'');
   if(current!==transition){transition=current;route=[];progress={};routeAnchor=undefined;aimTracking={};report.transitions.push({at:Date.now()-begun,story:structuredClone(s),vehicle:structuredClone(state.vehicle)});persist();await shot('stage-'+report.transitions.length);}
   const sample={at:Date.now()-begun,story:structuredClone(s),vehicle:structuredClone(state.vehicle),keys:[...held],firing,
    resources:Object.fromEntries(Object.entries(state.performance||{}).filter(([key])=>['luaKiB','resourceBytes','modelBytes','arrayBytes','texture2DBytes','imageBytes','materialBytes','soundBytes','retiredTargets'].includes(key)))};report.samples.push(sample);
   if(spawnDiagnostic){
    const previousResult=report.spawnDiagnostic.result;
    const captured=observeSpawnDiagnostic(report.spawnDiagnostic,state,Date.now(),report.battleTiming);
    if(report.spawnDiagnostic.result!==previousResult)persist();
    if(captured){check(true,'Diagnostic captured actual first enemy spawn and at least 12 wall-clock seconds of detailed timing');await keys();await fire(false);await shot('first-spawn-window');report.result='PASS';break;}
   }
   if(convoyCheck)convoyAcceptance.observe(report.convoyAcceptance,s,sample.at,check);
   if(logOnly&&observeLog(report.logAcceptance,s,check)){report.result='PASS';await keys();await fire(false);await shot('log-picked');break;}
   if(s.finished){check(!spawnDiagnostic,'Diagnostic window cannot be replaced by whole-mission completion');check(!logOnly,'Log acceptance cannot be replaced by whole-mission completion');check(true,'complete mission reached through natural commands and original rules');completedCampaign=levelNo===5;report.result='PASS';await shot('result');break;}
   if(s.choice){await keys();await fire(false);const choiceKey=convoyCheck?convoyAcceptance.option(report.convoyAcceptance,s.choice,Date.now()-begun):'1';await page.keyboard.press(choiceKey);await sleep(500);continue;}
   if(!s.alive||!state.vehicle){await keys();await fire(false);await sleep(500);continue;}
   if(!state.pointer.captured){await page.mouse.click(800,450);await sleep(400);continue;}
   const p=state.vehicle.position,step=level.steps[s.index-1],hold=naturalInput.holdPlan(step,p,state.aimTargets),boss=bossPlan(state),target=boss?.goal||hold?.goal||s.target;
   if(boss){
    assert.notEqual(boss.reason,'missing-read-only-boss-observer','Boss acceptance requires actual cockpit and braced observers');
    sample.bossInput=boss;
    if(boss.targetKey!==bossTargetKey){aimTracking={};bossTargetKey=boss.targetKey;}
    if(!boss.firing&&boss.reason!=='shelter-navigation'){await keys();await fire(false);await sleep(500);continue;}
   }
   if(!target||s.boss?.cinematic){await keys();await fire(false);await sleep(500);continue;}
   const enemy=boss?boss.firing:!hold&&s.marker?.enemy,fireTarget=boss?(boss.firing?boss.legacyAimTarget:null):hold?hold.target:enemy?target:null,distance=flat(p,target);
   if(!route.length&&!hold?.park&&needsRoad(p,target,enemy||!!hold)){
    const record={at:sample.at,step:s.step,enemy:!!enemy,from:[...p],target:[...target]};
    route=roadRoute(p,target,layout,{terrainConnector:levelNo===4,onConnector:value=>{record.connector=structuredClone(value);}});
    record.points=structuredClone(route);report.routes.push(record);persist();
    if(route===null)throw Error('S4 natural navigation has no terrain-reachable road entry; original nearest-node fallback disabled');
    routeAnchor=route[0]?.pos;
   }
   if(hold?.park)route=[];
   const passed=advanceRoute(route,p);if(passed.length)routeAnchor=passed.at(-1).pos;
   const goal=route.length?route[0].pos:target,d=flat(p,goal),angle=wrap(Math.atan2(goal[0]-p[0],goal[2]-p[2])-state.vehicle.yaw);
   const goalId=route.length?'road:'+route[0].id:enemy?'enemy':'target:'+target.join(','),now=Date.now();
   const reversing=navigationProgress(progress,goalId,d,now),telemetry=state.wing?.telemetry;
   sample.navigation={goalId,goal:[...goal],remaining:route.map(p=>p.id),passed:passed.map(p=>p.id),distance:d,angle,
    heightError:route.length&&routeAnchor?routeHeightError(routeAnchor,goal,p):null,
    best:progress.best,stalledMs:now-progress.stuckAt,reversing,
    support:telemetry&&{contact:telemetry.contact,wheelSupport:telemetry.wheelSupport,groundDrive:telemetry.groundDrive,altitude:telemetry.altitude,totalSpeed:telemetry.totalSpeed}};
   const kind=step?.kind;
   if(fireTarget){
    const aim=naturalInput.aimSolution(state.camera,fireTarget,aimTracking,Date.now());sample.aim={target:[...fireTarget],...aim};
    mouseX+=aim.dx;mouseY+=aim.dy;
    await page.mouse.move(mouseX,mouseY);await fire(true);
   }else{aimTracking={};await fire(false);}
   sample.navigation.hold=hold&&{park:hold.park,target:hold.target};
   const inputDelay=fireTarget||hold?60:250;
   if(hold?.park||boss?.firing&&!route.length&&distance<boss.stopRange||!route.length&&d<6&&Math.abs(p[1]-target[1])<18){sample.navigation.command=['Space',...(['install','capture'].includes(kind)?['g']:[])];await keys(sample.navigation.command);await sleep(inputDelay);continue;}
   sample.navigation.command=navigationCommand({enemy,distance,speed:state.vehicle.speed||0,goalDistance:d,reversing,angle,routeFollowing:route.length>0});
   await keys(sample.navigation.command);await sleep(inputDelay);
  }
  if(report.result==='RUNNING'){report.result='INCOMPLETE';report.failure='Natural command route deadline; inspect captured transitions and screenshots before attributing to game logic.';report.lastState=state;await shot('deadline');}
  await keys();await fire(false);if(!state.story?.finished)await page.keyboard.press('Escape');await page.keyboard.press('t');
  if(completedCampaign){
   const observed=new Set();report.epilogue=[];const endingAt=Date.now();
   while(state.mode==='trial'&&Date.now()-endingAt<180000){
    await dump();const ep=state.story?.naturalEpilogueDetail;
    if(ep&&!observed.has(ep.index)){observed.add(ep.index);report.epilogue.push(structuredClone(ep));}
    if(state.mode==='hangar'&&!state.loadingFlow.active)break;await sleep(500);
   }
   check(report.epilogue.some(ep=>ep.active),'Actual natural epilogue appeared; previously watched save cannot silently pass');
  }
  await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'actual return',180000);check(state.performance.arrayBytes===0,'natural attempt return releases terrain arrays');
  if(ambienceCheck){await ambience('amb_hangar','returned hall ambience');await shot('returned-hall');}
 }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;
  persist();
  if(!report.errors.some(s=>/Aborted\(OOM\)|renderer crashed/i.test(s)))await shot('failure').catch(()=>{});}
 finally{report.finishedAt=new Date().toISOString();persist();await Promise.race([browser.close().catch(()=>{}),sleep(5000)]);}
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,errors:report.errors.length,transitions:report.transitions.length,out}));if(report.result!=='PASS')process.exitCode=1;
}
module.exports={observeLog,loadRoadTerrain,roadRoute,advanceRoute,navigationProgress,routeHeightError,navigationCommand,needsRoad,configureBattleTiming,observeSpawnDiagnostic};
if(require.main===module)main().catch(e=>{console.error(e);process.exitCode=1;});

'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {stream}=require('./monitor-combat-run.cjs');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function scoped(s){
 assert.equal(s.samplePhase,'post-update','Observe after production visibility masking');
 const t=s.trial;assert(t?.firstPerson&&t.scope&&t.effectsFirstPerson&&t.ownsWeapons,'Actual current-scope ownership and camera');
 assert(t.models>0&&t.visible===0,'Actual own vehicle models hidden');assert.equal(t.weaponFx.visible,false,'Persistent sibling FX hidden');
 assert(Object.keys(t.weaponFx.batches).length>0,'Nonvacuous persistent FX batches');
 for(const [kind,b]of Object.entries(t.weaponFx.batches))assert.equal(b.enabled,false,'Scoped batch hidden '+kind);
 assert.equal(t.samples.hiddenViolations,0,'No enabled own persistent batch during scoped PostUpdate');
 assert(t.projected<=t.projectiles-t.nearOwn,'Own near projectiles omitted from rendered list');
}
function restored(s){
 const t=s.trial;assert(!t.firstPerson&&!t.scope&&!t.effectsFirstPerson,'Scope released');assert(t.visible>0,'Actual own vehicle visible after release');
 assert(t.weaponFx.visible,'Persistent FX visibility restored');let positive=0;
 for(const b of Object.values(t.weaponFx.batches)){assert.equal(b.enabled,b.count>0,'Restore exactly populated batches');if(b.count>0)positive++}
 assert(positive>0,'Nonempty effect restored');
}
function selfTest(){
 const good={samplePhase:'post-update',trial:{firstPerson:true,scope:true,effectsFirstPerson:true,ownsWeapons:true,models:10,visible:0,weaponFx:{visible:false,batches:{Band:{count:4,enabled:false}}},samples:{hiddenViolations:0},projected:1,projectiles:2,nearOwn:1}};
 scoped(good);for(const mutate of [s=>{s.trial.visible=1},s=>{s.trial.weaponFx.batches={}},s=>{s.trial.weaponFx.batches.Band.enabled=true},s=>{s.trial.samples.hiddenViolations=1},s=>{s.trial.projected=2}]){const s=structuredClone(good);mutate(s);assert.throws(()=>scoped(s))}
 const release=structuredClone(good);Object.assign(release.trial,{firstPerson:false,scope:false,effectsFirstPerson:false,visible:10});release.trial.weaponFx.visible=true;release.trial.weaponFx.batches.Band.enabled=true;restored(release);
 console.log('PASS: five invalid scoped presentations rejected; nonempty restore checked');
}
function equipment(s){
 const e=s.trial?.equipmentEmit;assert(e?.attached,'Equipment observer attached to actual instances');
 assert.match(e.boundary,/outsideOwnPersistent includes own WeaponView/,'Unattributed calls must not be called enemy');
 for(const collection of [e.totals,e.draws,e.live])for(const b of Object.values(collection)){
  for(const [k,v]of Object.entries(b))assert(Number.isSafeInteger(v)&&v>=0,'Nonnegative scalar equipment '+k);
  assert(b.nearHalfMeter<=b.near2m&&b.near2m<=b.calls,'Nested distance counters');assert(b.accepted<=b.calls,'Accepted draws bounded');
  assert(b.acceptedNearHalfMeter<=b.acceptedNear2m&&b.acceptedNear2m<=b.accepted&&b.acceptedBehindCamera<=b.accepted,'Accepted distance counters bounded');
 }
 assert(Array.isArray(e.latest)||Object.keys(e.latest).length===0,'Latest emissions list');assert(Object.values(e.latest).length<=6,'Bounded emission details');
 for(const row of Object.values(e.latest)){assert(['ownPersistent','outsideOwnPersistent'].includes(row.owner));assert(row.pos.length===3&&row.pos.every(Number.isFinite));assert(Number.isFinite(row.depth)&&Number.isFinite(row.distanceSquared)&&row.distanceSquared>=0)}
 for(const name of ['Glow','Smoke']){const b=e.postUpdateBatches[name];assert(b&&Number.isSafeInteger(b.count)&&b.count>=0&&typeof b.enabled==='boolean');assert.equal(b.firstPerson,s.trial.firstPerson)}
}
async function reacquireScope(page,poll,wait,label){
 await page.mouse.up({button:'left'});await page.mouse.up({button:'right'});await page.bringToFront();
 let state=await poll();
 if(!state.trial?.captured){
  const canvas=await page.locator('#canvas').boundingBox();assert(canvas&&canvas.width>0&&canvas.height>0,'Actual visible canvas for pointer recapture');
  await page.mouse.click(canvas.x+canvas.width/2,canvas.y+canvas.height/2);
  state=await wait(s=>s.trial?.captured,'actual click pointer recapture '+label,15000);
 }
 assert(state.trial.captured,'Pointer capture required before real ADS input');
 await page.mouse.down({button:'right'});
 state=await wait(s=>s.trial?.captured&&s.trial.firstPerson&&s.trial.scope,'actual right-button ADS reacquire '+label,15000);
 scoped(state);return state;
}
async function run(base,out,options={}){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out),'Preserve previous evidence');fs.mkdirSync(out,{recursive:true});
 const report={status:'RUNNING',startedAt:new Date().toISOString(),errors:[],httpErrors:[],checks:[],samples:[],boundary:'Controlled synthetic connected T5 catalog fixture in real unmodified App/TrialSession. Real right/left mouse input; F7 fixture setup, F6 controlled target placement/aim, F9 read-only state. Screenshots/polling are not FPS, mobile or natural/public gameplay acceptance.'};
 const deadline=Date.now()+360000;let browser,page,state,sequence=0;const streams=new Map();
 const persist=()=>{report.lastState=state;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n')};
 const healthy=()=>{assert(Date.now()<deadline,'360s total QA deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors[0]))};
 const progress=label=>{report.stage={label,at:new Date().toISOString()};persist();console.log(JSON.stringify({progress:label,out}))};
 try{
  const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.scopeFxQa?.isolated);report.identity=identity;
  if(options.compact!==undefined)assert.equal(identity.scopeFxQa.compact,options.compact,'Explicit controlled QA startup configuration');
  const manifest=JSON.parse(fs.readFileSync(identity.manifest_path,'utf8'));report.hashes={};
  for(const name of ['main.lua','app/TrialSession.lua','render/CombatEffects.lua','render/WeaponEffects.lua','combat/WeaponSystem.lua','ui/MissileHud.lua','ui/ReticleState.lua','controls/TouchMode.lua']){
   const entry=manifest.files.find(x=>x.fs_path===name);assert(entry,name);const response=await fetch(base+'/game-dist/assets/'+entry.uuid+'-'+entry.hash+entry.ext);assert.equal(response.status,200);
   const hash=sha(Buffer.from(await response.arrayBuffer()));assert.equal(hash,identity.identity.scripts[name]);report.hashes[name]=hash;
  }
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  const initial=options.initialViewport||{width:1600,height:900};
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});page=await browser.newPage({viewport:initial,deviceScaleFactor:options.dpr||1});
  page.on('console',m=>{const text=m.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');
   if(m.type()==='error'||/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\bERROR:/.test(text))report.errors.push(text);
   const at=text.indexOf('SCOPE_FX_CHUNK ');if(at>=0)try{const v=JSON.parse(text.slice(at+15));let s=streams.get(v.kind);if(!s){s=stream();streams.set(v.kind,s)}s.add(v);if(s.ready()){const data=s.value();assert.equal(v.kind,'state-'+data.sequence);assert(data.sequence>sequence,'Monotonic states');state=data;sequence=data.sequence}}catch(e){report.errors.push(e.stack)}
  });
  page.on('pageerror',e=>{report.errors.push(e.stack||e.message);fs.appendFileSync(path.join(out,'runtime.log'),'PAGEERROR '+(e.stack||e.message)+'\n')});page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({status:r.status(),url:r.url()})});
  async function poll(){const old=sequence,until=Math.min(deadline,Date.now()+5000);await page.keyboard.press('F9');while(sequence===old){healthy();assert(Date.now()<until,'Validated state timeout');await sleep(35)}if(options.equipmentEmit&&state.trial?.equipmentEmit?.attached)equipment(state);if(options.compact!==undefined){const r=state.reticle;assert.equal(r.compact,options.compact,'Retained startup compact policy');const k=options.compact?Math.min(state.width/(600*16/9),state.height/600,state.width/1300)*.62:Math.min(state.width/1920,state.height/1080);assert(Math.abs(r.layout.k-k)<1e-6,'Actual runtime layout scale matches source formula');assert.equal(r.dpr,options.dpr||1,'Actual runtime DPR')}return state}
  async function wait(predicate,label,timeout=20000){progress(label);const until=Math.min(deadline,Date.now()+timeout);while(!state||!predicate(state)){healthy();assert(Date.now()<until,'Stage timeout '+label);await poll();await sleep(120)}return state}
  async function shot(name){await poll();report.samples.push({name,state});fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(state,null,2));await page.locator('#canvas').screenshot({path:path.join(out,name+'.png'),timeout:15000})}
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login',{waitUntil:'domcontentloaded'});await page.bringToFront();
  await page.waitForFunction(()=>globalThis.Module?.calledRun===true,{},{timeout:150000});
  const bootstrapEnd=Date.now()+90000;
  while(!state){healthy();assert(Date.now()<bootstrapEnd,'App bootstrap deadline');await page.keyboard.press('F9');await sleep(500)}
  await wait(s=>s.mode==='hangar'&&!s.loading,'real hall');
  if(options.bootstrapOnly){await shot('actual-hall');report.checks.push('Actual app hall reached; bootstrap-only, no trial acceptance');report.status='PASS';return report}
  for(let n=0;n<4;n++){
   const b=(Array.isArray(state.widgets)?state.widgets:[]).find(w=>/^(跳过引导|确定跳过？再点一次)$/.test(w.text));if(!b)break;
   await page.mouse.click((b.rect[0]+b.rect[2]/2)/state.width*initial.width,(b.rect[1]+b.rect[3]/2)/state.height*initial.height);await sleep(300);await poll();
  }
  await page.keyboard.press('F7');await wait(s=>s.mode==='trial'&&!s.loading&&s.trial?.groups.length===4,'real T5 trial',180000);
  assert(state.fixture.synthetic&&state.fixture.parts===35);assert.deepEqual(state.trial.groups.map(x=>x.kind),['mg','laser','sniper','missile']);
  progress('actual pointer input');const captureDeadline=Math.min(deadline,Date.now()+15000);
  while(!state.trial?.captured){healthy();assert(Date.now()<captureDeadline,'Stage timeout actual pointer input');await page.mouse.click(initial.width/2,initial.height/2);await sleep(700);await poll()}
  await page.keyboard.press('F6');await poll();assert(state.placement.controlled);
  for(const kind of options.kinds||['laser','mg','sniper','missile']){
   const selected=state.trial.groups.findIndex(g=>g.kind===kind)+1;assert(selected>0);await page.keyboard.press(String(selected));await wait(s=>s.trial.selected===selected,'select '+kind);
   await page.keyboard.press('F6');await poll();await wait(s=>s.trial.energy>=95,'real energy recovery '+kind,45000);
   const batch={laser:'Band',mg:'Swirl',sniper:'Ribbon'}[kind];
   if(kind==='missile')await wait(s=>s.trial.lock?.locked,'real missile lock',15000);
   else{
    await page.mouse.down({button:'left'});
    await wait(s=>s.trial.weaponFx.batches[batch]?.count>0&&s.trial.weaponFx.batches[batch].enabled,'nonzero visible '+batch,20000);
   }
   await shot(kind+'-normal');if(batch){const b=state.trial.weaponFx.batches[batch];assert(b.count>0&&b.enabled,'Nonvacuous '+batch+' before scope')}
   const shots=state.trial.shots;
   try{
    await page.mouse.down({button:'right'});await wait(s=>s.trial.firstPerson&&s.trial.scope,'real right held '+kind);scoped(state);
    if(kind==='missile')await page.mouse.down({button:'left'});
    let fired=false;
    for(let n=0;n<12;n++){await sleep(160);await poll();scoped(state);if(state.trial.shots>shots)fired=true;if(n===0||n===5||n===11)await shot(kind+'-scope-'+n)}
    if(!fired)await wait(s=>s.trial.shots>shots,'real scoped shots '+kind,15000);
    scoped(state);assert(state.trial.shots>shots,'Real shots increase '+kind);report.checks.push(kind+' actual scoped fire; populated own FX hidden');
    if(options.equipmentEmit){equipment(state);report.equipmentEmit=state.trial.equipmentEmit;report.checks.push(kind+' scalar EquipmentEmit ownership/draw/live telemetry recorded; zero emissions permitted')}
    if(options.resizeMissile&&kind==='missile'){
     await page.mouse.up({button:'left'});await page.mouse.up({button:'right'});
     await page.setViewportSize({width:2000,height:900});await sleep(350);await poll();
     await shot('missile-resize-2000x900-before-recapture');
     await reacquireScope(page,poll,wait,'2000x900');equipment(state);
     assert(Math.abs(state.width/state.height-20/9)<.005,'Same-page UI logical viewport aspect 20:9');
     const canvas=await page.locator('#canvas').boundingBox();assert(canvas&&Math.abs(canvas.width/canvas.height-20/9)<.005,'Rendered canvas aspect 20:9');
     await shot('missile-scope-2000x900');report.checks.push('Missile scope same-page 1600x900 to 2000x900; actual aspect and scoped assertions');
     await page.mouse.up({button:'right'});await page.setViewportSize({width:1600,height:900});await sleep(250);await poll();
     await reacquireScope(page,poll,wait,'restore-1600x900');equipment(state);await shot('missile-scope-restored-1600x900');
    }
    if(options.compact!==undefined&&kind==='missile'){
     for(const viewport of [{width:1200,height:540},{width:1280,height:720}]){
      await page.mouse.up({button:'left'});await page.mouse.up({button:'right'});
      await page.setViewportSize(viewport);await sleep(350);await poll();
      await reacquireScope(page,poll,wait,viewport.width+'x'+viewport.height);
      await shot('compact-'+Number(options.compact)+'-scope-'+viewport.width+'x'+viewport.height);
      report.checks.push('Actual retained compact='+options.compact+' and scoped mask at '+viewport.width+'x'+viewport.height);
     }
    }
   }catch(e){try{await shot(kind+'-scope-failure-held')}catch{}throw e}
   finally{await page.mouse.up({button:'left'});await page.mouse.up({button:'right'})}
   await wait(s=>!s.trial.firstPerson&&!s.trial.scope,'scope release '+kind);await shot(kind+'-released');restored(state);report.checks.push(kind+' populated persistent FX restored');
  }
  if(!options.kinds)for(const kind of ['Band','Swirl','Ribbon'])assert(state.trial.samples.normalMax[kind]>0&&state.trial.samples.scopedMax[kind]>0,'Real populated persistent update coverage '+kind);
  assert(state.trial.samples.scoped>0&&state.trial.samples.hiddenViolations===0);report.status='PASS';
 }catch(e){report.status='FAIL';report.failure=e.stack;if(page)try{await page.screenshot({path:path.join(out,'failure.png'),timeout:3000})}catch{}throw e}
 finally{
  if(browser)try{await Promise.race([browser.close(),sleep(5000).then(()=>{throw Error('Browser close timeout')})]);report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.status='FAIL';report.closeError=e.message}
  report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({status:report.status,shutdown:report.shutdown,out,failure:report.failure}));
 }
 return report;
}
module.exports={run,scoped,restored,equipment,reacquireScope,selfTest};if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else run(process.argv[2],path.resolve(process.argv[3])).catch(e=>{console.error(e.stack);process.exitCode=1})}

'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {stream}=require('./monitor-combat-run.cjs');
const {scoped,equipment}=require('./scope-fx-isolated-run.cjs');
const {awaitFirstState}=require('./ads-pixel-run.cjs');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function check(source,kind){
 assert(source?.attached&&source.firstPerson&&source.ownViewMatches,'Actual sourceView matches current first-person VehicleView');
 assert.equal(source.group,kind);assert.equal(source.violations,0,'Own producer source identity');
 for(const origin of ['ownPersistent','ownMotion'])assert.equal(source.draws[kind+':scoped:'+origin+':own']||0,0,'Own equipment cannot submit visible scoped geometry');
}
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
 const report={status:'RUNNING',errors:[],httpErrors:[],samples:[],checks:[],boundary:'One isolated real App/Trial T5 fixture, four groups, real right/left mouse ADS. Actual sourceView particle identity and accepted draw counters; not natural gameplay, FPS or mobile acceptance.'};
 let browser,page,state,source,sequence=0,sourceSequence=0;const streams=new Map(),deadline=Date.now()+420000;
 const persist=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
 const healthy=()=>{assert(Date.now()<deadline,'420s deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors[0]))};
 try{
  const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.adsSourceQa?.isolated);report.identity=identity;
  const manifest=JSON.parse(fs.readFileSync(identity.manifest_path,'utf8'));report.payloadHashes={};
  for(const name of ['main.lua','render/CombatEffects.lua','render/WeaponEffects.lua','render/WeaponView.lua','app/TrialSession.lua']){
   const entry=manifest.files.find(row=>row.fs_path===name);assert(entry);const response=await fetch(base+'/game-dist/assets/'+entry.uuid+'-'+entry.hash+entry.ext);assert.equal(response.status,200);
   const actual=sha(Buffer.from(await response.arrayBuffer()));assert.equal(actual,identity.identity.scripts[name]);report.payloadHashes[name]=actual;
  }
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});page=await browser.newPage({viewport:{width:1600,height:900},deviceScaleFactor:1});
  page.on('console',m=>{const text=m.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');
   if(m.type()==='error'||/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\bERROR:/.test(text))report.errors.push(text);
   let at=text.indexOf('SCOPE_FX_CHUNK ');if(at>=0)try{const v=JSON.parse(text.slice(at+15));let s=streams.get(v.kind);if(!s){s=stream();streams.set(v.kind,s)}s.add(v);if(s.ready()){state=s.value();sequence=state.sequence}}catch(e){report.errors.push(e.stack)}
   at=text.indexOf('ADS_SOURCE_STATE ');if(at>=0)try{source=JSON.parse(text.slice(at+17));sourceSequence=source.sequence}catch(e){report.errors.push(e.stack)}
  });
  page.on('pageerror',e=>report.errors.push(e.stack||e.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({status:r.status(),url:r.url()})});
  async function poll(){const old=sequence,oldSource=sourceSequence,until=Date.now()+6000;await page.keyboard.press('F9');
   while(sequence===old||sourceSequence===oldSource){healthy();assert(Date.now()<until,'Actual scope+source state timeout');await sleep(35)}return state;
  }
  async function wait(predicate,label,timeout=25000){report.stage=label;persist();console.log(label);const until=Date.now()+timeout;
   do{healthy();await poll();if(predicate(state,source))return;assert(Date.now()<until,'Stage timeout '+label);await sleep(100)}while(true);
  }
  async function shot(label){await poll();report.samples.push({label,state:structuredClone(state),source:structuredClone(source)});
   fs.writeFileSync(path.join(out,label+'.json'),JSON.stringify({state,source},null,2));await page.locator('#canvas').screenshot({path:path.join(out,label+'.png'),timeout:15000});
  }
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login',{waitUntil:'domcontentloaded'});await page.bringToFront();
  await page.waitForFunction(()=>globalThis.Module?.calledRun===true,{},{timeout:150000});await awaitFirstState(()=>state,()=>page.keyboard.press('F9'),healthy);
  await wait(s=>s.mode==='hangar'&&!s.loading,'actual hall',90000);
  for(let n=0;n<4;n++){const b=(Array.isArray(state.widgets)?state.widgets:[]).find(w=>/^(跳过引导|确定跳过？再点一次)$/.test(w.text));if(!b)break;
   await page.mouse.click((b.rect[0]+b.rect[2]/2)/state.width*1600,(b.rect[1]+b.rect[3]/2)/state.height*900);await sleep(300);await poll();
  }
  await page.keyboard.press('F7');await wait(s=>s.mode==='trial'&&!s.loading&&s.trial?.groups.length===4,'actual T5 trial',180000);
  await page.mouse.click(800,450);await wait(s=>s.trial?.captured,'actual pointer',15000);
  for(const kind of ['mg','laser','sniper','missile']){
   const index=state.trial.groups.findIndex(g=>g.kind===kind)+1;assert(index>0);await page.keyboard.press(String(index));await wait(s=>s.trial.selected===index,'select '+kind);
   await page.keyboard.press('F6');await poll();assert(state.placement.controlled);await wait(s=>s.trial.energy>=95,'energy '+kind,45000);
   const shots=state.trial.shots;
   if(kind==='missile')await wait(s=>s.trial.lock?.locked,'real missile lock',15000);
   await page.mouse.down({button:'left'});
   if(kind==='mg')await wait(s=>s.trial?.weaponFx?.batches?.Swirl?.count>0,'actual MG spin',15000);
   else await sleep(500);
   await shot(kind+'-normal');
   const persistentBefore=source.emissions[kind+':scoped:ownPersistent:own']||0;
   await page.mouse.down({button:'right'});await wait(s=>s.trial.firstPerson&&s.trial.scope,'actual ADS '+kind,15000);
   scoped(state);equipment(state);check(source,kind);
   await wait(s=>s.trial.shots>shots,'real scoped shots '+kind,15000);
   for(let n=0;n<4;n++){await sleep(150);await poll();scoped(state);check(source,kind)}
   if(kind==='mg'){
    await wait((s,q)=>s.trial.firstPerson&&s.trial.scope&&(q.emissions[kind+':scoped:ownPersistent:own']||0)>persistentBefore&&(q.live['ownPersistent:own']||0)>0,'actual new persistent spark alive but hidden',15000);
    check(source,kind);report.nonvacuousPersistentSource=structuredClone(source);persist();
   }
   await shot(kind+'-scoped');scoped(state);check(source,kind);
   const restoredBefore=source.restored[kind+':ownPersistent']||0;
   if(kind==='mg')await wait((s,q)=>s.trial.firstPerson&&s.trial.scope&&q.youngOwnPersistent>0,'surviving scoped own spark before release',15000);
   await page.mouse.up({button:'right'});
   await wait((s,q)=>!s.trial.firstPerson&&!s.trial.scope&&q.ownViewCleared,'scope release '+kind,15000);
   if(kind==='mg'){
    await wait((s,q)=>(q.restored[kind+':ownPersistent']||0)>restoredBefore,'same scoped persistent particle draws after release',10000);
    report.checks.push('MG actual persistent source particles emitted alive in ADS with zero accepted draw; exact same surviving particle IDs submit again after release');
   }
   await shot(kind+'-released');await page.mouse.up({button:'left'});assert.equal(source.violations,0);
   report.checks.push(kind+' actual scoped fire, own model/persistent batch hidden, ownView identity and zero accepted own equipment draws; release clears ownView');
  }
  report.status='PASS';report.lastState=state;report.lastSource=source;
 }catch(e){report.status='FAIL';report.failure=e.stack;if(page)try{await page.screenshot({path:path.join(out,'failure.png'),timeout:3000})}catch{}throw e}
 finally{
  if(browser)try{await Promise.race([browser.close(),sleep(5000).then(()=>{throw Error('Browser close timeout')})]);report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.status='FAIL';report.closeError=e.message}
  report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({status:report.status,out,failure:report.failure}));
 }
 return report;
}
module.exports={run,check};if(require.main===module)run(process.argv[2],path.resolve(process.argv[3])).catch(e=>{console.error(e.stack);process.exitCode=1});

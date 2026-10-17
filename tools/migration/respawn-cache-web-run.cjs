'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {stream}=require('./monitor-combat-run.cjs');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function assertRespawn(s){
 assert(s.initial.prepared>0&&s.initial.hits>=8,'Initial pristine eight-car cache hits');
 assert(s.death&&s.target.alive,'Actual NPC death followed by live respawn');
 assert(s.cache.hits>s.death.hits,'Actual respawn cache hit increments');
 assert.equal(s.target.parts,s.death.parts,'Pristine full blueprint restored');
 assert(s.worldTime-s.death.deadAt>=s.death.respawnSeconds,'Actual simulation delay reached');
 assert.equal(s.cache.disposed,false);
}
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
 const report={status:'RUNNING',errors:[],httpErrors:[],startedAt:new Date().toISOString()},deadline=Date.now()+300000;
 let browser,page,state,seq=0;const streams=new Map();
 const persist=()=>{report.lastState=state;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n')};
 const healthy=()=>{assert(Date.now()<deadline,'300s total deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors[0]))};
 const stage=label=>{report.stage=label;persist();console.log(JSON.stringify({progress:label,out}))};
 try{
  const identity=await fetch(base+'/identity.json').then(r=>r.json());report.identity=identity;
  assert(identity.respawnCacheWeb?.isolated);assert.equal(identity.qa,false);
  const relative=path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/');
  const manifest=await fetch(base+'/game-dist/'+relative).then(r=>r.json());report.httpHashes={};
  for(const n of Object.keys(identity.respawnCacheWeb.sources)){
   const entry=manifest.files.find(x=>x.fs_path===n);assert(entry,n);
   const r=await fetch(base+'/game-dist/assets/'+entry.uuid+'-'+entry.hash+entry.ext);assert.equal(r.status,200);
   const hash=sha(Buffer.from(await r.arrayBuffer()));assert.equal(hash,identity.identity.scripts[n]);report.httpHashes[n]=hash;
  }
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});
  page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',m=>{
   const text=m.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');
   if(m.type()==='error'||/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\bERROR:/.test(text))report.errors.push(text);
   const prefix='RESPAWN_CACHE_WEB_CHUNK ',at=text.indexOf(prefix);
   if(at>=0)try{
    const v=JSON.parse(text.slice(at+prefix.length));let s=streams.get(v.kind);if(!s){s=stream();streams.set(v.kind,s)}s.add(v);
    if(s.ready()){state=s.value();assert.equal(v.kind,'state-'+state.sequence);state.widgets=Array.isArray(state.widgets)?state.widgets:[];seq++}
   }catch(e){report.errors.push(e.stack)}
  });
  page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({url:r.url(),status:r.status()})});
  page.on('requestfailed',r=>report.httpErrors.push({url:r.url(),error:r.failure()?.errorText}));
  async function poll(){
   const old=seq,initial=!state,until=initial?deadline:Math.min(deadline,Date.now()+5000);let next=0;
   while(seq===old){healthy();assert(Date.now()<until,'F7 state deadline');if(Date.now()>=next){await page.keyboard.press('F7');next=initial?Date.now()+500:Infinity}await sleep(50)}return state;
  }
  async function wait(predicate,label,timeout=15000){
   stage(label);const until=Math.min(deadline,Date.now()+timeout);
   while(!state||!predicate(state)){healthy();assert(Date.now()<until,'Stage deadline: '+label);await poll();if(!predicate(state))await sleep(300)}return state;
  }
  async function click(text){
   await wait(s=>s.widgets.some(x=>x.text===text&&!x.disabled&&x.rect[2]>0),'button '+text);
   const w=state.widgets.find(x=>x.text===text&&!x.disabled&&x.rect[2]>0);
   await page.mouse.click((w.rect[0]+w.rect[2]/2)/state.width*1600,(w.rect[1]+w.rect[3]/2)/state.height*900);await poll();
  }
  report.url=base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login';
  await page.goto(report.url,{waitUntil:'domcontentloaded',timeout:30000});await page.bringToFront();
  await page.waitForFunction(()=>globalThis.Module?.calledRun===true,{},{timeout:Math.max(1,deadline-Date.now())});
  await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loading,'hall bootstrap',120000);
  stage('public mode entry');const entryDeadline=Date.now()+15000;
  for(;;){
   healthy();assert(Date.now()<entryDeadline,'public mode entry deadline');
   const skip=state.widgets.find(x=>/^(跳过引导|确定跳过？再点一次)$/.test(x.text)&&!x.disabled);
   if(skip){if(skip.text==='跳过引导')await click('跳过引导');await click('确定跳过？再点一次');await wait(s=>!s.widgets.some(x=>/跳过引导|确定跳过/.test(x.text)),'tutorial skip')}
   else if(state.widgets.some(x=>x.text==='站点争夺'&&!x.disabled))break;
   else await click('出战');
   await sleep(100);await poll();
  }
  await click('站点争夺');await click('开始匹配');
  await wait(s=>s.mode==='trial'&&s.battle&&!s.loading,'actual eight-car battle',120000);
  if(state.intro){await page.keyboard.press('Space');await wait(s=>!s.intro,'camera intro skipped')}
  await wait(s=>s.battle.state==='live','actual battle live');
  stage('public pointer capture');const pointerDeadline=Date.now()+15000;let next=0;
  while(!state.captured){healthy();assert(Date.now()<pointerDeadline);if(Date.now()>=next){await page.locator('#canvas').click();next=Date.now()+700}await poll();await sleep(100)}
  assert(state.initial.prepared>0&&state.initial.hits>=8);assert.equal(state.battle.count,8);report.loaded=state;
  await page.locator('#canvas').screenshot({path:path.join(out,'loaded.png'),timeout:10000});
  stage('explicit QA NPC core Destroy/Flush');await page.keyboard.press('F10');
  await wait(s=>s.death&&!s.target.alive,'actual NPC dead');report.dead=state;
  assert.equal(state.cache.hits,state.death.hits,'Death does not spawn');
  await wait(s=>s.target.alive&&s.cache.hits>s.death.hits,'actual BeforeStep respawn',45000);
  assertRespawn(state);report.respawned=state;
  await page.locator('#canvas').screenshot({path:path.join(out,'respawned.png'),timeout:10000});
  await page.keyboard.press('Escape');await click('返回车库');await click('确定');
  await wait(s=>s.mode==='hangar'&&!s.loading,'public returned hall',45000);
  assert(state.cache.disposed&&state.cache.empty,'Retained scene-owned cache disposed and emptied');report.returned=state;
  await page.locator('#canvas').screenshot({path:path.join(out,'returned.png'),timeout:10000});
  report.status='PASS';report.boundary=identity.respawnCacheWeb.boundary;
 }catch(e){report.status='FAIL';report.failure=e.stack;if(page)try{await page.screenshot({path:path.join(out,'failure.png'),timeout:3000})}catch{}throw e}
 finally{
  if(browser)try{await Promise.race([browser.close(),sleep(5000).then(()=>{throw Error('close deadline')})]);report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.closeError=e.message}
  report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({status:report.status,shutdown:report.shutdown,out,failure:report.failure}));
 }
 return report;
}
function selfTest(){
 const good={initial:{prepared:8,hits:8},death:{hits:8,deadAt:10,respawnSeconds:5,parts:20},target:{alive:true,parts:20},cache:{hits:9,disposed:false},worldTime:15};assertRespawn(good);
 for(const change of [s=>s.cache.hits=8,s=>s.target.parts=19,s=>s.target.alive=false,s=>s.worldTime=14,s=>s.initial.hits=7,s=>s.cache.disposed=true]){const bad=structuredClone(good);change(bad);assert.throws(()=>assertRespawn(bad))}
 console.log('PASS: respawn acceptance and six negative controls');
}
module.exports={run,assertRespawn,selfTest};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else run(process.argv[2],path.resolve(process.argv[3])).catch(e=>{console.error(e.stack);process.exitCode=1})}

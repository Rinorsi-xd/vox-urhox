'use strict';
// Root owns hardware. Frozen originals are immutable; current production modules
// and diagnostic-only main suffix are supplied to this one browser by requests.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {stream}=require('./monitor-combat-run.cjs');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
function payloads(prepared){
 const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path)),modified=structuredClone(manifest),files=new Map();
 for(const name of ['main.lua','app/EndlessSession.lua','endless/View.lua']){
  const entry=manifest.files.find(x=>x.fs_path===name);assert(entry,name);
  const original=fs.readFileSync(path.join(prepared.source_directory,'dist/assets',entry.uuid+'-'+entry.hash+entry.ext));
  assert.equal(sha(original),prepared.identity.scripts[name],'Frozen original '+name);
  const body=name==='main.lua'?Buffer.concat([original,Buffer.from('\n'+fs.readFileSync(path.join(__dirname,'probe-endless-ground-pickup.lua'),'utf8'))]):fs.readFileSync(path.join(root,'scripts',name));
  modified.files.find(x=>x.fs_path===name).size=body.length;
  files.set('/game-dist/assets/'+entry.uuid+'-'+entry.hash+entry.ext,{name,original,body});
 }
 return {manifest,modified,files,manifestRoute:'/game-dist/'+path.relative(path.join(prepared.source_directory,'dist'),prepared.manifest_path).replaceAll('\\','/')};
}
function verify(stages){
 assert.deepEqual(stages.map(s=>s.stage),[1,2,3,4]);const [far,air,near,released]=stages;
 for(const s of [far,air,near])assert(s.frozen);
 assert(!released.frozen);assert(far.selected.pending&&air.selected.pending);assert(!near.selected.pending&&near.selected.collecting);
 assert.equal(far.run.credits,far.selected.before);assert.equal(air.run.credits,far.selected.before);
 assert.equal(near.run.credits,far.selected.before+far.selected.amount);
 assert(far.selected.death[0]===far.selected.root[0]);assert(Math.abs(far.selected.root[1]-far.selected.ground-.1)<.001);
 assert(air.run.player[1]-air.selected.root[1]>30,'Airborne old point remains far from displayed ground loot');
 assert.equal(new Set(stages.map(s=>s.selected.id)).size,1);assert(near.checks.length>=9);
 return {result:'PASS',sourcePickupRadius:8,checks:near.checks};
}
async function run(base,out,identityPath){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out),'Fresh evidence required');fs.mkdirSync(out,{recursive:true});
 const prepared=JSON.parse(fs.readFileSync(identityPath));const payload=payloads(prepared);
 const report={result:'RUNNING',stages:[],errors:[],httpErrors:[],requests:[],responses:[],startedAt:new Date().toISOString(),
  boundary:'Controlled real enemy destruction, controlled player teleports, unchanged production rules. Request-only main diagnostic; current production EndlessSession and View byte-exact. No natural full-wave, account, visual 1:1 or FPS acceptance.'};
 let browser,page,state,seq=0;const streams=new Map(),deadline=Date.now()+300000;
 const persist=()=>fs.writeFileSync(path.join(out,'result.json'),JSON.stringify({...report,lastState:state},null,2));
 function healthy(){assert(Date.now()<deadline,'300s total deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors[0]))}
 async function fresh(){const prior=seq,until=Math.min(deadline,Date.now()+(state?8000:130000));let next=0;
  while(seq===prior){healthy();assert(Date.now()<until,'Complete F7 state deadline');if(Date.now()>next){await page.keyboard.press('F7');next=Date.now()+500}await sleep(60)}return state}
 async function wait(fn,label,ms=30000){const until=Math.min(deadline,Date.now()+ms);while(!state||!fn(state)){healthy();assert(Date.now()<until,label);await fresh();await sleep(75)}return state}
 async function click(text){await wait(s=>s.widgets.some(w=>w.text===text&&!w.disabled),'Visible '+text,15000);const r=state.widgets.filter(w=>w.text===text&&!w.disabled).at(-1).rect;
  await page.mouse.click((r[0]+r[2]/2)*1600/state.width,(r[1]+r[3]/2)*900/state.height);await fresh()}
 try{
  report.identity=await fetch(base+'/identity.json').then(r=>r.json());assert.equal(report.identity.qa,false);assert.deepEqual(report.identity.identity,prepared.identity);
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   if(m.type()==='error'||/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\bERROR:/.test(line))report.errors.push(line);
   const at=line.indexOf('ENDLESS_PICKUP_CHUNK ');if(at>=0)try{const chunk=JSON.parse(line.slice(at+21));let parts=streams.get(chunk.kind);if(!parts){parts=stream();streams.set(chunk.kind,parts)}parts.add(chunk);
    if(parts.ready()){state=parts.value();assert.equal(chunk.kind,'state-'+state.sequence);seq++;fs.appendFileSync(path.join(out,'states.jsonl'),JSON.stringify(state)+'\n')}}catch(e){report.errors.push(e.stack)}
  });
  page.on('pageerror',e=>report.errors.push(e.stack));page.on('crash',()=>report.errors.push('Renderer crashed'));
  const routes=new Map(payload.files);routes.set(payload.manifestRoute,{name:'manifest',original:Buffer.from(JSON.stringify(payload.manifest)),body:Buffer.from(JSON.stringify(payload.modified))});
  page.on('response',response=>{if(response.status()>=400)report.httpErrors.push({url:response.url(),status:response.status()});const item=routes.get(new URL(response.url()).pathname);
   if(item)void response.body().then(bytes=>{assert(bytes.equals(item.body),'Actual response '+item.name);report.responses.push({name:item.name,sha256:sha(bytes)})}).catch(e=>report.errors.push(e.stack))});
  for(const [url,item]of routes)await page.route(base+url,async route=>{try{const response=await route.fetch();assert.equal(response.status(),200);const bytes=await response.body();
   if(item.name==='manifest')assert.deepEqual(JSON.parse(bytes),payload.manifest);else assert(bytes.equals(item.original),'Actual frozen original '+item.name);
   report.requests.push({name:item.name,originalSha256:sha(bytes),servedSha256:sha(item.body)});await route.fulfill({response,body:item.body,headers:{...response.headers(),'content-length':String(item.body.length)}})}catch(e){report.errors.push(e.stack);await route.abort()}});
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login',{waitUntil:'domcontentloaded',timeout:30000});await page.bringToFront();
  await wait(s=>s.mode==='hangar'&&!s.loading,'Actual hall',150000);
  const tutorialUntil=Date.now()+15000;
  for(;;){healthy();assert(Date.now()<tutorialUntil,'Public tutorial dismissal');const skip=state.widgets.find(w=>/^(跳过引导|确定跳过？再点一次)$/.test(w.text)&&!w.disabled);
   if(skip){if(skip.text==='跳过引导')await click(skip.text);await click('确定跳过？再点一次')}else{await page.keyboard.press('F10');await fresh();if(state.widgets.some(w=>w.text==='先锋 · 轮式激光'))break;await sleep(100)}}
  await click('先锋 · 轮式激光');
  await wait(s=>s.mode==='trial'&&s.run&&!s.loading,'Actual endless scene ready',120000);
  await page.locator('#canvas').click();await wait(s=>s.captured,'Actual driving pointer captured',10000);
  await wait(s=>s.run?.state==='combat'&&s.run.enemies>0&&s.run.pending>0&&!s.loading,'Natural first wave and actual enemy',30000);
  for(let stage=1;stage<=4;stage++){await page.keyboard.press('F11');await wait(s=>s.stage===stage,'Controlled pickup stage '+stage,15000);report.stages.push(structuredClone(state));await page.screenshot({path:path.join(out,'stage-'+stage+'.png'),timeout:10000});persist()}
  report.verification=verify(report.stages);await wait(s=>s.stage===4&&!s.selected.visual,'Natural absorption completes after simulation release',10000);
  assert.equal(state.run.credits,state.selected.before+state.selected.amount,'No duplicate credit');report.absorbed=structuredClone(state);await page.screenshot({path:path.join(out,'absorbed.png'),timeout:10000});
  await page.keyboard.press('Escape');await wait(s=>s.widgets.some(w=>w.text==='返回车库'),'Unified pause return',10000);await click('返回车库');await wait(s=>s.mode==='hangar'&&!s.loading,'Public returned hall',60000);
  await page.screenshot({path:path.join(out,'returned.png'),timeout:10000});
  for(const item of routes.values()){assert(report.requests.some(x=>x.name===item.name),'Request '+item.name);assert(report.responses.some(x=>x.name===item.name),'Response '+item.name)}
  healthy();report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;if(page)try{await page.screenshot({path:path.join(out,'failure.png'),timeout:3000})}catch{}throw error}
 finally{if(browser)try{await browser.close();report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.closeError=e.stack}report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({result:report.result,out,shutdown:report.shutdown,failure:report.failure}))}
 return report;
}
function selfTest(){
 const b={stage:1,frozen:true,selected:{id:'drop-1',pending:true,root:[20,.1,0],death:[20,40,0],ground:0,before:0,amount:37},run:{credits:0,player:[0,0,0]},checks:Array(10).fill('checked')};
 const rows=[1,2,3,4].map(stage=>({...structuredClone(b),stage}));rows[1].run.player=[20,40,0];rows[2].selected.pending=false;rows[2].selected.collecting=true;rows[2].run.credits=37;rows[3].frozen=false;
 assert.equal(verify(rows).result,'PASS');
 for(const change of [s=>s[1].selected.pending=false,s=>s[2].run.credits=74,s=>s[0].selected.root[1]=40,s=>s[3].frozen=true]){const bad=structuredClone(rows);change(bad);assert.throws(()=>verify(bad))}
 assert.equal('ENDLESS_PICKUP_CHUNK '.length,21);console.log('PASS: four controlled-stage negatives; no hardware launched');
}
module.exports={payloads,verify,run,selfTest};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else run(process.argv[2],path.resolve(process.argv[3]),path.resolve(process.argv[4])).catch(e=>{console.error(e.stack);process.exitCode=1})}

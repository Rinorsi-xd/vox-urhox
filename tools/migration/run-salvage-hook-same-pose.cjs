'use strict';
// Root-only hardware. Exact request overrides; no frozen/production bytes changed.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const {stream}=require('./monitor-combat-run.cjs');
function payloads(prepared,{production=false}={}){
 const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path));
 const candidate=production?{kind:'FROZEN_PRODUCTION_VISIBILITY_GUARD',distanceRule:'WORLD_EUCLIDEAN_TO_LOCAL_AABB',enterMeters:.4,exitMeters:.6,files:{}}:JSON.parse(fs.readFileSync(path.join(__dirname,'candidates/salvage-hook-guard/identity.json')));
 const files=new Map();const modified=structuredClone(manifest);
 for(const name of ['main.lua','render/SalvageCinematics.lua','salvage/Cinematics.lua']){
  const e=manifest.files.find(x=>x.fs_path===name);assert(e,name);
  const route='/game-dist/assets/'+e.uuid+'-'+e.hash+e.ext;
  const original=fs.readFileSync(path.join(prepared.source_directory,'dist/assets',e.uuid+'-'+e.hash+e.ext));
  assert.equal(sha(original),prepared.identity.scripts[name],'Frozen exact original '+name);
  let body;
  if(name==='main.lua')body=Buffer.concat([original,Buffer.from('\n'+fs.readFileSync(path.join(__dirname,'probe-salvage-hook-same-pose.lua'),'utf8'))]);
  else if(production){
   body=original;
   if(name==='render/SalvageCinematics.lua')assert(original.includes(Buffer.from('local clearance=self.hookHidden and .6 or .4')),'New Euclidean guard required');
   else assert(original.includes(Buffer.from('self.view:GuardCamera(self.session.camera:GetNode(),not self.playing)')),'Frozen camera guard wiring required');
   candidate.files[name]={sha256:sha(original),bytes:original.length};
  }else {const c=candidate.files[name];assert.equal(sha(original),c.originalSha256,'Candidate source identity '+name);body=fs.readFileSync(path.join(root,c.path));assert.equal(sha(body),c.candidateSha256)}
  modified.files.find(x=>x.fs_path===name).size=body.length;
  files.set(route,{name,original,body});
 }
 const manifestRoute='/game-dist/'+path.relative(path.join(prepared.source_directory,'dist'),prepared.manifest_path).replaceAll('\\','/');
 return {manifest,modified,manifestRoute,files,candidate};
}
function verifyStages(stages){
 assert.deepEqual(stages.map(s=>s.stage),[1,2,3,4,5]);
 const [a,b,a2,far,released]=stages;
 for(const row of [a,b,a2,far])assert.equal(row.frozen,true);
 assert.equal(released.frozen,false);
 assert.deepEqual(b.pose,a.pose,'B exact camera/body/holder/frame/time');assert.deepEqual(a2.pose,a.pose,'A2 exact camera/body/holder/frame/time');
 assert.equal(a.hook.visible,true);assert.equal(b.hook.visible,false);assert.equal(b.hook.guarded,true);assert.equal(a2.hook.visible,true);
 assert.equal(b.meshes.find(x=>x.model==='SalvageCine/model-15.bin').visible,false,'Actual hook component hidden in B');
 assert.equal(far.hook.visible,true);assert.equal(far.hook.guarded,false);
 const signature=s=>s.meshes.filter(x=>x.model!=='SalvageCine/model-15.bin');
 assert.equal(a.meshes.length,32);assert.equal(signature(a).length,31);
 assert.deepEqual(signature(b),signature(a));assert.deepEqual(signature(a2),signature(a));assert.deepEqual(signature(far),signature(a));
 assert.deepEqual(a2.meshes,a.meshes,'A2 exact restored batch states');
 assert.deepEqual(far.pose.vehicle,a.pose.vehicle);assert.deepEqual(far.pose.holder,a.pose.holder);assert.deepEqual(far.pose.frame,a.pose.frame);
 assert.equal(far.pose.runTime,a.pose.runTime);return {result:'PASS',samePose:true,batches:32,unchangedOtherBatches:31};
}
async function run(base,out,prepare,{production=false}={}){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out),'Do not overwrite evidence');fs.mkdirSync(out,{recursive:true});
 const prepared=JSON.parse(fs.readFileSync(prepare));const payload=payloads(prepared,{production});
 const report={result:'RUNNING',startedAt:new Date().toISOString(),checks:[],errors:[],httpErrors:[],stages:[],requests:[],responses:[],
  boundary:production?'Frozen-pose hook-only visibility diagnostic of exact frozen production modules; only main QA/manifest request change. No FPS/physics/natural camera acceptance.':'Frozen-pose hook-only visibility diagnostic, actual candidate modules request-injected. Does not measure FPS/physics/natural camera behavior. Original production/frozen files immutable.'};
 let browser,page,state,seq=0;const streams=new Map();const deadline=Date.now()+300000;
 const persist=()=>{report.lastState=state;fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2))};
 const healthy=()=>{assert(Date.now()<deadline,'300s total deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors[0]))};
 async function fresh(){const old=seq;const until=Math.min(deadline,Date.now()+(state?6000:120000));let next=0;while(seq===old){healthy();assert(Date.now()<until,'F7 complete state deadline');if(Date.now()>next){await page.keyboard.press('F7');next=Date.now()+500}await sleep(50)}return state}
 async function wait(test,label,timeout=30000){const until=Math.min(deadline,Date.now()+timeout);while(!state||!test(state)){healthy();assert(Date.now()<until,label);await fresh();await sleep(75)}return state}
 async function click(text){await wait(s=>s.widgets.some(x=>x.text===text&&!x.disabled&&x.rect[2]>0),'Visible '+text,15000);const r=state.widgets.filter(x=>x.text===text&&!x.disabled&&x.rect[2]>0).at(-1).rect;await page.mouse.click((r[0]+r[2]/2)*1600/state.width,(r[1]+r[3]/2)*900/state.height);await fresh()}
 try{
  report.identity=await fetch(base+'/identity.json').then(r=>r.json());assert.equal(report.identity.qa,false,'Use ordinary immutable preview, no previous QA suffix');
  assert.deepEqual(report.identity.identity,prepared.identity);assert.equal(report.identity.source_directory,prepared.source_directory);
  report.candidate=payload.candidate;report.probeSha256=sha(fs.readFileSync(path.join(__dirname,'probe-salvage-hook-same-pose.lua')));
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',message=>{const line=message.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   if(message.type()==='error'||/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\bERROR:/.test(line))report.errors.push(line);
   const at=line.indexOf('SALVAGE_HOOK_CHUNK ');if(at>=0)try{const part=JSON.parse(line.slice(at+19));let s=streams.get(part.kind);if(!s){s=stream();streams.set(part.kind,s)}s.add(part);if(s.ready()){state=s.value();assert.equal(part.kind,'state-'+state.sequence);seq++;fs.appendFileSync(path.join(out,'states.jsonl'),JSON.stringify(state)+'\n')}}catch(e){report.errors.push(e.stack)}
  });
  page.on('pageerror',e=>report.errors.push(e.stack));page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({url:r.url(),status:r.status()})});
  const routes=new Map(payload.files);routes.set(payload.manifestRoute,{name:'manifest',original:Buffer.from(JSON.stringify(payload.manifest)),body:Buffer.from(JSON.stringify(payload.modified))});
  for(const [url,item]of routes){
   await page.route(base+url,async route=>{try{const response=await route.fetch();assert.equal(response.status(),200);const bytes=await response.body();if(item.name==='manifest')assert.deepEqual(JSON.parse(bytes),payload.manifest);else assert(bytes.equals(item.original));report.requests.push({name:item.name,originalSha256:sha(bytes),injectedSha256:sha(item.body)});await route.fulfill({response,body:item.body,headers:{...response.headers(),'content-length':String(item.body.length)}})}catch(e){report.errors.push(e.stack);await route.abort()}});
  }
  page.on('response',response=>{const item=routes.get(new URL(response.url()).pathname);if(item)void response.body().then(bytes=>{assert(bytes.equals(item.body),'Actual browser bytes '+item.name);report.responses.push({name:item.name,sha256:sha(bytes)})}).catch(e=>report.errors.push(e.stack))});
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login',{waitUntil:'domcontentloaded',timeout:30000});await page.bringToFront();
  await wait(s=>s.mode==='hangar'&&!s.loading,'Actual hall',150000);
  const tutorialUntil=Date.now()+15000;
  for(;;){healthy();assert(Date.now()<tutorialUntil,'Public salvage lobby entry');const skip=state.widgets.find(x=>/^(跳过引导|确定跳过？再点一次)$/.test(x.text)&&!x.disabled);if(skip){if(skip.text==='跳过引导')await click(skip.text);await click('确定跳过？再点一次')}else if(state.widgets.some(x=>x.text==='打捞行动'&&!x.disabled)){await click('打捞行动');break}else{await sleep(100);await fresh()}}
  await wait(s=>s.tab==='salvage'&&!s.loading,'Salvage lobby');await click('出发');
  await wait(s=>s.run&&!s.loading,'Natural deployment',120000);await wait(s=>s.run?.landed&&!s.run.playing,'Natural deployment completed',30000);
  const pointerUntil=Date.now()+10000;while(!state.captured){healthy();assert(Date.now()<pointerUntil,'Public pointer capture');await page.locator('#canvas').click();await fresh()}
  await wait(s=>s.captured&&s.run?.landed&&!s.run.playing,'Natural cinematic idle after pointer capture',15000);
  report.naturalState=structuredClone(state);
  for(const [i,label]of ['near-a','near-b-guarded','near-a2-restored','far-restored','released'].entries()){
   await page.keyboard.press('F11');await wait(s=>s.stage===i+1,'Diagnostic '+label,15000);await sleep(150);await fresh();assert.equal(state.stage,i+1);report.stages.push(structuredClone(state));
   await page.screenshot({path:path.join(out,label+'.png'),timeout:10000});await fresh();
   if(i<4){assert.deepEqual(state.pose,report.stages[i].pose,'Pose constant throughout screenshot '+label);assert.deepEqual(state.meshes,report.stages[i].meshes,'Batch states constant throughout screenshot '+label)}
   persist();
  }
  report.verification=verifyStages(report.stages);
  await page.keyboard.press('t');await wait(s=>s.mode==='hangar'&&!s.loading&&s.result?.shown,'Public abandonment result',90000);
  await click('回大厅');await wait(s=>s.mode==='hangar'&&!s.loading&&!s.result,'Public returned hall',25000);
  await page.screenshot({path:path.join(out,'returned.png'),timeout:10000});
  for(const item of routes.values()){assert(report.requests.some(x=>x.name===item.name),'Request '+item.name);assert(report.responses.some(x=>x.name===item.name),'Response '+item.name)}
  healthy();report.result='PASS';report.checks=['Actual frozen originals and injected response bytes','Natural drop before diagnostic','Exact frozen camera and vehicle ABA','Only top-hook batch changes','Distant hook restored with other 31 batches unchanged','Diagnostic released before public return'];
 }catch(e){report.result='FAIL';report.failure=e.stack;if(page)try{await page.screenshot({path:path.join(out,'failure.png'),timeout:3000})}catch{}throw e}
 finally{if(browser)try{await browser.close();report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.closeError=e.message}report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({result:report.result,out,shutdown:report.shutdown,failure:report.failure}))}
 return report;
}
function selfTest(){
 const b={stage:1,frozen:true,pose:{camera:{position:[1,2,3]},vehicle:{position:[0,0,0]},holder:{},frame:{},runTime:10},hook:{visible:true,guarded:false},meshes:Array.from({length:32},(_,i)=>({model:'SalvageCine/model-'+i+'.bin',visible:true,node:{}}))};
 const stages=[1,2,3,4,5].map(stage=>({...structuredClone(b),stage}));stages[1].hook={visible:false,guarded:true};stages[1].meshes[15].visible=false;stages[4].frozen=false;
 assert.equal(verifyStages(stages).result,'PASS');
 for(const mutate of [s=>{s[1].pose.camera.position[0]++},s=>{s[2].pose.runTime++},s=>{s[1].meshes[10].visible=false},s=>{s[3].hook.visible=false},s=>{s[4].frozen=true},s=>{s[1].pose.vehicle.position[0]++}]){const bad=structuredClone(stages);mutate(bad);assert.throws(()=>verifyStages(bad))}
 assert.equal('SALVAGE_HOOK_CHUNK '.length,19);console.log('PASS: strict same-pose/other31/restore acceptance and six negative controls; no hardware launched');
}
module.exports={payloads,verifyStages,run,selfTest};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else run(process.argv[2],path.resolve(process.argv[3]),path.resolve(process.argv[4]||'.tmp/outgame-cached-1792196884433/identity.json'),{production:process.argv[5]==='--production'}).catch(e=>{console.error(e.stack);process.exitCode=1})}

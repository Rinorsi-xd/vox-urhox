'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {stream}=require('./monitor-combat-run.cjs');
const {scoped,equipment}=require('./scope-fx-isolated-run.cjs');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
async function awaitFirstState(getState,press,healthy,pause=sleep,now=Date.now){
 const until=now()+90000;
 while(!getState()){
  healthy();assert(now()<until,'Actual Lua first-state bootstrap deadline');
  await press();await pause(500);
 }
}
function frozen(state){
 assert(state?.frozen&&state.scope.firstPerson&&state.scope.scope,'Actual frozen ADS frame');
 assert(state.scope.models>0&&state.scope.visible===0&&!state.scope.persistentVisible,'Own model and persistent FX hidden');
 assert.equal(state.digest,state.referenceDigest,'Camera, simulation and FX state preserved');
 assert.equal(state.randomDelta,0,'No RNG advances while frozen');assert.equal(state.randomSeedDelta,0);
}
function comparePixels(first,last,clip){
 const {PNG}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/pngjs');
 const a=PNG.sync.read(fs.readFileSync(first)),b=PNG.sync.read(fs.readFileSync(last));
 assert.equal(a.width,b.width);assert.equal(a.height,b.height);
 const box={x:Math.floor(a.width*clip.left),y:Math.floor(a.height*clip.top),
  right:Math.floor(a.width*clip.right),bottom:Math.floor(a.height*clip.bottom)};
 let changed=0,maxChannel=0;const diff=new PNG({width:a.width,height:a.height});
 for(let y=box.y;y<box.bottom;y++)for(let x=box.x;x<box.right;x++){
  const at=(y*a.width+x)*4;let pixel=false;
  for(let c=0;c<3;c++){const d=Math.abs(a.data[at+c]-b.data[at+c]);diff.data[at+c]=d;maxChannel=Math.max(maxChannel,d);if(d)pixel=true}
  diff.data[at+3]=255;if(pixel)changed++;
 }
 return {box,pixels:(box.right-box.x)*(box.bottom-box.y),changed,maxChannel,diff:PNG.sync.write(diff)};
}
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out),'Preserve evidence');fs.mkdirSync(out,{recursive:true});
 const report={status:'RUNNING',errors:[],httpErrors:[],samples:[],boundary:'Isolated real ADS fixture; replay actual accepted geometry in fixed frame. Center A1/A2 exact plus state/RNG invariants required. No performance or mobile acceptance.'};
 let browser,page,state,pixel,sequence=0,pixelSequence=0;const streams=new Map(),deadline=Date.now()+360000;
 const persist=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
 const healthy=()=>{assert(Date.now()<deadline,'360s deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors[0]))};
 try{
  const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.adsPixelQa?.isolated);report.identity=identity;
  const manifest=JSON.parse(fs.readFileSync(identity.manifest_path,'utf8'));report.payloadHashes={};
  for(const name of ['main.lua','render/CombatEffects.lua','render/EffectBatch.lua','render/WeaponEffects.lua','render/WeaponView.lua','app/TrialSession.lua']){
   const entry=manifest.files.find(row=>row.fs_path===name);assert(entry,'Packaged '+name);
   const response=await fetch(base+'/game-dist/assets/'+entry.uuid+'-'+entry.hash+entry.ext);assert.equal(response.status,200);
   const actual=sha(Buffer.from(await response.arrayBuffer()));assert.equal(actual,identity.identity.scripts[name],'Actual HTTP module identity '+name);
   report.payloadHashes[name]=actual;
  }
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});
  page=await browser.newPage({viewport:{width:1600,height:900},deviceScaleFactor:1});
  page.on('console',m=>{const text=m.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');
   if(m.type()==='error'||/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\bERROR:/.test(text))report.errors.push(text);
   let at=text.indexOf('SCOPE_FX_CHUNK ');if(at>=0)try{
    const value=JSON.parse(text.slice(at+15));let s=streams.get(value.kind);if(!s){s=stream();streams.set(value.kind,s)}s.add(value);
    if(s.ready()){state=s.value();sequence=state.sequence}
   }catch(error){report.errors.push(error.stack)}
   at=text.indexOf('ADS_PIXEL_STATE ');if(at>=0)try{pixel=JSON.parse(text.slice(at+16));pixelSequence++}catch(error){report.errors.push(error.stack)}
  });
  page.on('pageerror',e=>report.errors.push(e.stack||e.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({status:r.status(),url:r.url()})});
  async function poll(){const old=sequence,until=Date.now()+6000;await page.keyboard.press('F9');while(sequence===old){healthy();assert(Date.now()<until,'Scope telemetry timeout');await sleep(35)}return state}
  async function wait(predicate,label,timeout=30000){report.stage=label;persist();console.log(label);const until=Date.now()+timeout;
   do{healthy();await poll();if(predicate(state))return state;assert(Date.now()<until,'Stage timeout '+label);await sleep(160)}while(true)
  }
  async function pixelPoll(){const old=pixelSequence,until=Date.now()+6000;await page.keyboard.press('F9');while(pixelSequence===old){healthy();assert(Date.now()<until,'Pixel telemetry timeout');await sleep(35)}return pixel}
  async function shot(label){await pixelPoll();frozen(pixel);report.samples.push({label,state:structuredClone(pixel)});
   fs.writeFileSync(path.join(out,label+'.json'),JSON.stringify(pixel,null,2));await page.locator('#canvas').screenshot({path:path.join(out,label+'.png'),timeout:15000});
  }
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login',{waitUntil:'domcontentloaded'});
  await page.bringToFront();await page.waitForFunction(()=>globalThis.Module?.calledRun===true,{},{timeout:150000});
  report.stage='waiting for actual Lua first state';persist();
  await awaitFirstState(()=>state,()=>page.keyboard.press('F9'),healthy);
  await wait(s=>s.mode==='hangar'&&!s.loading,'actual hall',90000);
  for(let n=0;n<4;n++){
   const b=(Array.isArray(state.widgets)?state.widgets:[]).find(w=>/^(跳过引导|确定跳过？再点一次)$/.test(w.text));if(!b)break;
   await page.mouse.click((b.rect[0]+b.rect[2]/2)/state.width*1600,(b.rect[1]+b.rect[3]/2)/state.height*900);await sleep(300);await poll();
  }
  await page.keyboard.press('F7');await wait(s=>s.mode==='trial'&&!s.loading&&s.trial?.groups.length===4,'actual T5 trial',180000);
  await page.mouse.click(800,450);await wait(s=>s.trial?.captured,'pointer capture',15000);
  await page.keyboard.press('1');await page.keyboard.press('F6');await poll();assert.equal(state.trial.group,'mg');assert(state.placement.controlled);
  await page.mouse.down({button:'left'});await wait(s=>s.trial?.weaponFx?.batches?.Swirl?.count>0,'MG real spin',15000);
  await page.mouse.down({button:'right'});await wait(s=>s.trial.firstPerson&&s.trial.scope,'actual ADS',15000);scoped(state);equipment(state);
  const freezeDeadline=Date.now()+15000;
  do{
   healthy();await page.keyboard.press('F8');await sleep(100);await pixelPoll();
   if(pixel.frozen)break;assert(Date.now()<freezeDeadline,'Nonvacuous equipment frame deadline');await sleep(150);
  }while(true);
  frozen(pixel);await page.mouse.up({button:'left'});await page.mouse.up({button:'right'});
  await page.keyboard.press('0');await sleep(100);await shot('A1-baseline');
  await page.keyboard.press('8');await sleep(100);await shot('B-motionOnly');
  assert(report.samples.at(-1).state.replay.Glow.removed>0,'Nonvacuous actual own WeaponView motion particle omission');
  await page.keyboard.press('0');await sleep(100);await shot('A2-restored');
  await page.keyboard.press('9');await sleep(100);await shot('C-allEquipment');
  assert(report.samples.at(-1).state.replay.Glow.removed>0,'Nonvacuous tagged Glow omission');
  await page.keyboard.press('0');await sleep(100);await shot('A3-restored');
  await page.keyboard.press('7');await sleep(100);await shot('D-noStreak');
  await page.keyboard.press('0');await sleep(100);await shot('A4-restored');
  const clip=pixel.centerRegion;report.differences={};
  for(const label of ['B-motionOnly','C-allEquipment','D-noStreak','A2-restored','A3-restored','A4-restored']){
   const diff=comparePixels(path.join(out,'A1-baseline.png'),path.join(out,label+'.png'),clip);
   fs.writeFileSync(path.join(out,label+'-diff.png'),diff.diff);delete diff.diff;report.differences[label]=diff;
  }
  for(const label of ['A2-restored','A3-restored','A4-restored'])assert.equal(report.differences[label].changed,0,'Exact center A1/'+label+' pixel restoration required');
  report.status='PASS';report.result='Controlled category differences valid; inspect screenshots and diffs for actual obstruction attribution.';
 }catch(error){report.status='FAIL';report.failure=error.stack;if(page)try{await page.screenshot({path:path.join(out,'failure.png'),timeout:3000})}catch{}throw error}
 finally{
  if(browser)try{await Promise.race([browser.close(),sleep(5000).then(()=>{throw Error('Browser close timeout')})]);report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.status='FAIL';report.closeError=e.message}
  report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({status:report.status,out,failure:report.failure}));
 }
 return report;
}
module.exports={run,frozen,comparePixels,awaitFirstState};
if(require.main===module)run(process.argv[2],path.resolve(process.argv[3])).catch(e=>{console.error(e.stack);process.exitCode=1});

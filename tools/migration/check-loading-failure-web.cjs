// Dedicated fault recovery route. No direct Lua/scene mutation from the browser.
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const MARKER='VOX_QA_CONTROLLED_POST_INSTALL_WARMUP_FAILURE';
const PREFIX='VOX_LOADING_FAILURE ';
const VIEWPORT={width:1600,height:900};
const ROOT=path.resolve(__dirname,'../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function identityContract(identity,expected){
 assert.equal(identity.qa,true,'Explicit QA server');
 assert.equal(identity.loadingFailureTest,true,'Dedicated controlled loading failure suffix');
 assert.equal(identity.monitorDisabled,true,'Gameplay monitor disabled during recovery route');
 assert.equal(identity.servedManifest,expected,'Expected immutable package');
 for(const flag of ['storyRoute','homeRoute','loadProfile','combatProfile','driveSectionsProfile','renderExperiment','warmExperiment','warmIntroExperiment'])
  assert.equal(identity[flag],false,'No unrelated projection or experiment '+flag);
 assert.match(identity.probeSha256,/^[a-f0-9]{64}$/,'Exact appended suffix identity');
}
function failureContract(record){
 assert.equal(record.enabled,true);assert.equal(record.injected,true);assert.equal(record.constructorRestored,true);
 for(const field of ['covered','finished','trialSame'])assert.equal(record.install?.[field],true,'Real installed session '+field);
 assert.equal(record.install.mode,'trial');assert.equal(record.install.pendingMap,false,'Loader transferred scene ownership');
 for(const field of ['flowActive','covered','finished','trialSame'])assert.equal(record.injection?.[field],true,'Presented failure boundary '+field);
 assert.equal(record.injection.pendingMap,false);assert.equal(record.flow?.failed,true);
 assert.equal(record.flow.active,true);assert.equal(record.flow.combatOwner,false,'Fail disposed and cleared warmup owner');
 assert.ok(record.flow.error.includes(MARKER),'Only controlled failure marker');
 assert.equal(record.warmupDisposes,1);assert.equal(record.warmupCleanup?.disposed,true);
 for(const name of ['proxyRoot','flashOwner','equipmentOwner'])assert.equal(record.warmupCleanup[name],false,'Warmup releases '+name);
 assert.ok(record.backRect?.w>0&&record.backRect?.h>0,'Rendered public return button');
 assert.ok(record.width>0&&record.height>0,'Actual logical viewport');
}
function returnedContract(record){
 assert.equal(record.returned,true);assert.equal(record.cancelCalls,1);assert.equal(record.reloadCalls,1);
 assert.equal(record.cancel?.fromFlow,true);assert.equal(record.cancel.failed,true);assert.equal(record.cancel.finished,true);
 assert.equal(record.cancel.pendingMap,false);assert.equal(record.cancel.trialPresent,true);
 assert.equal(record.recovery?.map,'hangar');assert.equal(record.recovery.phase,'cover','Old Back did not overwrite new recovery flow');
 assert.equal(record.recovery.active,true);assert.equal(record.recovery.failed,false);assert.equal(record.recovery.cancelled,false);
 assert.ok(record.recovery.generation>record.install.generation,'Replacement hall flow generation');
 assert.equal(record.trialDisposes,1);assert.equal(record.retiredTrial?.disposed,true);
 for(const key of ['scene','world','effects','view','hud','combatView'])assert.equal(record.retiredTrial[key],false,'Old trial no longer owns '+key);
 assert.equal(record.mode,'hangar');assert.equal(record.trialPresent,false);assert.equal(record.globalTrialPresent,false);
 assert.equal(record.globalHangarPresent,true);assert.equal(record.pendingMap,false);assert.equal(record.loaderState,'ready');
 assert.equal(record.flow?.map,'hangar');assert.equal(record.flow.active,false);assert.equal(record.flow.phase,'closed');
 assert.equal(record.flow.failed,false);assert.equal(record.flow.visible,false);assert.ok(record.flow.pageFrames>=2);
 const required=['bound-real-installed-session','single-controlled-presented-error','real-warmup-dispose',
  'actual-flow-failed','real-cancel-map-load','real-reload','real-trial-dispose','actual-hall-cover-closed'];
 let previous=-1;
 for(const name of required){const index=record.events.findIndex(event=>event.kind===name);assert.ok(index>previous,'Actual event order '+name);previous=index}
}
async function auditHttp(base,identity){
 const diskManifest=fs.readFileSync(identity.manifest_path),manifest=JSON.parse(diskManifest);
 const main=manifest.files.find(file=>file.fs_path==='main.lua'),payload=main.uuid+'-'+main.hash+main.ext;
 const packed=fs.readFileSync(path.join(identity.source_directory,'dist/assets',payload));
 const suffix=Buffer.concat([fs.readFileSync(path.join(__dirname,'qa-frame-wall-observer.lua')),Buffer.from('\n'),
  fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua')),Buffer.from('\n'),
  fs.readFileSync(path.join(__dirname,'monitor-disabled-observer.lua')),Buffer.from('\n'),
  fs.readFileSync(path.join(__dirname,'qa-loading-failure.lua'))]);
 assert.equal(sha(suffix),identity.probeSha256,'Expected controlled QA suffix bytes');
 const expected=Buffer.concat([packed,Buffer.from('\n'),suffix]);
 const responses=await Promise.all([fetch(base+'/game-dist/1.0.0/'+identity.servedManifest),fetch(base+'/game-dist/assets/'+payload)]);
 for(const response of responses)assert.equal(response.status,200,'Packaged HTTP resource');
 const [manifestBytes,mainBytes]=await Promise.all(responses.map(async response=>Buffer.from(await response.arrayBuffer())));
 manifest.files.find(file=>file.fs_path==='main.lua').size=expected.length;
 assert.deepEqual(JSON.parse(manifestBytes),manifest,'Manifest only advertises QA suffix byte count');
 assert.ok(mainBytes.equals(expected),'Actual HTTP main equals packed production plus exact QA suffix');
 const production={};
 for(const name of ['app/HangarApp.lua','app/LoadingFlow.lua','render/CombatWarmup.lua']){
  const hash=sha(fs.readFileSync(path.join(identity.source_directory,'scripts',name)));
  assert.equal(identity.identity.scripts[name],hash,'Frozen production identity '+name);production[name]=hash;
 }
 return {main:{file:payload,bytes:mainBytes.length,sha256:sha(mainBytes),packedSha256:sha(packed)},
  manifest:{sha256:sha(manifestBytes),diskSha256:sha(diskManifest)},suffixSha256:sha(suffix),production};
}
function selfTest(){
 const identity={qa:true,loadingFailureTest:true,monitorDisabled:true,servedManifest:'manifest-test.json',probeSha256:'a'.repeat(64)};
 for(const name of ['storyRoute','homeRoute','loadProfile','combatProfile','driveSectionsProfile','renderExperiment','warmExperiment','warmIntroExperiment'])identity[name]=false;
 identityContract(identity,'manifest-test.json');
 let negative=0;
 for(const key of ['qa','loadingFailureTest','monitorDisabled']){assert.throws(()=>identityContract({...identity,[key]:false},'manifest-test.json'));negative++}
 for(const key of ['storyRoute','homeRoute','driveSectionsProfile','combatProfile']){assert.throws(()=>identityContract({...identity,[key]:true},'manifest-test.json'));negative++}
 const failure={enabled:true,injected:true,constructorRestored:true,install:{covered:true,finished:true,trialSame:true,mode:'trial',pendingMap:false,generation:2},
  injection:{flowActive:true,covered:true,finished:true,trialSame:true,pendingMap:false},flow:{failed:true,active:true,combatOwner:false,error:MARKER},
  warmupDisposes:1,warmupCleanup:{disposed:true,proxyRoot:false,flashOwner:false,equipmentOwner:false},backRect:{x:20,y:30,w:112,h:46},width:1920,height:1080};
 failureContract(failure);
 for(const mutate of [x=>x.install.pendingMap=true,x=>x.install.covered=false,x=>x.injection.finished=false,
  x=>x.warmupCleanup.proxyRoot=true,x=>x.flow.combatOwner=true,x=>x.constructorRestored=false]){
  const copy=structuredClone(failure);mutate(copy);assert.throws(()=>failureContract(copy));negative++;
 }
 const result={...failure,returned:true,cancelCalls:1,reloadCalls:1,cancel:{fromFlow:true,failed:true,finished:true,pendingMap:false,trialPresent:true},
  recovery:{map:'hangar',phase:'cover',active:true,failed:false,cancelled:false,generation:3},trialDisposes:1,
  retiredTrial:{disposed:true,scene:false,world:false,effects:false,view:false,hud:false,combatView:false},
  mode:'hangar',trialPresent:false,globalTrialPresent:false,globalHangarPresent:true,pendingMap:false,loaderState:'ready',
  flow:{map:'hangar',active:false,phase:'closed',failed:false,visible:false,pageFrames:12},
  events:['bound-real-installed-session','single-controlled-presented-error','real-warmup-dispose','actual-flow-failed',
   'real-cancel-map-load','real-reload','real-trial-dispose','actual-hall-cover-closed'].map(kind=>({kind}))};
 returnedContract(result);
 for(const mutate of [x=>x.trialDisposes=0,x=>x.retiredTrial.scene=true,x=>x.flow.active=true,
  x=>x.recovery.phase='exit-cover',x=>x.cancelCalls=2,x=>x.events.reverse(),x=>x.globalTrialPresent=true,
  x=>x.recovery.generation=2,x=>x.flow.pageFrames=0]){
  const copy=structuredClone(result);mutate(copy);assert.throws(()=>returnedContract(copy));negative++;
 }
 console.log(JSON.stringify({result:'PASS',contracts:3,negativeControls:negative,boundary:'Synthetic contract checks only; no browser or engine launch.'}));
}
async function main(){
 const base=process.env.VOX_QA_BASE;assert.match(base||'',/^http:\/\/127\.0\.0\.1:\d+$/);
 const expected=process.env.VOX_EXPECT_MANIFEST;assert.match(expected||'',/^manifest-[a-f0-9]+\.json$/,'Explicit frozen manifest required');
 const response=await fetch(base+'/identity.json');assert.equal(response.status,200);const identity=await response.json();identityContract(identity,expected);
 const http=await auditHttp(base,identity);
 const out=path.join(ROOT,'docs/migration/evidence/loading-failure-web-'+Date.now());fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',identity,http,startedAt:new Date().toISOString(),checks:[],errors:[],httpErrors:[],parseIssues:[],expectedFailureLogs:[],
  boundary:'Dedicated QA fault injection after real CombatWarmup.New and public match controls/return click; actual Flow.Fail, CancelMapLoad, Reload and TrialSession.Dispose. Not a normal match, performance benchmark or mobile acceptance.'};
 const persist=()=>fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2)+'\n');persist();
 let browser,page,state,failure,sequence=0,failureSequence=0;
 const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label)};
 try{
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});page=await browser.newPage({viewport:VIEWPORT});
  page.on('console',message=>{
   const line=message.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   const controlled=line.includes('[LoadingFlow] Failed '+MARKER);
   if(controlled)report.expectedFailureLogs.push(line);
   const at=line.indexOf(PREFIX);
   if(at>=0){try{assert.ok(Buffer.byteLength(line)<64*1024,'Bounded recovery record');failure=JSON.parse(line.slice(at+PREFIX.length));failureSequence++;
    fs.appendFileSync(path.join(out,'recovery.jsonl'),JSON.stringify({sequence:failureSequence,wallMs:Date.now(),state:failure})+'\n');
   }catch(error){report.errors.push('Recovery observer: '+error.message)}}
   const ordinary=line.indexOf('OUTGAME_STATE ');
   if(ordinary>=0){try{
    state=JSON.parse(line.slice(ordinary+14));sequence++;
    fs.appendFileSync(path.join(out,'states.jsonl'),JSON.stringify({sequence,state})+'\n');
    for(const issue of report.parseIssues)if(!issue.recoveredBySequence)issue.recoveredBySequence=sequence;
   }catch(error){
    if(error instanceof SyntaxError&&/Unexpected end of JSON input/.test(error.message)&&!line.trimEnd().endsWith('}'))report.parseIssues.push({error:error.message,afterSequence:sequence});
    else report.errors.push('Main observer: '+error.message);
   }}
   if(!controlled&&/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|ERROR:/.test(line))report.errors.push(line);
  });
  page.on('pageerror',error=>report.errors.push(error.message));page.on('crash',()=>report.errors.push('Renderer crash'));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({status:r.status(),url:r.url()})});
  function healthy(){assert.equal(report.errors.length,0,report.errors.join('\n'))}
  async function wait(predicate,label,timeout=300000){
   const deadline=Date.now()+timeout;let next=0;
   while(!predicate()){
    healthy();assert.ok(Date.now()<deadline,'Timeout '+label);
    if(Date.now()>=next){next=Date.now()+500;await page.keyboard.press('F8')}await sleep(60);
   }
  }
  async function click(text){
   const rows=()=>Array.isArray(state?.widgets)?state.widgets:[];
   await wait(()=>rows().some(w=>w.text===text&&!w.disabled&&w.rect?.[2]>0),'public button '+text);
   const w=rows().find(w=>w.text===text&&!w.disabled&&w.rect?.[2]>0),before=sequence;
   await page.mouse.click((w.rect[0]+w.rect[2]/2)/state.width*VIEWPORT.width,(w.rect[1]+w.rect[3]/2)/state.height*VIEWPORT.height);
   await wait(()=>sequence>before,'button response '+text);
  }
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await page.bringToFront();
  await wait(()=>state?.mode==='hangar'&&state.tab==='hangar'&&!state.loadingFlow?.active,'initial hall');
  check(failure?.armed===true&&!failure.injected,'Fault waits through actual normal hall startup');report.initialState=state;
  await click('出战');await click('歼灭战');await click('开始匹配');
  await wait(()=>failure?.injected&&failure.flow?.failed&&failure.backRect?.w>0,'actual covered post-install failure');
  failureContract(failure);report.failedState=failure;report.checks.push('Real installed warmup error and cleanup contract');
  check(report.expectedFailureLogs.length===1,'Exactly one intentional Flow.Fail marker');
  await page.screenshot({path:path.join(out,'failed.png'),timeout:15000});
  const rect=failure.backRect;report.returnClick={logical:{...rect},viewport:{...VIEWPORT},width:failure.width,height:failure.height};
  await page.mouse.click((rect.x+rect.w/2)/failure.width*VIEWPORT.width,(rect.y+rect.h/2)/failure.height*VIEWPORT.height);
  await wait(()=>failure?.returned&&failure.flow?.phase==='closed'&&state?.mode==='hangar'&&!state.loadingFlow?.active,'actual return and hall cover closure');
  returnedContract(failure);report.returnedState=failure;report.hallState=state;report.checks.push('Real cancel/reload/dispose event order and returned ownership contract');
  await page.screenshot({path:path.join(out,'returned.png'),timeout:15000});
  const last=sequence;await page.keyboard.press('F8');await wait(()=>sequence>last,'fresh returned public state',15000);
  check(state.mode==='hangar'&&!state.loadingFlow?.active,'Fresh hall remains interactive without loading overlay');
  check(report.parseIssues.every(issue=>issue.recoveredBySequence),'Any truncated ordinary QA sample recovered');
  const final=await fetch(base+'/identity.json').then(r=>r.json());check(JSON.stringify(final)===JSON.stringify(identity),'Same immutable server and suffix identity throughout route');
  healthy();check(report.httpErrors.length===0,'No HTTP errors');check(report.expectedFailureLogs.length===1,'No repeated controlled failure');
  report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;throw error}
 finally{
  await browser?.close();report.shutdown='CLOSED';report.finishedAt=new Date().toISOString();persist();
  console.log(JSON.stringify({result:report.result,out,checks:report.checks.length,failure:report.failure,shutdown:report.shutdown}));
 }
}
module.exports={MARKER,identityContract,failureContract,returnedContract,auditHttp,selfTest};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else main().catch(error=>{console.error(error.message);process.exitCode=1})}

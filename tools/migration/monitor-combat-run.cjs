'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function canonical(v){return v&&typeof v==='object'?Array.isArray(v)?v.map(canonical):Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])])):v}
function signature(u){assert(u.source&&Array.isArray(u.source.parts)&&u.source.parts.length>0,'Actual nonempty blueprint source required');return sha(JSON.stringify(canonical({name:u.name,team:u.team,role:u.role,variant:u.variant,source:u.source,driver:u.driver})))}
function checksum(s){let hash=2166136261;for(const b of Buffer.from(s))hash=Math.imul(hash^b,16777619)>>>0;return hash}
function stream(){let n=null,bytes=null,hash=null;const parts=new Map();return {add(v){assert(Number.isInteger(v.count)&&v.count>0&&v.count<=2000);assert(Number.isInteger(v.index)&&v.index>=1&&v.index<=v.count);assert(Number.isInteger(v.bytes)&&v.bytes>0);assert(Number.isInteger(v.checksum)&&v.checksum>=0&&v.checksum<=0xffffffff);assert.equal(typeof v.data,'string');assert(Buffer.byteLength(v.data)<=600);if(n!==null){assert.equal(v.count,n);assert.equal(v.bytes,bytes);assert.equal(v.checksum,hash)}n=v.count;bytes=v.bytes;hash=v.checksum;assert(!parts.has(v.index));parts.set(v.index,v.data)},ready(){return n!==null&&parts.size===n},value(){assert(this.ready());const s=Array.from({length:n},(_,i)=>parts.get(i+1)).join('');assert.equal(Buffer.byteLength(s),bytes,'Encoded JSON byte count');assert.equal(checksum(s),hash,'Encoded JSON checksum');return JSON.parse(s)}}}
function verifySetup(s){
 assert.equal(s.reciprocalVisible,true);assert.match(s.boundary,/CONTROLLED DIAGNOSTIC/);
 assert.equal(s.before.monitorEnabled,true);assert.equal(s.after.monitorEnabled,true);
 assert.equal(s.before.roster.length,8);assert.equal(s.after.roster.length,8);
 assert.deepEqual(s.before.roster.map(signature),s.after.roster.map(signature),'Actual roster/assembly unchanged by setup');
 assert.equal(s.after.roster.filter(u=>u.driver).length,7,'All seven real AI drivers retained');
 for(let i=0;i<8;i++){const a=s.before.roster[i],b=s.after.roster[i];assert(a.alive&&b.alive);for(const key of ['parts','structure','hull'])assert.equal(b[key],a[key],'Setup never edits health/parts');}
 const cars=s.after.roster;
 for(let i=0;i<8;i++)for(let j=i+1;j<8;j++){
  const a=cars[i].footprint,b=cars[j].footprint;assert(a?.length===4&&b?.length===4);
  assert(a[2]+1<=b[0]||b[2]+1<=a[0]||a[3]+1<=b[1]||b[3]+1<=a[1],'No overlap of transformed real vehicle bounds');
 }
 return s;
}
function analyze(r){
 assert.equal(r.status,'CAPTURED');verifySetup(r.setup);
 assert(r.before.monitorEnabled&&r.after.monitorEnabled,'Production monitor remains enabled');
 assert.equal(r.before.roster.length,8);assert.equal(r.after.roster.length,8);
 assert.deepEqual(r.before.roster.map(signature),r.after.roster.map(signature),'No roster/blueprint changes during capture');
 const n=r.frameIds.length;assert(n>=3&&n<=4096);
 for(const key of ['wallMs','parts','shots','hits','damage','kills'])assert.equal(r[key].length,n,'Complete '+key+' array');
 assert.equal(r.rows.length,n*9);assert.deepEqual(r.names,['monitor.Finalize','monitor.Emit','bindings.Context']);
 for(let i=1;i<n;i++)assert.equal(r.frameIds[i],r.frameIds[i-1]+1,'Continuous actual frame IDs');
 assert(r.rows.every(x=>Number.isInteger(x)&&x>=0));assert(r.wallMs.every(x=>Number.isInteger(x)&&x>=0));
 const delta=Object.fromEntries(['shots','hits','damage','kills'].map(k=>[k,r.after.world[k]-r.before.world[k]]));
 assert(delta.shots>0,'Required actual player shooting');assert(delta.hits>0,'Zero-hit capture is FAIL');
 const playerDamage=r.after.playerDamage-r.before.playerDamage;assert(playerDamage>0,'Required actual player combat damage');
 const partsBefore=r.before.roster.reduce((n,u)=>n+u.parts,0);
 const minParts=Math.min(...r.parts);
 const structureLoss=r.after.roster.some((u,i)=>u.structure<r.before.roster[i].structure||u.parts<r.before.roster[i].parts);
 assert(structureLoss||minParts<partsBefore,'Required actual structure or part reduction');
 const full=[];for(let i=1;i<n-1;i++)full.push(i);
 const sum=values=>values.reduce((a,b)=>a+b,0),q=(values,p)=>values.slice().sort((a,b)=>a-b)[Math.ceil(values.length*p)-1];
 // Start-to-start wall[i+1] encloses the scopes executed in frame i.
 const times=full.map(i=>r.wallMs[i+1]);
 const scopes=r.names.map((name,j)=>{const ms=full.map(i=>r.rows[i*9+j*3]),calls=full.map(i=>r.rows[i*9+j*3+1]);return {name,totalMs:sum(ms),calls:sum(calls),meanMsPerFrame:sum(ms)/full.length,maxCallMs:Math.max(...full.map(i=>r.rows[i*9+j*3+2]))}});
 const emitFrames=full.filter(i=>r.rows[i*9+4]>0);
 const emitVsQuiet={emitting:{frames:emitFrames.length,meanMs:emitFrames.length?sum(emitFrames.map(i=>r.wallMs[i+1]))/emitFrames.length:null},quiet:{frames:full.length-emitFrames.length,meanMs:full.length>emitFrames.length?sum(full.filter(i=>!emitFrames.includes(i)).map(i=>r.wallMs[i+1]))/(full.length-emitFrames.length):null}};
 return {status:'PASS',fullFrames:full.length,partialFramesExcluded:2,delta,playerDamage,partsBefore,minParts,structureLoss,
  meanWallMs:sum(times)/times.length,p50WallMs:q(times,.5),p95WallMs:q(times,.95),p99WallMs:q(times,.99),maxWallMs:Math.max(...times),over80:times.filter(x=>x>80).length,
  scopes,emitVsQuiet,frames:full.map(i=>({frame:r.frameIds[i],wallMs:r.wallMs[i+1],parts:r.parts[i],shots:r.shots[i],hits:r.hits[i],damage:r.damage[i],kills:r.kills[i],finalizeMs:r.rows[i*9],finalizeCalls:r.rows[i*9+1],emitMs:r.rows[i*9+3],emitCalls:r.rows[i*9+4],contextMs:r.rows[i*9+6]})),
  boundary:'Three integer-wall coarse scopes with original monitor enabled. Emit is inclusive within Finalize; never add both. Emit-frame vs quiet-frame association is not causation. Whole-frame wall includes observers/render/waits. Controlled placement, no natural gameplay or optimization A/B / phone performance claim.'};
}
function selfTest(){
 const text=JSON.stringify({text:'Chinese 中文 🙂 \\"\n'}),packet={count:1,index:1,bytes:Buffer.byteLength(text),checksum:checksum(text),data:text};
 const good=stream();good.add(packet);assert.deepEqual(good.value(),JSON.parse(text));
 for(const mutate of [v=>{v.bytes++},v=>{v.checksum^=1},v=>{v.data=v.data.slice(0,-1)}]){const bad=structuredClone(packet);mutate(bad);const s=stream();s.add(bad);assert.throws(()=>s.value())}
 console.log('PASS: UTF-8 length/checksum transport; corrupt length/hash/truncated content rejected');
 const cars=Array.from({length:8},(_,i)=>({name:String(i),team:i<4?'blue':'red',role:'assault',variant:0,source:{parts:[i]},driver:i!==0,alive:true,parts:100,structure:50,hull:100,position:[(i%4)*20,0,i<4?0:50],footprint:[(i%4)*20-4,(i<4?0:50)-4,(i%4)*20+4,(i<4?0:50)+4],size:{min:[-4,-1,-4],max:[4,4,4]}}));
 const copy=x=>structuredClone(x),current={monitorEnabled:true,roster:cars,playerDamage:0,world:{shots:0,hits:0,damage:0,kills:0}};
 const r={status:'CAPTURED',setup:{before:copy(current),after:copy(current),reciprocalVisible:true,boundary:'CONTROLLED DIAGNOSTIC'},before:copy(current),after:copy(current),frameIds:[10,11,12],wallMs:[0,30,30],rows:[0,1,0,0,0,0,0,1,0,2,1,2,1,1,1,0,1,0,0,1,0,0,0,0,0,1,0],parts:[800,799,799],shots:[0,10,10],hits:[0,2,2],damage:[0,3,3],kills:[0,0,0],names:['monitor.Finalize','monitor.Emit','bindings.Context']};
 r.after.world={shots:10,hits:2,damage:3,kills:0};r.after.playerDamage=3;r.after.roster[4].parts=99;assert.equal(analyze(r).status,'PASS');
 const mutations=[x=>{x.after.world.hits=0},x=>{x.after.world.shots=0},x=>{x.after.roster[4].parts=100;x.parts=[800,800,800]},x=>{x.after.monitorEnabled=false},x=>{x.setup.after.roster[1].driver=false},x=>{x.setup.after.roster[1].footprint=x.setup.after.roster[0].footprint},x=>{x.after.roster[1].source.parts=[999]},x=>{x.frameIds[1]=20},x=>{x.rows.pop()},x=>{x.after.playerDamage=0},x=>{x.before.roster[0].source={}}];
 for(const mutate of mutations){const bad=copy(r);mutate(bad);assert.throws(()=>analyze(bad));}
 console.log('PASS: real player damage/hits/parts required; 11 negative controls rejected');
}
async function run(base,out,duration=45000,diagnostic=null){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(Number.isInteger(duration)&&duration>=10000&&duration<=90000);
 assert(!fs.existsSync(out),'Do not overwrite evidence');fs.mkdirSync(out,{recursive:true});
 const deadline=Date.now()+300000,report={status:'RUNNING',startedAt:new Date().toISOString(),durationMs:duration,errors:[],httpErrors:[],perfParseWarnings:[],checks:[]};
 let browser,page,state,sequence=0,setup=null,result=null,started=false,measuring=false;const streams=new Map();
 let cancelled=null,rejectCancel;
 const cancellation=new Promise((_,reject)=>{rejectCancel=reject});cancellation.catch(()=>{});
 const cancel=signal=>{cancelled=Error('Requested '+signal+' cancellation');report.cancellation=signal;rejectCancel(cancelled)};
 const sigint=()=>cancel('SIGINT'),sigterm=()=>cancel('SIGTERM');process.once('SIGINT',sigint);process.once('SIGTERM',sigterm);
 const persist=()=>{report.lastState=state;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n')};
 const progress=label=>{report.stage={label,at:new Date().toISOString()};persist();console.log(JSON.stringify({progress:label,out}))};
 const healthy=()=>{if(cancelled)throw cancelled;assert(Date.now()<deadline,'300s total deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors[0]));};
 const bounded=async(promise,label)=>{const left=deadline-Date.now();assert(left>0,label+' total deadline');let timer;try{return await Promise.race([promise,cancellation,new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('300s total deadline: '+label)),left))])}finally{clearTimeout(timer)}};
 try{
  const identity=await bounded(fetch(base+'/identity.json').then(r=>r.json()),'identity');report.identity=identity;
  assert(identity.monitorCombat?.isolated&&identity.monitorCombat.monitorEnabled&&identity.monitorCombat.coarseBindings===3);
  assert.equal(identity.qa,false);assert.equal(identity.monitorDisabled,false);assert.equal(identity.framePipelineProfile,false);
  const relative=path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/');
  const manifest=await bounded(fetch(base+'/game-dist/'+relative).then(r=>r.json()),'manifest');report.httpHashes={};
  for(const name of ['main.lua',...Object.keys(identity.monitorCombat.sources).filter(x=>x!=='main.lua')]){
   const entry=manifest.files.find(x=>x.fs_path===name);assert(entry,name);
   const response=await bounded(fetch(base+'/game-dist/assets/'+entry.uuid+'-'+entry.hash+entry.ext),'source '+name);assert.equal(response.status,200);
   const bytes=Buffer.from(await bounded(response.arrayBuffer(),'source bytes'));const hash=sha(bytes);assert.equal(hash,identity.identity.scripts[name]);report.httpHashes[name]=hash;
  }
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await bounded(chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']}),'launch');
  page=await bounded(browser.newPage({viewport:{width:1600,height:900}}),'page');
  page.on('console',message=>{
   const text=message.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');
   if(message.type()==='error'||/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\bERROR:/.test(text))report.errors.push(text);
   for(const [prefix,handler]of [['MONITOR_COMBAT_STARTED ',v=>{started=true;report.started=v}],['MONITOR_COMBAT_CHUNK ',v=>{let s=streams.get(v.kind);if(!s){s=stream();streams.set(v.kind,s)}s.add(v);if(s.ready()){const value=s.value();if(v.kind.startsWith('state-')){assert.equal(v.kind,'state-'+value.sequence);state=value;sequence++}else if(v.kind==='setup'){setup=verifySetup(value);report.setup=setup;fs.writeFileSync(path.join(out,'setup.json'),JSON.stringify(setup,null,2))}else if(v.kind==='result'){result=value;fs.writeFileSync(path.join(out,'capture.json'),JSON.stringify(result))}}}]]){
    const at=text.indexOf(prefix);if(at>=0)try{handler(JSON.parse(text.slice(at+prefix.length)))}catch(error){report.errors.push(error.stack)}
   }
   const at=text.indexOf('VOX_PERF ');if(at>=0){const raw=text.slice(at+9);fs.appendFileSync(path.join(out,'production-perf.jsonl'),raw+'\n');try{JSON.parse(raw)}catch(error){report.perfParseWarnings.push({bytes:Buffer.byteLength(raw),duringCapture:measuring,error:error.message})}}
  });
  page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({url:r.url(),status:r.status()})});
  page.on('requestfailed',r=>report.httpErrors.push({url:r.url(),error:r.failure()?.errorText}));
  async function poll(){
   const initial=state===undefined,old=sequence;
   const until=initial?deadline:Math.min(deadline,Date.now()+5000);let nextInput=0;
   while(sequence===old){
    healthy();assert(Date.now()<until,initial?'initial app bootstrap deadline':'state F7 deadline');
    // calledRun precedes Lua App creation; F7 before App exists emits no state.
    if(Date.now()>=nextInput){await bounded(page.keyboard.press('F7'),'state input');nextInput=initial?Date.now()+500:Infinity}
    await sleep(50);
   }
   return state;
  }
  async function wait(predicate,label,timeout=15000){progress(label);let next=0;const until=Math.min(deadline,Date.now()+timeout);while(!state||!predicate(state)){healthy();assert(Date.now()<until,'Stage deadline: '+label);if(Date.now()>next){await poll();next=Date.now()+500}await sleep(50)}return state}
  async function click(text){await wait(s=>s.widgets.some(x=>x.text===text&&!x.disabled&&x.rect[2]>0),'button '+text);const w=state.widgets.find(x=>x.text===text&&!x.disabled&&x.rect[2]>0);await bounded(page.mouse.click((w.rect[0]+w.rect[2]/2)/state.width*1600,(w.rect[1]+w.rect[3]/2)/state.height*900),'click '+text);await poll()}
  const url=base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login';report.url=url;
  await bounded(page.goto(url,{waitUntil:'domcontentloaded',timeout:30000}),'navigate');await page.bringToFront();
  await bounded(page.waitForFunction(()=>globalThis.Module?.calledRun===true,{},{timeout:Math.max(1,deadline-Date.now())}),'WASM calledRun');
  await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loading,'hall bootstrap',120000);assert.equal(state.monitorEnabled,true);
  // The initial tutorial can appear after the hall first becomes ready.
  // Revisit the real hall entry until the mode cards are actually visible.
  progress('public mode entry');const entryDeadline=Date.now()+15000;
  for(;;){
   healthy();assert(Date.now()<entryDeadline,'Stage deadline: public mode entry');
   const skip=state.widgets.find(x=>/^(跳过引导|确定跳过？再点一次)$/.test(x.text)&&!x.disabled);
   if(skip){
    if(skip.text==='跳过引导')await click('跳过引导');
    await click('确定跳过？再点一次');
    await wait(s=>!s.widgets.some(x=>/跳过引导|确定跳过/.test(x.text)),'public tutorial skip confirmed');
   }else if(state.widgets.some(x=>x.text==='站点争夺'&&!x.disabled))break;
   else await click('出战');
   await sleep(100);await poll();
  }
  await click('站点争夺');await click('开始匹配');
  await wait(s=>s.mode==='trial'&&s.battle&&!s.loading,'actual battle loading',120000);
  if(state.intro){await page.keyboard.press('Space');await wait(s=>!s.intro,'skip camera intro')}
  await wait(s=>s.battle.state==='live','actual battle live');
  progress('actual public pointer capture');const pointerDeadline=Math.min(deadline,Date.now()+15000);let nextPointerClick=0;
  while(!state.captured){
   healthy();assert(Date.now()<pointerDeadline,'Stage deadline: actual public pointer capture');
   if(Date.now()>=nextPointerClick){await bounded(page.locator('#canvas').click(),'public canvas pointer click');nextPointerClick=Date.now()+700}
   await poll();if(!state.captured)await sleep(100);
  }
  progress('controlled setup');await page.keyboard.press('F11');let stageDeadline=Date.now()+15000;while(!setup){healthy();assert(Date.now()<stageDeadline,'Stage deadline: controlled setup');await sleep(50)}
  await sleep(750);healthy();
  if(diagnostic){report.cdpDiagnosticRequested=true;report.cdp=diagnostic.metadata;await bounded(diagnostic.start(page),'CDP diagnostic start')}
  progress('capture start');await page.keyboard.press('F9');stageDeadline=Date.now()+15000;while(!started){healthy();assert(Date.now()<stageDeadline,'Stage deadline: capture start');await sleep(50)}
  if(diagnostic)await bounded(diagnostic.mark('held-input-start'),'CDP input start anchor');
  measuring=true;const start=Date.now();await page.mouse.down();
  while(Date.now()-start<duration){healthy();await sleep(100)}
  await page.mouse.up();if(diagnostic)await bounded(diagnostic.mark('held-input-end'),'CDP input end anchor');await page.keyboard.press('F9');measuring=false;
  stageDeadline=Date.now()+15000;while(!result){healthy();assert(Date.now()<stageDeadline,'Stage deadline: result transport');await sleep(50)}
  report.captureMs=Date.now()-start;
  if(diagnostic)await bounded(diagnostic.stop('capture-complete'),'CDP diagnostic stop');
  report.analysis=analyze(result);fs.writeFileSync(path.join(out,'analysis.json'),JSON.stringify(report.analysis,null,2)+'\n');
  await page.locator('#canvas').screenshot({path:path.join(out,'after-combat.png'),timeout:10000});
  await page.keyboard.press('Escape');await click('返回车库');await click('确定');
  await wait(s=>s.mode==='hangar'&&!s.loading,'returned hall');report.returned=state;
  await page.locator('#canvas').screenshot({path:path.join(out,'returned.png'),timeout:10000});
  report.status='PASS';report.checks=['HTTP main/modules match frozen identity','Default monitoring enabled','Eight unchanged real vehicles and seven AI','Dimension/terrain/static-ray safe controlled setup','Reciprocal real car visibility','Actual player shots and positive combat damage; world hit count is not player-specific','Actual structure/part decrease','Three coarse monitor scopes','Public return to hall'];
 }catch(error){report.status='FAIL';report.failure=error.stack;if(page)try{await page.screenshot({path:path.join(out,'failure.png'),timeout:3000})}catch{}throw error}
 finally{if(diagnostic)try{await diagnostic.stop('runner-finally')}catch(e){report.cdpFailure=e.message;if(report.status==='PASS')report.status='FAIL'}if(browser)try{await Promise.race([browser.close(),sleep(5000).then(()=>{throw Error('browser close timeout')})]);report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.closeError=e.message}process.removeListener('SIGINT',sigint);process.removeListener('SIGTERM',sigterm);report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({status:report.status,shutdown:report.shutdown,out,failure:report.failure}))}
 return report;
}
module.exports={analyze,verifySetup,stream,signature,run,selfTest};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else run(process.argv[2],path.resolve(process.argv[3]),Number(process.argv[4]||45000)).catch(e=>{console.error(e.stack);process.exitCode=1})}

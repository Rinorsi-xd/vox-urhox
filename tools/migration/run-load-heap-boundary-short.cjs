'use strict';
// One independent diagnostic deployment and public abandonment; never an FPS test.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),Module=require('node:module');
const ROOT=path.resolve(__dirname,'../..'),PREPARE='.tmp/outgame-cached-1792189057538/identity.json';
const builder=require('./build-load-heap-boundary-probe.cjs');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
const TAGS=['hall-stable','old-hall-cleaned','resources-ready','physics-prepared','activation-closed','returned-cleanup'];
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function once(source,needle,replacement){assert.equal(source.split(needle).length,2,'Unique boundary-short integration '+needle);return source.replace(needle,replacement)}
function frozen(){const file=path.resolve(ROOT,process.env.VOX_PREPARE_FILE||PREPARE);assert.equal(file,path.resolve(ROOT,PREPARE),'Single frozen f881 package');return JSON.parse(fs.readFileSync(file,'utf8'))}
function built(){return builder.build(frozen())}
function baseSuffix(){return fs.readFileSync(path.join(__dirname,'qa-frame-wall-observer.lua'),'utf8')+'\n'+fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'),'utf8')+'\n'+fs.readFileSync(path.join(__dirname,'monitor-disabled-observer.lua'),'utf8')}
function sourceSuffix(){return baseSuffix()+built().suffix}
function serverSource(source){
 const tool=built();
 source=once(source,'const fullProbe=probe+aimEngineProbe+salvageStockProbe;','const fullProbe=probe+aimEngineProbe+salvageStockProbe+'+JSON.stringify(tool.suffix)+';');
 return once(source,'previewIdentity=()=>({...prepared,qa,','previewIdentity=()=>({...prepared,loadHeapBoundaryShort:true,loadHeapBoundaryTool:'+JSON.stringify(tool.identity)+',qa,');
}
async function auditHttp(base){
 const prepared=frozen(),tool=built();
 const read=async route=>{const response=await fetch(base+route,{signal:AbortSignal.timeout(20000)});assert.equal(response.status,200,route);return Buffer.from(await response.arrayBuffer())};
 const identity=JSON.parse(await read('/identity.json'));
 assert.equal(identity.qa,true);assert.equal(identity.monitorDisabled,true);assert.equal(identity.perfMonitor,false);
 const injectionRequired=identity.loadHeapBoundaryShort!==true;
 const suffix=injectionRequired?baseSuffix():sourceSuffix();
 for(const flag of ['qaAimEngine','qaSalvageStock','storyRoute','homeRoute','loadProfile','combatProfile','driveSectionsProfile','trialSectionsProfile','afterStepProfile','framePipelineProfile','fixedStepPipelineProfile','renderExperiment','warmExperiment','warmIntroExperiment','loadingFailureTest'])assert.equal(identity[flag],false,'Separate heap-boundary server excludes '+flag);
 assert.deepEqual(identity.identity,prepared.identity);assert.deepEqual(identity.engineSources,prepared.engineSources);if(!injectionRequired)assert.deepEqual(identity.loadHeapBoundaryTool,tool.identity);
 assert.equal(identity.source_directory,prepared.source_directory);assert.equal(identity.servedManifest,'manifest-f881ebb0.json');assert.equal(identity.probeSha256,sha(suffix));
 const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path)),main=manifest.files.find(file=>file.fs_path==='main.lua');
 const name=main.uuid+'-'+main.hash+main.ext,expected=Buffer.concat([fs.readFileSync(path.join(prepared.source_directory,'dist/assets',name)),Buffer.from('\n'+suffix)]);
 const manifestRoute='/game-dist/'+path.relative(path.join(prepared.source_directory,'dist'),prepared.manifest_path).replaceAll('\\','/');
 const actualMain=await read('/game-dist/assets/'+name),actualManifest=JSON.parse(await read(manifestRoute));
 assert.ok(actualMain.equals(expected),'HTTP main exact frozen production + existing QA/disabled-monitor + boundary suffix');
 const expectedManifest=structuredClone(manifest);expectedManifest.files.find(file=>file.fs_path==='main.lua').size=expected.length;assert.deepEqual(actualManifest,expectedManifest);
 const runtime={};for(const name of ['UrhoXRuntime.js','UrhoXRuntime.wasm']){const bytes=await read('/'+name);assert.ok(bytes.equals(fs.readFileSync(path.join(ROOT,'.tmp/web-engine',name))));runtime[name]={bytes:bytes.length,sha256:sha(bytes)}}
 assert.deepEqual(JSON.parse(await read('/identity.json')),identity);
 return {result:'PASS',injectionRequired,identity,tool:tool.identity,manifestRoute,main:{name,bytes:actualMain.length,sha256:sha(actualMain)},suffixSha256:sha(suffix),runtime,boundary:'Exact origin HTTP artifact audit. If the origin is ordinary QA, only the owned browser main/manifest requests receive the boundary suffix, with separate exact response auditing. No Runtime performance claim.'};
}
function browserPayloads(){
 const prepared=frozen(),manifest=JSON.parse(fs.readFileSync(prepared.manifest_path)),main=manifest.files.find(file=>file.fs_path==='main.lua'),name=main.uuid+'-'+main.hash+main.ext;
 const packed=fs.readFileSync(path.join(prepared.source_directory,'dist/assets',name));
 const originalMain=Buffer.concat([packed,Buffer.from('\n'+baseSuffix())]),injectedMain=Buffer.concat([packed,Buffer.from('\n'+sourceSuffix())]);
 const originalManifest=structuredClone(manifest);originalManifest.files.find(file=>file.fs_path==='main.lua').size=originalMain.length;
 const injectedManifest=structuredClone(manifest);injectedManifest.files.find(file=>file.fs_path==='main.lua').size=injectedMain.length;
 return {name,originalMain,injectedMain,originalManifest,injectedManifest};
}
function verifyRecords(markers,diagnostics,snapshot){
 assert.equal(markers.length,6,'All six raw boundaries emitted once');assert.deepEqual([...markers.map(row=>row.tag)].sort(),[...TAGS].sort());
 markers.forEach((row,index)=>{assert.equal(row.sequence,index+1);assert.ok(Number.isInteger(row.frame)&&row.frame>=0);assert.equal(row.diagnostic,true);assert.equal(row.atomicAllocatorSnapshot,false)});
 assert.ok(diagnostics.every(row=>row.diagnostic===true&&row.excludeFromFps===true),'All intrusive diagnostic records excluded from FPS');
 assert.ok(!diagnostics.some(row=>row.kind==='observer-error'),'No observer error');
 const starts=diagnostics.filter(row=>row.kind==='sample-start'),ends=diagnostics.filter(row=>row.kind==='sample-end'),results=diagnostics.filter(row=>row.kind==='allocator-result'),late=diagnostics.filter(row=>row.kind==='late-same-frame-boundary');
 assert.ok(starts.length>0&&starts.length<=6);assert.equal(ends.length,starts.length);assert.equal(results.length,starts.length);
 const covered=new Set();
 for(const [index,start]of starts.entries()){
  assert.equal(start.id,index+1);assert.ok(start.tags.length>0);for(const tag of start.tags)covered.add(tag);
  const end=ends.filter(row=>row.id===start.id),result=results.filter(row=>row.id===start.id);
  assert.equal(end.length,1);assert.equal(result.length,1);assert.equal(end[0].status,'OK');assert.equal(result[0].allocator.kind,'sample');assert.equal(result[0].allocator.status,'OK');
  assert.deepEqual(end[0].tags,start.tags);assert.deepEqual(result[0].tags,start.tags);
  assert.ok(diagnostics.some(row=>row.kind==='sample-following-frame'&&row.id===start.id),'Following RAF exclusion marker for each allocator query');
 }
 for(const row of late){assert.ok(starts.some(start=>start.id===row.priorSample));covered.add(row.marker.tag)}
 assert.deepEqual([...covered].sort(),[...TAGS].sort(),'Each boundary has a deferred sample or explicit late-same-frame exclusion');
 assert.equal(snapshot.pending,0);assert.equal(snapshot.error,null);assert.equal(snapshot.zeroReentrancy,true);assert.equal(snapshot.allocatorCalls,starts.length);assert.deepEqual([...snapshot.tags].sort(),[...TAGS].sort());
 return {result:'PASS',boundaries:markers.length,allocatorCalls:starts.length,coalesced:starts.filter(row=>row.coalesced).map(row=>({id:row.id,tags:row.tags})),lateSameFrame:late,
  boundary:'Late/coalesced values remain non-atomic. These are aggregate allocator totals, not allocation-owner attribution or FPS evidence. Endpoint console-depth check and deferred observer design do not prove every native stack behavior.'};
}
async function run(){
 assert.deepEqual(process.argv.slice(2),[],'No long-route, heap-window, profiling or gameplay fixture flags');
 const base=process.env.VOX_QA_BASE;assert.match(base||'',/^http:\/\/127\.0\.0\.1:\d+$/);
 const out=path.resolve(ROOT,'docs/migration/evidence/load-heap-short-f881-'+Date.now());fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',out,base,startedAt:new Date().toISOString(),checks:[],errors:[],probeErrors:[],httpErrors:[],boundaries:[],diagnostics:[],route:{publicOnly:true,dwellMs:5000,totalDeadlineMs:300000,raidDeadlineMs:45000},
  boundary:'Intrusive loading-boundary heap diagnosis only. Public salvage enter, natural drop, five-second idle residency, T abandonment and returned result acknowledgement. No driving/loot/extraction success claim, no periodic allocator query, no forced GC or altered gameplay state, no FPS or mobile acceptance.'};
 let browser,page,server,state,seq=0,closing,totalTimer,raidTimer;
 const persist=()=>{report.lastState=state;fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2))};
 const {createRuntimeWatchdog,isRuntimeFatal}=require('./salvage-runtime-watchdog.cjs');
 const shutdown=()=>closing||(closing=require('./run-auto-gc-aba.cjs').closeOwnedBrowser(page,browser,server));
 const watchdog=createRuntimeWatchdog({onFatal:event=>{report.fatal=event;report.result='FAIL';persist();void shutdown()},operationTimeoutMs:15000});
 const op=(label,work,timeout)=>watchdog.operation(label,work,timeout);
 const check=(condition,label)=>{assert.ok(condition,label);report.checks.push(label);persist()};
 const healthy=()=>{watchdog.throwIfFatal();assert.equal(report.errors.length,0,report.errors.join('\n'));if(state?.loadingFlow?.failed)throw Error('LoadingFlow failed: '+state.loadingFlow.error)};
 const dump=async()=>op('F8 snapshot',()=>page.keyboard.press('F8'));
 async function wait(predicate,label,timeout=90000){const deadline=Date.now()+timeout;let nextPoll=0;while(!predicate(state)){healthy();assert.ok(Date.now()<deadline,'Timeout '+label);if(Date.now()>=nextPoll){nextPoll=Date.now()+800;await dump()}await sleep(70)}return state}
 async function fresh(){const before=seq;await dump();return wait(()=>seq>before,'fresh state',15000)}
 async function click(text){
  await fresh();await wait(s=>Array.isArray(s?.widgets)&&s.widgets.some(w=>w.text===text&&!w.disabled&&w.rect?.[2]>0&&(!w.entrance||w.entrance.opacity>.9)),'visible public button '+text,25000);
  const widget=state.widgets.filter(w=>w.text===text&&!w.disabled&&w.rect?.[2]>0&&(!w.entrance||w.entrance.opacity>.9)).at(-1),r=widget.rect;
  const canvas=await op('canvas bounds',()=>page.locator('canvas').boundingBox());assert.ok(canvas);
  await op('click '+text,()=>page.mouse.click(canvas.x+(r[0]+r[2]/2)*canvas.width/state.width,canvas.y+(r[1]+r[3]/2)*canvas.height/state.height));
 }
 totalTimer=setTimeout(()=>watchdog.fail('total-deadline','Short boundary diagnostic total wall deadline 300s'),300000);
 try{
  persist();report.httpAudit=await auditHttp(base);fs.writeFileSync(path.join(out,'http-audit.json'),JSON.stringify(report.httpAudit,null,2));
  const tool=built();fs.writeFileSync(path.join(out,'boundary-tool-identity.json'),JSON.stringify(tool.identity,null,2));fs.writeFileSync(path.join(out,'browser-init.js'),tool.browserInit);fs.writeFileSync(path.join(out,'injected-boundaries.lua'),tool.suffix);
  report.toolSha256=sha(fs.readFileSync(__filename));
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  server=await op('owned browser launch',()=>chromium.launchServer({headless:true,channel:'chrome',args:['--use-angle=d3d11']}),30000);
  browser=await op('owned browser connect',()=>chromium.connect(server.wsEndpoint()));page=await op('page create',()=>browser.newPage({viewport:{width:1600,height:900}}));
  page.on('console',message=>{
   const line=message.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   for(const [prefix,key,file]of [['VOX_LOAD_HEAP_BOUNDARY ','boundaries','load-boundaries.jsonl'],['VOX_LOAD_HEAP_DIAGNOSTIC ','diagnostics','load-diagnostics.jsonl']]){
    const at=line.indexOf(prefix);if(at>=0){const raw=line.slice(at+prefix.length);fs.appendFileSync(path.join(out,file),raw+'\n');try{const row=JSON.parse(raw);report[key].push(row);if(row.kind==='observer-error')watchdog.fail('heap-observer',row.reason);persist()}catch(error){report.probeErrors.push({kind:key,error:error.message});watchdog.fail('heap-parse',error.message)}}
   }
   const at=line.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(line.slice(at+14));seq++;fs.appendFileSync(path.join(out,'states.jsonl'),JSON.stringify({seq,state})+'\n')}catch(error){report.probeErrors.push({kind:'state',error:error.message,length:line.length});persist()}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line)){report.errors.push(line);persist()}
   if(isRuntimeFatal(line))watchdog.fail('console',line);
  });
  page.on('pageerror',error=>{report.errors.push(error.stack||error.message);watchdog.fail('pageerror',error.stack||error.message)});
  page.on('crash',()=>watchdog.fail('crash','Owned browser page crashed'));
  page.on('response',response=>{if(response.status()>=400){report.httpErrors.push({status:response.status(),url:response.url()});persist()}});
  const payload=browserPayloads();report.browserInjection={required:report.httpAudit.injectionRequired,fulfilled:[],responses:[],expectedMain:{bytes:payload.injectedMain.length,sha256:sha(payload.injectedMain)}};
  const interceptedPaths=['/game-dist/assets/'+payload.name,report.httpAudit.manifestRoute];
  if(report.httpAudit.injectionRequired)for(const routePath of interceptedPaths){
   await op('install request-only boundary suffix '+routePath,()=>page.route(base+routePath,async route=>{
    try{
     const response=await op('fetch original frozen request '+routePath,()=>route.fetch());assert.equal(response.status(),200);
     const original=await op('read original frozen request '+routePath,()=>response.body());
     const main=routePath.endsWith(payload.name);if(main)assert.ok(original.equals(payload.originalMain));else assert.deepEqual(JSON.parse(original),payload.originalManifest);
     const body=main?payload.injectedMain:Buffer.from(JSON.stringify(payload.injectedManifest));
     report.browserInjection.fulfilled.push({path:routePath,originalBytes:original.length,originalSha256:sha(original),bytes:body.length,sha256:sha(body)});persist();
     await route.fulfill({response,body,headers:{...response.headers(),'content-length':String(body.length)}});
    }catch(error){report.errors.push(error.stack);watchdog.fail('boundary-request-injection',error.stack);await route.abort().catch(()=>{})}
   }));
  }
  page.on('response',response=>{
   const url=new URL(response.url());if(!interceptedPaths.includes(url.pathname))return;
   void op('audit actual owned response '+url.pathname,()=>response.body()).then(bytes=>{
    if(url.pathname.endsWith(payload.name))assert.ok(bytes.equals(payload.injectedMain),'Actual browser main exact injected bytes');else assert.deepEqual(JSON.parse(bytes),payload.injectedManifest);
    report.browserInjection.responses.push({path:url.pathname,bytes:bytes.length,sha256:sha(bytes)});persist();
   }).catch(error=>{report.errors.push(error.stack);watchdog.fail('browser-payload-audit',error.stack)});
  });
  await op('install deferred observer before navigation',()=>page.addInitScript({content:tool.browserInit}));
  await op('navigate public game',()=>page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1'),60000);await op('owned focus',()=>page.bringToFront());
  await wait(s=>s?.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow?.active,'initial hall',180000);
  check(state.performance?.monitor?.enabled===false,'Actual production performance monitor disabled');
  await wait(()=>report.boundaries.some(row=>row.tag==='hall-stable'),'actual initial hall boundary',15000);
  await click('打捞行动');await wait(s=>s?.tab==='salvage'&&!s.loadingFlow?.active&&!s.vehicleLoading?.busy,'public salvage lobby',30000);
  report.loadout=structuredClone(state);await click('出发');
  await wait(s=>s?.salvageRun&&!s.loadingFlow?.active,'real salvage activation',150000);
  raidTimer=setTimeout(()=>watchdog.fail('raid-deadline','Short boundary diagnostic active raid wall deadline 45s'),45000);
  report.activation=structuredClone(state);await wait(s=>s?.salvageRun&&!s.salvageRun.cine.playing,'natural deployment cinematic completes',30000);
  await op('public gameplay pointer capture',()=>page.mouse.click(800,450));await wait(s=>s?.pointer?.captured,'actual pointer capture',15000);
  check(report.boundaries.some(row=>row.tag==='activation-closed'),'Actual deployment Close boundary recorded');
  report.dwell={startedAt:new Date().toISOString(),gameStart:state.salvageRun.time};await sleep(5000);healthy();await fresh();
  report.dwell.finishedAt=new Date().toISOString();report.dwell.gameEnd=state.salvageRun?.time;
  assert.ok(state.salvageRun&&!state.salvageRun.result,'Natural raid still active before public abandonment');
  const abandonSeq=seq;await op('public T abandonment',()=>page.keyboard.press('t'));
  await wait(s=>seq>abandonSeq&&(s?.loadingFlow?.active||s?.salvageReturn||s?.mode!=='trial'),'public abandonment starts actual return',15000);
  clearTimeout(raidTimer);raidTimer=null;
  await wait(s=>s?.mode==='hangar'&&!s.loadingFlow?.active&&s.salvageReturn?.shown,'public abandonment result in returned hall',90000);
  const acceptance=require('./salvage-return-acceptance.cjs');report.returnedResult=structuredClone(state);report.returnAcceptance=acceptance.assertResultInReturnedHall(state);
  check(state.salvageReturn.result.ok===false&&state.salvageReturn.result.keepCar===true&&state.salvageReturn.committed===true,'Public abandonment commits loss and preserves original vehicle');
  await click('回大厅');await wait(s=>s?.mode==='hangar'&&!s.loadingFlow?.active&&!s.dialog&&!s.salvageReturn,'public result acknowledgement',25000);await fresh();report.acknowledgement=acceptance.assertResultAcknowledgement(report.returnedResult,state);
  await wait(()=>report.boundaries.some(row=>row.tag==='returned-cleanup')&&report.diagnostics.filter(row=>row.kind==='sample-following-frame').length===report.diagnostics.filter(row=>row.kind==='sample-start').length,'all real cleanup and following-frame markers',30000);
  report.observerSnapshot=await op('final read-only observer endpoint',()=>page.evaluate(()=>window.__voxLoadHeapBoundaryObserver.snapshot()));
  report.recordVerification=verifyRecords(report.boundaries,report.diagnostics,report.observerSnapshot);
  check(interceptedPaths.every(routePath=>report.browserInjection.responses.some(row=>row.path===routePath)),'Actual browser main and manifest response bytes verified');
  check(report.httpErrors.length===0,'No HTTP failures');check(report.errors.length===0,'No Runtime errors');check(report.probeErrors.length===0,'No unparsed QA/heap records');
  await op('final screenshot outside allocator queries',()=>page.screenshot({path:path.join(out,'returned.png'),timeout:10000}));
  report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;persist()}
 finally{
  clearTimeout(totalTimer);clearTimeout(raidTimer);
  if(page&&!page.isClosed()&&!watchdog.fatal){try{await op('dispose observer',()=>page.evaluate(()=>{const observer=window.__voxLoadHeapBoundaryObserver;const snapshot=observer?.snapshot();observer?.dispose();return snapshot}),3000);report.observerDisposed=true}catch(error){report.disposeError=error.message}}
  report.shutdown=await shutdown();if(report.shutdown.status!=='CLOSED'){report.result='FAIL';report.failure=report.failure||'Owned browser shutdown failed'}
  report.finishedAt=new Date().toISOString();persist();
 }
 console.log(JSON.stringify({result:report.result,out,checks:report.checks.length,allocatorCalls:report.observerSnapshot?.allocatorCalls,shutdown:report.shutdown.status,failure:report.failure}));
 if(report.result!=='PASS')throw Error(report.failure||'Short boundary diagnostic failed');
 return report;
}
function selfTest(){
 const vm=require('node:vm'),source=fs.readFileSync(path.join(__dirname,'serve-outgame.cjs'),'utf8');new vm.Script(serverSource(source));new vm.Script(built().browserInit);
 const payload=browserPayloads();assert.ok(payload.injectedMain.equals(Buffer.concat([payload.originalMain,Buffer.from(built().suffix)])));assert.equal(payload.injectedManifest.files.find(file=>file.fs_path==='main.lua').size,payload.injectedMain.length);
 assert.throws(()=>serverSource(source.replace('const fullProbe=probe+aimEngineProbe+salvageStockProbe;','drift')));
 const markers=TAGS.map((tag,i)=>({tag,sequence:i+1,frame:i+1,diagnostic:true,atomicAllocatorSnapshot:false}));
 const diagnostics=TAGS.flatMap((tag,i)=>[{kind:'sample-start',id:i+1,tags:[tag]},{kind:'allocator-result',id:i+1,tags:[tag],allocator:{kind:'sample',status:'OK'}},{kind:'sample-end',id:i+1,tags:[tag],status:'OK'},{kind:'sample-following-frame',id:i+1}]).map(row=>({...row,diagnostic:true,excludeFromFps:true}));
 const snapshot={pending:0,error:null,zeroReentrancy:true,allocatorCalls:6,tags:TAGS};verifyRecords(markers,diagnostics,snapshot);
 assert.throws(()=>verifyRecords(markers.slice(1),diagnostics,snapshot));assert.throws(()=>verifyRecords(markers,diagnostics.filter(row=>row.kind!=='sample-following-frame'),snapshot));
 const bad=structuredClone(diagnostics);bad[1].allocator.status='UNAVAILABLE';assert.throws(()=>verifyRecords(markers,bad,snapshot));
 assert.throws(()=>verifyRecords(markers,[...diagnostics,{kind:'observer-error',diagnostic:true,excludeFromFps:true}],snapshot));
 assert.throws(()=>verifyRecords(markers,diagnostics,{...snapshot,pending:1}));
 console.log('PASS: latest-f881 seven-source contracts, service/browser syntax, exact integration drift rejection and six-boundary acceptance negative controls; no hardware launched');
}
function compile(file,source){const m=new Module(file,module);m.filename=file;m.paths=Module._nodeModulePaths(path.dirname(file));m._compile(source,file);return m.exports}
module.exports={serverSource,sourceSuffix,auditHttp,verifyRecords,selfTest};
if(require.main===module){
 if(process.argv.includes('--self-test'))selfTest();
 else if(process.argv.includes('--serve')){assert.deepEqual(process.argv.slice(2),['--serve']);process.env.VOX_PREPARE_FILE=PREPARE;process.argv.push('--qa','--monitor-disabled');const file=path.join(__dirname,'serve-outgame.cjs');compile(file,serverSource(fs.readFileSync(file,'utf8'))).startPreviewServer()}
 else if(process.argv.includes('--audit')){assert.deepEqual(process.argv.slice(2),['--audit']);auditHttp(process.env.VOX_QA_BASE).then(result=>console.log(JSON.stringify(result,null,2))).catch(error=>{console.error(error.stack);process.exitCode=1})}
 else run().catch(error=>{console.error(error.stack);process.exitCode=1});
}

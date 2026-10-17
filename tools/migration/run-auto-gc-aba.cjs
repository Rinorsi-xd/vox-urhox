'use strict';
// Reuse the frozen-package server and real eight-car public-input runner in memory.
// The existing files and every production source byte remain untouched.
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const sha=v=>crypto.createHash('sha256').update(v).digest('hex');
function replaceOnce(text,needle,replacement){assert.equal(text.split(needle).length,2,'Unique integration boundary: '+needle.slice(0,70));return text.replace(needle,replacement)}
function compile(file,source){const m=new Module(file,module);m.filename=file;m.paths=Module._nodeModulePaths(path.dirname(file));m._compile(source,file);return m.exports}
function environmentSnapshot(){
 const command="@(Get-Process | Where-Object { $_.ProcessName -match '^Urho(X|3D)' } | Select-Object Id,ProcessName,CPU,StartTime) | ConvertTo-Json -Compress";
 try{
  const raw=require('node:child_process').execFileSync('powershell.exe',['-NoProfile','-Command',command],{windowsHide:true,encoding:'utf8',timeout:10000}).trim();
  const data=raw?JSON.parse(raw):[];
  return {at:new Date().toISOString(),processes:Array.isArray(data)?data:[data],boundary:'Read-only process CPU totals. No user process stopped; unrelated system/GPU interference remains unmeasured.'};
 }catch(error){return {at:new Date().toISOString(),unavailable:error.message}}
}
function environmentDelta(before,after){
 return (after.processes||[]).map(p=>{
  const old=before.processes?.find(q=>q.Id===p.Id&&q.StartTime===p.StartTime);
  return {...p,cpuDeltaSeconds:old&&typeof old.CPU==='number'&&typeof p.CPU==='number'?p.CPU-old.CPU:null};
 });
}
async function closeOwnedBrowser(page,browser,server){
 const result=await require('./salvage-runtime-watchdog.cjs').closeRuntime(page,browser);
 if(!server)return result;
 let timer;
 try{
  await Promise.race([server.close(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Dedicated browser server close timeout')),3000)})]);
  return {...result,status:'CLOSED',ownedServer:'CLOSED'};
 }catch(error){
  try{await server.kill();return {...result,status:'CLOSED',ownedServer:'KILLED',closeError:error.message}}
  catch(killError){return {...result,status:'CLOSE_FAILED',ownedServer:'UNKNOWN',closeError:error.message,killError:killError.message}}
 }finally{clearTimeout(timer)}
}
function suffix(options={}){
 const core=fs.readFileSync(path.join(__dirname,'qa-auto-gc-aba.lua'),'utf8');
 const allocation=options.allocation===true?fs.readFileSync(path.join(__dirname,'qa-allocation-owners.lua'),'utf8'):null;
 let output='\ndo\nlocal factory=(function()\n'+core+'\nend)()\n'+String.raw`
assert(not rawget(_G,'VOX_QA_AUTO_GC_ABA'),'Duplicate automatic-GC experiment')
local Cycle=require 'core.CollectionCycle'
local Lifetime=require 'render.RenderTargetLifetime'
local function App() return VOX_HANGAR and VOX_HANGAR.app or VOX_TRIAL and VOX_TRIAL.app or lastObservedApp end
local function Gate()
    local app=App();local s=app and app.trial;local b=s and s.battle
    if not app or app.stopped or not s or s.disposed or not b then return 'not a live competitive session' end
    if app.loadingFlow.active or app.mapPreview or app.vehicleSwitch and app.vehicleSwitch.pending then return 'loading/preview/switch active' end
    if not input.focus or input.minimized or not s.pointer.captured or s.dialog then return 'focus/pointer/menu gate' end
    if s.intro and not s.intro.done or b.rules.state~='live' then return 'intro/non-live battle' end
    if not input:GetKeyDown(KEY_W) or not input:GetMouseButtonDown(MOUSEB_LEFT) or not s.controls.held.fire then return 'held drive/fire not active' end
    local c=Cycle.State()
    if c.active or c.stepping or c.restoreRequested or Lifetime.PendingCount()~=0 then return 'explicit collection/retirement work pending' end
    if #b.entries~=8 or #s.world.units~=8 then return 'actual roster is not eight vehicles' end
    local parts={tostring(s),tostring(b),tostring(b.rules.round)}
    for i,e in ipairs(b.entries) do
        local u=e.unit
        if not u.alive or not u.vehicle or not u.vehicle.body then return 'vehicle died/unloaded' end
        parts[#parts+1]=tostring(u)..':'..tostring(u.bp:Size())..':'..tostring(u.vehicle)
    end
    return nil,table.concat(parts,'|')
end
local probe=factory.New({gc=collectgarbage,clock=function()return Time:GetSystemTime()end,
    frame=function()return GetTime().frameNumber end,gate=Gate,
    getGlobal=function()return collectgarbage end,setGlobal=function(value)collectgarbage=value end})
_G.VOX_QA_AUTO_GC_ABA=probe
local oldUpdate,oldPost,oldPresented,oldStop=HandleUpdate,HandlePostUpdate,HandleFramePresented,Stop
local emitted=false
local function Emit()
    if not emitted and (probe.phase=='done' or probe.phase=='invalid') then
        emitted=true;print('VOX_GC_ABA_REPORT '..cjson.encode(probe:Report()))
    end
end
function HandleUpdate(...)
    if input:GetKeyPress(KEY_F11) then probe:Abort('explicit runner/watchdog cancellation') end
    if input:GetKeyPress(KEY_F10) then
        local ok,why=probe:Safe('Arm')
        print('VOX_GC_ABA_ARM '..cjson.encode({ok=ok,reason=why,state=probe:Snapshot()}))
    end
    probe:Safe('BeginFrame')
    local result=table.pack(pcall(oldUpdate,...))
    if not result[1] then probe:Abort('Update exception');Emit();error(result[2],0) end
    return table.unpack(result,2,result.n)
end
function HandlePostUpdate(...)
    local result=table.pack(pcall(oldPost,...))
    if not result[1] then probe:Abort('PostUpdate exception');Emit();error(result[2],0) end
    return table.unpack(result,2,result.n)
end
function HandleFramePresented(...)
    local result=table.pack(pcall(oldPresented,...))
    if not result[1] then probe:Abort('FramePresented exception');Emit();error(result[2],0) end
    probe:Safe('EndFrame');Emit()
    return table.unpack(result,2,result.n)
end
function Stop(...)
    probe:Abort('Runtime Stop');Emit()
    if oldStop then return oldStop(...) end
end
end
`;
 if(allocation){
  output=replaceOnce(output,"_G.VOX_QA_AUTO_GC_ABA=probe",String.raw`
local allocationFactory=(function()
`+allocation+String.raw`
end)()
local alloc=allocationFactory.New({gc=collectgarbage,phase=function()return probe.phase end,
    frame=function()return GetTime().frameNumber end})
local callbacks={HandleUpdate=HandleUpdate,HandlePostUpdate=HandlePostUpdate,HandleFramePresented=HandleFramePresented}
alloc:PrepareCallbacks(callbacks,require 'urhox-libs/UI')
HandleUpdate=callbacks.HandleUpdate;HandlePostUpdate=callbacks.HandlePostUpdate;HandleFramePresented=callbacks.HandleFramePresented
_G.VOX_QA_AUTO_GC_ABA=probe`);
  output=replaceOnce(output,"emitted=true;print('VOX_GC_ABA_REPORT '..cjson.encode(probe:Report()))",String.raw`
        emitted=true
        local report=probe:Report();report.allocation=alloc:Report();alloc:RestoreWrappers()
        print('VOX_GC_ABA_REPORT '..cjson.encode(report))`);
  output=replaceOnce(output,"local ok,why=probe:Safe('Arm')","if not alloc.trialPrepared then alloc:PrepareTrial(App()) end\n        local ok,why=probe:Safe('Arm')");
  output=replaceOnce(output,"probe:Safe('BeginFrame')","probe:Safe('BeginFrame');alloc:BeginFrame()");
  output=replaceOnce(output,"if not result[1] then probe:Abort('Update exception')","if not result[1] then alloc:EndFrame();probe:Abort('Update exception')");
  output=replaceOnce(output,"if not result[1] then probe:Abort('PostUpdate exception')","if not result[1] then alloc:EndFrame();probe:Abort('PostUpdate exception')");
  output=replaceOnce(output,"if not result[1] then probe:Abort('FramePresented exception')","if not result[1] then alloc:EndFrame();probe:Abort('FramePresented exception')");
  output=replaceOnce(output,"probe:Safe('EndFrame');Emit()","alloc:EndFrame();probe:Safe('EndFrame');Emit()");
  output=replaceOnce(output,"probe:Abort('Runtime Stop');Emit()","alloc:EndFrame();probe:Abort('Runtime Stop');Emit()");
 }
 return output;
}
function serverSource(source,options={}){
 source=replaceOnce(source,'const fullProbe=probe+aimEngineProbe+salvageStockProbe;','const fullProbe=probe+aimEngineProbe+salvageStockProbe+'+JSON.stringify(suffix(options))+';');
 source=replaceOnce(source,'previewIdentity=()=>({...prepared,qa,','previewIdentity=()=>({...prepared,gcAbaProfile:true,gcAbaAllocationOwners:'+String(options.allocation===true)+',gcAbaProbeSha256:'+JSON.stringify(sha(fs.readFileSync(path.join(__dirname,'qa-auto-gc-aba.lua'))))+',qa,');
 return source;
}
function runnerSource(source){
 source=replaceOnce(source,"const report={result:'RUNNING',route,matchMode,url,identity,production,", "assert.equal(identity.gcAbaProfile,true,'Dedicated automatic-GC QA server');\n assert.equal(identity.gcAbaAllocationOwners===true,process.argv.includes('--allocation-owners'),'Matching explicit allocation-owner mode');\n const report={gcABA:{toolSha256:sha(fs.readFileSync(path.join(__dirname,'run-auto-gc-aba.cjs'))),probeSha256:sha(fs.readFileSync(path.join(__dirname,'qa-auto-gc-aba.lua'))),environmentBefore:require(path.join(__dirname,'run-auto-gc-aba.cjs')).environmentSnapshot(),arm:null,report:null,heap:[],boundary:'Diagnostic A/B/A only; never ship stopped GC'},result:'RUNNING',route,matchMode,url,identity,production,");
 source=replaceOnce(source,'const pipelineRecords=[];','const pipelineRecords=[];\n'+String.raw`
 let gcWatchdog,gcBrowserServer;
 const sampleHeap=async tag=>{
  let timer;
  const row=await Promise.race([page.evaluate(tag=>window.__voxGcHeap.sample(tag),tag),
   new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Allocator guard timeout')),3000)})]).finally(()=>clearTimeout(timer));
  report.gcABA.heap.push(row);assert.equal(row?.status,'OK','Actual allocator sample available');return row;
 };
`);
 source=replaceOnce(source,"browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});page=await browser.newPage({viewport:VIEWPORT});",String.raw`
  gcBrowserServer=await chromium.launchServer({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
  browser=await chromium.connect(gcBrowserServer.wsEndpoint());page=await browser.newPage({viewport:VIEWPORT});
`);
 source=replaceOnce(source,'const line=message.text();lineNumber++;',String.raw`const line=message.text();lineNumber++;
   if(line.includes('VOX_GC_ABA_ARM '))report.gcABA.arm=JSON.parse(line.slice(line.indexOf('VOX_GC_ABA_ARM ')+15));
   if(line.includes('VOX_GC_ABA_REPORT ')){
    report.gcABA.report=JSON.parse(line.slice(line.indexOf('VOX_GC_ABA_REPORT ')+18));
    fs.writeFileSync(path.join(out,'auto-gc-aba.json'),JSON.stringify(report.gcABA,null,2));
   }
`);
 source=replaceOnce(source,"const heldInputStartMs=now();report.inputDispatchMs=heldInputStartMs-startMs;",String.raw`
  const heldInputStartMs=now();report.inputDispatchMs=heldInputStartMs-startMs;
  await page.addScriptTag({path:path.join(__dirname,'wasm-heap-diagnostics.js')});
  await page.evaluate(()=>{window.__voxGcHeap=window.VoxWasmHeapDiagnostics.createProbe(window,{enabled:true,intervalMs:5000,emit:()=>{}})});
  report.gcABA.allocatorBaseline=await sampleHeap('before-arm');
  gcWatchdog=setTimeout(()=>{report.gcABA.watchdog='Dedicated browser kill requested after 15s without completion';
   persist();gcBrowserServer.kill().catch(error=>{report.gcABA.killError=error.message;persist()});},15000);gcWatchdog.unref();
  await page.keyboard.press('F10');
`);
 source=replaceOnce(source,'healthy();const tick=now();await poll();',String.raw`healthy();const tick=now();await poll();
   const heap=await sampleHeap('guard');
   if(heap.inUseBytes-report.gcABA.allocatorBaseline.inUseBytes>24*1024*1024){
    await page.keyboard.press('F11');throw Error('Actual allocator growth exceeded 24 MiB; experiment invalid');
   }
   if(report.gcABA.arm?.ok===false)throw Error('Automatic-GC arm gate refused: '+report.gcABA.arm.reason);
   if(report.gcABA.report?.state.phase==='invalid')throw Error('Automatic-GC experiment invalid: '+report.gcABA.report.state.reason);
`);
 source=replaceOnce(source,"report.measurementResult='PASS';",String.raw`
  assert.equal(report.gcABA.arm?.ok,true,'Explicit automatic-GC arm acknowledged');
  assert.equal(report.gcABA.report?.state.phase,'done','Complete A1/B/recovery/A2 acknowledged');
  assert.equal(report.gcABA.report.state.restored,true,'Original mode and running state restored');
  assert.equal(Object.keys(report.gcABA.report.explicitCalls).length,0,'No explicit GC contamination');
  clearTimeout(gcWatchdog);
  report.gcABA.allocatorAfter=await sampleHeap('after-done');
  report.gcABA.toolSha256=sha(fs.readFileSync(path.join(__dirname,'run-auto-gc-aba.cjs')));
  report.gcABA.probeSha256=sha(fs.readFileSync(path.join(__dirname,'qa-auto-gc-aba.lua')));
  report.gcABA.summary=require(path.join(__dirname,'run-auto-gc-aba.cjs')).summarize(report.gcABA.report,pipelineRecords);
  fs.writeFileSync(path.join(out,'auto-gc-aba.json'),JSON.stringify(report.gcABA,null,2));
  report.measurementResult='PASS';
`);
 source=replaceOnce(source,"measuring=false;\n  try{if(page&&!page.isClosed())",String.raw`measuring=false;
  // The engine can block CDP; a dedicated browser must close if restore cannot ACK.
  if(page&&!page.isClosed()){
   let deadline;
   try{await Promise.race([(async()=>{
    await page.keyboard.press('F11');
    if(framePipeline&&state?.framePipeline?.enabled){await page.keyboard.press('F9');await sleep(150)}
    await page.keyboard.press('F8');await sleep(150);
    await page.evaluate(()=>{window.__voxGcHeap?.dispose()});
   })(),new Promise((_,reject)=>{deadline=setTimeout(()=>reject(Error('Restore request timeout')),3000)})]);}
   catch(error){report.gcABA.cleanupError=error.message}finally{clearTimeout(deadline)}
  }
  if(report.gcABA.arm?.ok&&!report.gcABA.report?.state.restored)report.gcABA.restoreAckMissing=true;
  if(report.gcABA.report?.state.restored)clearTimeout(gcWatchdog);
  fs.writeFileSync(path.join(out,'auto-gc-aba.json'),JSON.stringify(report.gcABA,null,2));
  try{if(page&&!page.isClosed())`);
 source=replaceOnce(source,"await browser?.close();report.shutdown='CLOSED';report.finishedAt=new Date().toISOString();",String.raw`
  clearTimeout(gcWatchdog);
  report.gcABA.shutdown=await require(path.join(__dirname,'run-auto-gc-aba.cjs')).closeOwnedBrowser(page,browser,gcBrowserServer);
  report.shutdown=report.gcABA.shutdown.status;report.finishedAt=new Date().toISOString();
  report.gcABA.environmentAfter=require(path.join(__dirname,'run-auto-gc-aba.cjs')).environmentSnapshot();
  report.gcABA.environmentCpuDelta=require(path.join(__dirname,'run-auto-gc-aba.cjs')).environmentDelta(report.gcABA.environmentBefore,report.gcABA.environmentAfter);
  fs.writeFileSync(path.join(out,'auto-gc-aba.json'),JSON.stringify(report.gcABA,null,2));
`);
 return source+'\nmodule.exports.runAutoGcMain=main;\n';
}
function summarize(gcReport,pipeline){
 assert.equal(gcReport.state.phase,'done');assert.equal(gcReport.state.restored,true);
 assert.equal(Object.keys(gcReport.explicitCalls).length,0);
 const byFrame=new Map(pipeline.map(r=>[r.frame.frame,r.frame])),out={};
 const q=(a,p)=>{const x=[...a].sort((a,b)=>a-b);return x[Math.min(x.length-1,Math.ceil(p*x.length)-1)]};
 for(const phase of ['A1','B','A2']){
  const tagged=gcReport.frames.filter(f=>f.phase===phase).slice(1,-1);
  const frames=tagged.map(f=>byFrame.get(f.frame));
  assert.ok(frames.length>=8,'At least eight interior frames in '+phase);
  assert.ok(frames.every(f=>f&&!f.partialStart&&!f.partialEnd),'Complete directly tagged pipeline frames in '+phase);
  const wall=frames.map(f=>f.wallMs);
  out[phase]={frames:frames.length,frameIds:frames.map(f=>f.frame),medianWallMs:q(wall,.5),p95WallMs:q(wall,.95),
   over80:frames.filter(f=>f.wallMs>80).map(f=>f.frame),
   meanFixedMs:frames.reduce((n,f)=>n+['fixed.BeforeStep','fixed.WorldStep','fixed.AfterStep'].reduce((s,k)=>s+(f.scopes[k]?.inclusiveMs||0),0),0)/frames.length};
 }
 return {phases:out,boundary:'Direct engine-frame tags only; first/last phase frames, settle and recovery excluded. These are diagnostic wall durations including observers, not optimization gain or mobile FPS. Stable unit/part counts do not guarantee identical transient projectile/AI workload.'};
}
function selfTest(){
 const serve=fs.readFileSync(path.join(__dirname,'serve-outgame.cjs'),'utf8');
 const runner=fs.readFileSync(path.join(__dirname,'check-performance-uninstrumented-web.cjs'),'utf8');
 const patchedServer=serverSource(serve),patchedRunner=runnerSource(runner);
 new (require('node:vm').Script)(patchedServer);new (require('node:vm').Script)(patchedRunner);
 assert.ok(!serve.includes('gcAbaProfile'));assert.ok(!runner.includes('VOX_GC_ABA_ARM'));
 assert.throws(()=>replaceOnce('a a','a','b'),/Unique/);
 assert.ok(suffix().includes('local oldUpdate,oldPost,oldPresented,oldStop'));
 assert.ok(suffix({allocation:true}).includes('alloc:PrepareCallbacks'));
 new (require('node:vm').Script)(serverSource(serve,{allocation:true}));
 const frame={partialStart:false,partialEnd:false,wallMs:20,scopes:{'fixed.BeforeStep':{inclusiveMs:4}}};
 const data={state:{phase:'done',restored:true},explicitCalls:[],frames:[]},pipeline=[];
 for(const [j,phase]of ['A1','B','A2'].entries())for(let i=0;i<12;i++){
  const id=j*20+i;data.frames.push({phase,frame:id});pipeline.push({frame:{...frame,frame:id}});
 }
 const summary=summarize(data,pipeline);assert.equal(summary.phases.B.frames,10);assert.equal(summary.phases.B.medianWallMs,20);
 const missing=pipeline.filter(r=>r.frame.frame!==25);assert.throws(()=>summarize(data,missing),/Complete directly tagged/);
 assert.throws(()=>summarize({...data,explicitCalls:[{op:'step'}]},pipeline));
 console.log('PASS: exact disabled suffix/server/runner integration, JS parsing and drift rejection; no engine launched');
}
module.exports={suffix,serverSource,runnerSource,summarize,closeOwnedBrowser,environmentSnapshot,environmentDelta,selfTest};
if(require.main===module){
 if(process.argv.includes('--self-test'))selfTest();
 else if(!process.argv.includes('--enable-auto-gc-aba'))throw Error('Default OFF. Explicit --enable-auto-gc-aba required; QA diagnostic, not an optimization.');
 else if(process.argv.includes('--serve')){
  process.argv=process.argv.filter(a=>!['--serve','--enable-auto-gc-aba'].includes(a));
  process.argv.push('--qa','--monitor-disabled','--profile-frame-pipeline','--profile-fixed-step-pipeline');
  const file=path.join(__dirname,'serve-outgame.cjs');compile(file,serverSource(fs.readFileSync(file,'utf8'),{allocation:process.argv.includes('--allocation-owners')})).startPreviewServer();
 }else{
  assert.equal(process.env.VOX_PERF_ROUTE||'match','match','Eight-car battle only');
  process.env.VOX_PERF_ROUTE='match';process.env.VOX_PERF_MATCH_MODE=process.env.VOX_PERF_MATCH_MODE||'conquest';process.env.VOX_PERF_DRIVE_MS='10000';
  process.argv.push('--frame-pipeline','--fixed-step-pipeline','--cdp-profile-trace','--correlate-frame-trace');
  const file=path.join(__dirname,'check-performance-uninstrumented-web.cjs');
  compile(file,runnerSource(fs.readFileSync(file,'utf8'))).runAutoGcMain().catch(error=>{console.error(error.stack);process.exitCode=1});
 }
}

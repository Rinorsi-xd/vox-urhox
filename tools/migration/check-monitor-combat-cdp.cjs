// Offline protocol/analysis tests only. This file never imports Playwright.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{EventEmitter}=require('node:events');
const {create,CATEGORIES}=require('./monitor-combat-cdp.cjs');
const {analyze,unionMs,completeEvents}=require('./analyze-monitor-combat-trace.cjs');
async function protocol(failMode){
 const root=path.resolve(__dirname,'../..'),out=fs.mkdtempSync(path.join(root,'.tmp/cdp-protocol-offline-'));
 class Fake extends EventEmitter{
  constructor(){super();this.calls=[];this.reads=0;this.detached=false;this.sync=[]}
  async send(method,params){this.calls.push(method);
   if(method==='Browser.getVersion')return {product:'OFFLINE_FAKE_NOT_RUNTIME'};
   if(method==='Tracing.getCategories')return {categories:CATEGORIES.split(',').filter(x=>x!=='gpu')};
   if(method==='Performance.getMetrics')return {metrics:[{name:'Timestamp',value:1+this.calls.length*.001}]};
   if(method==='Tracing.recordClockSyncMarker'){this.sync.push({ph:'c',name:'clock_sync',args:{sync_id:params.syncId},ts:1e6});return {}}
   if(method==='Profiler.stop')return {profile:{startTime:1e6,endTime:2e6,nodes:[{id:1,callFrame:{functionName:'wasm-function[1]'}}],samples:[1],timeDeltas:[1000]}};
   if(method==='Tracing.end'){this.emit('Tracing.tracingComplete',{stream:'trace',dataLossOccurred:failMode==='loss'});return {}}
   if(method==='IO.read'){
    const text=failMode==='bad-json'?'{broken':JSON.stringify({traceEvents:failMode==='no-marker'?[]:this.sync});
    const split=Math.floor(text.length/2),part=this.reads++===0?text.slice(0,split):text.slice(split);
    return {data:Buffer.from(part).toString('base64'),base64Encoded:true,eof:this.reads===2};
   }
   return {};
  }
  async detach(){this.detached=true}
 }
 const fake=new Fake(),probe=create(out),page={context:()=>({newCDPSession:async()=>fake})};
 await probe.start(page);fake.emit('Runtime.consoleAPICalled',{timestamp:Date.now(),args:[{value:'VOX_PERF {"type":"sample"}'}],type:'log'});
 await probe.mark('held-input-start');await probe.mark('held-input-end');
 if(failMode)await assert.rejects(probe.stop('offline-'+failMode));else{
  await probe.stop('offline-success');const before=fake.calls.length;await probe.stop('idempotent');assert.equal(fake.calls.length,before);
  assert.equal(probe.metadata.status,'COLLECTED');assert.equal(probe.metadata.consoleRows,1);assert.equal(fake.reads,2);
  assert.deepEqual(probe.metadata.requestedCategoriesAbsentFromInventory,['gpu']);assert.equal(JSON.parse(fs.readFileSync(path.join(out,'drive.trace.json'),'utf8')).traceEvents.length,4);assert(probe.metadata.clockSyncVerified);
 }
 assert(fake.detached);assert.equal(fake.listenerCount('Runtime.consoleAPICalled'),0);
 assert(!fake.calls.some(x=>/collectGarbage|evaluate|addScript|setVirtualTime/i.test(x)),'No GC/input/clock interception');
 return out;
}
function analysis(){
 const anchors=[{label:'held-input-start',cdpMonotonicSeconds:0,wallBeforeMs:100000,wallAfterMs:100000},{label:'held-input-end',cdpMonotonicSeconds:1,wallBeforeMs:101000,wallAfterMs:101000}];
 const metadata={status:'COLLECTED',traceDataLoss:false,clockSyncVerified:true,clockAnchors:anchors,requestedCategoriesAbsentFromInventory:[]};
 const events=[{ph:'M',name:'thread_name',pid:1,tid:2,args:{name:'CrRendererMain'}}];
 for(let i=0;i<10;i++)events.push({ph:'X',name:'FunctionCall',args:{data:{functionName:'MainLoop_runner'}},pid:1,tid:2,ts:i*100000,dur:90000,tdur:80000});
 events.push({ph:'X',name:'V8.GCScavenger',pid:1,tid:2,ts:1000,dur:4000},
  {ph:'X',name:'V8.GCScavenger.Inner',pid:1,tid:2,ts:2000,dur:1000},
  {ph:'X',name:'GetProgramiv',pid:1,tid:2,ts:10000,dur:3000});
 const profile={startTime:0,endTime:1e6,nodes:[{id:1,callFrame:{functionName:'wasm-function[77]'}}],samples:[1,1],timeDeltas:[1000,2000]};
 const consoleRows=[{cdpEpochMs:100010,text:'VOX_PERF '+JSON.stringify({type:'slow_frame',frame:20,frameMs:91,scriptMs:60,context:{mode:'trial',sceneIsTrial:true}})}];
 const result=analyze(metadata,profile,{traceEvents:events},consoleRows);
 assert.equal(result.coverage.mainLoops,10);assert.equal(result.mainLoop.meanRecordedThreadCpuMs,80);assert.equal(result.mainLoop.meanOffCpuMs,10);
 assert.equal(result.mainThreadV8Gc.unionWallMs,4);assert.equal(result.mainThreadGlQueriesAndWaits.unionWallMs,3);
 assert.equal(result.statisticalWasmNodes[0].sampledWeightMs,3);assert.equal(result.emissionAnchors.length,1);
 assert.match(result.emissionAnchors[0].boundary,/NEXT BeginFrame/);assert.equal(result.luaGcUnresolved,true);
 const missing=analyze(metadata,profile,{traceEvents:events.filter(x=>x.name!=='FunctionCall')},consoleRows);
 assert.equal(missing.coverage.mainLoops,0);assert.equal(missing.mainLoop.meanRecordedThreadCpuMs,null);
 const noCpu=analyze(metadata,profile,{traceEvents:events.map(({tdur,...x})=>x)},consoleRows);assert.equal(noCpu.mainLoop.meanRecordedThreadCpuMs,null);
 const badClock=structuredClone(metadata);badClock.clockAnchors[1].wallBeforeMs+=100;badClock.clockAnchors[1].wallAfterMs+=100;
 assert.equal(analyze(badClock,profile,{traceEvents:events},consoleRows).emissionAnchors.length,0);
 assert.throws(()=>analyze({...metadata,traceDataLoss:true},profile,{traceEvents:events},consoleRows));
 assert.throws(()=>analyze(metadata,profile,{traceEvents:events.map(x=>({...x,tdur:1000000}))},consoleRows));
 const twoThreads=structuredClone(events);twoThreads[2].tid=99;
 assert.throws(()=>analyze(metadata,profile,{traceEvents:twoThreads},consoleRows),/Ambiguous runtime main thread/);
 const wrongMode=structuredClone(consoleRows);wrongMode[0].text='VOX_PERF '+JSON.stringify({type:'slow_frame',frame:20,frameMs:91,context:{mode:'hangar',sceneIsTrial:false}});
 assert.equal(analyze(metadata,profile,{traceEvents:events},wrongMode).emissionAnchors.length,0);
 assert.equal(unionMs([[0,4000],[1000,2000],[4000,6000]]),6);
 assert.equal(completeEvents({traceEvents:[{ph:'B',name:'task',pid:1,tid:2,ts:0,tts:10},{ph:'E',pid:1,tid:2,ts:1000,tts:510}]}).complete[0].tdur,500);
}
(async()=>{const paths=[];for(const mode of [null,'loss','bad-json','no-marker'])paths.push(await protocol(mode));analysis();require('./monitor-combat-run.cjs').selfTest();console.log(JSON.stringify({status:'OFFLINE_CDP_PROTOCOL_AND_ANALYSIS_PASS',noBrowserOrRuntime:true,protocolCases:4,paths},null,2))})().catch(error=>{console.error(error.stack);process.exitCode=1});

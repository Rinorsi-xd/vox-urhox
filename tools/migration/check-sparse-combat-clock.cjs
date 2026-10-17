'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),vm=require('node:vm');
const {create,clockAnchors}=require('./sparse-combat-cpu.cjs');
const {runnerSource}=require('./sparse-combat-run.cjs');
const bridge={overflow:false,firstStack:'Error\n at wasm-function[1040] (wasm://wasm/id:0x123)',rows:[[1,'begin',8,100,100],[1,'begin',1,101,101],[1,'end',1,111,111],[1,'end',8,112,112]]};
const profile={startTime:1104000,nodes:[{id:1,callFrame:{functionName:'wasm-function[9978]'},children:[2]},{id:2,callFrame:{functionName:'wasm-function[767]'}}],samples:[2,2,2],timeDeltas:[1000,2000,2000]};
const requests=[{label:'start',marker:'one',beforeMs:100,afterMs:100.2},{label:'end',marker:'two',beforeMs:200,afterMs:200.2}];
const event=(message,ts)=>({name:'TimeStamp',pid:1,tid:2,ts,args:{data:{message}}});
const trace={traceEvents:[event('one',1100100),event('two',1200100)]};
const anchors=clockAnchors(trace,requests);assert(anchors.every(a=>a.upperMs-a.lowerMs<.201));
let negativeControls=0;
for(const mutate of [
 t=>t.traceEvents.pop(),t=>t.traceEvents.push(t.traceEvents[0]),t=>t.traceEvents[1].tid++,t=>t.traceEvents[0].ts=NaN,
]){const copy=structuredClone(trace);mutate(copy);assert.throws(()=>clockAnchors(copy,requests));negativeControls++}
assert.throws(()=>clockAnchors(trace,[requests[0],{...requests[1],afterMs:211}]));negativeControls++;
async function collect(mode){
 const out=fs.mkdtempSync(path.resolve('.tmp/sparse-clock-offline-'));let complete,detached=false,index=0,closed=0;
 const events=[];
 const cdp={once(name,fn){assert.equal(name,'Tracing.tracingComplete');complete=fn},async detach(){detached=true},async send(method,params){
  if(method==='Browser.getVersion')return {product:'offline-mock'};
  if(method==='Runtime.evaluate'){
   assert(params.expression.includes('const beforeMs=performance.now();console.timeStamp(')&&params.expression.includes('const afterMs=performance.now();'),'Same synchronous JS task brackets marker');
   const marker=JSON.parse(/console\.timeStamp\(("[^"]+")\)/.exec(params.expression)[1]);const beforeMs=index++?200:100,afterMs=beforeMs+.2;
   events.push(event(marker,(beforeMs+1000.1)*1000));return {result:{value:{beforeMs,afterMs}}};
  }
  if(method==='Profiler.stop')return {profile:{...profile,startTime:1100000,endTime:1201000,timeDeltas:[5000,2000,2000]}};
  if(method==='Tracing.end'){complete({stream:'clock-test',dataLossOccurred:mode==='data-loss'});return {}}
  if(method==='IO.read'){
   if(mode==='read-failure')throw Error('offline IO failure');
   const rows=mode==='missing-marker'?events.slice(0,1):events;
   return {data:JSON.stringify({traceEvents:rows}),eof:true};
  }
  if(method==='IO.close'){closed++;return {}}
  return {};
 }};
 const target={context:()=>({newCDPSession:async()=>cdp}),evaluate:async()=>bridge,addInitScript:async()=>{}};
 const collector=create(out);await collector.install(target);await collector.start(target);await collector.mark('held-input-start');await collector.mark('held-input-end');
 if(mode==='valid'){
  await collector.stop('offline-complete');assert.equal(collector.metadata.status,'COLLECTED');assert.equal(collector.metadata.attribution.assigned9978Us,4000);assert.equal(collector.metadata.trace,true);assert.equal(collector.metadata.traceCategories,'devtools.timeline');
 }else{
  await assert.rejects(collector.stop('offline-complete'));assert.equal(collector.metadata.status,'FAILED');assert(fs.existsSync(path.join(out,'drive.cpuprofile')),'Retain raw CPU profile on later diagnostic failure');
  await assert.rejects(collector.stop('runner-finally'),'Repeated stop retains original failure');
 }
 assert(detached,'Always detach');assert.equal(closed,1,'Always close trace stream');
 assert.equal(JSON.parse(fs.readFileSync(path.join(out,'sparse-cpu.json'))).status,collector.metadata.status);
 return {mode,out,status:collector.metadata.status};
}
async function generatedFinalization(missingSync=false){
 const source=runnerSource(),start=source.indexOf("if(diagnostic)try{await bounded(diagnostic.stop('capture-complete')"),end=source.indexOf(" }catch(error){report.status='FAIL';"),finallyStart=source.indexOf(' finally{if(diagnostic)'),finallyEnd=source.indexOf('\n return report;');
 assert(start>=0&&end>start&&finallyStart>end&&finallyEnd>finallyStart);
 const completion=source.slice(start,end),finalization=source.slice(finallyStart,finallyEnd),writes=[],screens=[],calls={stop:0,persist:0,analyze:0};
 const context={assert,path,out:'offline-output',report:{status:'RUNNING'},state:{mode:'hangar',loading:false},result:{markerCount:2},diagnostic:{async stop(){calls.stop++;throw Error('Clock alignment uncertainty exceeds 10ms')}},
  bounded:async promise=>promise,persist:()=>calls.persist++,global:{__voxSparseAnalyze(){calls.analyze++;return {status:'PASS_ATTRIBUTION_ONLY'}}},fs:{readFileSync:()=>{if(missingSync)throw Error('Missing diagnostic sync artifact');return JSON.stringify({rows:[1,2]})},writeFileSync:p=>writes.push(p)},
  page:{locator:()=>({screenshot:async({path:p})=>screens.push(p)}),keyboard:{press:async()=>{}}},click:async()=>{},wait:async()=>{},browser:{close:async()=>{}},sleep:async()=>{},process:{removeListener(){}},sigint(){},sigterm(){},console:{log(){}},Date,Promise};
 const returned=await vm.runInNewContext('(async()=>{try{'+completion+'}'+finalization+'return report})()',context);
 assert.equal(returned.status,'FAIL','Diagnostic failure remains overall FAIL');assert.equal(returned.gameplayStatus,'PASS');assert.equal(returned.diagnosticStatus,'FAILED');assert(returned.cdpFailure.includes('Clock alignment'));if(missingSync)assert(returned.syncFailure.includes('Missing diagnostic sync'));
 assert.equal(calls.analyze,1,'Actual generated runner still analyzes retained gameplay capture');assert(writes.some(p=>p.endsWith('analysis.json')));assert.equal(screens.length,2,'Actual generated runner reaches after-combat and returned screenshots');
 assert.equal(returned.returned.mode,'hangar');assert.equal(returned.shutdown,'CLOSED');assert.equal(calls.stop,2);assert(calls.persist>=2);return {status:returned.status,missingSync,analysisRetained:true,publicReturnPathExecuted:true,screenshots:screens.length,diagnosticFailureRetained:true};
}
(async()=>{
 const collectors=[];for(const mode of ['valid','missing-marker','data-loss','read-failure'])collectors.push(await collect(mode));
 const finalization=[await generatedFinalization(),await generatedFinalization(true)];console.log(JSON.stringify({status:'PASS',negativeControls,collectors,generatedRunnerFinalization:finalization,boundary:'Offline mocked CDP and execution of exact generated runner completion/finally blocks. No browser, Runtime, real clock mapping or performance acceptance.'},null,2));
})().catch(error=>{console.error(error.stack);process.exitCode=1});

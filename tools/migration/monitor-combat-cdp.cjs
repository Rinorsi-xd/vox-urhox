'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const CATEGORIES='devtools.timeline,disabled-by-default-devtools.timeline,v8,disabled-by-default-v8.gc,disabled-by-default-v8.wasm,blink,cc,gpu,viz,toplevel,renderer.scheduler,disabled-by-default-devtools.timeline.frame,disabled-by-default-gpu.service';
const BOUNDARY='Opt-in CDP sampling and browser trace with original controlled eight-car gameplay/monitor. CPU samples are statistical JS/WASM stacks, not exact Lua function costs. V8 GC does not observe Lua GC inside WASM. Trace duration includes waits; missing categories/tdur/symbols are unavailable evidence, not zero cost. No GL interception, JS monkey patches, forced collection, added Lua wrappers or optimization/FPS/device acceptance.';
function create(out){
 let cdp=null,tracing=false,profiling=false,completion=null,stopping=null,consoleListener=null;
 const toolHashes=Object.fromEntries(['monitor-combat-cdp.cjs','monitor-combat-run.cjs','monitor-combat-trace-run.cjs','analyze-monitor-combat-trace.cjs','analyze-combat-cdp.cjs'].map(name=>[name,crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,name))).digest('hex')]));
 const metadata={status:'NOT_STARTED',boundary:BOUNDARY,categories:CATEGORIES,samplingIntervalUs:1000,clockAnchors:[],consoleRows:0,toolHashes};
 const file=name=>path.join(out,name);
 const now=()=>Number(process.hrtime.bigint()/1000000n);
 const write=()=>fs.writeFileSync(file('cdp-capture.json'),JSON.stringify(metadata,null,2)+'\n');
 async function send(method,params){let timer;try{return await Promise.race([cdp.send(method,params),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('CDP request timeout '+method)),10000)})])}finally{clearTimeout(timer)}}
 async function mark(label){
  assert(cdp&&tracing,'Active trace required');
  const hostBeforeMs=now(),wallBeforeMs=Date.now();
  const result=await send('Performance.getMetrics');const timestamp=result.metrics.find(x=>x.name==='Timestamp')?.value;
  const hostAfterMs=now(),wallAfterMs=Date.now();assert(Number.isFinite(timestamp),'Actual Chrome monotonic Timestamp');
  const syncId='vox-combat-'+label+'-'+hostBeforeMs;await send('Tracing.recordClockSyncMarker',{syncId});
  metadata.clockAnchors.push({label,syncId,hostBeforeMs,hostAfterMs,wallBeforeMs,wallAfterMs,cdpMonotonicSeconds:timestamp});write();
 }
 async function start(page){
  assert.equal(metadata.status,'NOT_STARTED');assert(fs.existsSync(out));metadata.status='STARTING';write();
  fs.writeFileSync(file('console-timeline.jsonl'),'',{flag:'wx'});
  cdp=await page.context().newCDPSession(page);
  metadata.browser=await send('Browser.getVersion');
  metadata.availableCategories=(await send('Tracing.getCategories')).categories;
  metadata.requestedCategoriesAbsentFromInventory=CATEGORIES.split(',').filter(x=>!metadata.availableCategories.includes(x));
  await send('Runtime.enable');await send('Performance.enable');await send('Profiler.enable');
  consoleListener=event=>{
   if(!tracing)return;
   const text=(event.args||[]).map(x=>x.value??x.description??'').join(' ');
   if(!/VOX_PERF |MONITOR_COMBAT_STARTED |Succeed to compile shader|ERROR:|Aborted\(/.test(text))return;
   const row={hostReceivedMonotonicMs:now(),hostReceivedWallMs:Date.now(),cdpEpochMs:event.timestamp,executionContextId:event.executionContextId,type:event.type,text};
   fs.appendFileSync(file('console-timeline.jsonl'),JSON.stringify(row)+'\n');metadata.consoleRows++;
  };
  cdp.on('Runtime.consoleAPICalled',consoleListener);
  completion=new Promise(resolve=>cdp.once('Tracing.tracingComplete',resolve));
  await send('Tracing.start',{categories:CATEGORIES,options:'record-as-much-as-possible',transferMode:'ReturnAsStream'});tracing=true;
  await send('Profiler.setSamplingInterval',{interval:1000});await send('Profiler.start');profiling=true;
  await mark('trace-start');metadata.status='RECORDING';write();
 }
 async function stop(reason){
  if(stopping)return stopping;
  if(!cdp)return;
  stopping=(async()=>{
   metadata.stopReason=reason;let failure;
   try{
    if(tracing)await mark('trace-stop');
    if(profiling){const result=await send('Profiler.stop');profiling=false;fs.writeFileSync(file('drive.cpuprofile'),JSON.stringify(result.profile))}
    if(tracing){
     await send('Tracing.end');tracing=false;
     let timer;const finished=await Promise.race([completion,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('CDP trace completion timeout')),30000)})]).finally(()=>clearTimeout(timer));
     assert(finished.stream,'Actual Chrome trace stream');metadata.traceDataLoss=finished.dataLossOccurred??null;
     const descriptor=fs.openSync(file('drive.trace.json'),'wx');let bytes=0;
     try{for(;;){const chunk=await send('IO.read',{handle:finished.stream,size:1024*1024});const data=chunk.base64Encoded?Buffer.from(chunk.data,'base64'):Buffer.from(chunk.data);bytes+=data.length;assert(bytes<=256*1024*1024,'Diagnostic trace exceeds 256MiB bound');fs.writeSync(descriptor,data);if(chunk.eof)break}}
     finally{fs.closeSync(descriptor);await send('IO.close',{handle:finished.stream})}
     metadata.traceBytes=bytes;
    }
    assert(metadata.traceDataLoss!==true,'Chrome reported trace data loss');
    const profile=JSON.parse(fs.readFileSync(file('drive.cpuprofile'),'utf8')),trace=JSON.parse(fs.readFileSync(file('drive.trace.json'),'utf8'));
    const sync=(trace.traceEvents||[]).filter(e=>e.name==='clock_sync');
    metadata.traceClockSyncMarkers=metadata.clockAnchors.map(anchor=>{
     const matches=sync.filter(e=>e.args?.sync_id===anchor.syncId);assert.equal(matches.length,1,'Actual unique trace clock marker '+anchor.syncId);
     return {label:anchor.label,syncId:anchor.syncId,traceUs:matches[0].ts};
    });metadata.clockSyncVerified=true;
    const summary=require('./analyze-combat-cdp.cjs').analyze(profile,trace);fs.writeFileSync(file('cdp-summary.json'),JSON.stringify(summary,null,2)+'\n');
    metadata.status='COLLECTED';
   }catch(error){failure=error;metadata.status='FAILED';metadata.error=error.stack}
   finally{
    if(profiling)try{await send('Profiler.stop')}catch{}profiling=false;
    if(tracing)try{await send('Tracing.end')}catch{}tracing=false;
    if(consoleListener)cdp.off('Runtime.consoleAPICalled',consoleListener);
    try{await cdp.detach();metadata.detached=true}catch(error){metadata.detached=false;metadata.detachError=error.message;failure??=error}
    write();
   }
   if(failure)throw failure;
  })();return stopping;
 }
 return {metadata,start,mark,stop};
}
module.exports={create,CATEGORIES,BOUNDARY};

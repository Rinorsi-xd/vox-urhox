'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
function installBridge(){
 const rows=[];let firstStack=null,overflow=false;
 Object.defineProperty(globalThis,'__voxSparseSync',{value:{rows,get firstStack(){return firstStack},get overflow(){return overflow}},configurable:false});
 function record(args){
  const text=args.map(x=>typeof x==='string'?x:'').join(' '),match=/VOX_SPARSE_SYNC (\d+) (begin|end|error) (\d+) (\d+)/.exec(text);
  if(match){
   if(rows.length>=20000)overflow=true;
   else{
    const at=performance.now();
    if(firstStack===null){const previous=Error.stackTraceLimit;Error.stackTraceLimit=60;firstStack=new Error('synchronous marker origin').stack;Error.stackTraceLimit=previous;}
    rows.push([+match[1],match[2],+match[3],+match[4],at]);
   }
  }
 }
 for(const level of ['log','info','debug','warn','error']){
  const original=console[level];if(typeof original!=='function')continue;
  console[level]=function(...args){record(args);return original.apply(this,args);};
 }
}
function intervals(bridge){
 assert(!bridge.overflow,'Marker bridge overflow');assert.match(bridge.firstStack||'',/wasm-function\[\d+\]|wasm:\/\//,'Markers must synchronously originate on WASM stack');
 const stack=[],out=[];let serial=0,last=-Infinity;
 for(const row of bridge.rows){
  assert(row.length===5&&row.every((x,i)=>i===1||Number.isFinite(x)),'Complete marker row');
  const [id,kind,owner,lua,at]=row;assert(Number.isInteger(id)&&id>0&&id>=serial&&id<=serial+1,'Serial marker order');serial=id;
  assert(at>=last,'Monotonic JS marker clock');last=at;assert(owner>=1&&owner<=8);
  if(kind==='begin')stack.push({id,owner,lua,at,depth:stack.length});
  else{
   assert.equal(kind,'end','Errors in actual sampled code fail capture');const start=stack.pop();
   assert(start&&start.id===id&&start.owner===owner,'Strict synchronous nested marker pairing');
   const luaMs=(lua-start.lua)>>>0,jsMs=at-start.at;
   assert(Math.abs(jsMs-luaMs)<=5,'Buffered/mismatched logger clocks; semantic assignment rejected');
   out.push({serial:id,owner,depth:start.depth,startMs:start.at,endMs:at,luaMs,jsMs});
  }
 }
 assert.equal(stack.length,0,'Complete marker stack');assert(out.length>0,'Real semantic markers required');return out;
}
function attribute(profile,bridge,anchors){
 const spans=intervals(bridge);assert.equal(anchors.length,2,'Two independent Chrome clock brackets required');
 for(const a of anchors){assert(a.upperMs>=a.lowerMs&&a.upperMs-a.lowerMs<=10,'Clock alignment uncertainty exceeds 10ms');}
 const lower=Math.max(...anchors.map(a=>a.lowerMs)),upper=Math.min(...anchors.map(a=>a.upperMs));assert(lower<=upper,'Chrome clock offset drift / disjoint anchor brackets');
 const offset=(lower+upper)/2,uncertainty=(upper-lower)/2;
 const nodes=new Map(profile.nodes.map(n=>[n.id,n])),parents=new Map();for(const n of profile.nodes)for(const child of n.children||[])parents.set(child,n.id);
 assert.equal(profile.samples.length,profile.timeDeltas.length);
 const under9978=id=>{for(let depth=0;id!==undefined&&depth<500;depth++,id=parents.get(id)){if(/wasm-function\[9978\](?:$|:)/.test(nodes.get(id)?.callFrame?.functionName||''))return true;}return false;};
 let t=profile.startTime,total9978Us=0,assigned9978Us=0,ambiguous9978Us=0;const owners={};
 for(let i=0;i<profile.samples.length;i++){
  t+=profile.timeDeltas[i];if(!under9978(profile.samples[i]))continue;
  total9978Us+=profile.timeDeltas[i];const at=t/1000-offset;
  const from=at-profile.timeDeltas[i]/1000;
  const candidates=spans.filter(s=>from-uncertainty>s.startMs&&at+uncertainty<s.endMs).sort((a,b)=>b.depth-a.depth);
  if(!candidates.length){if(spans.some(s=>at+uncertainty>=s.startMs&&at-uncertainty<=s.endMs))ambiguous9978Us+=profile.timeDeltas[i];continue;}
  const owner=candidates[0].owner;owners[owner]=(owners[owner]||0)+profile.timeDeltas[i];assigned9978Us+=profile.timeDeltas[i];
 }
 assert(total9978Us>0,'Actual WASM 9978 stack samples required');
 assert(assigned9978Us>0,'No unambiguous 9978 samples inside real semantic spans; reject clock/coverage result');
 return {status:'ATTRIBUTED',offsetMs:offset,uncertaintyMs:uncertainty,spans:spans.length,total9978Us,assigned9978Us,ambiguous9978Us,owner9978StatisticalUs:owners,
  unassigned9978Us:total9978Us-assigned9978Us-ambiguous9978Us,
  boundary:'CPU samples assigned only inside complete synchronous semantic spans after both clock brackets agree; uncertain boundaries excluded. 9978 remains an unsymbolized WASM index. Statistical sample weight is not exact call time, allocation bytes, Lua GC proof or recoverable FPS.'};
}
function clockAnchors(trace,requests){
 assert.equal(requests.length,2,'Two synchronous JS clock requests required');
 const markers=(trace.traceEvents||[]).filter(e=>e.name==='TimeStamp');
 let thread;
 return requests.map(request=>{
  assert([request.beforeMs,request.afterMs].every(Number.isFinite)&&request.afterMs>=request.beforeMs,'Finite monotonic same-task JS bracket');
  const matching=markers.filter(e=>(e.args?.data?.message??e.args?.data?.name)===request.marker);
  assert.equal(matching.length,1,'Exactly one actual console.timeStamp trace marker '+request.marker);
  const event=matching[0];assert(Number.isFinite(event.ts)&&Number.isInteger(event.pid)&&Number.isInteger(event.tid),'Actual Chrome trace timestamp/thread');
  const current=event.pid+':'+event.tid;if(thread===undefined)thread=current;else assert.equal(current,thread,'Both markers originate on the same renderer thread');
  const anchor={label:request.label,marker:request.marker,traceUs:event.ts,jsBeforeMs:request.beforeMs,jsAfterMs:request.afterMs,
   lowerMs:event.ts/1000-request.afterMs,upperMs:event.ts/1000-request.beforeMs,pid:event.pid,tid:event.tid};
  assert(anchor.upperMs-anchor.lowerMs<=10,'Clock alignment uncertainty exceeds 10ms');return anchor;
 });
}
function create(out){
 let page,cdp,profiling=false,tracing=false,completion,stopping=null;
 const metadata={status:'NOT_STARTED',samplingIntervalUs:1000,trace:true,traceCategories:'devtools.timeline',clockRequests:[],clockAnchors:[],
  clockMethod:'Same Runtime.evaluate task brackets synchronous console.timeStamp with performance.now; actual trace timestamp maps CPU profiler monotonic microseconds to JS milliseconds. Two unique same-thread markers and <=10ms intersecting brackets required.',
  boundary:'Sparse attribution, not FPS benefit A/B. CDP CPU profiling plus devtools.timeline trace for clock markers adds diagnostic overhead; no rendering categories, V8 trace categories, exact Lua call timing or mobile performance acceptance.'};
 const file=n=>path.join(out,n),persist=()=>fs.writeFileSync(file('sparse-cpu.json'),JSON.stringify(metadata,null,2)+'\n');
 async function send(method,params){let timer;try{return await Promise.race([cdp.send(method,params),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('CDP timeout '+method)),10000))])}finally{clearTimeout(timer)}}
 async function mark(label){
  assert(tracing&&profiling,'Active trace/profile required');assert(metadata.clockRequests.length<2,'Exactly two input boundary clock requests');
  const marker='vox-sparse-clock-'+metadata.clockRequests.length+'-'+label;
  const expression='(()=>{const beforeMs=performance.now();console.timeStamp('+JSON.stringify(marker)+');const afterMs=performance.now();return {beforeMs,afterMs}})()';
  const js=await send('Runtime.evaluate',{expression,returnByValue:true});assert(!js.exceptionDetails,'Clock evaluation must complete');
  const value=js.result.value;assert([value.beforeMs,value.afterMs].every(Number.isFinite));
  metadata.clockRequests.push({label,marker,...value});persist();
 }
 return {metadata,
  async install(target){await target.addInitScript(installBridge);},
  async start(target){
   assert.equal(metadata.status,'NOT_STARTED');page=target;cdp=await page.context().newCDPSession(page);
   await send('Runtime.enable');await send('Profiler.enable');
   metadata.browser=await send('Browser.getVersion');await send('Profiler.setSamplingInterval',{interval:1000});
   completion=new Promise(resolve=>cdp.once('Tracing.tracingComplete',resolve));
   await send('Tracing.start',{categories:metadata.traceCategories,options:'record-as-much-as-possible',transferMode:'ReturnAsStream'});tracing=true;
   await send('Profiler.start');profiling=true;metadata.status='RECORDING';persist();
  },
  // The existing runner calls this exactly at held-input-start/end.
  mark,
  async stop(reason){
   if(stopping)return stopping;if(!cdp)return;
   stopping=(async()=>{let failure;
    try{
     if(profiling){const {profile}=await send('Profiler.stop');profiling=false;fs.writeFileSync(file('drive.cpuprofile'),JSON.stringify(profile));}
     const data=await page.evaluate(()=>({rows:globalThis.__voxSparseSync?.rows,firstStack:globalThis.__voxSparseSync?.firstStack,overflow:globalThis.__voxSparseSync?.overflow}));
     fs.writeFileSync(file('sparse-sync.json'),JSON.stringify(data));
     if(tracing){
      await send('Tracing.end');tracing=false;
      let timer;const finished=await Promise.race([completion,new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('CDP clock trace completion timeout')),15000))]).finally(()=>clearTimeout(timer));
      assert(finished.stream,'Actual Chrome clock trace stream');metadata.traceDataLoss=finished.dataLossOccurred??null;
      const descriptor=fs.openSync(file('sparse-clock.trace.json'),'wx');let bytes=0;
      try{for(;;){const chunk=await send('IO.read',{handle:finished.stream,size:1024*1024});const data=chunk.base64Encoded?Buffer.from(chunk.data,'base64'):Buffer.from(chunk.data);bytes+=data.length;assert(bytes<=64*1024*1024,'Clock trace exceeds 64MiB bound');fs.writeSync(descriptor,data);if(chunk.eof)break}}
      finally{fs.closeSync(descriptor);await send('IO.close',{handle:finished.stream})}
      metadata.traceBytes=bytes;assert(metadata.traceDataLoss!==true,'Chrome reported clock trace data loss');
     }
     const profile=JSON.parse(fs.readFileSync(file('drive.cpuprofile')));
     const trace=JSON.parse(fs.readFileSync(file('sparse-clock.trace.json')));metadata.clockAnchors=clockAnchors(trace,metadata.clockRequests);
     assert([profile.startTime,profile.endTime].every(Number.isFinite)&&profile.endTime>=profile.startTime,'Actual CPU profile monotonic bounds');
     assert(metadata.clockAnchors.every(a=>a.traceUs>=profile.startTime&&a.traceUs<=profile.endTime),'Both trace markers lie within actual CPU profile monotonic bounds');
     metadata.attribution=attribute(profile,data,metadata.clockAnchors);metadata.status='COLLECTED';
     fs.writeFileSync(file('sparse-cpu-attribution.json'),JSON.stringify(metadata.attribution,null,2)+'\n');
    }catch(e){metadata.status='FAILED';metadata.error=e.stack;failure=e;}
    finally{if(profiling)try{await send('Profiler.stop')}catch{}profiling=false;if(tracing)try{await send('Tracing.end')}catch{}tracing=false;try{await cdp.detach();metadata.detached=true}catch(e){failure??=e;}metadata.stopReason=reason;persist();}
    if(failure)throw failure;
   })();return stopping;
  }
 };
}
module.exports={create,installBridge,intervals,attribute,clockAnchors};

'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const BOUNDARY=require('./monitor-combat-cdp.cjs').BOUNDARY;
function unionMs(intervals){
 const sorted=intervals.filter(([a,b])=>Number.isFinite(a)&&Number.isFinite(b)&&b>=a).sort((a,b)=>a[0]-b[0]);
 let total=0,start=null,end=null;for(const [a,b]of sorted){if(start===null){start=a;end=b}else if(a<=end)end=Math.max(end,b);else{total+=end-start;start=a;end=b}}if(start!==null)total+=end-start;return total/1000;
}
function completeEvents(trace){
 const raw=Array.isArray(trace)?trace:trace.traceEvents;assert(Array.isArray(raw));const complete=[],stacks=new Map();
 for(const event of raw){
  if(event.ph==='X'&&Number.isFinite(event.ts)&&Number.isFinite(event.dur)&&event.dur>=0)complete.push(event);
  else if(event.ph==='B'){const key=event.pid+':'+event.tid,stack=stacks.get(key)||[];stack.push(event);stacks.set(key,stack)}
  else if(event.ph==='E'){const begin=stacks.get(event.pid+':'+event.tid)?.pop();if(begin&&event.ts>=begin.ts)complete.push({...begin,ph:'X',dur:event.ts-begin.ts,...(Number.isFinite(event.tts)&&Number.isFinite(begin.tts)?{tdur:event.tts-begin.tts}:{})})}
 }
 return {raw,complete,unclosed:[...stacks.values()].reduce((n,s)=>n+s.length,0)};
}
function analyze(metadata,profile,trace,consoleRows){
 assert.equal(metadata.status,'COLLECTED');assert.equal(metadata.traceDataLoss===true,false);
 assert.equal(metadata.clockSyncVerified,true,'Recorded unique Chrome clock markers verified');
 const start=metadata.clockAnchors.find(x=>x.label==='held-input-start'),end=metadata.clockAnchors.find(x=>x.label==='held-input-end');
 assert(start&&end&&end.cdpMonotonicSeconds>start.cdpMonotonicSeconds,'Actual ordered held-input anchors');
 const from=start.cdpMonotonicSeconds*1e6,to=end.cdpMonotonicSeconds*1e6;
 const {raw,complete,unclosed}=completeEvents(trace);
 const loops=complete.filter(e=>e.name==='FunctionCall'&&e.args?.data?.functionName==='MainLoop_runner').sort((a,b)=>a.ts-b.ts);
 const owners=new Set(loops.map(e=>e.pid+':'+e.tid));assert(owners.size<=1,'Ambiguous runtime main thread');
 const inside=loops.filter(e=>e.ts>=from&&e.ts+e.dur<=to);
 const thread=inside[0]&&{pid:inside[0].pid,tid:inside[0].tid};
 const main=thread?complete.filter(e=>e.pid===thread.pid&&e.tid===thread.tid&&e.ts<to&&e.ts+e.dur>from):[];
 const threads=raw.filter(e=>e.ph==='M'&&e.name==='thread_name').map(e=>({pid:e.pid,tid:e.tid,name:e.args?.name}));
 const summarize=e=>({name:e.name,category:e.cat,pid:e.pid,tid:e.tid,startUs:e.ts,wallMs:e.dur/1000,
  ...(Number.isFinite(e.tdur)?{threadCpuMs:e.tdur/1000,offCpuMs:(e.dur-e.tdur)/1000}:{threadCpuUnavailable:true}),args:e.args});
 const classify=(pattern,events=main)=>{
  const matches=events.filter(e=>pattern.test(e.name)),clipped=matches.map(e=>[Math.max(from,e.ts),Math.min(to,e.ts+e.dur)]);
  return {events:matches.length,unionWallMs:unionMs(clipped),largest:matches.sort((a,b)=>b.dur-a.dur).slice(0,20).map(summarize),
   unavailableIfEmpty:matches.length===0,boundary:'Union avoids double-counting nested matching spans. This records named wall events, not exact CPU time or GPU hardware execution.'};
 };
 const gc=classify(/^(?:MinorGC|MajorGC|V8\.GC|GCScavenger|GCCompactor)/i);
 const gl=classify(/(?:WebGL|GetProgramiv|GetShaderiv|CompileShader|LinkProgram|getProgramParameter|getShaderParameter|WaitForToken|WaitForGetOffset|GpuChannel|GLES2|SyncToken)/i);
 const wasm=classify(/wasm/i);
 const low=Math.max(...metadata.clockAnchors.map(c=>c.wallBeforeMs-c.cdpMonotonicSeconds*1000-1));
 const high=Math.min(...metadata.clockAnchors.map(c=>c.wallAfterMs-c.cdpMonotonicSeconds*1000+1));
 const consistent=Number.isFinite(low)&&Number.isFinite(high)&&low<=high&&high-low<=5;
 const emissionAnchors=[],rejected=[];
 for(const row of consoleRows){
  const at=row.text.indexOf('VOX_PERF ');if(at<0)continue;
  let record;try{record=JSON.parse(row.text.slice(at+9))}catch{continue}
  if(record.type!=='slow_frame'||record.frameMs<=80||record.context?.mode!=='trial'||record.context?.sceneIsTrial!==true)continue;
  if(!consistent){rejected.push({monitorFrame:record.frame,reason:'Epoch/trace clock unavailable or uncertainty >5ms'});continue}
  const a=(row.cdpEpochMs-high)*1000,b=(row.cdpEpochMs-low)*1000;
  const possible=loops.filter(e=>e.ts<=b&&e.ts+e.dur>=a),certain=possible.filter(e=>e.ts<=a&&e.ts+e.dur>=b);
  if(possible.length!==1||certain.length!==1){rejected.push({monitorFrame:record.frame,reason:'Console timestamp not certainly contained in one MainLoop',possible:possible.length});continue}
  const loop=certain[0];
  if(loop.ts<from||loop.ts+loop.dur>to){rejected.push({monitorFrame:record.frame,reason:'Emission callback outside complete CDP input window'});continue}
  emissionAnchors.push({monitorFrame:record.frame,reportedPreviousIntervalMs:record.frameMs,reportedPreviousScriptMs:record.scriptMs,
   emissionLoop:summarize(loop),consoleTraceRangeUs:[a,b],
   boundary:'Production Finalize emits this record in the NEXT BeginFrame. This anchors only its emission callback, never assigns this MainLoop CPU/GC/GL to the reported previous frame. No intervening frames inferred.'});
 }
 const cpu=require('./analyze-combat-cdp.cjs').cpuSummary(profile);
 const loopRows=inside.map(summarize),withCpu=loopRows.filter(e=>Number.isFinite(e.threadCpuMs));
 for(const row of withCpu)assert(row.threadCpuMs>=0&&row.threadCpuMs<=row.wallMs+1,'Bounded recorded thread CPU');
 const mean=(rows,key)=>rows.length?rows.reduce((n,r)=>n+r[key],0)/rows.length:null;
 return {status:'TRACE_ANALYZED_WITH_EXPLICIT_LIMITS',boundary:BOUNDARY,windowUs:[from,to],thread,threads,
  coverage:{mainLoops:inside.length,mainLoopsWithThreadCpu:withCpu.length,unclosedBeginEvents:unclosed,
   traceDataLoss:metadata.traceDataLoss,clockConsistent:consistent,epochMinusTraceMs:[low,high],clockUncertaintyMs:high-low,
   requestedCategoriesAbsentFromInventory:metadata.requestedCategoriesAbsentFromInventory},
  mainLoop:{meanWallMs:mean(loopRows,'wallMs'),meanRecordedThreadCpuMs:mean(withCpu,'threadCpuMs'),meanOffCpuMs:mean(withCpu,'offCpuMs'),
   over80:loopRows.filter(e=>e.wallMs>80),longest:[...loopRows].sort((a,b)=>b.wallMs-a.wallMs).slice(0,30),
   boundary:'Independent traced callback windows wholly between CDP input-request markers; they differ from production Update-to-Update frame intervals. OffCPU is wall minus recorded thread CPU, never a GPU measurement.'},
  mainThreadV8Gc:gc,mainThreadGlQueriesAndWaits:gl,mainThreadWasmEvents:wasm,
  mainThreadLongEvents:main.filter(e=>e.dur>=20000).sort((a,b)=>b.dur-a.dur).slice(0,80).map(summarize),
  cpu:{...cpu,windowBoundary:'Whole CDP profile, including marker/start/stop and post-capture transport. Statistical weights must not be mixed with exact held-window MainLoop CPU or Lua frame durations.'},statisticalWasmNodes:cpu.top.filter(x=>/wasm/i.test(x.name+' '+x.url)),
  luaGcUnresolved:true,emissionAnchors,rejectedEmissionAnchors:rejected,
  requiredNextEvidence:inside.length===0?'No recognizable MainLoop callback; inspect raw event inventory before any CPU-vs-wall claim.':
   withCpu.length===0?'Trace lacks MainLoop thread CPU; wall spans alone cannot separate execution from waits.':
    'Inspect measured MainLoop CPU, actual named GC/GL spans and sampled WASM stacks. Unnamed WASM/Lua VM work needs engine symbols; V8 GC absence does not rule out Lua GC.'};
}
function run(directory){
 const read=name=>JSON.parse(fs.readFileSync(path.join(directory,name),'utf8'));
 const lines=fs.readFileSync(path.join(directory,'console-timeline.jsonl'),'utf8').trim().split(/\r?\n/).filter(Boolean).map(JSON.parse);
 const result=analyze(read('cdp-capture.json'),read('drive.cpuprofile'),read('drive.trace.json'),lines);
 fs.writeFileSync(path.join(directory,'combat-trace-attribution.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});return result;
}
module.exports={analyze,completeEvents,unionMs,run};
if(require.main===module){const result=run(path.resolve(process.argv[2]));console.log(JSON.stringify({status:result.status,coverage:result.coverage,mainLoop:result.mainLoop,mainThreadV8Gc:result.mainThreadV8Gc,requiredNextEvidence:result.requiredNextEvidence},null,2))}

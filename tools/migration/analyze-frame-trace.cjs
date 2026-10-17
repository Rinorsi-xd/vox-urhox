'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const BOUNDARY='Same-run coarse Lua callback wall scopes and Chrome MainLoop wall/thread CPU. Console epoch-to-trace conversion uses bounded CDP clock anchors. Only frames with a direct console timestamp certainly inside one MainLoop are paired; sparse anchor order never proves the intervening frames. Callback frame-wall and MainLoop boundaries differ; do not subtract or sum them. WASM indices are not Lua source names; no optimization gain or mobile FPS follows.';
function correlate(report,records,consoleRows,trace){
 assert.equal(report.frameTraceCorrelationRequested,true,'Explicit diagnostic correlation required');
 assert.equal(report.cdpCaptureRequested,true);assert.equal(report.framePipelineRequested,true);
 assert.equal(report.measurementResult,'PASS','Input coverage must pass before attribution');
 for(const row of records){
  assert.deepEqual(row.identity,report.framePipelineIdentity,'Exact report/probe/source capture identity');
  assert.equal(row.frame.epoch,report.framePipelineEpoch,'Exact report capture epoch');
 }
 const pipeline=require('./analyze-frame-pipeline.cjs').analyze(records);
 assert.deepEqual(pipeline.issues,[],'Valid frame callback accounting');
 const clocks=report.cdp.clockAnchors;
 assert.ok(clocks.length>=2,'Start and stop CDP clock anchors');
 // Date.now has integer resolution. Use an enclosing interval, never a point estimate.
 const low=Math.max(...clocks.map(c=>c.wallBeforeMs-c.cdpMonotonicSeconds*1000-1));
 const high=Math.min(...clocks.map(c=>c.wallAfterMs-c.cdpMonotonicSeconds*1000+1));
 assert.ok(Number.isFinite(low)&&Number.isFinite(high)&&low<=high,'Consistent epoch/trace clock bounds');
 assert.ok(high-low<=5,'Clock uncertainty at most 5ms');
 const events=Array.isArray(trace)?trace:trace.traceEvents;
 const loops=events.filter(e=>e.ph==='X'&&e.name==='FunctionCall'&&e.args?.data?.functionName==='MainLoop_runner').sort((a,b)=>a.ts-b.ts);
 assert.ok(loops.length>0,'Actual MainLoop trace events');
 const owners=new Set(loops.map(e=>e.pid+':'+e.tid));assert.equal(owners.size,1,'One runtime main thread');
 for(let i=1;i<loops.length;i++)assert.ok(loops[i].ts>=loops[i-1].ts+loops[i-1].dur,'Non-overlapping MainLoop events');
 const anchors=[],rejected=[];
 for(const row of consoleRows){
  const at=row.text.indexOf('OUTGAME_STATE ');if(at<0)continue;
  let state;try{state=JSON.parse(row.text.slice(at+14))}catch{continue}
  const frame=state.framePipeline?.currentFrame;
  if(!Number.isInteger(frame)||state.framePipeline.enabled!==true)continue;
  assert.deepEqual(state.framePipeline.identity,report.framePipelineIdentity,'Console anchor source identity');
  assert.equal(state.framePipeline.epoch,report.framePipelineEpoch,'Console anchor capture epoch');
  if(state.frame!==undefined)assert.equal(frame,state.frame,'Console observer reports the same engine frame');
  const beginUs=(row.cdpEpochMs-high)*1000,endUs=(row.cdpEpochMs-low)*1000;
  const possible=loops.map((loop,index)=>({loop,index})).filter(({loop})=>loop.ts<=endUs&&loop.ts+loop.dur>=beginUs);
  const certain=possible.filter(({loop})=>loop.ts<=beginUs&&loop.ts+loop.dur>=endUs);
  if(possible.length!==1||certain.length!==1){rejected.push({frame,reason:'Console timestamp not certainly inside exactly one MainLoop',possible:possible.length});continue}
  anchors.push({frame,loopIndex:certain[0].index,offset:frame-certain[0].index,consoleTraceRangeUs:[beginUs,endUs]});
 }
 assert.ok(new Set(anchors.map(a=>a.frame)).size>=3,'At least three independent engine-frame console anchors');
 assert.equal(new Set(anchors.map(a=>a.offset)).size,1,'All independent anchors agree on exact frame/loop order');
 const minFrame=Math.min(...anchors.map(a=>a.frame)),maxFrame=Math.max(...anchors.map(a=>a.frame));
 assert.ok(maxFrame-minFrame>=10,'Anchors span at least ten engine frames');
 const direct=new Map(anchors.map(a=>[a.frame,a.loopIndex]));
 const retained=records.filter(r=>r.frame.frame>report.framePipelineAnchorFrame&&r.frame.frame<=report.framePipelineSummary.throughFrame&&!r.frame.partialStart&&!r.frame.partialEnd);
 const paired=[],outside=[];
 for(const {frame:f}of retained){
  const index=direct.get(f.frame),loop=loops[index];
  if(!loop){outside.push(f.frame);continue}
  assert.ok(Number.isFinite(loop.tdur)&&loop.tdur>=0&&loop.tdur<=loop.dur+1000,'Thread CPU duration available and bounded');
  const nested=events.filter(e=>e.ph==='X'&&e.pid===loop.pid&&e.tid===loop.tid&&e.ts>=loop.ts&&e.ts+e.dur<=loop.ts+loop.dur);
  const selected=names=>nested.filter(e=>names.test(e.name)).sort((a,b)=>b.dur-a.dur).slice(0,3).map(e=>({name:e.name,wallMs:e.dur/1000,...(Number.isFinite(e.tdur)?{threadCpuMs:e.tdur/1000}:{})}));
  const update=f.scopes['main.Update']?.inclusiveMs||0;
  const fixed=['fixed.BeforeStep','fixed.WorldStep','fixed.AfterStep'].reduce((n,key)=>n+(f.scopes[key]?.inclusiveMs||0),0);
  paired.push({frame:f.frame,loopIndex:index,traceStartUs:loop.ts,mainLoopWallMs:loop.dur/1000,mainLoopThreadCpuMs:loop.tdur/1000,
   mainLoopOffCpuMs:(loop.dur-loop.tdur)/1000,pipelineWallMs:f.wallMs,updateWallMs:update,fixedWallMs:fixed,otherUpdateWallMs:update-fixed,
   steps:f.scopes['fixed.WorldStep']?.calls||0,scopes:f.scopes,
   glQueries:selected(/GetProgramiv|GetShaderiv/),v8Gc:selected(/^(?:MinorGC|MajorGC|V8\.GC)/)});
 }
 assert.ok(paired.length>=3,'At least three directly anchored measured frames');
 const mean=key=>paired.reduce((n,row)=>n+row[key],0)/paired.length;
 const hostClocks=clocks.map(c=>[c.cdpMonotonicSeconds*1000-c.hostAfterMs-1,c.cdpMonotonicSeconds*1000-c.hostBeforeMs]);
 const hostLow=Math.max(...hostClocks.map(c=>c[0])),hostHigh=Math.min(...hostClocks.map(c=>c[1]));
 assert.ok(Number.isFinite(hostLow)&&Number.isFinite(hostHigh)&&hostLow<=hostHigh,'Consistent host monotonic/trace clock bounds');
 const traceStart=(report.cdp.inputStartedHostMonotonicMs+hostHigh)*1000,traceEnd=(report.cdp.inputEndedHostMonotonicMs+hostLow)*1000;
 const inputLoops=loops.filter(e=>e.ts>=traceStart&&e.ts+e.dur<=traceEnd);
 assert.ok(inputLoops.length>=30,'At least thirty MainLoops entirely inside held-input clock bounds');
 const loopRows=inputLoops.map(e=>{
  assert.ok(Number.isFinite(e.tdur)&&e.tdur>=0&&e.tdur<=e.dur+1000,'Captured MainLoop thread CPU available');
  return {traceStartUs:e.ts,wallMs:e.dur/1000,threadCpuMs:e.tdur/1000,offCpuMs:(e.dur-e.tdur)/1000};
 });
 const allMean=key=>loopRows.reduce((n,row)=>n+row[key],0)/loopRows.length;
 return {boundary:BOUNDARY,clockBounds:{epochMinusTraceMs:[low,high],uncertaintyMs:high-low},anchors,rejectedAnchors:rejected,
  pairedFrames:paired.length,excludedUnanchoredFrames:outside,
  meanMainLoopWallMs:mean('mainLoopWallMs'),meanMainLoopThreadCpuMs:mean('mainLoopThreadCpuMs'),meanMainLoopOffCpuMs:mean('mainLoopOffCpuMs'),
  over50:paired.filter(row=>row.mainLoopWallMs>50),longest:[...paired].sort((a,b)=>b.mainLoopWallMs-a.mainLoopWallMs).slice(0,20),frames:paired,
  allInputMainLoops:{boundary:'Independent MainLoop trace events within held input, including unanchored loops. No engine-frame or Lua owner is assigned to these rows.',count:loopRows.length,
   meanWallMs:allMean('wallMs'),meanThreadCpuMs:allMean('threadCpuMs'),meanOffCpuMs:allMean('offCpuMs'),over50:loopRows.filter(e=>e.wallMs>50),longest:[...loopRows].sort((a,b)=>b.wallMs-a.wallMs).slice(0,20)}};
}
function selfTest(){
 const identity={mainSha256:'main',probeSha256:'probe'},records=[],events=[],consoleRows=[];
 for(let i=0;i<50;i++){
  const scopes=Object.fromEntries(['main.Update','main.PostUpdate','main.FramePresented','ui.Update','ui.Render'].map(name=>[name,{calls:1,inclusiveMs:1,selfMs:1,maxMs:1,errors:0}]));
  const times=Object.keys(scopes).flatMap((name,j)=>[[name,'enter',j],[name,'leave',j+1]]);
  records.push({identity,frame:{frame:i+100,epoch:1,startWall:i*20,wallMs:20,measuredWallMs:5,unscopedWallMs:15,events:times,scopes,framePresentedCalls:1}});
  events.push({ph:'X',name:'FunctionCall',args:{data:{functionName:'MainLoop_runner'}},pid:1,tid:2,ts:i*20000,dur:18000,tdur:16000});
  if([5,25,45].includes(i))consoleRows.push({cdpEpochMs:100000+i*20+8,text:'OUTGAME_STATE '+JSON.stringify({frame:i+100,framePipeline:{enabled:true,currentFrame:i+100,identity,epoch:1}})});
 }
 const report={frameTraceCorrelationRequested:true,cdpCaptureRequested:true,framePipelineRequested:true,measurementResult:'PASS',framePipelineIdentity:identity,framePipelineEpoch:1,framePipelineAnchorFrame:99,framePipelineSummary:{throughFrame:149},cdp:{inputStartedHostMonotonicMs:0,inputEndedHostMonotonicMs:1000,clockAnchors:[{wallBeforeMs:100000,wallAfterMs:100000,hostBeforeMs:0,hostAfterMs:0,cdpMonotonicSeconds:0},{wallBeforeMs:101000,wallAfterMs:101000,hostBeforeMs:1000,hostAfterMs:1000,cdpMonotonicSeconds:1}]}};
 const run=(r=report,c=consoleRows,t=events)=>correlate(r,records,c,{traceEvents:t});
 const result=run();assert.equal(result.pairedFrames,3);assert.equal(result.meanMainLoopThreadCpuMs,16);assert.equal(result.meanMainLoopOffCpuMs,2);assert.equal(result.allInputMainLoops.count,50);
 const hidden=structuredClone(events);hidden.splice(11,1,{...hidden[11],ts:218000,dur:1000,tdur:500});
 assert.ok(!run(report,consoleRows,hidden).frames.some(f=>f.frame===111),'Never infer intervening frame from sparse anchor order');
 assert.throws(()=>run({...report,frameTraceCorrelationRequested:false}),/Explicit/);
 assert.throws(()=>run(report,consoleRows.slice(0,2)),/three independent/);
 const wrong=structuredClone(consoleRows),state=JSON.parse(wrong[1].text.slice(14));state.frame++;state.framePipeline.currentFrame++;wrong[1].text='OUTGAME_STATE '+JSON.stringify(state);
 assert.throws(()=>run(report,wrong),/exact frame\/loop order/);
 assert.throws(()=>run(report,consoleRows,events.map(e=>({...e,tdur:undefined}))),/CPU duration/);
 const clocks=structuredClone(report);clocks.cdp.clockAnchors[1].wallBeforeMs+=100;clocks.cdp.clockAnchors[1].wallAfterMs+=100;
 assert.throws(()=>run(clocks),/clock bounds/);
 assert.throws(()=>run(report,consoleRows,events.map((e,i)=>({...e,tid:i===1?3:2}))),/One runtime/);
 assert.throws(()=>run({...report,framePipelineEpoch:2}),/capture epoch/);
 assert.throws(()=>run({...report,framePipelineIdentity:{...identity,mainSha256:'another'}}),/capture identity/);
 console.log('PASS: frame/trace anchors, CPU vs wall, source accounting and eight attribution negatives');
}
module.exports={correlate,BOUNDARY,selfTest};
if(require.main===module){
 if(process.argv.includes('--self-test'))selfTest();
 else{
  const directory=process.argv[2];assert.ok(directory,'Usage: node analyze-frame-trace.cjs evidence-directory');
  const json=name=>JSON.parse(fs.readFileSync(path.join(directory,name),'utf8'));
  const lines=name=>fs.readFileSync(path.join(directory,name),'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
  const result=correlate(json('result.json'),lines('frame-pipeline.jsonl'),lines('console-timeline.jsonl'),json('drive.trace.json'));
  fs.writeFileSync(path.join(directory,'frame-trace-correlation.json'),JSON.stringify(result,null,2));
  console.log(JSON.stringify({pairedFrames:result.pairedFrames,anchors:result.anchors.length,meanMainLoopWallMs:result.meanMainLoopWallMs,meanMainLoopThreadCpuMs:result.meanMainLoopThreadCpuMs,over50:result.over50.length}));
 }
}

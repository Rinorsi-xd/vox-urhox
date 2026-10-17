'use strict';
const fs=require('node:fs');
const assert=require('node:assert/strict');
const BOUNDARY='CDP CPU profiles are statistical JavaScript/WASM stack samples, not exact function CPU durations or Lua source attribution. Trace event duration is wall time, may include waits and nested overlapping work, and is not GPU hardware execution time. Missing threads/categories are unavailable evidence, not zero cost.';
function cpuSummary(profile){
 const nodes=new Map((profile.nodes||[]).map(node=>[node.id,{node,count:0,weightUs:0}]));
 const samples=profile.samples||[],deltas=profile.timeDeltas||[];let unknown=0;
 for(let i=0;i<samples.length;i++){
  const entry=nodes.get(samples[i]);if(!entry){unknown++;continue}
  entry.count++;entry.weightUs+=Number.isFinite(deltas[i])&&deltas[i]>=0?deltas[i]:0;
 }
 return {boundary:BOUNDARY,durationMs:(profile.endTime-profile.startTime)/1000,samples:samples.length,
  deltaCount:deltas.length,unknownNodeSamples:unknown,
  top:[...nodes.values()].filter(entry=>entry.count).sort((a,b)=>b.weightUs-a.weightUs).slice(0,60).map(entry=>({
   name:entry.node.callFrame?.functionName||'(anonymous)',url:entry.node.callFrame?.url,
   line:Number.isInteger(entry.node.callFrame?.lineNumber)?entry.node.callFrame.lineNumber+1:null,
   samples:entry.count,sampledWeightMs:entry.weightUs/1000}))};
}
function traceSummary(trace){
 const events=Array.isArray(trace)?trace:trace.traceEvents||[],threads=new Map(),processes=new Map(),stacks=new Map(),complete=[],sync=[];
 const key=event=>event.pid+':'+event.tid;
 for(const event of events){
  if(event.ph==='M'&&event.name==='thread_name')threads.set(key(event),event.args?.name||'');
  if(event.ph==='M'&&event.name==='process_name')processes.set(event.pid,event.args?.name||'');
 }
 function add(event,durationUs){
  if(!Number.isFinite(durationUs)||durationUs<0)return;
  complete.push({name:event.name,category:event.cat,pid:event.pid,tid:event.tid,
   process:processes.get(event.pid)||'',thread:threads.get(key(event))||'',tsUs:event.ts,durationMs:durationUs/1000,
   ...(Number.isFinite(event.tdur)?{recordedThreadCpuMs:event.tdur/1000}:{}),args:event.args});
 }
 for(const event of events){
  if(event.name==='clock_sync'||event.cat==='__metadata'&&event.args?.sync_id)sync.push(event);
  if(event.ph==='X')add(event,event.dur);
  else if(event.ph==='B'){const stack=stacks.get(key(event))||[];stack.push(event);stacks.set(key(event),stack)}
  else if(event.ph==='E'){const stack=stacks.get(key(event));const begin=stack?.pop();if(begin)add(begin,event.ts-begin.ts)}
 }
 const inventory=new Map();
 for(const event of events){const k=key(event);if(!inventory.has(k))inventory.set(k,{pid:event.pid,tid:event.tid,process:processes.get(event.pid)||'',thread:threads.get(k)||'',events:0,completeEvents:0,maxEventMs:0});inventory.get(k).events++}
 for(const event of complete){const row=inventory.get(event.pid+':'+event.tid);row.completeEvents++;row.maxEventMs=Math.max(row.maxEventMs,event.durationMs)}
 const grouped=new Map();
 for(const event of complete){const k=event.pid+':'+event.tid+':'+event.name;const row=grouped.get(k)||{name:event.name,category:event.category,pid:event.pid,tid:event.tid,thread:event.thread,process:event.process,count:0,maxWallMs:0};row.count++;row.maxWallMs=Math.max(row.maxWallMs,event.durationMs);grouped.set(k,row)}
 return {boundary:BOUNDARY,eventCount:events.length,completeEvents:complete.length,
  threadInventory:[...inventory.values()].sort((a,b)=>b.events-a.events),clockSync:sync,
  longEvents:complete.filter(event=>event.durationMs>=80).sort((a,b)=>b.durationMs-a.durationMs).slice(0,100),
  topEventNamesByMaxWall:[...grouped.values()].sort((a,b)=>b.maxWallMs-a.maxWallMs).slice(0,80),
  unclosedBeginEvents:[...stacks.values()].reduce((sum,stack)=>sum+stack.length,0)};
}
function analyze(profile,trace){return {boundary:BOUNDARY,cpu:cpuSummary(profile),trace:traceSummary(trace)}}
function selfTest(){
 const p=cpuSummary({startTime:1000,endTime:6000,nodes:[{id:1,callFrame:{functionName:'sampled',lineNumber:0}}],samples:[1,1],timeDeltas:[1000,2000]});
 assert.equal(p.durationMs,5);assert.equal(p.top[0].sampledWeightMs,3);assert.equal(p.top[0].samples,2);
 const t=traceSummary({traceEvents:[{ph:'M',name:'thread_name',pid:1,tid:2,args:{name:'CrRendererMain'}},{ph:'X',name:'Task',pid:1,tid:2,ts:0,dur:90000},{ph:'B',name:'nested',pid:1,tid:2,ts:2000},{ph:'E',pid:1,tid:2,ts:5000},{ph:'c',name:'clock_sync',args:{sync_id:'fixture'},ts:1}]});
 assert.equal(t.longEvents.length,1);assert.equal(t.longEvents[0].thread,'CrRendererMain');assert.equal(t.completeEvents,2);assert.equal(t.clockSync.length,1);
 assert.equal(t.topEventNamesByMaxWall.find(event=>event.name==='nested').maxWallMs,3);
 assert.equal('totalCpuMs' in t,false);console.log('PASS: CDP statistical CPU weights, trace thread metadata/B-E/X durations, sync markers and non-CPU boundaries');
}
module.exports={analyze,cpuSummary,traceSummary,selfTest,BOUNDARY};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else{assert.ok(process.argv[2]&&process.argv[3],'Usage: node analyze-combat-cdp.cjs drive.cpuprofile drive.trace.json [summary.json]');const result=analyze(JSON.parse(fs.readFileSync(process.argv[2])),JSON.parse(fs.readFileSync(process.argv[3])));if(process.argv[4])fs.writeFileSync(process.argv[4],JSON.stringify(result,null,2));else console.log(JSON.stringify(result,null,2))}}

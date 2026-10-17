// Offline attribution of existing semantic scopes; no timing run or production edits.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const directory=path.resolve(process.argv[2]||'docs/migration/evidence/monitor-combat-simulation-fd97-a');
const output=process.argv[3]||'independent-simulation-attribution.json';
assert.match(output,/^[A-Za-z0-9_-]+\.json$/);
const destination=path.join(directory,output),baseName=output.replace(/\.json$/,'-base.json');
const baseFrames=baseName.replace(/\.json$/,'-frames.json');
for(const name of [output,baseName,baseFrames])assert(!fs.existsSync(path.join(directory,name)),'Preserve previous analysis '+name);
const report=JSON.parse(fs.readFileSync(path.join(directory,'report.json')));
assert.equal(report.status,'PASS','Wait for a complete successful run');
const metadata=report.identity.monitorCombat.simulationBreakdown;
assert(metadata);assert.equal(metadata.count,29);assert.equal(metadata.debugUpvalues,false);
assert.equal(metadata.bindings.length,29);
assert.equal(new Set(metadata.bindings.map(x=>x.label)).size,29);
for(const [relative,hash]of Object.entries(metadata.sourceHashes))assert.equal(report.identity.identity.scripts[relative],hash,'Actual module identity '+relative);
const runtime=fs.readFileSync(path.join(directory,'runtime.log'));
const marker='MONITOR_COMBAT_SIMULATION_READY ';
const ready=runtime.toString('utf8').split(/\r?\n/).filter(line=>line.includes(marker));
assert.equal(ready.length,1,'Exactly one live install');
const readyEvent=JSON.parse(ready[0].slice(ready[0].indexOf(marker)+marker.length));
assert.equal(readyEvent.count,29);assert.equal(readyEvent.debugUpvalues,false);
const capture=JSON.parse(fs.readFileSync(path.join(directory,'capture.json')));
assert(readyEvent.frame<capture.frameIds[0],'Install precedes capture');
const child=spawnSync(process.execPath,[path.join(__dirname,'monitor-combat-flush-analyze.cjs'),directory,baseName],{encoding:'utf8',maxBuffer:6*1024*1024});
assert.equal(child.status,0,child.stderr||child.stdout);
const base=JSON.parse(fs.readFileSync(path.join(directory,baseName)));
const detailed=JSON.parse(fs.readFileSync(path.join(directory,baseFrames)));
const frames=detailed.frames;assert(frames.length>0);
const empty=name=>({name,ms:0,selfMs:0,calls:0,maxMs:0});
const stage=(frame,name)=>frame.stages.find(x=>x.name===name)||empty(name);
const sum=xs=>xs.reduce((a,b)=>a+b,0);
const names=metadata.bindings.map(x=>x.label);
for(const prefix of ['sim.ai.','sim.legs.','sim.combatFx.'])assert(base.allFrameStageTotals.some(x=>x.name.startsWith(prefix)&&x.calls>0),'Workload must exercise '+prefix);
const totals=names.map(name=>{
 const rows=frames.map(frame=>stage(frame,name));
 return {name,calls:sum(rows.map(x=>x.calls)),framesWithCalls:rows.filter(x=>x.calls).length,
  inclusiveMs:sum(rows.map(x=>x.ms)),exclusiveMs:sum(rows.map(x=>x.selfMs)),
  exclusiveMeanMsPerFrame:sum(rows.map(x=>x.selfMs))/frames.length,maxSingleCallMs:Math.max(...rows.map(x=>x.maxMs))};
}).sort((a,b)=>b.exclusiveMs-a.exclusiveMs);
const compact=(frame,index)=>({engineFrame:frame.engineFrame,monitorFrame:frame.monitorFrame,intervalMs:frame.intervalMs,
 scriptMs:frame.scriptMs,steps:frame.steps,luaKiB:frame.luaKiB,
 heapDeltaKiB:index>0?frame.luaKiB-frames[index-1].luaKiB:null,
 parents:['ai.Step','legGait.Step','legs.Step','effects.Update','weaponIdleFx.Update','unit.Flush'].map(name=>stage(frame,name)),
 semanticChildren:names.map(name=>stage(frame,name)).filter(x=>x.calls).sort((a,b)=>b.selfMs-a.selfMs),
 topExclusive:[...frame.stages].sort((a,b)=>b.selfMs-a.selfMs).slice(0,8)});
const selected=frames.map(compact);
const result={status:'INDEPENDENT_SIMULATION_ATTRIBUTION_PASS',readyEvent,metadata,
 summary:base.summary,alignment:base.alignment,workload:base.workload,retention:base.retention,totals,
 unexercised:totals.filter(x=>x.calls===0).map(x=>x.name),
 spikes:selected.filter(x=>x.intervalMs>80),
 largestAi:frames.map((frame,index)=>({frame,index,ms:stage(frame,'ai.Step').ms})).sort((a,b)=>b.ms-a.ms).slice(0,12).map(x=>compact(x.frame,x.index)),
 largestLegGait:frames.map((frame,index)=>({frame,index,ms:stage(frame,'legGait.Step').ms})).sort((a,b)=>b.ms-a.ms).slice(0,12).map(x=>compact(x.frame,x.index)),
 sourceHashes:{...base.sourceHashes,'simulation-runtime.log':crypto.createHash('sha256').update(runtime).digest('hex')},
 boundaries:[
  'Existing independent complete-frame alignment and eight Flush scopes are reused; first/last partial observer frames excluded.',
  'Twenty-nine semantic labels aggregate all callers and vehicles per frame. Recorded selfMs excludes synchronous measured children; inclusive ancestors and descendants cannot be summed.',
  'A shared IK/navigation/effects method may also be called outside the most obvious parent. Frame totals do not establish individual caller trees.',
  'No new per-ray/Quad/vertex wrapping, debug Lua APIs, forced collections, GC modes or gameplay modifications.',
  'Clock resolution is integer wall milliseconds. Normal automatic GC, native calls and scheduling can be included in any scope. Heap drops do not prove GC duration.',
  'This probe adds measurement work. It is attribution, not matched FPS optimization A/B or Snapdragon845/TapTap sustained acceptance.',
 ]};
fs.writeFileSync(destination,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:result.status,summary:result.summary,totals:result.totals,unexercised:result.unexercised,
 spikes:result.spikes.map(x=>({engineFrame:x.engineFrame,intervalMs:x.intervalMs,parents:x.parents,semanticChildren:x.semanticChildren})),output:destination},null,2));

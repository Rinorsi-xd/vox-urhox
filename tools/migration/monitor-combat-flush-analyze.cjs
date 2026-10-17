// Offline only. Reuse the independently checked K frame alignment, then interpret child scopes.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const names=['flush.graph','flush.connectivity','flush.specBuild','flush.buildParts','flush.mergeBoxes','flush.rotors','flush.turretRange','flush.disposeVehicle'];
const directory=path.resolve(process.argv[2]||'docs/migration/evidence/monitor-combat-flush-2a92-a');
const output=process.argv[3]||'independent-flush-attribution.json';
assert.match(output,/^[A-Za-z0-9_-]+\.json$/);
const destination=path.join(directory,output),baseName=output.replace(/\.json$/,'-frames.json');
assert(!fs.existsSync(destination)&&!fs.existsSync(path.join(directory,baseName)),'Preserve previous analysis');
const rawReport=fs.readFileSync(path.join(directory,'report.json'));
const report=JSON.parse(rawReport);assert.equal(report.status,'PASS','Wait for a complete successful run');
assert.equal(report.identity.monitorCombat.flushBreakdown.count,8);
const rawRuntime=fs.readFileSync(path.join(directory,'runtime.log'));
const ready=rawRuntime.toString('utf8').split(/\r?\n/).filter(x=>x.includes('MONITOR_COMBAT_FLUSH_READY '));
assert.equal(ready.length,1,'Exactly one live-install readiness event');
const readyEvent=JSON.parse(ready[0].slice(ready[0].indexOf('MONITOR_COMBAT_FLUSH_READY ')+27));
assert.equal(readyEvent.count,8);
const child=spawnSync(process.execPath,[path.join(__dirname,'effect-indexed-analyze-k.cjs'),baseName,directory,'--include-frames'],{encoding:'utf8',maxBuffer:4*1024*1024});
assert.equal(child.status,0,child.stderr||child.stdout);
const attribution=JSON.parse(fs.readFileSync(path.join(directory,baseName)));
const capture=JSON.parse(fs.readFileSync(path.join(directory,'capture.json')));
const frames=attribution.frames;
assert(frames.length>0);
assert(readyEvent.frame<capture.frameIds[0],'Install must precede capture');
for(const name of names)assert(attribution.stageTotals.some(x=>x.name===name&&x.calls>0),'Missing actual child scope '+name);
const empty=name=>({name,ms:0,selfMs:0,calls:0,maxMs:0});
const stage=(frame,name)=>frame.stages.find(x=>x.name===name)||empty(name);
const sum=xs=>xs.reduce((a,b)=>a+b,0);
const totals=selected=>names.map(name=>{
 const rows=selected.map(frame=>stage(frame,name));
 return {name,framesWithCalls:rows.filter(x=>x.calls>0).length,calls:sum(rows.map(x=>x.calls)),
  inclusiveMs:sum(rows.map(x=>x.ms)),exclusiveMs:sum(rows.map(x=>x.selfMs)),
  inclusiveMeanMsPerFrame:selected.length?sum(rows.map(x=>x.ms))/selected.length:0,
  exclusiveMeanMsPerFrame:selected.length?sum(rows.map(x=>x.selfMs))/selected.length:0,
  maxSingleCallMs:rows.reduce((a,b)=>Math.max(a,b.maxMs),0)};
}).sort((a,b)=>b.exclusiveMs-a.exclusiveMs);
const byId=new Map(capture.frameIds.map((id,i)=>[id,i]));
const detailed=frames.map(frame=>{
 const i=byId.get(frame.engineFrame);assert(i>=1&&i<capture.frameIds.length-1);
 const unit=stage(frame,'unit.Flush'),spec=stage(frame,'flush.specBuild');
 return {...frame,partDelta:capture.parts[i]-capture.parts[i-1],hitDelta:capture.hits[i]-capture.hits[i-1],
  damageDelta:capture.damage[i]-capture.damage[i-1],killDelta:capture.kills[i]-capture.kills[i-1],
  luaKiBDelta:i>=2?frame.luaKiB-(frames.find(x=>x.engineFrame===frame.engineFrame-1)?.luaKiB??frame.luaKiB):null,
  flush:{inclusiveMs:unit.ms,exclusiveMs:unit.selfMs,calls:unit.calls,maxSingleCallMs:unit.maxMs,
   measuredDescendantMs:unit.ms-unit.selfMs,specBuildCalls:spec.calls,
   children:names.map(name=>stage(frame,name)).filter(x=>x.calls>0).sort((a,b)=>b.selfMs-a.selfMs)}};
});
const compact=frame=>({engineFrame:frame.engineFrame,monitorFrame:frame.monitorFrame,intervalMs:frame.intervalMs,
 scriptMs:frame.scriptMs,steps:frame.steps,luaKiB:frame.luaKiB,luaKiBDelta:frame.luaKiBDelta,
 partDelta:frame.partDelta,hitDelta:frame.hitDelta,damageDelta:frame.damageDelta,killDelta:frame.killDelta,
 finalizeMs:frame.finalizeMs,emitMs:frame.emitMs,contextMs:frame.contextMs,flush:frame.flush,
 topExclusive:[...frame.stages].sort((a,b)=>b.selfMs-a.selfMs).slice(0,8)});
const structural=detailed.filter(x=>x.partDelta<0),rebuilt=detailed.filter(x=>x.flush.specBuildCalls>0);
const spikes=detailed.filter(x=>x.intervalMs>80).map(frame=>({...compact(frame),
 originalSlowRecord:attribution.spikes.find(x=>x.monitorFrame===frame.monitorFrame)}));
const result={status:'INDEPENDENT_FLUSH_ATTRIBUTION_PASS',readyEvent,summary:attribution.summary,alignment:attribution.alignment,
 sourceHashes:{...attribution.sourceHashes,'report.json':crypto.createHash('sha256').update(rawReport).digest('hex'),
  'runtime.log':crypto.createHash('sha256').update(rawRuntime).digest('hex')},
 workload:attribution.workload,retention:attribution.retention,allFrameChildTotals:totals(detailed),
 structuralLoss:{frames:structural.length,childTotals:totals(structural),worst:structural.sort((a,b)=>b.intervalMs-a.intervalMs).slice(0,20).map(compact)},
 rebuildWork:{frames:rebuilt.length,childTotals:totals(rebuilt),worst:rebuilt.sort((a,b)=>b.flush.inclusiveMs-a.flush.inclusiveMs).slice(0,20).map(compact)},
 spikes,allFrameStageTotals:attribution.stageTotals,
 boundaries:[
  'Exact K frame alignment reused. First/last partial observer frames excluded. No interpolation.',
  'Exclusive values are actual monitor selfMs, subtracting measured synchronous child durations. Inclusive parent/child labels must never be added.',
  'Labels aggregate all vehicles/calls in each frame, including other callers such as respawn. They do not encode individual call trees; child totals cannot be asserted wholly inside Flush.',
  'unit.Flush measuredDescendantMs is its recorded inclusive minus exclusive. Child-label inclusive values may overlap each other.',
  'partDelta is end-frame simulation parts; damage/hit values are cumulative world counters. Correlation does not prove each child invocation was caused by a specific hit.',
  'Normal automatic GC, native calls and scheduling can be included in wall scopes. Heap drops are associations, not GC proof.',
  'This is additional-monitor attribution, not an optimization A/B or TapTap/Snapdragon845 sustained FPS acceptance.'
 ]};
fs.writeFileSync(destination,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:result.status,summary:result.summary,alignment:result.alignment,
 children:result.allFrameChildTotals,structuralFrames:structural.length,rebuildFrames:rebuilt.length,
 spikes:spikes.map(({originalSlowRecord,...x})=>x),output:destination},null,2));

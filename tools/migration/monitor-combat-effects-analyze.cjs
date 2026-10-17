// Offline actual complete-frame section attribution; never starts a Runtime.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const directory=path.resolve(process.argv[2]),output=process.argv[3]||'independent-effects-attribution.json';
assert.match(output,/^[A-Za-z0-9_-]+\.json$/);const baseName=output.replace(/\.json$/,'-frames.json');
for(const name of [output,baseName])assert(!fs.existsSync(path.join(directory,name)),'Preserve earlier analysis '+name);
const report=JSON.parse(fs.readFileSync(path.join(directory,'report.json')));assert.equal(report.status,'PASS');
assert.equal(report.shutdown,'CLOSED');assert.deepEqual(report.errors,[]);assert.deepEqual(report.httpErrors,[]);
const metadata=report.identity.monitorCombat.effectsBreakdown;assert(metadata);assert.equal(metadata.count,13);assert.equal(metadata.methods,7);
assert.equal(metadata.transform.baselineSha256,metadata.transform.strippedSha256);
assert.equal(report.identity.identity.scripts['render/CombatEffects.lua'],metadata.transform.derivedSha256);
assert.equal(report.identity.g1WebCpu.variants['render/CombatEffects.lua'].baselineSha256,metadata.transform.baselineSha256);
for(const [relative,hash]of Object.entries(metadata.sourceHashes))assert.equal(report.identity.identity.scripts[relative],hash);
const runtime=fs.readFileSync(path.join(directory,'runtime.log'));
function event(marker){
 const rows=runtime.toString('utf8').split(/\r?\n/).filter(line=>line.includes(marker));assert.equal(rows.length,1,marker+' exactly once');
 return JSON.parse(rows[0].slice(rows[0].indexOf(marker)+marker.length));
}
const ready=event('MONITOR_COMBAT_EFFECTS_READY '),done=event('MONITOR_COMBAT_EFFECTS_DONE ');
assert.equal(ready.sections,13);assert.equal(ready.methods,7);assert.equal(ready.debugUpvalues,false);assert.equal(ready.perPrimitiveWrappers,false);
assert.equal(done.restored,true);assert.equal(done.scopeDepth,0);
const capture=JSON.parse(fs.readFileSync(path.join(directory,'capture.json')));
assert(ready.frame<capture.frameIds[0]);assert(done.frame>=capture.frameIds.at(-1));
const child=spawnSync(process.execPath,[path.join(__dirname,'effect-indexed-analyze-k.cjs'),baseName,directory,'--include-frames'],{encoding:'utf8',maxBuffer:5*1024*1024});
assert.equal(child.status,0,child.stderr||child.stdout);
const base=JSON.parse(fs.readFileSync(path.join(directory,baseName))),frames=base.frames;
const sectionNames=metadata.transform.labels,methodNames=metadata.bindings.map(row=>row.label),names=[...sectionNames,...methodNames];
assert.equal(sectionNames.length,13);assert.equal(new Set(names).size,20);
const empty=name=>({name,ms:0,selfMs:0,calls:0,maxMs:0}),stage=(frame,name)=>frame.stages.find(row=>row.name===name)||empty(name);
const sum=xs=>xs.reduce((a,b)=>a+b,0);
for(const frame of frames){
 const parent=stage(frame,'effects.Update');const sections=sectionNames.map(name=>stage(frame,name));
 for(const row of sections)assert.equal(row.calls,parent.calls,'One whole section per active effects.Update '+row.name);
 assert(sum(sections.map(row=>row.ms))<=parent.ms,'Section inclusive sum fits effects.Update');
}
const totals=names.map(name=>{
 const rows=frames.map(frame=>stage(frame,name));
 return {name,calls:sum(rows.map(row=>row.calls)),framesWithCalls:rows.filter(row=>row.calls).length,
  inclusiveMs:sum(rows.map(row=>row.ms)),exclusiveMs:sum(rows.map(row=>row.selfMs)),
  inclusiveMeanMsPerFrame:sum(rows.map(row=>row.ms))/frames.length,
  exclusiveMeanMsPerFrame:sum(rows.map(row=>row.selfMs))/frames.length,
  maxCallMs:Math.max(...rows.map(row=>row.maxMs))};
}).sort((a,b)=>b.exclusiveMs-a.exclusiveMs);
for(const name of sectionNames)assert(totals.find(row=>row.name===name).calls>0,'Actual section exercised '+name);
function compact(frame,index){
 return {engineFrame:frame.engineFrame,monitorFrame:frame.monitorFrame,intervalMs:frame.intervalMs,scriptMs:frame.scriptMs,
  steps:frame.steps,luaKiB:frame.luaKiB,heapDeltaKiB:index>0?frame.luaKiB-frames[index-1].luaKiB:null,
  effectsParent:stage(frame,'effects.Update'),driveViewsParent:stage(frame,'playerView.Update'),
  sections:sectionNames.map(name=>stage(frame,name)),methods:methodNames.map(name=>stage(frame,name)),
  effectsOutsideSectionsMs:stage(frame,'effects.Update').ms-sum(sectionNames.map(name=>stage(frame,name).ms)),
  topExclusive:[...frame.stages].sort((a,b)=>b.selfMs-a.selfMs).slice(0,12)};
}
const selected=frames.map(compact);
const result={status:'INDEPENDENT_EFFECT_SECTIONS_PASS',ready,done,metadata,summary:base.summary,alignment:base.alignment,
 workload:base.workload,retention:base.retention,totals,unexercised:totals.filter(row=>!row.calls).map(row=>row.name),
 allFrameStageTotals:base.stageTotals,spikesAtLeast80:selected.filter(frame=>frame.intervalMs>=80),
 worstEffects:selected.slice().sort((a,b)=>b.effectsParent.ms-a.effectsParent.ms).slice(0,16),
 worstDriveViews:selected.slice().sort((a,b)=>b.driveViewsParent.ms-a.driveViewsParent.ms).slice(0,16),
 sectionCoverage:{actualFrames:frames.length,effectCalls:sum(frames.map(frame=>stage(frame,'effects.Update').calls)),
  outsideSectionsMs:sum(selected.map(frame=>frame.effectsOutsideSectionsMs))},
 sourceHashes:{...base.sourceHashes,'runtime.log':crypto.createHash('sha256').update(runtime).digest('hex')},
 boundaries:[
  'Existing independent complete-frame alignment reused. First/last partial observer frames excluded; no interpolation.',
  'Thirteen section markers enclose whole existing loops. No per-particle/vertex/Quad wrappers. Insertions remove byte-for-byte to the original module.',
  'Existing chips/missiles wrappers remain descendants; section selfMs excludes measured children. Inclusive ancestors and descendants cannot be added.',
  'Batch.Finish is shared by CombatEffects and WeaponEffects. Its aggregate label must not be attributed entirely to fx.section.finish.',
  'playerView.Update wraps a shared DriveView metatable and includes other combat vehicles, not only the human player. Child view labels also aggregate all vehicles.',
  'Integer wall milliseconds include native calls, automatic GC and scheduling. Heap drops alone do not measure GC duration; engine gap is not automatically GPU.',
  'This probe adds measurement work. It is attribution, not matched FPS A/B, a gameplay change, or Snapdragon845/TapTap sustained acceptance.',
 ]};
fs.writeFileSync(path.join(directory,output),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:result.status,summary:result.summary,totals:result.totals,sectionCoverage:result.sectionCoverage,
 spikesAtLeast80:result.spikesAtLeast80.map(frame=>({engineFrame:frame.engineFrame,intervalMs:frame.intervalMs,scriptMs:frame.scriptMs,
 effectsParent:frame.effectsParent,sections:frame.sections.filter(row=>row.ms),topExclusive:frame.topExclusive})),
 output:path.join(directory,output)},null,2));

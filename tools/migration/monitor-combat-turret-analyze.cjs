// Offline-only decode of actual cold/warm For calls; no Runtime/browser invocation.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const {stream}=require('./monitor-combat-run.cjs');
const directory=path.resolve(process.argv[2]);
const output=process.argv[3]||'independent-turret-attribution.json';
assert.match(output,/^[A-Za-z0-9_-]+\.json$/);
const destination=path.join(directory,output),flushName=output.replace(/\.json$/,'-flush.json');
assert(!fs.existsSync(destination)&&!fs.existsSync(path.join(directory,flushName)),'Preserve prior evidence');
const report=JSON.parse(fs.readFileSync(path.join(directory,'report.json')));
assert.equal(report.status,'PASS','Wait for a complete successful run');
assert.equal(report.identity.monitorCombat.turretBreakdown.resultKind,'turret-result');
const raw=fs.readFileSync(path.join(directory,'runtime.log')),lines=raw.toString('utf8').split(/\r?\n/);
const readyLines=lines.filter(x=>x.includes('MONITOR_TURRET_READY '));assert.equal(readyLines.length,1);
const readyPrefix='MONITOR_TURRET_READY ',ready=JSON.parse(readyLines[0].slice(readyLines[0].indexOf(readyPrefix)+readyPrefix.length));
if(report.identity.monitorCombat.turretBreakdown.usesDebugUpvalues)assert.equal(ready.debugUpvalues,true);
else {assert.equal(ready.debugUpvalues,false);assert.equal(ready.sourceMarkers,true);
 const proof=report.identity.monitorCombat.turretBreakdown.transform;
 assert.equal(proof.method,'three-reversible-entry-lines');assert.equal(proof.strippedSha256,proof.baselineSha256);
 assert.equal(proof.insertedLines.length,3);
}
const transport=stream();let chunks=0;
for(const line of lines){const at=line.indexOf('MONITOR_COMBAT_CHUNK ');if(at<0)continue;
 const item=JSON.parse(line.slice(at+21));if(item.kind==='turret-result'){transport.add(item);chunks++}
}
assert(transport.ready(),'Complete checksum-verified turret result transport');
const result=transport.value();assert.equal(result.restored,true,'Original For/Compute closures restored');
assert(result.errors&&typeof result.errors==='object'&&Object.keys(result.errors).length===0,'No captured helper exceptions');
assert.deepEqual(result.columns,['engineFrame','blueprintId','cachePresent','forMs','prepareCalls','prepareMs','evaluateCalls','evaluateMs','class','error']);
assert.deepEqual(result.classes,['coldBlueprint','fullReuse','contextRangeReuse','warmEvaluate']);
assert(result.rows.length>0,'Actual For calls required');
for(const row of result.rows){assert.equal(row.length,10);for(const value of row)assert(Number.isFinite(value)&&Number.isInteger(value)&&value>=0);
 assert(row[1]>0);assert(row[2]===0||row[2]===1);assert.equal(row[9],0);
 assert.equal(row[8],row[2]===0?1:row[6]>0?4:row[4]>0?3:2,'Class from actual pre-call cache and helper calls');
}
const capture=JSON.parse(fs.readFileSync(path.join(directory,'capture.json')));
assert(ready.frame<capture.frameIds[0],'Live install before capture');
const child=spawnSync(process.execPath,[path.join(__dirname,'monitor-combat-flush-analyze.cjs'),directory,flushName],{encoding:'utf8',maxBuffer:4*1024*1024});
assert.equal(child.status,0,child.stderr||child.stdout);
const attribution=JSON.parse(fs.readFileSync(path.join(directory,flushName)));
const frames=JSON.parse(fs.readFileSync(path.join(directory,flushName.replace(/\.json$/,'-frames.json')))).frames;
const grouped=new Map();for(const row of result.rows){if(!grouped.has(row[0]))grouped.set(row[0],[]);grouped.get(row[0]).push(row)}
const sum=(rows,index)=>rows.reduce((total,row)=>total+row[index],0);
const stage=(frame,name)=>frame.stages.find(x=>x.name===name)||{name,ms:0,selfMs:0,calls:0,maxMs:0};
const selected=[];
for(const frame of frames){const rows=grouped.get(frame.engineFrame)||[];selected.push(...rows);
 assert.equal(rows.length,stage(frame,'flush.turretRange').calls,'Exact per-frame real For count');
 assert.equal(sum(rows,4),stage(frame,'turret.prepare').calls,'Exact per-frame Prepare count');
 assert.equal(sum(rows,6),stage(frame,'turret.evaluate').calls,'Exact per-frame Evaluate count');
 assert.equal(rows.filter(row=>row[2]===0).length,stage(frame,'turret.coldFor').calls,'Exact per-frame cold count');
 assert.equal(rows.filter(row=>row[2]===1).length,stage(frame,'turret.warmFor').calls,'Exact per-frame warm count');
}
const classes=result.classes.map((name,index)=>{const rows=selected.filter(row=>row[8]===index+1);return {name,calls:rows.length,
 forMs:sum(rows,3),prepareCalls:sum(rows,4),prepareMs:sum(rows,5),evaluateCalls:sum(rows,6),evaluateMs:sum(rows,7),
 maxForMs:rows.reduce((max,row)=>Math.max(max,row[3]),0)}});
const detailed=frames.map(frame=>({engineFrame:frame.engineFrame,monitorFrame:frame.monitorFrame,intervalMs:frame.intervalMs,
 scriptMs:frame.scriptMs,parts:frame.parts,luaKiB:frame.luaKiB,steps:frame.steps,forCalls:grouped.get(frame.engineFrame)||[],
 stages:['unit.Flush','flush.turretRange','turret.coldFor','turret.warmFor','turret.prepare','turret.evaluate'].map(name=>stage(frame,name))}));
const coldByBlueprint=new Map();for(const row of selected)if(row[2]===0)coldByBlueprint.set(row[1],(coldByBlueprint.get(row[1])||0)+1);
for(const count of coldByBlueprint.values())assert.equal(count,1,'Successful For writes a cache per blueprint');
const decoded={status:'INDEPENDENT_TURRET_ATTRIBUTION_PASS',ready,transport:{chunks,restored:result.restored,errors:result.errors},
 sourceHashes:{runtimeLog:crypto.createHash('sha256').update(raw).digest('hex'),...attribution.sourceHashes},
 summary:attribution.summary,alignment:attribution.alignment,workload:attribution.workload,columns:result.columns,
 classes,completeFrameCalls:selected.length,excludedEdgeCalls:result.rows.length-selected.length,
 actualColdBlueprints:coldByBlueprint.size,
 worstForCalls:[...selected].sort((a,b)=>b[3]-a[3]).slice(0,20),
 worstForFrames:detailed.filter(frame=>frame.forCalls.length>0).sort((a,b)=>sum(b.forCalls,3)-sum(a.forCalls,3)).slice(0,20),
 spikes:detailed.filter(frame=>frame.intervalMs>80),
 boundaries:[
  'Actual frozen For cache table is read before each call; actual shared Prepare/Evaluate closures execute unchanged.',
  'Cold means that exact blueprint object has no For cache, not that every asset/sample/ray cache is cold.',
  'FullReuse means no Prepare/Evaluate call. ContextRangeReuse means Prepare ran but Evaluate did not. WarmEvaluate means an existing blueprint cache required Evaluate.',
  'Manual per-call integer wall timing includes instrumentation and may differ from monitor scope timing. Durations are not CPU-only measurements.',
  'Same verified frame alignment as K; exact per-frame For/Prepare/Evaluate/cold/warm counts checked against the existing monitor.',
  'First/last partial frames excluded. Shared closure restoration and checksum transport required.',
  'Additional measurement overhead; attribution only, not an optimization A/B or phone performance acceptance.'
 ]};
fs.writeFileSync(destination,JSON.stringify(decoded,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:decoded.status,classes,completeFrameCalls:decoded.completeFrameCalls,
 worstForCalls:decoded.worstForCalls.slice(0,5),spikes:decoded.spikes,output:destination},null,2));

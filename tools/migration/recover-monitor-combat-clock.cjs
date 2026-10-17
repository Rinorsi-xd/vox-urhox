'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
function run(directory){
 const read=name=>JSON.parse(fs.readFileSync(path.join(directory,name),'utf8'));
 const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
 const metadata=read('cdp-capture.json'),trace=read('drive.trace.json'),profile=read('drive.cpuprofile');
 assert.equal(metadata.status,'COLLECTED');assert.equal(metadata.detached,true);assert.equal(metadata.traceDataLoss,false);
 assert.equal(metadata.clockSyncVerified,undefined,'This recovery is only for the archived pre-verification collector');
 assert.deepEqual(metadata.clockAnchors.map(a=>a.label),['trace-start','held-input-start','held-input-end','trace-stop']);
 const markers=trace.traceEvents.filter(e=>e.name==='clock_sync');
 const verified=metadata.clockAnchors.map(anchor=>{
  const matches=markers.filter(e=>e.args?.sync_id===anchor.syncId);assert.equal(matches.length,1,'Unique raw trace marker '+anchor.syncId);
  const marker=matches[0];assert.equal(marker.ph,'c');assert(Number.isFinite(marker.ts));
  const delayUs=marker.ts-anchor.cdpMonotonicSeconds*1e6;assert(delayUs>=0&&delayUs<=10000,'Measured marker follows its CDP Timestamp within 10ms');
  return {label:anchor.label,syncId:anchor.syncId,traceUs:marker.ts,performanceTimestampUs:anchor.cdpMonotonicSeconds*1e6,delayUs};
 });
 for(let i=1;i<verified.length;i++)assert(verified[i].traceUs>verified[i-1].traceUs,'Strictly ordered real clock markers');
 const analysisFile=path.join(__dirname,'analyze-monitor-combat-trace.cjs');
 const collectorFile=path.join(__dirname,'monitor-combat-cdp.cjs');
 const verification={status:'RAW_CLOCK_SYNC_INDEPENDENTLY_VERIFIED',generatedAt:new Date().toISOString(),
  boundary:'Original metadata is unchanged. The collector loaded at browser launch predates marker-verification enhancement. This derived verification reads actual trace clock_sync events and supplies the same strict analyzer requirement in memory. It is not a rerun or historical tool identity claim.',
  recordedCollectorSha256:metadata.toolHashes['monitor-combat-cdp.cjs'],currentCollectorSha256:sha(collectorFile),
  currentAnalyzerSha256:sha(analysisFile),sourceHashes:Object.fromEntries(['cdp-capture.json','drive.trace.json','drive.cpuprofile','console-timeline.jsonl'].map(n=>[n,sha(path.join(directory,n))])),verified};
 const rows=fs.readFileSync(path.join(directory,'console-timeline.jsonl'),'utf8').trim().split(/\r?\n/).filter(Boolean).map(JSON.parse);
 const derived={...metadata,clockSyncVerified:true,traceClockSyncMarkers:verified};
 const result=require('./analyze-monitor-combat-trace.cjs').analyze(derived,profile,trace,rows);
 result.derivedClockVerification='independent-clock-sync-verification.json';
 fs.writeFileSync(path.join(directory,'independent-clock-sync-verification.json'),JSON.stringify(verification,null,2)+'\n',{flag:'wx'});
 fs.writeFileSync(path.join(directory,'combat-trace-attribution-derived.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({status:result.status,verification:verification.status,coverage:result.coverage,mainLoop:{...result.mainLoop,longest:result.mainLoop.longest.slice(0,5)},
  gc:result.mainThreadV8Gc,gl:result.mainThreadGlQueriesAndWaits,wasm:result.mainThreadWasmEvents,cpu:result.cpu,
  emissionAnchors:result.emissionAnchors.length,rejectedEmissionAnchors:result.rejectedEmissionAnchors.length},null,2));return result;
}
module.exports={run};
if(require.main===module)run(path.resolve(process.argv[2]));

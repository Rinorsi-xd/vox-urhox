// Existing run attribution only; no browser, renderer or production mutation.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const base='docs/migration/evidence/intro-natural-web-1600x900-manifest-3ba43bd8';
const jsonPath=path.join(root,base+'.json'),logPath=path.join(root,base+'.log');
const run=JSON.parse(fs.readFileSync(jsonPath,'utf8'));
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const shots={},records=[],memoryDrops=[];let previous=null;
for(const sample of run.samples){
 const shot=sample.shot||'unknown';
 const row=shots[shot]??={shot,samples:0,firstSampleAt:sample.at,lastSampleAt:sample.at,renderCalls:0,renderTotalMs:0,sampledLastRenderMaxMs:0,knownLifetimeRecordMaxMs:null,luaMinKiB:Infinity,luaMaxKiB:0,longTasks:0,maxLongTaskMs:0};
 row.samples++;row.lastSampleAt=sample.at;
 const memory=sample.performance?.luaKiB;
 if(memory!==undefined){row.luaMinKiB=Math.min(row.luaMinKiB,memory);row.luaMaxKiB=Math.max(row.luaMaxKiB,memory);}
 const timer=sample.openingTiming?.openingPage,prior=previous?.openingTiming?.openingPage;
 if(timer){
  row.renderCalls+=Math.max(0,timer.calls-(prior?.calls||0));row.renderTotalMs+=Math.max(0,timer.totalMs-(prior?.totalMs||0));
  row.sampledLastRenderMaxMs=Math.max(row.sampledLastRenderMaxMs,timer.lastMs||0);
  if(timer.maxShot===shot)row.knownLifetimeRecordMaxMs=Math.max(row.knownLifetimeRecordMaxMs||0,timer.maxMs||0);
  if(timer.maxMs>(prior?.maxMs||0))records.push({sampleAt:sample.at,sampleShot:shot,actualMaxShot:timer.maxShot,actualMaxAge:timer.maxAge,maxMs:timer.maxMs,luaKiB:memory,previousSampleLuaKiB:previous?.performance?.luaKiB});
 }
 if(memory!==undefined&&previous?.performance?.luaKiB-memory>20000)memoryDrops.push({beforeAt:previous.at,afterAt:sample.at,beforeShot:previous.shot,afterShot:shot,beforeKiB:previous.performance.luaKiB,afterKiB:memory});
 previous=sample;
}
for(const task of run.audioContinuity.longTasks){const row=shots[task.shot];if(row){row.longTasks++;row.maxLongTaskMs=Math.max(row.maxLongTaskMs,task.duration);}}
for(const row of Object.values(shots))row.renderAverageMs=row.renderCalls?row.renderTotalMs/row.renderCalls:null;
const log=fs.readFileSync(logPath,'utf8').split(/\r?\n/);
const stampNearbyNativeMarkers=log.filter(line=>/^\[2026-10-16 05_12_1[4-9]/.test(line)&&!line.includes('OUTGAME_STATE'));
const report={result:'MEASURED_HISTORICAL',manifest:'manifest-3ba43bd8.json',inputs:{[base+'.json']:hash(jsonPath),[base+'.log']:hash(logPath)},
 functionality:run.functionality,continuity:run.continuity,instrumentation:run.instrumentation,
 raf:{p95:run.audioContinuity.rafP95,p99:run.audioContinuity.rafP99,max:run.audioContinuity.maxRaf,freezes:run.audioContinuity.rafFreezes},
 shots:Object.values(shots),records,memoryDrops,stampNearbyNativeMarkers,
 boundary:'Render method wrapper wall time from the actual existing run, including native bridge and any GC during the call; excludes later NanoVG flush, GPU execution and whole-frame work. Per-shot totals use differences between public state samples, so a boundary interval can include the preceding shot. A missing lifetime record for a shot is not a zero maximum; sampled lastMs is a lower bound. Browser long-task shot labels are sampled and may lag transitions. Lua memory drops are consistent with collection, not GC-cause tracing. No new GPU execution or claim that this explains the full continuity failure.'};
const out=path.join(root,'docs/migration/evidence/intro-ui-cost-manifest-3ba43bd8.json');
fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({result:report.result,records,shots:report.shots.filter(row=>['familiar','payslip','m-build','m-drive','m-missile','m-salvage','comms','contract','stamp','gate'].includes(row.shot)),evidence:out},null,2));

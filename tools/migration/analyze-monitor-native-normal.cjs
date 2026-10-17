'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const [aPath,cPath,outPath]=process.argv.slice(2);assert(aPath&&cPath&&outPath,'A-directory C-directory fresh-output required');
const resolve=p=>path.resolve(root,p),read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const aRoot=resolve(aPath),cRoot=resolve(cPath),output=resolve(outPath);assert(!fs.existsSync(output));
const ids=[read(path.join(aRoot,'identity.json')),read(path.join(cRoot,'identity.json'))];
const changed=Object.keys(ids[0].sourceHashes).filter(key=>ids[0].sourceHashes[key]!==ids[1].sourceHashes[key]);
assert.deepEqual(changed,['scripts/monitor-native-normal.lua']);
for(const [i,id]of ids.entries()){
 assert.equal(id.timingValidity,'NORMAL_GC_FIXED_WORKLOAD_WALL');assert.equal(id.configuration.profile,false);
 assert.equal(id.configuration.variant,i===0?'A':'C');
 for(const [key,hash]of Object.entries(id.sourceHashes))assert.equal(sha(fs.readFileSync(path.join(i===0?aRoot:cRoot,key))),hash,key);
}
assert.deepEqual(ids[0].roster,ids[1].roster);assert.deepEqual(ids[0].projectHashes,ids[1].projectHashes);
assert.equal(ids[0].sourceFrozenSha256,ids[1].sourceFrozenSha256);assert.equal(ids[0].assetRoot,ids[1].assetRoot);
const commonConfiguration=({variant,...other})=>other;
assert.deepEqual(commonConfiguration(ids[0].configuration),commonConfiguration(ids[1].configuration));
const order=[[aRoot,'A1'],[cRoot,'C1'],[cRoot,'C2'],[aRoot,'A2']];
const results=order.map(([directory,label])=>{
 const file=path.join(directory,label+'.json'),r=read(file),process=read(path.join(directory,label+'.process.json')),
  validation=read(path.join(directory,label+'.validation.json')),launch=read(path.join(directory,label+'.launch.json'));
 assert.equal(r.status,'NORMAL_GC_TIMING_PASS');assert.equal(process.exitCode,0);assert.equal(process.completedWithinDeadline,true);
 assert.equal(validation.valid,true);assert.deepEqual(validation.nativeErrors,[]);assert.equal(r.collectorRunning,true);
 assert.equal(r.collectorGuardRestored,true);assert.equal(r.frames.length,r.configuration.steps);assert.equal(r.configuration.warmup,120);
 assert.deepEqual(r.configuration,ids[label.startsWith('A')?0:1].configuration,'Output configuration matches frozen fixture');
 assert.equal(r.profile,false);assert.equal(r.snapshots.length,1);assert.equal(r.initial.cars.length,8);
 assert.equal(r.timedSinkCalls,r.configuration.steps*4);
 assert(r.monitorErrors!==null&&typeof r.monitorErrors==='object'&&Object.keys(r.monitorErrors).length===0,
  'monitorErrors must be a strictly empty Lua table encoded as [] or {}');
 assert.equal(r.wrappersRestored,true);
 assert.equal(Object.values(r.timedSinkTypes).reduce((sum,value)=>sum+value,0),r.timedSinkCalls);
 if(label.startsWith('C'))assert.equal(r.timedSinkTypes.padding,r.timedSinkCalls);
 assert.equal(r.wholeInstrumentation,label.startsWith('A'));assert.equal(r.wrappersInstalledDuringTest,label.startsWith('A'));
 if(label.startsWith('C')){assert.equal(r.stages,false);assert.equal(r.stageNames,false)}else assert(r.stageNames.includes('vehicle.Step'));
 assert.equal(r.totalStepMs,r.frames.reduce((sum,row)=>sum+row.ms,0));assert.equal(r.meanStepMs,r.totalStepMs/r.configuration.steps);
 const sorted=r.frames.map(row=>row.ms).sort((x,y)=>x-y),quantile=q=>sorted[Math.ceil(q*sorted.length)-1];
 return {label,file,sha256:sha(fs.readFileSync(file)),r,launch,summary:{label,totalMs:r.totalStepMs,meanMs:r.meanStepMs,
  per1000StepsMs:r.meanStepMs*1000,p50Ms:quantile(.5),p95Ms:quantile(.95),p99Ms:quantile(.99),maxMs:sorted.at(-1),
  over80:r.frames.filter(row=>row.ms>80).length,minAlive:Math.min(...r.frames.map(row=>row.alive)),
  shots:r.frames.at(-1).shots-r.initial.shots,hits:r.frames.at(-1).hits-r.initial.hits,
  damage:r.frames.at(-1).damage-r.initial.damage,partLoss:r.initial.cars.reduce((sum,car)=>sum+car.parts,0)-Math.min(...r.frames.map(row=>row.parts)),
  heapBeforeKiB:r.heapBeforeKiB,heapAfterKiB:r.heapAfterKiB,timedSinkTypes:r.timedSinkTypes}};
});
const workload=r=>({metadata:r.metadata,initial:r.initial,snapshots:r.snapshots,randomAfter:r.randomAfter,aiRandomAfter:r.aiRandomAfter,
 frames:r.frames.map(({ms,...row})=>row)});
for(const result of results.slice(1)){
 assert.deepEqual(workload(result.r),workload(results[0].r),'Exact reachable Lua state/body/workload/RNG '+result.label);
 for(const key of ['runtimeInputs','resourceInputs','assetInputs'])assert.deepEqual(result.launch[key],results[0].launch[key],key);
}
assert(results.every(result=>result.summary.shots>0&&result.summary.hits>0&&result.summary.damage>0&&result.summary.partLoss>0),'Actual firing/hits/damage/structural loss required');
const aMean=(results[0].r.meanStepMs+results[3].r.meanStepMs)/2,cMean=(results[1].r.meanStepMs+results[2].r.meanStepMs)/2;
const overhead=aMean-cMean,aDrift=Math.abs(results[0].r.meanStepMs-results[3].r.meanStepMs),cDrift=Math.abs(results[1].r.meanStepMs-results[2].r.meanStepMs);
const report={status:'MONITOR_NORMAL_GC_ACCA_EXACT_WORKLOAD_PASS',runs:results.map(result=>({...result.summary,file:result.file,sha256:result.sha256})),
 aMeanMs:aMean,cMeanMs:cMean,instrumentationOverheadMs:overhead,instrumentationOverheadFractionOfOff:cMean>0?overhead/cMean:null,
 aDriftMs:aDrift,cDriftMs:cDrift,signalAboveObservedDrift:Math.abs(overhead)>Math.max(aDrift,cDrift),
 exactCapturedUnitAiWeaponStateAndWorkload:true,globalAndPerAiRngMatch:true,changedSources:changed,
 boundary:'Four serial independent Native processes A(on)/C(off)/C(off)/A(on), same real eight-car simulation, normal GC. Measures actual Attach/wrappers/core Monitor/Context bookkeeping with matched trivial sinks; excludes production JSON/console/files/panel/UI/render/audio/full BattleController objectives. Unit/AI/weapon Lua-data digests omit external world/space/environment/layout/navigation roots and functions/metatables/native userdata internals; explicit world stats/time/debris roots, vehicle/debris bodies and global/per-AI RNG exported separately. No claim of complete engine-state equality. Not complete browser monitor overhead, FPS or Snapdragon845 acceptance. Finalize monitorMs is not treated as total monitoring cost.'};
fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(report,null,2));

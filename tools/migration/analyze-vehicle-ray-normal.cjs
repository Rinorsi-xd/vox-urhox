'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const [aPath,bPath,outPath]=process.argv.slice(2);assert(aPath&&bPath&&outPath,'A-directory B-directory fresh-output required');
const resolve=p=>path.resolve(root,p),read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const aRoot=resolve(aPath),bRoot=resolve(bPath),output=resolve(outPath);assert(!fs.existsSync(output));
const ids=[read(path.join(aRoot,'identity.json')),read(path.join(bRoot,'identity.json'))];
const changed=Object.keys(ids[0].sourceHashes).filter(key=>ids[0].sourceHashes[key]!==ids[1].sourceHashes[key]);
assert.deepEqual(changed.sort(),['scripts/combat/VehicleRay.lua','scripts/vehicle-ray-normal.lua'].sort());
for(const [i,id]of ids.entries()){
 assert.equal(id.timingValidity,'NORMAL_GC_FIXED_WORKLOAD_WALL');assert.equal(id.configuration.profile,false);
 assert.equal(id.configuration.variant,i===0?'A':'B');
 for(const [key,hash]of Object.entries(id.sourceHashes))assert.equal(sha(fs.readFileSync(path.join(i===0?aRoot:bRoot,key))),hash,key);
}
assert.deepEqual(ids[0].roster,ids[1].roster);assert.deepEqual(ids[0].projectHashes,ids[1].projectHashes);
const order=[[aRoot,'A1'],[bRoot,'B1'],[bRoot,'B2'],[aRoot,'A2']];
const results=order.map(([directory,label])=>{
 const file=path.join(directory,label+'.json'),r=read(file),process=read(path.join(directory,label+'.process.json')),
  validation=read(path.join(directory,label+'.validation.json'));
 assert.equal(r.status,'NORMAL_GC_TIMING_PASS');assert.equal(process.exitCode,0);assert.equal(process.completedWithinDeadline,true);
 assert.equal(validation.valid,true);assert.deepEqual(validation.nativeErrors,[]);assert.equal(r.collectorRunning,true);
 assert.equal(r.collectorGuardRestored,true);assert.equal(r.frames.length,240);assert.equal(r.configuration.warmup,120);
 assert.equal(r.profile,false);assert.equal(r.snapshots.length,4);assert.equal(r.initial.cars.length,8);
 assert.equal(r.totalStepMs,r.frames.reduce((sum,row)=>sum+row.ms,0));assert.equal(r.meanStepMs,r.totalStepMs/240);
 const sorted=r.frames.map(row=>row.ms).sort((x,y)=>x-y),quantile=q=>sorted[Math.ceil(q*sorted.length)-1];
 return {label,file,sha256:sha(fs.readFileSync(file)),r,summary:{label,totalMs:r.totalStepMs,meanMs:r.meanStepMs,
  p50Ms:quantile(.5),p95Ms:quantile(.95),p99Ms:quantile(.99),maxMs:sorted.at(-1),over80:r.frames.filter(row=>row.ms>80).length,
  minAlive:Math.min(...r.frames.map(row=>row.alive)),shots:r.frames.at(-1).shots-r.initial.shots,
  hits:r.frames.at(-1).hits-r.initial.hits,damage:r.frames.at(-1).damage-r.initial.damage,
  heapBeforeKiB:r.heapBeforeKiB,heapAfterKiB:r.heapAfterKiB}};
});
const workload=r=>({metadata:r.metadata,initial:r.initial,snapshots:r.snapshots,randomAfter:r.randomAfter,
 frames:r.frames.map(({ms,...row})=>row)});
for(const result of results.slice(1))assert.deepEqual(workload(result.r),workload(results[0].r),'Exact workload/state/RNG '+result.label);
assert(results[0].summary.shots>0,'Actual measured firing required');
const aMean=(results[0].r.meanStepMs+results[3].r.meanStepMs)/2,bMean=(results[1].r.meanStepMs+results[2].r.meanStepMs)/2;
const reduction=1-bMean/aMean,baselineDrift=Math.abs(results[0].r.meanStepMs-results[3].r.meanStepMs)/aMean;
const candidateDrift=Math.abs(results[1].r.meanStepMs-results[2].r.meanStepMs)/bMean;
const report={status:'NORMAL_GC_ABBA_EXACT_WORKLOAD_PASS',runs:results.map(result=>({...result.summary,file:result.file,sha256:result.sha256})),
 aMeanMs:aMean,bMeanMs:bMean,reductionFraction:reduction,baselineDriftFraction:baselineDrift,candidateDriftFraction:candidateDrift,
 signalAboveObservedDrift:reduction>Math.max(baselineDrift,candidateDrift),
 exactBehaviorAndWorkload:true,changedSources:changed,
 boundary:'Four independent serial Native processes, 120 warmup +240 fixed steps, natural automatic GC. Exact metadata/initial state/60-step snapshots/RNG and per-step alive/parts/shots/hits/damage match. Unwrapped simulation step wall timing; no graphics/audio/UI/full match consumers. Arithmetic gain is not sustained game FPS, Web performance or Snapdragon845 acceptance.'};
fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(report,null,2));

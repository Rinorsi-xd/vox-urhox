'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const readJson=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const inputs=process.argv.slice(2);assert.equal(inputs.length,4,'Four root-run JSON files in ABBA order required');
const rows=inputs.map(input=>{const result=readJson(input);
 const base=input.slice(0,-5),process=readJson(base+'.process.json'),validation=readJson(base+'.validation.json'),launch=readJson(base+'.launch.json');
 const identity=readJson(path.join(path.dirname(input),'identity.json'));
 assert(process.completedWithinDeadline&&process.exitCode===0,'Confirmed successful Runtime exit');
 assert(validation.valid&&validation.nativeErrors.length===0,'No Native ERROR lines');
 assert.equal(validation.timingValidity,'NORMAL_GC_FIXED_WORKLOAD_WALL');
 assert.equal(launch.timingValidity,'NORMAL_GC_FIXED_WORKLOAD_WALL');
 assert.deepEqual(launch.sourceHashes,identity.sourceHashes,'Launcher verified exact candidate');
 assert.deepEqual(result.configuration,identity.configuration,'Runtime configuration exact');
 assert.equal(result.status,'NORMAL_GC_TIMING_PASS');assert(result.collectorGuardRestored&&result.collectorRunning);
 assert.equal(result.frames.length,480);assert.equal(result.heightChecks,4862);
 const ms=result.frames.map(x=>x.ms),sum=ms.reduce((a,b)=>a+b,0);assert.equal(sum,result.totalStepMs);assert.equal(sum/480,result.meanStepMs);
 return {input:path.resolve(input),result,identity,launch};});
assert.deepEqual(rows.map(x=>x.result.configuration.variant),['A','B','B','A']);
const first=rows[0].result;
const sourceSubset=identity=>Object.fromEntries(Object.entries(identity.sourceHashes).filter(([key])=>!['scripts/core/HeightField.lua','scripts/heightfield-effects-native.lua'].includes(key)));
for(const row of rows){
 assert.equal(row.identity.sourceFrozenSha256,rows[0].identity.sourceFrozenSha256,'Same production freeze');
 assert.deepEqual(sourceSubset(row.identity),sourceSubset(rows[0].identity),'Only HeightField production module differs');
 assert.deepEqual(row.identity.projectHashes,rows[0].identity.projectHashes,'Same project configuration');
 assert.deepEqual(row.launch.assetInputs,rows[0].launch.assetInputs,'Same actual asset hashes');
 assert.deepEqual(row.launch.runtimeInputs,rows[0].launch.runtimeInputs,'Same actual Native Runtime');
 assert.deepEqual(row.launch.resourceInputs,rows[0].launch.resourceInputs,'Same engine resources');
 const expected=row.result.configuration.variant==='A'?'9e95855a228e49fd6c3b7fd8b7b7091a713d5478e0e3ca2fc112f1a096b8946a':'6e595e1a0f7fce56013ddbff63aca3ce9e2c60b86734990e105c9530675e4872';
 assert.equal(row.identity.sourceHashes['scripts/core/HeightField.lua'],expected);
}
for(const {result}of rows.slice(1)){
 assert.deepEqual(result.initial,first.initial,'Initial populations');
 assert.deepEqual(result.randomAfter,first.randomAfter,'Full RNG tail');
 assert.deepEqual(result.snapshots,first.snapshots,'Periodic full particle/smoke state digests');
 assert.equal(result.stateDigest,first.stateDigest,'Final state digest');
 assert.deepEqual(result.frames.map(({ms,...work})=>work),first.frames.map(({ms,...work})=>work),'Per-frame exact populations and batch counts');
}
const sums=rows.map(x=>x.result.totalStepMs),a=(sums[0]+sums[3])/2,b=(sums[1]+sums[2])/2;
const drift=Math.abs(sums[3]-sums[0])/a;
const reduction=(a-b)/a;
const percentile=(array,q)=>[...array].sort((a,b)=>a-b)[Math.ceil(array.length*q)-1];
const report={status:'MATCHED_ABBA_ANALYZED',inputs:rows.map(x=>x.input),
 rounds:rows.map(({result:r})=>({variant:r.configuration.variant,totalMs:r.totalStepMs,meanUpdateMs:r.meanStepMs,
  p95:percentile(r.frames.map(x=>x.ms),.95),max:r.maxStepMs,heapBeforeKiB:r.heapBeforeKiB,heapAfterKiB:r.heapAfterKiB})),
 aMeanUpdateMs:a/480,bMeanUpdateMs:b/480,reductionPercent:reduction*100,baselineDriftPercent:drift*100,
 equivalence:'All 480 per-frame populations/batch counts, 8 full particle/smoke snapshots, RNG and native exact height checks agree.',
 boundary:'Normal-GC real Effects.Update stress fixture; not full-game FPS, real-match Web or Snapdragon845/TapTap sustained acceptance. Any adoption needs root review and actual Web validation. Timing integer 1ms resolution.'};
console.log(JSON.stringify(report,null,2));

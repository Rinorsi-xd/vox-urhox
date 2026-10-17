'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function read(p){return JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''))}
const [aPath,bPath,outPath]=process.argv.slice(2);assert(aPath&&bPath&&outPath);
const directories=[aPath,bPath].map(p=>path.resolve(root,p)),output=path.resolve(root,outPath);assert(!fs.existsSync(output));
const identities=directories.map(p=>read(path.join(p,'identity.json')));
assert.deepEqual(Object.keys(identities[0].sourceHashes).sort(),Object.keys(identities[1].sourceHashes).sort());
const changed=Object.keys(identities[0].sourceHashes).filter(k=>identities[0].sourceHashes[k]!==identities[1].sourceHashes[k]);
assert.deepEqual(changed.sort(),['scripts/drive/HoverControl.lua','scripts/vehicle-ray-normal.lua'].sort());
for(const [index,id]of identities.entries()){
 assert.equal(id.timingValidity,'NORMAL_GC_FIXED_WORKLOAD_WALL');assert.equal(id.configuration.profile,false);
 assert.equal(id.configuration.variant,index===0?'A':'B');
 for(const [file,digest]of Object.entries(id.sourceHashes))assert.equal(sha(fs.readFileSync(path.join(directories[index],file))),digest,file);
}
assert.deepEqual(identities[0].roster,identities[1].roster);assert.deepEqual(identities[0].projectHashes,identities[1].projectHashes);
const order=[[0,'A1'],[1,'B1'],[1,'B2'],[0,'A2']];
const results=order.map(([index,label])=>{
 const dir=directories[index],file=path.join(dir,label+'.json'),r=read(file),process=read(path.join(dir,label+'.process.json')),
  validation=read(path.join(dir,label+'.validation.json')),launch=read(path.join(dir,label+'.launch.json'));
 assert.equal(r.status,'NORMAL_GC_TIMING_PASS');assert.equal(process.exitCode,0);assert.equal(process.completedWithinDeadline,true);
 assert.equal(validation.valid,true);assert.deepEqual(validation.nativeErrors,[]);
 assert(r.collectorRunning&&r.collectorGuardRestored);assert.equal(r.profile,false);
 assert.equal(r.frames.length,240);assert.equal(r.snapshots.length,4);assert.equal(r.initial.cars.length,8);
 assert.equal(r.totalStepMs,r.frames.reduce((s,f)=>s+f.ms,0));assert.equal(r.meanStepMs,r.totalStepMs/240);
 const sorted=r.frames.map(f=>f.ms).sort((a,b)=>a-b),q=p=>sorted[Math.ceil(p*sorted.length)-1];
 return {r,launch,summary:{label,file,sha256:sha(fs.readFileSync(file)),meanMs:r.meanStepMs,totalMs:r.totalStepMs,
  p95Ms:q(.95),p99Ms:q(.99),maxMs:sorted.at(-1),over80:r.frames.filter(f=>f.ms>80).length}};
});
const workload=r=>({metadata:r.metadata,initial:r.initial,snapshots:r.snapshots,randomAfter:r.randomAfter,
 frames:r.frames.map(({ms,...f})=>f)});
function firstDifference(a,b,where='$'){
 if(Object.is(a,b))return null;
 if(a===null||b===null||typeof a!==typeof b||typeof a!=='object')return {path:where,before:a,after:b};
 for(const key of new Set([...Object.keys(a),...Object.keys(b)])){
  const difference=firstDifference(a[key],b[key],where+(Array.isArray(a)?'['+key+']':'.'+key));
  if(difference)return difference;
 }
 return null;
}
const comparisons=[];
for(const r of results.slice(1)){
 const expected=workload(results[0].r),actual=workload(r.r);
 comparisons.push({against:'A1',label:r.summary.label,
  fields:Object.fromEntries(Object.keys(expected).map(key=>[key,firstDifference(expected[key],actual[key],key)]))});
 assert.equal(r.launch.runtimeSha256,results[0].launch.runtimeSha256);
 assert.deepEqual(r.launch.resourceInputs,results[0].launch.resourceInputs);
 assert.deepEqual(r.launch.assetInputs,results[0].launch.assetInputs);
}
assert(results[0].r.frames.at(-1).shots>results[0].r.initial.shots,'Actual firing coverage');
const a=(results[0].r.meanStepMs+results[3].r.meanStepMs)/2,b=(results[1].r.meanStepMs+results[2].r.meanStepMs)/2,
 reduction=1-b/a,aDrift=Math.abs(results[0].r.meanStepMs-results[3].r.meanStepMs)/a,
 bDrift=Math.abs(results[1].r.meanStepMs-results[2].r.meanStepMs)/b;
const exact=comparisons.every(c=>Object.values(c.fields).every(value=>value===null));
const report={status:exact?'NORMAL_GC_ABBA_EXACT_WORKLOAD_PASS':'FAIL_EXACT_WORKLOAD',
 candidateDecision:exact&&reduction>Math.max(aDrift,bDrift)?'MEASURED_CANDIDATE_NOT_ADOPTED':'REJECTED',
 runs:results.map(r=>r.summary),changedSources:changed,comparisons,
 candidateRepeatFirstDifference:firstDifference(workload(results[1].r),workload(results[2].r)),
 aMeanMs:a,bMeanMs:b,baselineDriftFraction:aDrift,candidateDriftFraction:bDrift,
 ...(exact?{reductionFraction:reduction,signalAboveObservedDrift:reduction>Math.max(aDrift,bDrift)}:{}),
 exactBehaviorAndWorkload:exact,productionChanged:false,
 boundary:'Four serial Native processes,120warmup+240steps,normal automatic GC. A/B initial state,step workload,snapshots and RNG must match exactly before any gain calculation. Integer simulation wall time, no full-game render/audio/UI or Web/FPS/device claim. State mismatch or gain below observed drift is rejected.'};
fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(report,null,2));
if(!exact)process.exitCode=1;

// Offline failure record. Preserve strict paired rejection and original inputs.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),util=require('node:util');
const {analyze}=require('./analyze-single-step-allocation.cjs');
const {paired}=require('./analyze-gc-ray-allocation-next.cjs');
const root=path.resolve(__dirname,'../..'),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function load(directory){
 const location=path.resolve(root,directory);const raw=fs.readFileSync(path.join(location,'allocation-1.json'));
 const identityRaw=fs.readFileSync(path.join(location,'identity.json'));const identity=JSON.parse(identityRaw),value=JSON.parse(raw);
 for(const [relative,expected]of Object.entries({...identity.sourceHashes,...identity.projectHashes}))
  assert.equal(sha(fs.readFileSync(path.join(location,relative))),expected,'Frozen input '+relative);
 const result=analyze(value,identity);assert.equal(result.status,'INDEPENDENT_SINGLE_STEP_ALLOCATION_PASS');
 const process=JSON.parse(fs.readFileSync(path.join(location,'allocation-1.process.json')));
 const validation=JSON.parse(fs.readFileSync(path.join(location,'allocation-1.validation.json')));
 assert.equal(process.exitCode,0);assert.equal(process.completedWithinDeadline,true);
 assert.equal(validation.valid,true);assert.deepEqual(validation.nativeErrors,[]);
 return {value,identity,process,validation,path:path.join(location,'allocation-1.json'),hashes:{raw:sha(raw),identity:sha(identityRaw)}};
}
function differences(a,b,at='',out=[],limit=32){
 if(out.length>=limit||util.isDeepStrictEqual(a,b))return out;
 if(a&&b&&typeof a==='object'&&typeof b==='object'){
  for(const key of [...new Set([...Object.keys(a),...Object.keys(b)])].sort())differences(a[key],b[key],at+'.'+key,out,limit);
 }else out.push({path:at,before:a===undefined?'MISSING':a,detailed:b===undefined?'MISSING':b});
 return out;
}
const directory=process.argv[2]||'.tmp/gc-ray-allocation-4a3a-1017-a';
const before=load(path.join(directory,'baseline')),detailed=load(path.join(directory,'detailed'));
let rejection=false;try{paired(before.path,detailed.path)}catch(error){rejection={name:error.name,message:error.message.split('\n')[0],code:error.code||false}}
assert(rejection&&rejection.message==='Unchanged actual sampled workload: snapshots','Preserve actual strict paired rejection');
const samples=before.value.snapshots.map((sample,index)=>({step:sample.step,
 differingCars:sample.cars.flatMap((car,i)=>{
  const other=detailed.value.snapshots[index].cars[i];if(util.isDeepStrictEqual(car,other))return [];
  return [{index:i+1,name:before.value.metadata[i].name,driverBefore:car.driver,driverDetailed:other.driver,
   stateEqual:util.isDeepStrictEqual(car.state,other.state),positionEqual:util.isDeepStrictEqual(car.state.p,other.state.p),
   firstDifferences:differences(car,other,'car'+(i+1),[],4)}];
 })}));
const sharedCalls=before.value.allocation.totals.flatMap(row=>{
 const fresh=detailed.value.allocation.totals.find(item=>item.name===row.name);assert(fresh);
 return row.calls===fresh.calls?[]:[{name:row.name,before:row.calls,detailed:fresh.calls}];
});
const result={status:'FAIL_PAIRED_WORKLOAD_MISMATCH',timingValidity:'INVALID_FOR_PERFORMANCE',rejection,
 inputs:{baseline:{path:before.path,...before.hashes,process:before.process},detailed:{path:detailed.path,...detailed.hashes,process:detailed.process}},
 individualDiagnostics:'BOTH_COMPLETE_RESTORED_ERROR_FREE',samples:samples.length,measuredShots:{baseline:before.value.measuredShots,detailed:detailed.value.measuredShots},
 warmup:{steps:before.value.configuration.warmup,countersEqual:util.isDeepStrictEqual(before.value.workload.baseline,detailed.value.workload.baseline),
  counters:before.value.workload.baseline,stateSnapshotsAvailable:false,divergenceBeforeObserverKnown:false},
 metadataEqual:util.isDeepStrictEqual(before.value.metadata,detailed.value.metadata),
 finalWorkloadEqual:util.isDeepStrictEqual(before.value.workload.final,detailed.value.workload.final),
 rngDifferences:differences(before.value.rngFinal,detailed.value.rngFinal,'rngFinal'),
 sharedBoundaryCallDifferences:sharedCalls,snapshotDifferences:samples,
 sourceReview:{files:['EnemyDriver.lua','EnemyDriverThink.lua','EnemyDriverMotion.lua','EnemyDriverNav.lua','EnemyDriverTactics.lua','EnemyDriverMath.lua'].map(name=>{
  const relative='scripts/combat/'+name;const source=fs.readFileSync(path.join(root,relative));
  return {path:relative,sha256:sha(source),wallClockRandomReferenceFound:/os\.(?:clock|time)|GetSystemTime|GetElapsedTime/.test(source.toString())};
 }),finding:'Reviewed driver code uses explicit seeded generator and accumulated fixed-dt s.time. No wall-clock RNG reference found in these six modules; not proof of determinism of native physics or all callees.'},
 cause:'NOT_ESTABLISHED',next:'Capture exact post-assembly and post-warmup pre-observer states in both arms, retain strict gates, then compare A/A before changing physics or RNG. If pre-observer states match, run actual same-ray original/routed shadow equality before trusting detailed attribution.',
 boundary:'Offline audit of two real Native allocation diagnostics. No timings or allocation ratios compared as optimization benefits. Missing pre-observer state prevents dating the divergence. Original raw files, failed gate and production remain unchanged. No Runtime/browser/server launched.'};
const output=process.argv[3]||path.join(root,'docs/migration/evidence/gc-ray-allocation-next-native-1017-a-fail.json');
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:result.status,rejection,samples:result.samples,warmup:result.warmup,rngDifferences:result.rngDifferences,sharedCalls,snapshotFirst:samples[0],output},null,2));

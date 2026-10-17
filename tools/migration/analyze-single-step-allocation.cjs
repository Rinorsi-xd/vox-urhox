// Reject aborted/partial stopped-GC samples before generating owner rankings.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
function analyze(result,identity){
 assert.equal(identity.status,'READY_NOT_RUN');assert.equal(identity.timingValidity,'INVALID_FOR_PERFORMANCE');
 assert.equal(result.status,'ALLOCATION_DIAGNOSTIC_PASS');assert.equal(result.timingValidity,'INVALID_FOR_PERFORMANCE');
 assert.deepEqual(result.configuration,identity.configuration);
 assert.equal(result.collectorMutationGuard,true);assert.equal(result.collectorGuardRestored,true);
 assert.deepEqual(result.rosterIdentity,identity.roster);
 const a=result.allocation;assert.equal(a.aborted,false);assert.equal(a.restored,true);assert.equal(a.modeUntouched,true);
 assert.equal(a.allocationValidity,'COMPLETE_SAMPLES_ONLY');assert.equal(a.timingValidity,'INVALID_FOR_PERFORMANCE');
 assert.equal(a.limitKiB,16384);assert.equal(a.deadlineMs,250);
 assert.equal(a.frames.length,identity.configuration.samples);assert.equal(result.metadata.length,8);
 assert.equal(result.metadata.filter(x=>x.manual).length,1);
 assert.equal(new Set(a.names).size,a.names.length);assert.equal(a.totals.length,a.names.length);
 const sum=(xs)=>xs.reduce((n,v)=>n+v,0),close=(left,right,label)=>assert(Math.abs(left-right)<1e-6,label);
 const ids=new Map(a.names.map((name,id)=>[name,id]));
 const row=(frame,name)=>frame.rows[assertId(name)];
 function assertId(name){assert(ids.has(name),'Required observed stage '+name);return ids.get(name)}
 let measuredShots=0;
 for(const [index,frame]of a.frames.entries()){
  assert.equal(frame.complete,true);assert.equal(frame.restored,true);assert.equal(frame.error,false);
  assert.equal(frame.modeUntouched,true);assert.equal(frame.rows.length,a.names.length);
  assert.equal(frame.step,identity.configuration.warmup+(index+1)*(identity.configuration.normalBetween+1));
  assert(frame.netKiB>=0&&frame.netKiB<=16384,'Complete stopped-GC heap budget');
  assert(frame.wallMsDiagnosticOnly>=0&&frame.wallMsDiagnosticOnly<=250,'Complete stopped-GC deadline');
  close(frame.endKiB-frame.startKiB,frame.netKiB,'Net heap arithmetic');
  close(frame.netKiB-frame.measuredKiB,frame.unscopedKiB,'Unscoped heap arithmetic');
  close(sum(frame.rows.map(x=>x.selfKiB)),frame.measuredKiB,'Exclusive owner conservation');
  for(const r of frame.rows){assert(r.calls>=0&&r.errors===0);assert(r.selfKiB>=-1e-6&&r.inclusiveKiB>=-1e-6);assert(r.maxKiB<=r.inclusiveKiB+1e-6)}
  assert.equal(row(frame,'fixed.CompleteStep').calls,1);assert.equal(row(frame,'fixed.WorldStep').calls,1);
  assert.equal(row(frame,'physics.Space.Step').calls,1);assert.equal(row(frame,'drive.Vehicle.Step').calls,8);
  assert.equal(row(frame,'combat.EnemyDriver.Step').calls,7);assert.equal(row(frame,'combat.WeaponSystem.Step').calls,8);
  assert.equal(row(frame,'fixture.DrainUnit').calls,8);assert.equal(row(frame,'fixture.DrainWorld').calls,1);
  assert(Number.isInteger(frame.shots)&&frame.shots>=0);assert(Number.isInteger(frame.hits)&&frame.hits>=0);
  assert(frame.firingRequests>=1&&frame.firingRequests<=8);assert.equal(frame.cooldownOnly,frame.shots===0);
  measuredShots+=frame.shots;
 }
 assert(measuredShots>0);assert.equal(result.measuredShots,measuredShots);
 for(const [id,total]of a.totals.entries()){
  assert.equal(total.name,a.names[id]);assert.equal(total.errors,0);
  for(const field of ['calls','inclusiveKiB','selfKiB','errors'])close(total[field],sum(a.frames.map(f=>f.rows[id][field])),'Owner total '+total.name+'.'+field);
  close(total.maxKiB,Math.max(...a.frames.map(f=>f.rows[id].maxKiB)),'Owner maximum '+total.name);
 }
 const totals=a.totals.map(r=>({...r,meanKiBPerCall:r.calls?r.inclusiveKiB/r.calls:0,selfKiBPerStep:r.selfKiB/a.frames.length}));
 const totalNet=sum(a.frames.map(f=>f.netKiB));
 return {status:'INDEPENDENT_SINGLE_STEP_ALLOCATION_PASS',timingValidity:'INVALID_FOR_PERFORMANCE',
  configuration:result.configuration,rosterIdentity:result.rosterIdentity,map:result.map,metadata:result.metadata,
  measuredShots,measuredHits:sum(a.frames.map(f=>f.hits)),cooldownOnlySamples:a.frames.filter(f=>f.cooldownOnly).map(f=>f.step),
  netKiB:totalNet,netKiBPerStep:totalNet/a.frames.length,unscopedKiB:sum(a.frames.map(f=>f.unscopedKiB)),
  ownersByExclusiveKiB:[...totals].sort((a,b)=>b.selfKiB-a.selfKiB),
  ownersByInclusiveKiB:[...totals].sort((a,b)=>b.inclusiveKiB-a.inclusiveKiB),
  unexercised:totals.filter(r=>r.calls===0).map(r=>r.name),
  collector:{runningRestored:a.restored,modeUntouched:a.modeUntouched,mutatorGuard:true,maxIntervalSteps:1,limitKiB:a.limitKiB,deadlineMs:a.deadlineMs},
  boundaries:[
   'Only complete error-free samples with restored collector and exclusive-owner conservation enter rankings; aborted partials are rejected.',
   'One real eight-vehicle 60Hz CPU step per stopped-GC interval; timing is INVALID, not an optimization CPU/FPS A/B.',
   'Lua heap allocations include native binding/observer work; inclusive parents overlap. No inferred GPU/WASM bytes or GC wall duration.',
   'Captured eight vehicle sources run with nearest-live-enemy selection, seven AI drivers and one manual held-fire player. This CPU fixture has no rendering/audio/UI/objective consumers.',
   'DrainUnit and DrainWorld explicitly account for fixture output-queue replacement; unexercised effects are not covered.',
  ]};
}
module.exports={analyze};
if(require.main===module){
 const input=path.resolve(process.argv[2]),identityFile=path.resolve(process.argv[3]);
 const resultBytes=fs.readFileSync(input),identityBytes=fs.readFileSync(identityFile);
 const identity=JSON.parse(identityBytes);for(const [relative,expected]of Object.entries({...identity.sourceHashes,...identity.projectHashes})){
  assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(identity.target,relative))).digest('hex'),expected,'Frozen fixture source '+relative);
 }
 const result=analyze(JSON.parse(resultBytes),identity);
 result.inputHashes={result:crypto.createHash('sha256').update(resultBytes).digest('hex'),identity:crypto.createHash('sha256').update(identityBytes).digest('hex')};
 const out=process.argv[4]?path.resolve(process.argv[4]):input.replace(/\.json$/,'-independent.json');
 fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({status:result.status,netKiBPerStep:result.netKiBPerStep,measuredShots:result.measuredShots,
  exclusiveTop:result.ownersByExclusiveKiB.slice(0,15),inclusiveTop:result.ownersByInclusiveKiB.slice(0,8),output:out},null,2));
}

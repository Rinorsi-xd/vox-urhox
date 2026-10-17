// Strict paired allocation attribution, deliberately excluding timing claims.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {analyze}=require('./analyze-single-step-allocation.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function inspect(file){
 const directory=path.dirname(path.resolve(file));const raw=fs.readFileSync(file),idRaw=fs.readFileSync(path.join(directory,'identity.json'));
 const value=JSON.parse(raw),identity=JSON.parse(idRaw);
 for(const [relative,hash]of Object.entries({...identity.sourceHashes,...identity.projectHashes}))
  assert.equal(sha(fs.readFileSync(path.join(directory,relative))),hash,'Frozen fixture drift '+relative);
 assert.equal(value.rayObserverRestored,true);assert(value.rngFinal&&value.rngFinal.cars.length===8);
 return {value,identity,result:analyze(value,identity),hashes:{raw:sha(raw),identity:sha(idRaw)}};
}
function paired(beforeFile,detailedFile){
 const before=inspect(beforeFile),detailed=inspect(detailedFile);
 assert.equal(before.identity.gcRayAttribution.detailed,false);assert.equal(detailed.identity.gcRayAttribution.detailed,true);
 assert.deepEqual(before.value.configuration,detailed.value.configuration);
 assert.deepEqual(before.value.rosterIdentity,detailed.value.rosterIdentity);
 for(const key of ['metadata','snapshots','workload','rngFinal','measuredShots'])
  assert.deepEqual(before.value[key],detailed.value[key],'Unchanged actual sampled workload: '+key);
 const all=detailed.result.ownersByInclusiveKiB;
 const get=name=>assertDefined(all.find(row=>row.name===name),name);
 function assertDefined(value,name){assert(value,'Missing measured route '+name);return value}
 const cast=get('gcRay.Cast'),cold=get('gcRay.coldBounds'),cached=get('gcRay.cachedBounds');
 assert(cast.calls>0&&cold.calls>0&&cached.calls>0,'Require actual cold and cached coverage');
 assert.equal(cast.calls,cold.calls+cached.calls);
 for(const old of before.value.allocation.totals){
  const fresh=detailed.value.allocation.totals.find(row=>row.name===old.name);
  assert(fresh);assert.equal(fresh.calls,old.calls,'Shared observer workload '+old.name);
 }
 return {status:'PAIRED_ALLOCATION_ATTRIBUTION_PASS',timingValidity:'INVALID_FOR_PERFORMANCE',
  hashes:{before:before.hashes,detailed:detailed.hashes},frames:detailed.value.allocation.frames.length,
  workloadEqual:true,sampledSnapshotsEqual:true,finalRngSentinelsEqual:true,routes:{cast,cold,cached},
  math:all.filter(row=>row.name.startsWith('gcRay.math.')),
  measuredHeap:{beforeKiBPerStep:before.result.netKiBPerStep,detailedKiBPerStep:detailed.result.netKiBPerStep},
  boundary:'Attribution only. Extra routing/wrapper costs change heap and execution; no CPU/FPS subtraction permitted. Cold means no rayBounds on entry, not a measured exclusive Bounds function. Math inclusive entries overlap nested helpers. Equal sampled state, workload, shared calls and final one-draw RNG sentinels do not assert identical hidden state at every intermediate step.'};
}
module.exports={paired};
if(require.main===module){const report=paired(process.argv[2],process.argv[3]);assert(process.argv[4],'Fresh output path required');fs.writeFileSync(process.argv[4],JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(report,null,2))}

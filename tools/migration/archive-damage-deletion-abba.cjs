const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const source=path.join(root,'.tmp/perf-damage-flush-deletion-c935-1017');
const target=path.join(root,'docs/migration/evidence/native-damage-deletion-c935-2026-10-17');
assert(!fs.existsSync(target),'Preserve prior archive');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const labels=['deletion-A1','deletion-B1','deletion-B2','deletion-A2'];
const summaryName=labels.join('-')+'.independent-abba.json';
const summary=read(path.join(source,summaryName));
const identity=read(path.join(source,'identity.json'));
assert.equal(summary.status,'NATIVE_ABBA_VERIFIED');
for(const [name,hash] of Object.entries(summary.inputs))assert.equal(sha(path.join(source,name)),hash,'Summary input mismatch '+name);
for(const variant of ['A','B'])for(const [name,hash] of Object.entries(identity.variants[variant].hashes))assert.equal(sha(path.join(identity.variants[variant].directory,name)),hash,'Frozen source mismatch '+name);
for(const [name,hash] of Object.entries(identity.resourceInputs))assert.equal(sha(path.join(identity.resources,name)),hash,'Resource mismatch '+name);
for(const [name,hash] of Object.entries(identity.runtimeInputs))assert.equal(sha(path.join(identity.runtimeDirectory,name)),hash,'Runtime mismatch '+name);
const difference=Object.keys(identity.variants.A.hashes).filter(name=>identity.variants.A.hashes[name]!==identity.variants.B.hashes[name]);
assert.deepEqual(difference,['scripts/construction/TurretRange.lua']);
const baseline=path.join(root,'.tmp/perf-damage-flush-c935-1017/scripts/construction/TurretRange.lua');
const candidate=path.join(root,'tools/migration/candidates/TurretRangeSampledDeletion.lua');
assert.equal(sha(candidate),'05201936c1772a7c36f8ddac26095e5d1112e8a714621922638009867095591d');
const hook=text=>text.replace(/\breturn M\s*$/,'M.__ProbeCachePresent=function(bp)return cached[bp]~=nil end\nreturn M\n');
assert.equal(fs.readFileSync(path.join(identity.variants.A.directory,'scripts/construction/TurretRange.lua'),'utf8'),hook(fs.readFileSync(baseline,'utf8')));
assert.equal(fs.readFileSync(path.join(identity.variants.B.directory,'scripts/construction/TurretRange.lua'),'utf8'),hook(fs.readFileSync(candidate,'utf8')));
assert.deepEqual(identity.nativeTolerance,{float32Ulps:2,absoluteComponent:1e-4,positionEuclideanMetres:1e-4,slack:1e-12});
const ulp=value=>value===0?2**-149:Math.max(2**-149,2**(Math.floor(Math.log2(Math.abs(value)))-23));
let nativeStates=0,nativeComponents=0,maxDrift=0;
function native(a,b){
  const pure=value=>Object.fromEntries(Object.entries(value).filter(([key])=>!['p','q','lv','av'].includes(key)));
  assert.deepEqual(pure(a),pure(b));let squared=0;
  for(const key of ['p','q','lv','av'])for(const component of key==='q'?['x','y','z','w']:['x','y','z']){
    const x=a[key][component],y=b[key][component],delta=Math.abs(x-y);
    assert(Number.isFinite(x)&&Number.isFinite(y));assert(delta<=1e-4&&delta<=2*Math.max(ulp(x),ulp(y))+1e-12);
    if(key==='p')squared+=delta*delta;nativeComponents++;
  }
  assert(Math.sqrt(squared)<=1e-4);maxDrift=Math.max(maxDrift,Math.sqrt(squared));nativeStates++;
}
let reference;const totals=[];
for(const [index,label] of labels.entries()){
  const result=read(path.join(source,label+'.json'));
  const processRecord=read(path.join(source,label+'.process.json'));
  const validation=read(path.join(source,label+'.validation.json'));
  assert.equal(processRecord.exitCode,0);assert.equal(validation.valid,true);assert.equal(validation.nativeErrors.length,0);
  assert.equal(result.status,'PASS');assert.equal(result.steps.length,192);assert.equal(result.metadata.length,64);assert.equal(result.loading.length,64);
  assert.equal(result.cleanup,true);assert.equal(result.collectorRunning,true);assert.deepEqual(result.batchCleanup,Array(8).fill(true));
  for(const suffix of ['stdout.log','stderr.log'])assert(!/\bERROR:/.test(fs.readFileSync(path.join(source,label+'.'+suffix),'utf8')));
  for(const load of result.loading){assert.equal(load.clearanceWarm,false);assert.equal(load.primeCheckpoints,0);assert.equal(load.misses,0);assert.equal(load.hits,load.unit);}
  const pureSteps=result.steps.map(step=>({batch:step.batch,unit:step.unit,step:step.step,target:step.target,partsBefore:step.partsBefore,partsAfter:step.partsAfter,events:step.events,signature:step.signature,signatureBytes:step.signatureBytes}));
  const pureMeta=result.metadata.map(({state,...row})=>row);
  for(let i=0;i<result.steps.length;i++){
    const step=result.steps[i];assert.equal(step.behaviorChecks,true);assert.equal(step.alive,true);assert.equal(step.partsAfter,step.partsBefore-1);native(step.stateBefore,step.stateAfter);
    if(step.step===1)native(result.metadata[(step.batch-1)*8+step.unit-1].state,step.stateBefore);else native(result.steps[i-1].stateAfter,step.stateBefore);
  }
  if(!reference)reference={result,pureSteps,pureMeta};else{
    assert.deepEqual(pureSteps,reference.pureSteps);assert.deepEqual(pureMeta,reference.pureMeta);
    for(let i=0;i<result.metadata.length;i++)native(reference.result.metadata[i].state,result.metadata[i].state);
    for(let i=0;i<result.steps.length;i++)for(const key of ['stateBefore','stateAfter'])native(reference.result.steps[i][key],result.steps[i][key]);
  }
  const sum=(rows,get)=>rows.reduce((n,row)=>n+get(row),0);
  const round=[1,2,3].map(number=>sum(result.steps.filter(step=>step.step===number),step=>step.stats['unit.Flush'].wallMs));
  const flush=sum(result.steps,step=>step.stats['unit.Flush'].wallMs),turret=sum(result.steps,step=>step.stats['turretRange.For'].wallMs);
  const loading=sum(result.loading,load=>load.prepare.wallMs+load.spawn.wallMs);
  assert.equal(flush,summary.passes[index].sums['unit.Flush'].wallMs);assert.equal(turret,summary.passes[index].sums['turretRange.For'].wallMs);
  assert.equal(loading,summary.passes[index].loading.total.wallMs);assert.deepEqual(round,summary.passes[index].rounds.map(row=>row.flushWallMs));
  totals.push({label,flush,turret,loading,round,maxSingleFlushMs:Math.max(...result.steps.map(step=>step.stats['unit.Flush'].wallMs)),outerFlushMs:sum(result.steps,step=>step.flush.wallMs)});
}
assert.equal(nativeStates,summary.nativeChecks.states);assert.equal(nativeComponents,summary.nativeChecks.components);assert.equal(maxDrift,summary.nativeChecks.maxPositionDriftMetres);
const review={status:'INDEPENDENT_NATIVE_EVIDENCE_REVIEW_PASS',summarySha256:sha(path.join(source,summaryName)),sourceDifference:difference,nativeStates,nativeComponents,maxPositionDriftMetres:maxDrift,totals,
  verdict:'Small complete-workload gain, strong later-damage gain, cold first-damage slightly slower. Not sufficient to claim fixed stutters, sustained combat FPS, Web equivalence, or Snapdragon845 acceptance. Candidate remains separate from cache adoption; no production edits.',
  comparisons:summary.comparisons};
fs.mkdirSync(target,{recursive:true});const entries=[];
function copy(src,name){const dst=path.join(target,name);fs.mkdirSync(path.dirname(dst),{recursive:true});fs.copyFileSync(src,dst);assert.equal(sha(src),sha(dst));entries.push({source:path.relative(root,src).replaceAll('\\','/'),archive:name,sha256:sha(src),bytes:fs.statSync(src).size});}
for(const entry of fs.readdirSync(source,{withFileTypes:true}))if(entry.isFile())copy(path.join(source,entry.name),'originals/'+entry.name);
for(const name of ['perf-damage-flush-deletion-native.lua','perf-damage-flush-deletion-prepare.cjs','perf-damage-flush-deletion-run.ps1','perf-damage-flush-deletion-analyze.cjs','check-turret-sampled-deletion.lua','check-turret-sampled-deletion.py'])copy(path.join(root,'tools/migration',name),'tools/'+name);
copy(candidate,'candidate/TurretRange.lua');copy(baseline,'baseline/TurretRange.lua');
copy(path.join(root,'docs/migration/evidence/turret-sampled-deletion-offline-2026-10-17.json'),'offline-correctness.json');
copy(path.join(root,'tools/migration/archive-damage-deletion-abba.cjs'),'tools/archive-damage-deletion-abba.cjs');
fs.writeFileSync(path.join(target,'independent-review.json'),JSON.stringify(review,null,2));
fs.writeFileSync(path.join(target,'archive-sha256.json'),JSON.stringify({originalsPreserved:true,entries,derived:['independent-review.json']},null,2));
console.log(JSON.stringify({status:review.status,target,files:entries.length,nativeStates,nativeComponents,maxDrift,totals}));

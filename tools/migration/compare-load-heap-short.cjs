'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {analyze}=require('./analyze-load-heap-short.cjs');
function compare(baselineDirectory,candidateDirectory){
 const baseline=analyze(baselineDirectory),candidate=analyze(candidateDirectory),report=JSON.parse(fs.readFileSync(path.join(candidateDirectory,'result.json')));
 assert.deepEqual(candidate.loading.prepared.map(row=>row.name),baseline.loading.prepared.map(row=>row.name),'Exact preparation resource order');
 assert.equal(candidate.loading.modelCount,282);assert.equal(candidate.loading.preparedCount,283);
 assert.deepEqual(report.stateTransportWarnings,[]);assert.equal(report.checks.length,9);assert.equal(report.acknowledgement.status,'ACK_CLOSED_IN_HALL');
 assert.ok(report.browserInjection.responses.some(row=>row.sha256===report.candidate.candidateSha256));
 const state=report.activatedScreenshotState;assert.equal(state.mode,'trial');assert.equal(state.loadingFlow.active,false);assert.equal(state.salvageRun.cine.playing,false);assert.equal(state.salvageRun.cine.holding,false);assert.equal(state.salvageRun.cine.nativeKinematic,false);assert.equal(state.pointer.captured,true);
 const fullSteps=Object.fromEntries(report.activation.loadingFlow.steps.map(row=>[row.id,row.elapsed]));
 return {result:'PASS_DIAGNOSTIC_COMPARISON_VISUAL_OPEN',baselineEvidence:path.resolve(baselineDirectory),candidateEvidence:path.resolve(candidateDirectory),
  identities:{baselineSourceSha256:baseline.loading.executedSourceSha256,candidateSourceSha256:candidate.loading.executedSourceSha256,actualCandidateResponseVerified:true},resourceOrderIdentical:true,preparedResources:283,models:282,
  phaseTimes:{baseline:baseline.loading.phaseTimes,candidate:candidate.loading.phaseTimes,candidateCompleteActivationSteps:fullSteps},
  modelSpan:{baselineMs:baseline.loading.modelSpanWallMs,candidateMs:candidate.loading.modelSpanWallMs,deltaMs:candidate.loading.modelSpanWallMs-baseline.loading.modelSpanWallMs,baselineFrames:baseline.loading.modelSpanFrames,candidateFrames:candidate.loading.modelSpanFrames},
  boundaryMemory:candidate.samples.map((row,i)=>({tag:row.tag,baselineInUseMiB:baseline.samples[i].inUseMiB,candidateInUseMiB:row.inUseMiB,deltaInUseMiB:row.inUseMiB-baseline.samples[i].inUseMiB,baselineResourceMiB:baseline.samples[i].resourceBytes/1048576,candidateResourceMiB:row.resourceBytes/1048576,baselineLuaMiB:baseline.samples[i].luaBytes/1048576,candidateLuaMiB:row.luaBytes/1048576})),
  candidateScreenshotState:{mode:state.mode,phase:state.loadingFlow.phase,captured:state.pointer.captured,simulationTime:state.salvageRun.time,cine:state.salvageRun.cine,camera:state.camera,vehicle:state.vehicle,batches:state.performance.batches,primitives:state.performance.primitives},
  visualAcceptance:'OPEN: activated.png independently viewed as brown background plus HUD. Snapshot is after natural drop, released vehicle and pointer capture. Landing dust age exceeds 2.6s lifetime. It is not a screenshot before the natural landing. Geometry submission counts do not prove a correctly visible map, shader, or camera. No later active-game screenshot was captured.',
  boundary:'Observed loading timing only; no combat FPS or mobile/thermal acceptance. Sparse allocator queries are intrusive. Cache, allocator and Lua overlap. Network/cache warmness is uncontrolled. Aggregate endpoints do not attribute native owners or establish a full peak.'};
}
module.exports={compare};
if(require.main===module){assert.equal(process.argv.length,4);const candidateDirectory=path.resolve(process.argv[3]),result=compare(path.resolve(process.argv[2]),candidateDirectory);fs.writeFileSync(path.join(candidateDirectory,'independent-baseline-comparison.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({...result,candidateScreenshotState:undefined},null,2))}

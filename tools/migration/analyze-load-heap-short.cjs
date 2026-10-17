'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex'),MiB=1024*1024;
function analyze(directory){
 const read=name=>fs.readFileSync(path.join(directory,name),'utf8'),jsonl=name=>read(name).trim().split('\n').filter(Boolean).map(line=>JSON.parse(line));
 const result=JSON.parse(read('result.json')),markers=jsonl('load-boundaries.jsonl'),diagnostics=jsonl('load-diagnostics.jsonl'),states=jsonl('states.jsonl');
 assert.equal(result.result,'PASS');assert.equal(result.shutdown.status,'CLOSED');assert.equal(markers.length,6);
 const tags=['hall-stable','old-hall-cleaned','resources-ready','physics-prepared','activation-closed','returned-cleanup'];assert.deepEqual(markers.map(row=>row.tag),tags);assert.ok(result.errors.length===0&&result.httpErrors.length===0&&result.probeErrors.length===0);
 const samples=markers.map((marker,index)=>{
  assert.equal(marker.sequence,index+1);
  const start=diagnostics.filter(row=>row.kind==='sample-start'&&row.tags.includes(marker.tag));assert.equal(start.length,1,'Actual uncoalesced per-phase sample '+marker.tag);assert.equal(start[0].tags.length,1);
  const records=diagnostics.filter(row=>row.kind==='allocator-result'&&row.id===start[0].id);assert.equal(records.length,1);const sample=records[0].allocator;assert.equal(sample.status,'OK');assert.equal(sample.kind,'sample');
  const end=diagnostics.filter(row=>row.kind==='sample-end'&&row.id===start[0].id);assert.equal(end.length,1);assert.equal(end[0].status,'OK');
  assert.ok(diagnostics.some(row=>row.kind==='sample-following-frame'&&row.id===start[0].id));
  return {tag:marker.tag,frame:marker.frame,engineWallMs:marker.engineWallMs,allocatorWallMs:sample.wallMs,inUseBytes:sample.inUseBytes,inUseMiB:sample.inUseBytes/MiB,
   freeBytes:sample.freeBytes,arenaBytes:sample.arenaBytes,capacityBytes:sample.capacityBytes,resourceBytes:marker.resourceBytes,luaBytes:marker.luaKiB*1024,
   sampleDurationMs:sample.durationMs,schedulingDelayMs:start[0].delaysMs[0],markerToSampleBoundary:'Marker cache/Lua and deferred allocator totals are different instants and overlap; never sum them.'};
 });
 assert.ok(diagnostics.every(row=>row.excludeFromFps&&row.diagnostic));assert.ok(!diagnostics.some(row=>row.kind==='observer-error'||row.kind==='late-same-frame-boundary'));
 const deltas=samples.slice(1).map((row,index)=>{const prior=samples[index];return {from:prior.tag,to:row.tag,engineWallMs:row.engineWallMs-prior.engineWallMs,engineFrames:row.frame-prior.frame,
  allocatorInUseBytes:row.inUseBytes-prior.inUseBytes,allocatorInUseMiB:(row.inUseBytes-prior.inUseBytes)/MiB,
  resourceBytes:row.resourceBytes-prior.resourceBytes,resourceMiB:(row.resourceBytes-prior.resourceBytes)/MiB,luaBytes:row.luaBytes-prior.luaBytes,luaMiB:(row.luaBytes-prior.luaBytes)/MiB}});
 const prepared=[];
 for(const line of read('runtime.log').split('\n')){
  const match=line.match(/^\[([^\]]+)\]\[(\d+)\].*?\[SceneLoader\] Prepared (\S+) bytes=([\d.]+) cache=([\d.]+)/);if(!match)continue;
  const n=match[1].match(/\d+/g).map(Number);prepared.push({name:match[3],frame:+match[2],wallMs:Date.UTC(n[0],n[1]-1,n[2],n[3],n[4],n[5],n[6]),memoryBytes:+match[4],cacheBytes:+match[5]});
 }
 const models=prepared.filter(row=>row.name.startsWith('Salvage/run-model-'));
 const intervals=models.slice(1).map((row,index)=>({after:models[index].name,before:row.name,engineFrames:row.frame-models[index].frame,wallMs:row.wallMs-models[index].wallMs,memoryBytes:row.memoryBytes}));
 const histogram=key=>Object.entries(intervals.reduce((out,row)=>(out[row[key]]=(out[row[key]]||0)+1,out),{})).map(([value,count])=>({value:+value,count})).sort((a,b)=>b.count-a.count||a.value-b.value);
 const phaseTimes={};for(const row of states){if(row.state.loading?.pending==='salvage')for(const [phase,time]of Object.entries(row.state.loading.phaseTimes||{}))phaseTimes[phase]=Math.max(phaseTimes[phase]||0,time)}
 const loaderHash=result.httpAudit.identity.identity.scripts['app/SceneLoader.lua'];
 const source=fs.readFileSync(path.join(result.httpAudit.identity.source_directory,'scripts/app/SceneLoader.lua'),'utf8');assert.equal(sha(source),loaderHash);assert.equal(source.split('self.warmIndex=self.warmIndex+1;self.warmWait=3').length,2);
 let modelWaitFrames=3,executedSourceSha256=loaderHash;
 if(result.candidate){
  const bytes=fs.readFileSync(path.join(directory,'candidate-SceneLoader.lua'));assert.equal(sha(bytes),result.candidate.candidateSha256);assert.deepEqual(result.candidate.allowlist,['app/SceneLoader.lua']);
  assert.equal(bytes.toString('utf8').replace("self.warmWait=(item.type=='Model' and 0 or 3)",'self.warmWait=3'),source);
  modelWaitFrames=0;executedSourceSha256=sha(bytes);
 }
 const modelSpan=models.at(-1).frame-models[0].frame,insideModelMandatoryWaitFrames=(models.length-1)*modelWaitFrames;
 return {result:'PASS',evidence:path.resolve(directory),inputSha256:Object.fromEntries(['result.json','load-boundaries.jsonl','load-diagnostics.jsonl','states.jsonl','runtime.log'].map(name=>[name,sha(read(name))])),samples,deltas,
  contracts:{rawMarkers:markers.length,rawAllocatorResults:diagnostics.filter(row=>row.kind==='allocator-result').length,followingMarkers:diagnostics.filter(row=>row.kind==='sample-following-frame').length,
   actualAbandonment:result.returnedResult.salvageReturn.result,initialLobby:states.find(row=>row.state.mode==='hangar'&&row.state.tab==='hangar')?.state.lobby||null,returnedLobby:result.lastState.lobby,
   returnedResourceTypes:result.lastState.performance&&Object.fromEntries(['resourceBytes','modelBytes','texture2DBytes','arrayBytes','imageBytes','materialBytes','soundBytes','luaKiB','retiredTargets','assetRelease'].map(key=>[key,result.lastState.performance[key]])),
   oldTrialRelease:result.returnedResult.salvageReturn.release},
  loading:{preparedCount:prepared.length,modelCount:models.length,firstModel:models[0],lastModel:models.at(-1),modelSpanFrames:modelSpan,modelSpanWallMs:models.at(-1).wallMs-models[0].wallMs,
   modelIntervalFrames:histogram('engineFrames'),modelIntervalMs:histogram('wallMs'),smallModels:models.filter(row=>row.memoryBytes<=4096).length,
   modelWaitFrames,modelMandatoryNoWorkUpdates:models.length*modelWaitFrames,insideFirstLastModelMandatoryNoWorkUpdates:insideModelMandatoryWaitFrames,
   insideModelFrameShare:insideModelMandatoryWaitFrames/modelSpan,textureMandatoryNoWorkUpdates:(prepared.length-models.length)*3,
   phaseTimes,prepared,intervals,sourceSha256:loaderHash,executedSourceSha256,
   boundary:'Frozen Loader has three early-return Update slots after each success; the allowlisted candidate changes only Model waits to zero. These are counted scheduling slots, not timed CPU work. Exact no-work wall duration is unavailable because loading Update entry times were not recorded; no wall-time saving is asserted.'},
  boundary:'resources-ready to physics-prepared includes scene XML loading/native scene instantiation and world Build, before full vehicle/session construction. Aggregate deltas do not identify native allocation owners. Initial competitive hall and returned salvage lobby differ; residual memory is not by itself a leak. Intrusive allocator queries exclude FPS use.'};
}
module.exports={analyze};
if(require.main===module){assert.equal(process.argv.length,3);const directory=path.resolve(process.argv[2]),result=analyze(directory);fs.writeFileSync(path.join(directory,'independent-boundary-analysis.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({result:result.result,samples:result.samples.map(({tag,inUseMiB,resourceBytes,luaBytes,sampleDurationMs})=>({tag,inUseMiB,resourceMiB:resourceBytes/MiB,luaMiB:luaBytes/MiB,sampleDurationMs})),deltas:result.deltas,loading:{...result.loading,prepared:undefined,intervals:undefined}},null,2))}

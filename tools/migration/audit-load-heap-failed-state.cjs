'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),Module=require('node:module');
const {transport}=require('./run-load-heap-model-wait-recovered.cjs');
const {verifyRecords}=require('./run-load-heap-boundary-short.cjs');
function audit(directory,baselineDirectory){
 const read=name=>fs.readFileSync(path.join(directory,name),'utf8'),report=JSON.parse(read('result.json'));
 assert.equal(report.result,'FAIL');assert.equal(report.shutdown.status,'CLOSED');assert.deepEqual(report.errors,[]);assert.deepEqual(report.httpErrors,[]);
 assert.deepEqual(report.probeErrors,[{kind:'state',error:'Unexpected end of JSON input',length:813}]);assert.match(report.failure,/No unparsed QA\/heap records/);
 const replay={probeErrors:[]},reader=transport(replay),states=[];let seq=0,state;
 for(const [index,line] of read('runtime.log').split(/\r?\n/).entries()){
  const at=line.indexOf('OUTGAME_STATE ');if(at<0)continue;
  const accepted=reader.parse(line.slice(at+14),seq,state,line);if(accepted){state=accepted.state;seq=accepted.seq;states.push({seq,state})}
  else replay.stateTransportWarnings.at(-1).runtimeLine=index+1;
 }
 reader.verify();assert.equal(replay.stateTransportWarnings.length,1);assert.deepEqual(states,read('states.jsonl').trim().split('\n').map(line=>JSON.parse(line)));
 assert.equal(replay.stateTransportWarnings[0].line.length,813);assert.equal(replay.stateTransportWarnings[0].seqBefore,33);assert.equal(replay.stateTransportWarnings[0].recoveredBySequence,34);
 const markers=read('load-boundaries.jsonl').trim().split('\n').map(line=>JSON.parse(line)),diagnostics=read('load-diagnostics.jsonl').trim().split('\n').map(line=>JSON.parse(line));
 const verification=verifyRecords(markers,diagnostics,report.observerSnapshot);assert.equal(verification.result,'PASS');
 const analyzerFile=path.join(__dirname,'analyze-load-heap-short.cjs');let source=fs.readFileSync(analyzerFile,'utf8');
 assert.equal(source.split("assert.equal(result.result,'PASS');").length,2);source=source.replace("assert.equal(result.result,'PASS');","assert.equal(result.result,'FAIL');");
 const gate='result.errors.length===0&&result.httpErrors.length===0&&result.probeErrors.length===0';assert.equal(source.split(gate).length,2);source=source.replace(gate,'result.errors.length===0&&result.httpErrors.length===0&&result.probeErrors.length===1');
 const m=new Module(analyzerFile,module);m.filename=analyzerFile;m.paths=Module._nodeModulePaths(__dirname);m._compile(source,analyzerFile);
 const candidate=m.exports.analyze(directory),baseline=require('./analyze-load-heap-short.cjs').analyze(baselineDirectory);
 assert.deepEqual(candidate.loading.prepared.map(row=>row.name),baseline.loading.prepared.map(row=>row.name),'Exact resource preparation order');
 assert.equal(candidate.loading.modelCount,282);assert.equal(candidate.loading.preparedCount,283);
 assert.equal(candidate.loading.executedSourceSha256,report.candidate.candidateSha256);
 assert.ok(report.browserInjection.responses.some(row=>row.sha256===report.candidate.candidateSha256));
 const first=markers.find(row=>row.tag==='old-hall-cleaned');const warning=replay.stateTransportWarnings[0];const failedFrame=Number(warning.line.match(/^\[[^\]]+\]\[(\d+)\]/)[1]);assert.ok(failedFrame<first.frame,'Truncation preceded salvage resource loading');
 const comparison={resourceOrderIdentical:true,modelCounts:[baseline.loading.modelCount,candidate.loading.modelCount],
  phaseTimes:{baseline:baseline.loading.phaseTimes,candidate:candidate.loading.phaseTimes},
  modelSpan:{baselineMs:baseline.loading.modelSpanWallMs,candidateMs:candidate.loading.modelSpanWallMs,deltaMs:candidate.loading.modelSpanWallMs-baseline.loading.modelSpanWallMs,baselineFrames:baseline.loading.modelSpanFrames,candidateFrames:candidate.loading.modelSpanFrames},
  boundaryMemory:candidate.samples.map((row,i)=>({tag:row.tag,baselineInUseMiB:baseline.samples[i].inUseMiB,candidateInUseMiB:row.inUseMiB,deltaInUseMiB:row.inUseMiB-baseline.samples[i].inUseMiB,baselineResourceMiB:baseline.samples[i].resourceBytes/1048576,candidateResourceMiB:row.resourceBytes/1048576,baselineLuaMiB:baseline.samples[i].luaBytes/1048576,candidateLuaMiB:row.luaBytes/1048576})),
  modelFrameHistogram:{baseline:baseline.loading.modelIntervalFrames,candidate:candidate.loading.modelIntervalFrames}};
 return {result:'PARTIAL_DIAGNOSTIC_STRICT_RUN_FAILED',strictRunResult:report.result,strictFailure:report.failure,shutdown:'CLOSED',stateRecoveryReplay:replay.stateTransportWarnings,recordVerification:verification,comparison,
  candidate:{...candidate,result:'PARTIAL_DIAGNOSTIC_STRICT_RUN_FAILED'},
  usable:'Exact archived candidate and actual response identity, complete 283 preparation order, six uncoalesced heap boundaries, phase endpoints, public abandonment and acknowledged returned hall; raw complete state sequence replay agrees.',
  unavailable:'Original strict acceptance failed; no PASS override, activated/returned screenshots, combat FPS, mobile performance, allocation-owner or isolated causal network/download gain claim. Original candidate did not reach final screenshot after its strict assertion.',
  boundary:'One A/B pair with uncontrolled resource/network warmness. Intrusive sparse heap queries and short public idle route do not measure gameplay FPS. Cache, Lua and allocator totals overlap and cannot be summed.'};
}
module.exports={audit};
if(require.main===module){assert.equal(process.argv.length,4);const directory=path.resolve(process.argv[2]),result=audit(directory,path.resolve(process.argv[3]));fs.writeFileSync(path.join(directory,'independent-failed-state-audit.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({result:result.result,recovery:result.stateRecoveryReplay.map(({runtimeLine,seqBefore,recoveredBySequence,previousStage,recoveredStage})=>({runtimeLine,seqBefore,recoveredBySequence,previousStage,recoveredStage})),comparison:result.comparison,usable:result.usable,unavailable:result.unavailable},null,2))}

'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const args=process.argv.slice(2);
assert(args.length===4||(args.length===6&&args[4]==='--out'),'Four report.json paths in A1 B1 B2 A2 order, optional --out summary.json');
const paths=args.slice(0,4),runs=paths.map(file=>JSON.parse(fs.readFileSync(file,'utf8'))),labels=['A1','B1','B2','A2'];
const changed='drive/VehicleSpec.lua';
const hashes={baseline:'c11d04f77fc0899d5837cccc2db853be5d3bf560cbffe9c401aa582c0b4a7336',candidate:'13cd41b0ce5756c179773094b0f94a57e8fb6fce520f9a2e2b6a9454789cb6ec'};
const names=[['raceCar',false],['raceCar',true],['megaMech',false],['megaMech',true],['bridge-detach',false]];
for(const[index,run]of runs.entries()){
 assert.equal(run.status,'PASS',labels[index]);assert.equal(run.shutdown,'CLOSED',labels[index]);
 assert.equal(run.errors.length,0);assert.equal(run.httpErrors.length,0);
 assert.deepEqual(run.runtimeHashes,runs[0].runtimeHashes,'Same Runtime bytes');
 assert.equal(run.result.configuration.mode,'timing');assert.equal(run.result.configuration.scenario,'damage');
 assert.deepEqual(run.result.configuration,runs[0].result.configuration);
 assert.equal(run.identity.g1WebCpu.entrySha256,runs[0].identity.g1WebCpu.entrySha256,'Same probe entry');
 assert.equal(run.identity.g1WebCpu.sourceFrozen,runs[0].identity.g1WebCpu.sourceFrozen,'Same source freeze');
 const scripts=run.identity.identity.scripts,initial=runs[0].identity.identity.scripts;
 assert.deepEqual(Object.keys(scripts),Object.keys(initial));
 for(const name of Object.keys(scripts))if(name!==changed)assert.equal(scripts[name],initial[name],name);
 assert.equal(scripts[changed],labels[index].startsWith('A')?hashes.baseline:hashes.candidate,'Exact candidate identity');
 assert.deepEqual(run.result.damage.fixtures.map(f=>[f.name,f.combat]),names);
 assert.equal(run.damageProgress.length,12);assert.equal(run.result.damage.randomTail.length,32);
 assert.deepEqual(run.result.damage.randomTail,runs[0].result.damage.randomTail,'RNG tail');
 assert.equal(run.result.damage.stateDigest,runs[0].result.damage.stateDigest,'Aggregate state');
 let progressIndex=0;
 for(const fixture of run.result.damage.fixtures){
  assert.equal(fixture.initialBuildScopes,false,'No initial profile wrappers');
  if('initialBuildLocalScopes'in fixture)assert.equal(fixture.initialBuildLocalScopes,false);
  for(const stage of fixture.stages){
   assert.equal(stage.damageScopes,false);assert.equal(stage.flushScopes,false);
   for(const key of ['damageLocalScopes','flushLocalScopes'])if(key in stage)assert.equal(stage[key],false);
   const progress=run.damageProgress[progressIndex++];assert.equal(progress.name,fixture.name);assert.equal(progress.combat,fixture.combat);
   const{stateDigest,...transport}=stage;assert.deepEqual(progress.stage,transport,'Streamed progress matches final');
  }
 }
 assert.equal(progressIndex,12);
}
const rows=[];
for(let fixtureIndex=0;fixtureIndex<5;fixtureIndex++){
 const fixtures=runs.map(run=>run.result.damage.fixtures[fixtureIndex]),first=fixtures[0];
 for(const fixture of fixtures){
  assert.equal(fixture.name,first.name);assert.equal(fixture.combat,first.combat);
  assert.match(fixture.initialRangesDigest,/^[a-f0-9]{16}$/);assert.equal(fixture.initialRangesDigest,first.initialRangesDigest);
  assert.equal(fixture.stages.length,first.stages.length);
 }
 rows.push({name:first.name,combat:first.combat,kind:'initial build',ms:fixtures.map(f=>f.initialBuildMs)});
 for(let stageIndex=0;stageIndex<first.stages.length;stageIndex++){
  const stages=fixtures.map(f=>f.stages[stageIndex]);
  for(const stage of stages){
   for(const key of ['kind','target','amount','partsBefore','partsAfter','alive','budgetBefore','budgetAfter','debrisPieces','stateDigest','rangeDigest'])assert.deepEqual(stage[key],stages[0][key],key);
   assert.match(stage.rangeDigest,/^[a-f0-9]{16}$/);
   for(const key of ['damageMs','flushMs'])assert(Number.isInteger(stage[key])&&stage[key]>=0,key);
  }
  const times=stages.map(s=>s.flushMs);
  rows.push({name:first.name,combat:first.combat,kind:stages[0].kind,ms:times,
   baselineMeanMs:(times[0]+times[3])/2,candidateMeanMs:(times[1]+times[2])/2});
 }
}
const target=rows.filter(row=>row.name==='megaMech'&&!row.combat&&/^part [123]$/.test(row.kind));assert.equal(target.length,3);
const baseline=target.reduce((sum,row)=>sum+row.baselineMeanMs,0),candidate=target.reduce((sum,row)=>sum+row.candidateMeanMs,0);
const summary={status:'EQUIVALENT_RESULTS',module:changed,hashes,order:labels,paths,rows,
 equivalence:{sameRuntime:true,sameSourceFreeze:true,sameProbe:true,onlyTargetModuleDiffers:true,configuration:true,initialRanges:true,stageRanges:true,state:true,randomTail32:true,streamedProgress:true},
 shutdowns:runs.map((r,i)=>({label:labels[i],shutdown:r.shutdown,runtimeErrors:r.errors.length,httpErrors:r.httpErrors.length})),
 target:{name:'megaMech noncombat three single-part Flush sum',baselineMeanMs:baseline,candidateMeanMs:candidate,
  decision:candidate>=baseline?'REJECT_NO_TARGET_BENEFIT':'REQUIRES_MORE_VALIDATION',productionModified:false},
 boundary:'Two repeats per variant. Isolated damage fixture only; no sustained FPS, mobile, thermal or statistical improvement claim.'};
const output=JSON.stringify(summary,null,2)+'\n';
if(args[5]){fs.mkdirSync(path.dirname(args[5]),{recursive:true});fs.writeFileSync(args[5],output)}
console.log(output);

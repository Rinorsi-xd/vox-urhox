'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {verifyResult}=require('./g1-web-cpu-run.cjs');
const reportPath=process.argv[2],output=process.argv[3];assert(reportPath,'Pass report.json, optional summary.json');
const report=JSON.parse(fs.readFileSync(reportPath,'utf8'));
assert.equal(report.status,'PASS');assert.equal(report.shutdown,'CLOSED');assert.equal(report.errors.length,0);assert.equal(report.httpErrors.length,0);
verifyResult(report.result,report.identity);
const baseline=require('../../docs/migration/evidence/g1-web-cpu-occids-A1/report.json');
assert.deepEqual(report.runtimeHashes,baseline.runtimeHashes);
assert.deepEqual(report.result.damage.randomTail,baseline.result.damage.randomTail);
assert.equal(report.result.damage.stateDigest,baseline.result.damage.stateDigest,'Uninstrumented baseline state digest');
const rows=[];
function measurement(fixture,kind,outerMs,coarse,locals){
 const c=new Map(coarse.map(row=>[row.name,row]));const scopes=locals.map(row=>({...row}));
 const selfTotal=coarse.reduce((sum,row)=>sum+row.selfMs,0);assert(selfTotal<=outerMs);
 const residual={};
 for(const [prefix,parent]of [['TurretRange.','TurretRange.For'],['MergeBoxes.','VehicleSpec.MergeBoxes']]){
  const measured=scopes.filter(row=>row.name.startsWith(prefix)).reduce((sum,row)=>sum+row.selfMs,0);
  residual[parent]={inclusiveMs:c.get(parent).ms,localSelfMs:measured,residualMs:c.get(parent).ms-measured};
 }
 rows.push({fixture:fixture.name,combat:fixture.combat,kind,outerMs,coarseSelfMs:selfTotal,outerResidualMs:outerMs-selfTotal,scopes,residual});
}
for(let index=0;index<report.result.damage.fixtures.length;index++){
 const fixture=report.result.damage.fixtures[index],before=baseline.result.damage.fixtures[index];
 assert.equal(fixture.name,before.name);assert.equal(fixture.combat,before.combat);
 assert.equal(fixture.initialRangesDigest,before.initialRangesDigest);assert.equal(fixture.stages.length,before.stages.length);
 measurement(fixture,'initial build',fixture.initialBuildMs,fixture.initialBuildScopes,fixture.initialBuildLocalScopes);
 for(let stageIndex=0;stageIndex<fixture.stages.length;stageIndex++){
  const stage=fixture.stages[stageIndex],old=before.stages[stageIndex];
  assert.equal(stage.rangeDigest,old.rangeDigest);assert.equal(stage.stateDigest,old.stateDigest);
  measurement(fixture,stage.kind+' Damage',stage.damageMs,stage.damageScopes,stage.damageLocalScopes);
  measurement(fixture,stage.kind+' Flush',stage.flushMs,stage.flushScopes,stage.flushLocalScopes);
 }
}
const summary={status:'PASS',source:reportPath,baseline:'g1-web-cpu-occids-A1/report.json',equivalentRangesStateRng:true,rows,
 boundary:'Nested export and local timers overlap. Only local scope self values may be added within a matching parent. Instrumented attribution, not optimization or FPS proof.'};
const bytes=JSON.stringify(summary,null,2)+'\n';if(output){fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,bytes)}
console.log(bytes);

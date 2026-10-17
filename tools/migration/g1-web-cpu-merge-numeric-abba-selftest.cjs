'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(__dirname+'/g1-web-cpu-merge-numeric-abba.cjs','utf8');
const recorded=JSON.parse(fs.readFileSync(__dirname+'/../../docs/migration/evidence/g1-web-cpu-occids-A1/report.json','utf8'));
const hashes=['c11d04f77fc0899d5837cccc2db853be5d3bf560cbffe9c401aa582c0b4a7336','13cd41b0ce5756c179773094b0f94a57e8fb6fce520f9a2e2b6a9454789cb6ec'];
function fixtures(){return ['A1','B1','B2','A2'].map(label=>{
 const r=structuredClone(recorded);r.identity.identity.scripts['drive/VehicleSpec.lua']=hashes[label.startsWith('A')?0:1];return r;
})}
function run(rows){let output;vm.runInNewContext(source,{require:name=>name==='node:fs'?{readFileSync:file=>JSON.stringify(rows[Number(file)])}:require(name),
 process:{argv:['node','script','0','1','2','3']},console:{log:value=>{output=JSON.parse(value)}}});return output}
assert.equal(run(fixtures()).status,'EQUIVALENT_RESULTS');assert.equal(run(fixtures()).target.decision,'REJECT_NO_TARGET_BENEFIT');
const controls=[
 r=>{r[1].result.damage.fixtures[0].initialRangesDigest=undefined},
 r=>{r[2].runtimeHashes.fake='drift'},
 r=>{r[1].identity.identity.scripts['construction/TurretRange.lua']='drift'},
 r=>{r[3].result.damage.fixtures[0].stages[0].flushScopes=[]},
 r=>{r[2].result.damage.fixtures[2].stages[0].rangeDigest='1111111111111111'},
 r=>{r[2].result.damage.randomTail[0]=-.1},
 r=>{r[3].result.damage.stateDigest='drift'},
 r=>{r[1].httpErrors.push('resource failure')},
 r=>{r[1].identity.g1WebCpu.entrySha256='drift'},
 r=>{r[1].identity.g1WebCpu.sourceFrozen='drift'},
 r=>{r[1].identity.identity.scripts['drive/VehicleSpec.lua']='wrong candidate'},
 r=>{r[2].damageProgress[0].stage.flushMs++},
 r=>{r[0].shutdown='RUNNING'},
];
for(const change of controls){const rows=fixtures();change(rows);assert.throws(()=>run(rows))}
console.log(JSON.stringify({status:'PASS',negativeControls:controls.length,boundary:'Synthetic verifier checks only; no candidate runtime performance measurement.'}));

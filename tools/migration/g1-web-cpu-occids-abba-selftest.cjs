'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(__dirname+'/g1-web-cpu-occids-abba.cjs','utf8');
const recorded=JSON.parse(fs.readFileSync(__dirname+'/../../docs/migration/evidence/g1-web-cpu-sections-damage/report.json','utf8'));
function fixtures(){return ['A1','B1','B2','A2'].map(label=>{
 const r=structuredClone(recorded);r.result.configuration.mode='timing';
 r.identity.identity.scripts['construction/TurretRange.lua']=label.startsWith('A')?'baseline':'candidate';
 for(const f of r.result.damage.fixtures){f.initialBuildScopes=false;f.initialRangesDigest='0000000000000000';
  for(const s of f.stages){s.damageScopes=false;s.flushScopes=false;s.rangeDigest='0000000000000000'}}
 return r;
})}
function run(rows){let output;vm.runInNewContext(source,{require:name=>name==='node:fs'?{readFileSync:file=>JSON.stringify(rows[Number(file)])}:require(name),
 process:{argv:['node','script','0','1','2','3']},console:{log:value=>{output=JSON.parse(value)}}});return output}
assert.equal(run(fixtures()).status,'EQUIVALENT_RESULTS');
const controls=[
 r=>{r[1].result.damage.fixtures[0].initialRangesDigest=undefined},
 r=>{r[2].runtimeHashes.fake='drift'},
 r=>{r[1].identity.identity.scripts['drive/VehicleSpec.lua']='drift'},
 r=>{r[3].result.damage.fixtures[0].stages[0].flushScopes=[]},
 r=>{r[2].result.damage.fixtures[2].stages[0].rangeDigest='1111111111111111'},
 r=>{r[2].result.damage.randomTail[0]=-.1},
 r=>{r[3].result.damage.stateDigest='drift'},
 r=>{r[1].httpErrors.push('resource failure')},
];
for(const change of controls){const rows=fixtures();change(rows);assert.throws(()=>run(rows))}
console.log(JSON.stringify({status:'PASS',negativeControls:controls.length,boundary:'Synthetic verifier tests only; no benchmark numbers.'}));

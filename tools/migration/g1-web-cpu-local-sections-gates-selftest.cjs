'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const {verifyResult}=require('./g1-web-cpu-run.cjs');
const identity=require('../../.tmp/g1-web-cpu-local-sections-fc1c-profile/identity.json');
const recorded=require('../../docs/migration/evidence/g1-web-cpu-sections-damage/report.json');
const labels=['TurretRange.For.Signatures','TurretRange.For.Invalidations','TurretRange.Prepare','TurretRange.Evaluate','TurretRange.SameContext','MergeBoxes.Index','MergeBoxes.Sort','MergeBoxes.Sweep'];
function data(){
 const result=structuredClone(recorded.result);
 function locals(rows){const byName=new Map(rows.map(row=>[row.name,row]));return labels.map(name=>({name,ms:0,selfMs:0,calls:name==='TurretRange.For.Signatures'?byName.get('TurretRange.For').calls:name.startsWith('MergeBoxes.')?byName.get('VehicleSpec.MergeBoxes').calls:0}))}
 for(const f of result.damage.fixtures){f.initialBuildLocalScopes=locals(f.initialBuildScopes);for(const s of f.stages){s.damageLocalScopes=locals(s.damageScopes);s.flushLocalScopes=locals(s.flushScopes)}}
 return result;
}
verifyResult(data(),identity);
const controls=[
 r=>{r.damage.fixtures[0].initialBuildLocalScopes.pop()},
 r=>{r.damage.fixtures[0].initialBuildLocalScopes[0].calls++},
 r=>{r.damage.fixtures[0].initialBuildLocalScopes[5].calls++},
 r=>{r.damage.fixtures[0].initialBuildLocalScopes[1].name='unknown'},
 r=>{r.damage.fixtures[0].initialBuildLocalScopes[1].selfMs=-1},
 r=>{const row=r.damage.fixtures[0].initialBuildLocalScopes[1];row.ms=1e9;row.selfMs=1e9},
];
for(const change of controls){const r=data();change(r);assert.throws(()=>verifyResult(r,identity))}
console.log(JSON.stringify({status:'PASS',negativeControls:controls.length,boundary:'Synthetic local profile gate controls only; no performance evidence.'}));

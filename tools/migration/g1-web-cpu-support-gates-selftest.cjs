'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),{verify}=require('./g1-web-cpu-support-verify.cjs');
const recorded=JSON.parse(fs.readFileSync(__dirname+'/../../docs/migration/evidence/g1-web-cpu-contract-profile/report.json','utf8'));
function fixture(){
 const r=structuredClone(recorded),result=r.result;result.configuration.scenario='crater';r.identity.g1WebCpu.configuration.scenario='crater';
 result.map={bodies:2064,terrainChunks:100,authored:1883,boulders:81};
 r.identity.identity.scripts['drive/RaySuspension.lua']='d4b325932d0b63635b34a6d021163aa609f2b838897088a1cc0fcd3fb872ebd1';
 r.identity.identity.scripts['physics/Space.lua']='a23f6653acf15fd4d6b4a81b24b40cd1bc09ea412c4d4568afca62558b0b1570';
 r.identity.g1WebCpu.probeSha256='5937101fe942d42bf653ee5694eb61dcbb700153357551e5cfc8894879a0d9d8';
 result.supportPreload={path:'Crater/VisualHeight.bin',fileBytes:1643544,fileId:'VHF1',ready:true};
 for(const row of result.scopes){row.ms=0;row.selfMs=0}
 result.totalMs=0;result.samplesMs=result.samplesMs.map(()=>0);
 const map=new Map(result.scopes.map(r=>[r.name,r]));
 result.supportScopes=['apply.support','apply.contact','apply.impulses','hover.Step'].map(name=>({name,calls:result.steps*6,ms:0,selfMs:0}));
 for(const phase of ['construct','native','filter'])result.supportScopes.push({name:'ray.other.'+phase,calls:map.get('physics.Raycast').calls,ms:0,selfMs:0});
 return r;
}
assert.equal(verify(fixture()).status,'PASS');
const controls=[
 r=>r.result.supportScopes.push({...r.result.supportScopes[0]}),
 r=>r.result.supportScopes[0].calls++,
 r=>r.result.supportScopes.find(x=>x.name==='ray.other.native').calls++,
 r=>r.result.supportScopes.find(x=>x.name==='ray.other.construct').ms++,
 r=>r.result.supportScopes[0].selfMs=-1,
 r=>r.result.supportScopes[0].name='unknown',
 r=>r.identity.identity.scripts['physics/Space.lua']='drift',
 r=>r.identity.g1WebCpu.probeSha256='drift',
 r=>r.result.scopes.find(x=>x.name==='vehicle.Step').ms++,
 r=>r.httpErrors.push('failed asset'),
 r=>r.result.configuration.scenario='lanes',
 r=>r.result.supportPreload.ready=false,
];
for(const change of controls){const r=fixture();change(r);assert.throws(()=>verify(r))}
const transform=require('./g1-web-cpu-support-prepare.cjs');
for(const fn of [transform.suspension,transform.space])assert.throws(()=>fn('stale source without expected anchors'));
console.log(JSON.stringify({status:'PASS',negativeControls:controls.length+2,boundary:'Synthetic gate/anchor tests only; not runtime performance.'}));

'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
function verify(report){
 assert.equal(report.status,'PASS');assert.equal(report.shutdown,'CLOSED');assert.equal(report.errors.length,0);assert.equal(report.httpErrors.length,0);
 require('./g1-web-cpu-run.cjs').verifyResult(report.result,report.identity);
 const result=report.result;assert.equal(result.configuration.mode,'profile');assert.equal(result.configuration.scenario,'crater');
 const expected={
  'drive/RaySuspension.lua':'d4b325932d0b63635b34a6d021163aa609f2b838897088a1cc0fcd3fb872ebd1',
  'physics/Space.lua':'a23f6653acf15fd4d6b4a81b24b40cd1bc09ea412c4d4568afca62558b0b1570',
 };
 for(const[name,sha]of Object.entries(expected))assert.equal(report.identity.identity.scripts[name],sha,'Exact instrumented module');
 assert.equal(report.identity.g1WebCpu.probeSha256,'5937101fe942d42bf653ee5694eb61dcbb700153357551e5cfc8894879a0d9d8');
 assert.deepEqual(result.supportPreload,{path:'Crater/VisualHeight.bin',fileBytes:1643544,fileId:'VHF1',ready:true});
 const rows=[...result.scopes,...result.supportScopes],map=new Map(rows.map(r=>[r.name,r]));assert.equal(map.size,rows.length,'Unique labels');
 for(const row of rows)assert(Number.isInteger(row.calls)&&row.calls>=0&&row.selfMs>=0&&row.ms>=row.selfMs);
 const supportAllowed=new Set(['apply.support','apply.contact','apply.impulses','stability.Step','hover.Step']);
 const callers=['suspension.Sample','leg.Cast','stability.Step','hover.Step','other'];
 for(const caller of callers)for(const phase of ['construct','native','filter'])supportAllowed.add('ray.'+caller+'.'+phase);
 for(const row of result.supportScopes)assert(supportAllowed.has(row.name),'Known support label');
 for(const phase of ['apply.support','apply.contact','apply.impulses'])assert.equal(map.get(phase)?.calls,map.get('suspension.Apply').calls,'One phase per Apply');
 assert.equal(map.get('hover.Step').calls,result.steps*6);
 let rayCalls=0,rayMs=0;
 for(const caller of callers){
  const phases=['construct','native','filter'].map(phase=>map.get('ray.'+caller+'.'+phase)||{calls:0,ms:0,selfMs:0});
  assert.equal(phases[0].calls,phases[1].calls);assert.equal(phases[1].calls,phases[2].calls);
  for(const row of phases)assert.equal(row.ms,row.selfMs,'Ray stages are terminal');
  rayCalls+=phases[0].calls;rayMs+=phases.reduce((s,r)=>s+r.ms,0);
 }
 assert.equal(rayCalls,map.get('physics.Raycast').calls,'Every ray belongs to exactly one caller');
 assert.equal(map.get('physics.Raycast').ms,map.get('physics.Raycast').selfMs+rayMs,'Ray subtree conservation');
 const sumSelf=rows.reduce((s,r)=>s+r.selfMs,0),rootMs=['vehicle.Step','vehicle.StepRotors','physics.Step'].reduce((s,n)=>s+map.get(n).ms,0);
 assert.equal(sumSelf,rootMs,'All nested scopes conserve roots');assert(rootMs<=result.totalMs,'Scopes fit timed fixture');
 const applyMs=['apply.support','apply.contact','apply.impulses'].reduce((s,n)=>s+map.get(n).ms,0);
 assert.equal(map.get('suspension.Apply').ms,map.get('suspension.Apply').selfMs+applyMs,'Apply subtree conservation');
 return {status:'PASS',source:report.identity.source_directory,steps:result.steps,totalMs:result.totalMs,msPerStep:result.msPerStep,rayCalls,scopeCount:rows.length,rootMs,sumSelf,
  unscopedFixtureMs:result.totalMs-rootMs,rows,boundary:'Profile-only attribution, fake-clock tests excluded from performance. Isolated six-car crater fixture, no whole battle/845 FPS claim.'};
}
module.exports={verify};if(require.main===module){const result=verify(JSON.parse(fs.readFileSync(process.argv[2],'utf8')));if(process.argv[3])fs.writeFileSync(process.argv[3],JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));}

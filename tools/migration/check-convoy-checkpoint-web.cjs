'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const level=require('../../assets/Story/Mission/Level2.json').level,step=level.steps.find(s=>s.kind==='escort');
function check(records){
 assert(records.length>=2,'Both actual checkpoints required');const seen=new Set();
 for(const r of records){
  assert.equal(r.mission,'s2');assert([1,2].includes(r.checkpoint));assert(Number.isInteger(r.sequence));
  assert(r.hp>0&&r.hp<=1);assert.equal(r.cpHp,r.hp);assert.equal(r.cpD,r.d);
  assert(r.d/r.total>=step.checkpoints[r.checkpoint-1],'Actual convoy threshold crossed');
  const first=r.calls.slice(0,3);assert.deepEqual(first.map(e=>e.kind),['Banner','radio','say']);
  assert.equal(first[0].kick,'检查点');assert.equal(first[0].title,'检查点 '+r.checkpoint);
  assert.equal(first[0].style,'install');assert.equal(first[0].ms,2400);
  assert.equal(first[1].cue,'install');assert.equal(first[1].accepted,true);assert.equal(first[1].playing,true);
  assert.deepEqual(first[2].lines,step.cpLines[r.checkpoint-1]);assert.equal(first[2].urgent,false);
  assert.equal(r.calls.filter(e=>e.kind==='radio'&&e.cue==='install').length,1);
  assert.equal(r.calls.filter(e=>e.kind==='Banner'&&e.kick==='检查点').length,1);
  const key=r.failures+':'+r.checkpoint;assert(!seen.has(key),'One checkpoint notification per actual attempt');seen.add(key);
 }
 assert(records.some(r=>r.checkpoint===1));assert(records.some(r=>r.checkpoint===2));
 return {status:'CHECKPOINT_CONSUMERS_PASS',records:records.length,checkpoints:[1,2],
  boundary:'Observed actual consumer order and accepted SoundSource playing flags. No claim of audible playback, visual parity, natural full completion or performance.'};
}
function selfTest(){
 const records=[1,2].map(checkpoint=>({mission:'s2',sequence:checkpoint,checkpoint,failures:0,hp:1,cpHp:1,d:step.checkpoints[checkpoint-1]*500,cpD:step.checkpoints[checkpoint-1]*500,total:500,
  calls:[{kind:'Banner',kick:'检查点',title:'检查点 '+checkpoint,style:'install',ms:2400},
   {kind:'radio',cue:'install',accepted:true,playing:true},{kind:'say',lines:step.cpLines[checkpoint-1],urgent:false}]}));
 check(records);let rejected=0;
 for(const mutate of [a=>a.pop(),a=>{[a[0].calls[1],a[0].calls[2]]=[a[0].calls[2],a[0].calls[1]]},
  a=>{a[0].calls[1].accepted=false},a=>{a[0].calls[1].playing=false},a=>{a[0].calls[2].lines=[]},
  a=>{a[0].d=0;a[0].cpD=0},a=>{a.push(structuredClone(a[0]))},a=>{a[0].cpHp=.5}]){
  const bad=structuredClone(records);mutate(bad);assert.throws(()=>check(bad));rejected++;
 }
 return {status:'PASS',rejected,boundary:'Synthetic acceptance controls only, not runtime evidence'};
}
function analyze(file){
 const report=JSON.parse(fs.readFileSync(file,'utf8'));assert(report.identity.convoyCheckpointWeb?.isolated);
 assert.equal(report.errors.length,0);assert.equal(report.probeErrors.length,0);assert.equal(report.level,'s2');
 assert(['PASS','INCOMPLETE'].includes(report.result),'Retain actual route failures');
 assert.equal(report.shutdown?.status,'CLOSED','Actual browser must be closed');
 assert(report.checks.includes('natural attempt return releases terrain arrays'),'Actual public return and terrain release required');
 const log=fs.readFileSync(path.join(path.dirname(file),'runtime.log'),'utf8'),records=[];
 for(const line of log.split(/\r?\n/)){const p='CONVOY_CHECKPOINT_CONSUMERS ',at=line.indexOf(p);if(at>=0)records.push(JSON.parse(line.slice(at+p.length)))}
 const result={...check(records),sourceResult:report.result,records,identity:report.identity.convoyCheckpointWeb};
 const out=path.join(path.dirname(file),'checkpoint-consumers.json');fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');return {status:result.status,out,records:records.length};
}
module.exports={check,selfTest,analyze};
if(require.main===module){try{console.log(JSON.stringify(process.argv[2]?analyze(process.argv[2]):selfTest()))}catch(e){console.error(e.stack);process.exitCode=1}}

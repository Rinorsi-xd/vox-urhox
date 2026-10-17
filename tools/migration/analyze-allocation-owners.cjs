'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
function analyze(data){
 const r=data.report,a=r.allocation;assert.equal(r.state.restored,true);assert.equal(r.state.restoreError,false);
 assert.equal(a.invalid,false);assert.equal(Object.keys(a.issues).length,0);
 assert.equal(a.bindingCount,33);assert.equal(a.names.length,33);assert.equal(a.totals.length,33);
 assert.equal(new Set(a.names).size,33);assert.ok(a.frames.length>0);
 assert.equal(data.shutdown.status,'CLOSED');assert.equal(data.shutdown.ownedServer,'CLOSED');
 assert.equal(Object.keys(r.explicitCalls).length,0);
 const totals=a.names.map(name=>({name,calls:0,inclusiveKiB:0,selfKiB:0,errors:0}));
 let net=0,self=0,unscoped=0;
 const close=(x,y,label)=>assert.ok(Math.abs(x-y)<1e-7,label+': '+x+' != '+y);
 for(let i=0;i<a.frames.length;i++){
  const f=a.frames[i];assert.equal(f.used,true);assert.equal(f.rows.length,33);
  if(i)assert.equal(f.number,a.frames[i-1].number+1,'Contiguous allocation frame IDs');
  close(f.endKiB-f.startKiB,f.netKiB,'Frame net');
  const sum=f.rows.reduce((s,row,j)=>{
   assert.ok(Number.isInteger(row.calls)&&row.calls>=0);assert.equal(row.errors,0);
   assert.ok(row.selfKiB>=0&&row.inclusiveKiB>=row.selfKiB);
   for(const key of ['calls','inclusiveKiB','selfKiB','errors'])totals[j][key]+=row[key];
   return s+row.selfKiB;
  },0);
  close(sum,f.measuredKiB,'Disjoint owner self conservation');
  close(sum+f.unscopedKiB,f.netKiB,'Frame total conservation');
  const b=r.frames.find(x=>x.frame===f.number&&x.phase==='B');
  if(b)assert.ok(b.luaKB<=f.startKiB&&b.endLuaKB>=f.endKiB,'Controller contains allocation interval');
  else assert.equal(f.number,r.abortEvidence.frame,'Only final guard-crossing frame may lack controller completion');
  net+=f.netKiB;self+=sum;unscoped+=f.unscopedKiB;
 }
 for(let i=0;i<totals.length;i++){
  assert.equal(totals[i].name,a.totals[i].name);
  for(const key of ['calls','inclusiveKiB','selfKiB','errors'])close(totals[i][key],a.totals[i][key],'Stored owner total '+key);
 }
 close(self+unscoped,net,'Whole window conservation');
 const aborted=r.state.phase==='invalid';
 if(aborted){assert.equal(r.state.reason,'Lua no-auto-GC memory growth budget');assert.equal(r.abortEvidence.phase,'B');
  assert.ok(r.abortEvidence.luaKB-r.abortEvidence.baselineKB>r.growthKB);assert.equal(a.frames.at(-1).number,r.abortEvidence.frame);}
 const ranked=totals.map(t=>({...t,selfPercent:t.selfKiB/net*100,perFrameKiB:t.selfKiB/a.frames.length,
  perCallKiB:t.calls?t.selfKiB/t.calls:null})).sort((x,y)=>y.selfKiB-x.selfKiB);
 return {allocationEvidence:'VALID',abaPerformanceEvidence:aborted?'INVALID':'REQUIRES_TIMING_ANALYSIS',
  frames:a.frames.length,firstFrame:a.frames[0].number,lastFrame:a.frames.at(-1).number,
  controllerCompleteBFrames:r.state.framesB,netKiB:net,measuredSelfKiB:self,unscopedKiB:unscoped,
  unscopedPercent:unscoped/net*100,ranked,
  boundary:a.boundary};
}
if(require.main===module){
 const file=process.argv.find(x=>x.endsWith('.json'));assert.ok(file,'Provide auto-gc-aba.json');
 const data=JSON.parse(fs.readFileSync(file,'utf8'));const result=analyze(data);
 if(process.argv.includes('--self-test')){
  for(const mutate of [d=>d.report.allocation.frames[0].rows.pop(),d=>d.report.allocation.totals[0].selfKiB++,
   d=>d.report.allocation.frames[1].number++,d=>d.report.state.restored=false,
   d=>d.report.allocation.frames[0].netKiB++,d=>d.report.allocation.frames[0].rows[0].errors++]){
   const copy=structuredClone(data);mutate(copy);assert.throws(()=>analyze(copy));
  }
  console.log('PASS: original evidence and six corrupted-evidence negative controls');
 }
 console.log(JSON.stringify(result,null,2));
}
module.exports={analyze};

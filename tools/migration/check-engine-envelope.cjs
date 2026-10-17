'use strict';
const assert=require('node:assert/strict');
const {analyze,NAMES}=require('./engine-envelope-analyze.cjs');
const {suffix}=require('./engine-envelope-prepare.cjs');
const {buildRunner}=require('./sparse-combat-run.cjs');
suffix();buildRunner();
const result={sampleCount:2,engineEnvelope:{schema:1,names:NAMES,overflow:false,events:20,
 rows:[...NAMES.flatMap((_,i)=>[1,i+1,0xfffffff8+i>>>0]),...NAMES.flatMap((_,i)=>[2,i+1,100+i])],
 dumps:['before','after'].map(label=>({label,overflow:false,ok:true,messages:[{level:1,customLog:'',message:'VOX_ENGINE_ENVELOPE_DUMP_CONTROL '+label},{level:1,customLog:'',message:'Profiler1.1.0 / Windows'}]}))}};
const a=analyze(result);assert.equal(a.selectedFrames,2);assert.equal(a.events,20);assert.equal(a.frames[0].events[8].deltaFromPreviousMs,1);assert.equal(a.dumpStatus[0].nativeNamedReports,1);
const missing=structuredClone(result);missing.engineEnvelope.rows.splice(0,3);missing.engineEnvelope.events--;assert.equal(analyze(missing).availability[0].missingSerials[0],1);
const unavailable=structuredClone(result);unavailable.engineEnvelope.dumps.forEach(d=>{d.ok=false;d.error='unavailable';d.messages={}});assert.equal(analyze(unavailable).dumpStatus[0].callOk,false);
let negatives=0;
for(const mutate of [r=>r.engineEnvelope.overflow=true,r=>r.engineEnvelope.rows[0]=0,r=>r.engineEnvelope.rows[1]=11,
 r=>r.engineEnvelope.rows[2]=-1,r=>r.engineEnvelope.rows[5]=0xfffffff0,r=>r.engineEnvelope.rows.pop(),
 r=>{r.engineEnvelope.rows.splice(27,3);r.engineEnvelope.events--},r=>r.engineEnvelope.dumps[0].label='after',
 r=>r.engineEnvelope.dumps[1].overflow=true,r=>r.engineEnvelope.dumps[0].messages={bad:'not an empty Lua table'},
 r=>r.engineEnvelope.rows[33]=1]){
 const bad=structuredClone(result);mutate(bad);assert.throws(()=>analyze(bad),'Negative control '+negatives);negatives++;
}
console.log(JSON.stringify({status:'PASS_OFFLINE_ONLY',checks:['complete uint32 wrap','missing event marked unavailable','dump unavailable retained','unique generated suffix anchors','inherited actual runner compilation'],negativeControls:negatives}));

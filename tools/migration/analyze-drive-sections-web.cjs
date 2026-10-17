'use strict';
const assert=require('node:assert/strict');
function summarize(records,options={}){
 const names=new Map(),frames=[],rows=new Map(),seen=new Set();let expectedFrame=null;
 for(const record of records){
  assert.equal(record.dropped,0,'No detail frames dropped');
  assert.ok(Array.isArray(record.names)&&Array.isArray(record.frames),'Named raw detail frames');
  assert.equal(new Set(record.names).size,record.names.length,'Unique scope labels');
  record.names.forEach((name,i)=>{assert.equal(typeof name,'string');if(names.has(i+1))assert.equal(names.get(i+1),name);names.set(i+1,name)});
  if(options.sourceIdentity)assert.deepEqual(record.sourceIdentity,options.sourceIdentity,'Detailed source matches frozen modules');
  for(const frame of record.frames){
   assert.ok(Number.isInteger(frame.frame)&&frame.frame>0,'Positive frame number');
   if(options.afterFrame!==undefined&&frame.frame<=options.afterFrame)continue;
   if(options.throughFrame!==undefined&&frame.frame>options.throughFrame)continue;
   if(frames.length===0&&options.afterFrame!==undefined)assert.equal(frame.frame,options.afterFrame+1,'First input detail frame retained');
   assert.ok(!seen.has(frame.frame),'No repeated detail frame');seen.add(frame.frame);
   if(expectedFrame!==null)assert.equal(frame.frame,expectedFrame,'Every detail frame retained in order');expectedFrame=frame.frame+1;
   assert.ok(Number.isInteger(frame.startWall)&&Number.isInteger(frame.endWall)&&frame.endWall>=frame.startWall,'Ordered wall frame bounds');
   const ids=new Set();let production=false;
   for(const value of frame.values){
    assert.equal(value.length,5);const [id,calls,inclusive,self,max]=value;
    assert.ok(names.has(id)&&!ids.has(id),'Known unique scope');ids.add(id);
    assert.ok(Number.isInteger(calls)&&calls>0,'Scope invocation count');
    for(const number of [inclusive,self,max])assert.ok(Number.isInteger(number)&&number>=0,'Integer wall durations');
    assert.ok(self<=inclusive&&max<=inclusive,'Self/max bounded by inclusive total');
    const name=names.get(id),row=rows.get(name)||{name,calls:0,inclusiveMs:0,selfMs:0,maxCallMs:0,frames:0};
    row.calls+=calls;row.inclusiveMs+=inclusive;row.selfMs+=self;row.maxCallMs=Math.max(row.maxCallMs,max);row.frames++;rows.set(name,row);
    if(name==='update.production'){production=true;assert.equal(calls,1);assert.ok(inclusive<=frame.endWall-frame.startWall,'Update scope fits containing frame')}
   }
   assert.ok(production,'Every frame contains the original production Update scope');frames.push(frame);
  }
 }
 assert.ok(frames.length>0,'Detail input frames retained');
 if(options.throughFrame!==undefined)assert.equal(frames.at(-1).frame,options.throughFrame,'Final input frame retained');
 const totalWallMs=frames.reduce((sum,frame)=>sum+frame.endWall-frame.startWall,0);
 return {frames:frames.length,firstFrame:frames[0].frame,lastFrame:frames.at(-1).frame,totalWallMs,
  rows:[...rows.values()].map(row=>({...row,inclusiveMsPerFrame:row.inclusiveMs/frames.length,selfMsPerFrame:row.selfMs/frames.length})).sort((a,b)=>b.selfMs-a.selfMs),
  boundary:'QA integer wall durations with wrappers and internal section boundaries. Inclusive parents overlap children; self is elapsed minus measured nested durations, not exact CPU. Unknown/unwrapped children remain within parent self. No FPS or optimization gain.'};
}
function selfTest(){
 const record={names:['update.production','vehicle.Step'],dropped:0,frames:[{frame:1,startWall:10,endWall:30,values:[[1,1,19,4,19],[2,6,15,15,5]]}]};
 const result=summarize([record],{afterFrame:0,throughFrame:1});assert.equal(result.rows.find(r=>r.name==='vehicle.Step').calls,6);
 assert.throws(()=>summarize([record,record]));assert.throws(()=>summarize([{...record,dropped:1}]));
 assert.throws(()=>summarize([{...record,frames:[{...record.frames[0],values:[[1,1,19,20,19]]}]}]));
 assert.throws(()=>summarize([record],{afterFrame:1}));console.log('PASS: raw drive scope continuity, bounds, counts, source identity and dropped-frame rejection');
 assert.throws(()=>summarize([{...record,frames:[{...record.frames[0],frame:2}]}],{afterFrame:0,throughFrame:2}),/First input detail frame retained/);
}
module.exports={summarize,selfTest};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else{const fs=require('node:fs');const records=fs.readFileSync(process.argv[2],'utf8').trim().split('\n').map(JSON.parse);console.log(JSON.stringify(summarize(records),null,2))}}

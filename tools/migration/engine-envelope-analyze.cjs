'use strict';
const assert=require('node:assert/strict');
const NAMES=['PreRenderUpdate','RenderUpdate','PostRenderUpdate','BeginRendering','PreRenderUI','PostPreRenderUI','PostRenderUI','EndRendering','PreEndFrame','EndFrame'];
function array(value){if(Array.isArray(value))return value;assert(value&&Object.keys(value).length===0,'Only actual empty Lua table may normalize to empty array');return [];}
function analyze(result){
 const e=result.engineEnvelope;assert(e&&e.schema===1,'Actual engine event payload');assert.equal(e.overflow,false,'Engine event ring overflow');
 assert.deepEqual(e.names,NAMES);const rows=array(e.rows);assert.equal(rows.length,e.events*3);assert(e.events>0);
 const frames=Array.from({length:result.sampleCount},(_,i)=>({serial:i+1,events:[],counts:Array(10).fill(0)}));
 let previousSerial=0;
 for(let i=0;i<rows.length;i+=3){const [serial,eventId,at]=rows.slice(i,i+3);
  assert(Number.isInteger(serial)&&serial>=1&&serial<=frames.length&&serial>=previousSerial,'Real selected serial order');previousSerial=serial;
  assert(Number.isInteger(eventId)&&eventId>=1&&eventId<=10);assert(Number.isInteger(at)&&at>=0&&at<=0xffffffff);
  const f=frames[serial-1],last=f.events.at(-1);if(last)assert(((at-last.at)>>>0)<0x80000000,'Chronological uint32 event clock');
  f.events.push({eventId,name:NAMES[eventId-1],at,deltaFromPreviousMs:last?(at-last.at)>>>0:null});f.counts[eventId-1]++;
 }
 for(const f of frames){assert(f.events.length>0,'Every selected frame has actual event coverage');assert(f.counts[9]>0,'Every selected frame reaches actual EndFrame event');}
 const dumps=array(e.dumps);assert.deepEqual(dumps.map(d=>d.label),['before','after'],'Exactly two out-of-window dump requests');
 const dumpStatus=dumps.map(d=>{assert.equal(d.overflow,false,'Dump log capture overflow');assert.equal(typeof d.ok,'boolean');const messages=array(d.messages);
  return {label:d.label,callOk:d.ok,error:d.error??null,controlDelivered:messages.some(m=>m.message.includes('VOX_ENGINE_ENVELOPE_DUMP_CONTROL '+d.label)),
   nativeNamedReports:messages.filter(m=>m.customLog===''&&/Profiler\d+(?:\.\d+)+/.test(m.message)).length,messageCount:messages.length};});
 return {status:'PASS_EVENT_ATTRIBUTION_ONLY',selectedFrames:frames.length,events:e.events,
  availability:NAMES.map((name,i)=>({name,calls:frames.reduce((n,f)=>n+f.counts[i],0),coveredFrames:frames.filter(f=>f.counts[i]>0).length,
   missingSerials:frames.filter(f=>!f.counts[i]).map(f=>f.serial)})),dumpStatus,frames,
  boundary:'Integer chronological boundary timestamps in actual selected frames, not method/thread CPU. Missing events are unavailable, never zero milliseconds. Event order is recorded rather than assumed. Native dump capability may remain unavailable; raw messages/errors are preserved. No optimization benefit, isolated CPU gap attribution or mobile acceptance.'};
}
module.exports={analyze,NAMES};

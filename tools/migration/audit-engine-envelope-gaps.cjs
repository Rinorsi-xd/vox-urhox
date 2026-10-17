'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {analyze}=require('./engine-envelope-analyze.cjs'),{intervals}=require('./sparse-combat-cpu.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function derive(capture,bridge){
 const parsed=analyze(capture),spans=intervals(bridge),frames=[];
 const once=(rows,kind,owner)=>{const r=rows.filter(r=>r[1]===kind&&r[2]===owner);assert.equal(r.length,1);return r[0];};
 for(const frame of parsed.frames){
  const marks=bridge.rows.filter(r=>r[0]===frame.serial),mainEnd=once(marks,'end',8),uiBegin=once(marks,'begin',7),uiEnd=once(marks,'end',7);
  const mainGap=(uiBegin[3]-mainEnd[3])>>>0;assert(mainGap<1000,'Same-frame Lua main/UI boundary');
  const split=(start,end,startLabel,endLabel)=>{
   const duration=(end-start)>>>0;assert(duration<1000,'Same-frame coarse boundary duration');
   const inside=frame.events.map(e=>({...e,relativeMs:(e.at-start)|0})).filter(e=>e.relativeMs>=0&&e.relativeMs<=duration);
   const segments=[];let last=0,label=startLabel;
   for(const e of inside){assert(e.relativeMs>=last);segments.push({from:label,to:e.name,ms:e.relativeMs-last});last=e.relativeMs;label=e.name;}
   segments.push({from:label,to:endLabel,ms:duration-last});assert.equal(segments.reduce((n,s)=>n+s.ms,0),duration);
   return {durationMs:duration,segments};
  };
  const endFrames=frame.events.filter(e=>e.eventId===10),endFrame=endFrames.at(-1);assert(endFrame);
  const lastEndFrameAfterUi=((endFrame.at-uiEnd[3])|0)>=0;
  const mainUi=split(mainEnd[3],uiBegin[3],'main.Update end','UI.Render begin');
  const uiTail=lastEndFrameAfterUi?split(uiEnd[3],endFrame.at,'UI.Render end','last actual EndFrame'):null;
  const top=spans.filter(s=>s.serial===frame.serial&&s.depth===0).sort((a,b)=>a.startMs-b.startMs);assert.deepEqual(top.map(s=>s.owner),[8,7]);
  frames.push({serial:frame.serial,mainToUiLua:mainUi,mainToUiJsMs:top[1].startMs-top[0].endMs,
   uiEndToEndFrameLua:uiTail,lastEndFrameAfterUi,chronologicalEvents:frame.events,
   clockBoundary:'Lua event and semantic-end timestamps share integer Time clock. JS marker gap uses performance.now separately. No exact cross-clock mapping or native function CPU inferred.'});
 }
 const bySegment={};for(const f of frames)for(const s of f.mainToUiLua.segments){const key=s.from+' -> '+s.to;const a=bySegment[key]??={calls:0,totalMs:0,maxMs:0};a.calls++;a.totalMs+=s.ms;a.maxMs=Math.max(a.maxMs,s.ms);}
 return {status:'DERIVED_EVENT_CHRONOLOGY_ONLY',selectedFrames:frames.length,availability:parsed.availability,dumpStatus:parsed.dumpStatus,
  meanMainToUiLuaMs:frames.reduce((n,f)=>n+f.mainToUiLua.durationMs,0)/frames.length,
  meanMainToUiJsMs:frames.reduce((n,f)=>n+f.mainToUiJsMs,0)/frames.length,
  mainToUiSegmentTotals:bySegment,frames,
  boundary:'Actual selected-frame integer event wall intervals conserve main-end to UI-begin Lua gap; duplicate boundaries and zero tick differences retained. Event intervals include callbacks and measurement overhead, are not method self CPU or GPU. UI-end to EndFrame excludes later trace loop tail. Missing events remain unavailable. No optimization A/B, gain or mobile acceptance.'};
}
module.exports={derive};
if(require.main===module){const dir=path.resolve(process.argv[2]),output=path.resolve(process.argv[3]||path.join(dir,'independent-engine-envelope-gaps.json'));assert(!fs.existsSync(output),'Fresh derived output only');
 const names=['capture.json','sparse-sync.json'],bytes=names.map(n=>fs.readFileSync(path.join(dir,n))),r=derive(...bytes.map(b=>JSON.parse(b)));
 r.inputSha256=Object.fromEntries(names.map((n,i)=>[n,sha(bytes[i])]));for(let i=0;i<names.length;i++)assert.equal(sha(fs.readFileSync(path.join(dir,names[i]))),sha(bytes[i]));
 fs.writeFileSync(output,JSON.stringify(r,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,selectedFrames:r.selectedFrames,mainToUiLua:r.meanMainToUiLuaMs,mainToUiJs:r.meanMainToUiJsMs,segments:r.mainToUiSegmentTotals,dumpStatus:r.dumpStatus},null,2));}

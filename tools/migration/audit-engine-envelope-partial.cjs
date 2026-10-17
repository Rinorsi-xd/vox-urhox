'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {NAMES}=require('./engine-envelope-analyze.cjs'),{intervals}=require('./sparse-combat-cpu.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function table(text){
 assert(text.startsWith('Profiler1.1.0\nWeb(Win32)\n'));assert(text.includes('Last frame')&&text.includes('Whole execution time'));
 const rows=[],stack=[];
 for(const line of text.split('\n')){const m=/^(\s*)(.*?)\s+(\d+):\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*$/.exec(line);if(!m)continue;
  const row={name:m[2],depth:+m[3],lastFrame:{count:+m[4],avg:+m[5],max:+m[6],total:+m[7]},whole:{count:+m[8],avg:+m[9],max:+m[10],total:+m[11]}};
  while(stack.length&&stack.at(-1).depth>=row.depth)stack.pop();row.path=[...stack.map(r=>r.name),row.name].join(' / ');rows.push(row);stack.push(row);
 }assert(rows.length>0);return rows;
}
function derive(capture,bridge,report){
 const stages=require('./sparse-combat-run.cjs').analyze(capture),e=capture.engineEnvelope;
 assert.equal(e.schema,1);assert.equal(e.overflow,false);assert.deepEqual(e.names,NAMES);assert(Array.isArray(e.rows)&&e.rows.length===e.events*3);
 const frames=Array.from({length:capture.sampleCount},(_,i)=>({serial:i+1,events:[]}));let previousSerial=0;
 for(let i=0;i<e.rows.length;i+=3){const [serial,id,at]=e.rows.slice(i,i+3);assert(Number.isInteger(serial)&&serial>=1&&serial<=frames.length&&serial>=previousSerial);previousSerial=serial;assert(Number.isInteger(id)&&id>=1&&id<=10);assert(Number.isInteger(at)&&at>=0&&at<=0xffffffff);
  const f=frames[serial-1],last=f.events.at(-1);if(last)assert(((at-last.at)>>>0)<0x80000000);f.events.push({id,name:NAMES[id-1],at});}
 const span=intervals(bridge),segmentTotals={},pairs={},one=(rows,kind,owner)=>{const match=rows.filter(r=>r[1]===kind&&r[2]===owner);assert.equal(match.length,1);return match[0];};
 const add=(key,ms)=>{assert(ms>=0&&ms<1000);const r=segmentTotals[key]??={calls:0,totalMs:0,maxMs:0};r.calls++;r.totalMs+=ms;r.maxMs=Math.max(r.maxMs,ms);};
 for(const f of frames){assert(f.events.length>0);const marks=bridge.rows.filter(r=>r[0]===f.serial),mainEnd=one(marks,'end',8),uiBegin=one(marks,'begin',7),uiEnd=one(marks,'end',7);
  const top=span.filter(s=>s.serial===f.serial&&s.depth===0).sort((a,b)=>a.startMs-b.startMs);assert.deepEqual(top.map(s=>s.owner),[8,7]);
  const mainUi=(uiBegin[3]-mainEnd[3])>>>0;assert(mainUi<1000);let last=0,label='main.Update end',sum=0;
  for(const ev of f.events){const rel=(ev.at-mainEnd[3])|0;if(rel<0||rel>mainUi)continue;assert(rel>=last);const ms=rel-last;add(label+' -> '+ev.name,ms);sum+=ms;last=rel;label=ev.name;}
  add(label+' -> UI.Render begin',mainUi-last);sum+=mainUi-last;assert.equal(sum,mainUi);
  f.mainToUiLuaMs=mainUi;f.mainToUiJsMs=top[1].startMs-top[0].endMs;
  const after=f.events.filter(ev=>((ev.at-uiEnd[3])|0)>=0),lastEvent=after.at(-1);f.lastAvailableAfterUi=lastEvent?{name:lastEvent.name,luaMs:(lastEvent.at-uiEnd[3])>>>0}:null;
  for(let j=1;j<f.events.length;j++){const a=f.events[j-1],b=f.events[j],key=a.name+' -> '+b.name,ms=(b.at-a.at)>>>0;const p=pairs[key]??={calls:0,totalMs:0,maxMs:0};p.calls++;p.totalMs+=ms;p.maxMs=Math.max(p.maxMs,ms);}
 }
 const dumps=e.dumps;assert(Array.isArray(dumps)&&dumps.length===2);assert.deepEqual(dumps.map(d=>d.label),['before','after']);
 const text=dumps.map(d=>{assert.equal(d.ok,true);assert.equal(d.overflow,false);assert(d.messages.some(m=>m.customLog==='lua'&&m.message.includes('VOX_ENGINE_ENVELOPE_DUMP_CONTROL '+d.label)));const m=d.messages.filter(m=>m.customLog===''&&m.message.startsWith('Profiler1.1.0\nWeb(Win32)\n'));assert.equal(m.length,1);return m[0].message;});
 const [before,after]=text.map(table);assert.deepEqual(before.map(r=>[r.path,r.depth]),after.map(r=>[r.path,r.depth]));
 const rootBefore=before.find(r=>r.path==='RunFrame'),rootAfter=after.find(r=>r.path==='RunFrame'),frameDelta=rootAfter.whole.count-rootBefore.whole.count;assert.equal(frameDelta,capture.frameIds.length);
 const differences=after.map((r,i)=>{const b=before[i],count=r.whole.count-b.whole.count,total=r.whole.total-b.whole.total;assert(count>=0&&total>=-0.001);const capped=b.whole.count===99999||r.whole.count===99999;
  return {path:r.path,depth:r.depth,countDelta:count,countMayBeCapped:capped,totalDeltaPrintedUnits:total,meanPerCompletedRunFrame:total/frameDelta,meanPerCall:capped||!count?null:total/count,before:b.whole,after:r.whole};});
 const rootDelta=differences.find(r=>r.path==='RunFrame');
 return {status:'DERIVED_PARTIAL_WITH_ORIGINAL_CAPTURE_FAIL',originalStatus:report.status,originalFailure:report.failure,errors:report.errors,httpErrors:report.httpErrors,
  sampling:{frames:capture.frameIds.length,selected:frames.length,events:e.events,markerCount:capture.markerCount,captureMs:report.captureMs},
  availability:NAMES.map((name,i)=>({name,calls:frames.reduce((n,f)=>n+f.events.filter(ev=>ev.id===i+1).length,0),coveredFrames:frames.filter(f=>f.events.some(ev=>ev.id===i+1)).length})),
  orderCounts:Object.entries(frames.reduce((m,f)=>{const k=f.events.map(e=>e.name).join(' -> ');m[k]=(m[k]||0)+1;return m;},{})),
  stages,frames,eventPairTotals:pairs,mainToUiSegments:segmentTotals,
  meanMainToUiLuaMs:frames.reduce((n,f)=>n+f.mainToUiLuaMs,0)/frames.length,meanMainToUiJsMs:frames.reduce((n,f)=>n+f.mainToUiJsMs,0)/frames.length,
  profiler:{reports:2,frameDelta,rootDelta,rows:differences,
   period:'Whole-execution cumulative after minus before, not subtraction of lifetime averages or last-frame values. RunFrame count delta equals actual captured frame count. Dumps bracket capture and execute inside Update: partial first/last frame and before-dump overhead can differ from held-input boundaries.',
   units:'Raw header omits units. Printed RunFrame delta closely matches 45-second capture when interpreted as milliseconds; this is runtime clock consistency evidence, not an explicit header unit declaration.',
   countLimit:'Printed count 99999 may be capped; do not infer exact per-call count or mean for such rows.',
   nesting:'Every named parent includes children. Rows, nested view IDs and rendererSubmit must not be summed across hierarchy. Named Present/bgfx are CPU wall scopes, not GPU durations.'},
  workload:{beforeWorld:capture.before.world,afterWorld:capture.after.world,playerDamageBefore:capture.before.playerDamage,playerDamageAfter:capture.after.playerDamage,
   before:capture.before.roster.map(r=>({name:r.name,parts:r.parts,structure:r.structure,alive:r.alive})),after:capture.after.roster.map(r=>({name:r.name,parts:r.parts,structure:r.structure,alive:r.alive})),
   minimumParts:Math.min(...capture.parts)},
  rawProfilerText:text,
  boundary:'Raw original FAIL and EndFrame absence retained. Independent partial analysis uses only actual delivered events and complete semantic markers; it does not weaken the frozen capture validator or create missing tail timestamps. Integer clock ties do not establish strict ordering against marker callbacks. No optimization A/B, gain, exact event CPU or device acceptance.'};
}
module.exports={derive,table};
if(require.main===module){const dir=path.resolve(process.argv[2]),out=path.join(dir,'independent-engine-partial.json');assert(!fs.existsSync(out));const names=['capture.json','sparse-sync.json','report.json'],bytes=names.map(n=>fs.readFileSync(path.join(dir,n))),r=derive(...bytes.map(b=>JSON.parse(b)));
 r.inputSha256=Object.fromEntries(names.map((n,i)=>[n,sha(bytes[i])]));for(let i=0;i<names.length;i++)assert.equal(sha(fs.readFileSync(path.join(dir,names[i]))),sha(bytes[i]));
 const texts=r.rawProfilerText;delete r.rawProfilerText;fs.writeFileSync(out,JSON.stringify(r,null,2)+'\n',{flag:'wx'});for(let i=0;i<texts.length;i++)fs.writeFileSync(path.join(dir,'independent-web-profiler-'+['before','after'][i]+'.txt'),texts[i],{flag:'wx'});
 console.log(JSON.stringify({out,status:r.status,availability:r.availability,orderCounts:r.orderCounts,mainToUiLua:r.meanMainToUiLuaMs,mainToUiJs:r.meanMainToUiJsMs,mainToUiSegments:r.mainToUiSegments,eventPairs:r.eventPairTotals,profilerTop:r.profiler.rows.filter(x=>x.totalDeltaPrintedUnits>100).sort((a,b)=>b.totalDeltaPrintedUnits-a.totalDeltaPrintedUnits).slice(0,16),frameDelta:r.profiler.frameDelta},null,2));}

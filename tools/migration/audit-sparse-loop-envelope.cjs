'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {intervals,clockAnchors}=require('./sparse-combat-cpu.cjs');
const dir=path.resolve(process.argv[2]),out=path.join(dir,'independent-loop-envelope.json');
assert(!fs.existsSync(out),'Fresh output only');
const hashes={};
function read(name){const bytes=fs.readFileSync(path.join(dir,name));hashes[name]=crypto.createHash('sha256').update(bytes).digest('hex');return JSON.parse(bytes);}
const profile=read('drive.cpuprofile'),bridge=read('sparse-sync.json'),metadata=read('sparse-cpu.json'),trace=read('sparse-clock.trace.json');
const anchors=clockAnchors(trace,metadata.clockRequests),lower=Math.max(...anchors.map(a=>a.lowerMs)),upper=Math.min(...anchors.map(a=>a.upperMs));
assert(lower<=upper);const offset=(lower+upper)/2,uncertainty=(upper-lower)/2;
const spans=intervals(bridge),events=trace.traceEvents;
const loops=events.filter(e=>e.ph==='X'&&e.name==='FunctionCall'&&e.args?.data?.functionName==='MainLoop_runner');
const paired=[];
for(const serial of [...new Set(spans.map(s=>s.serial))]){
 const top=spans.filter(s=>s.serial===serial&&s.depth===0).sort((a,b)=>a.startMs-b.startMs);
 assert.deepEqual(top.map(s=>s.owner),[8,7],'Disjoint main.Update and UI.Render');
 const begin=(top[0].startMs+offset-uncertainty)*1000,end=(top[1].endMs+offset+uncertainty)*1000;
 const containing=loops.filter(e=>e.ts<=begin&&e.ts+e.dur>=end);
 assert.equal(containing.length,1,'Both top scopes certainly in one actual MainLoop');
 const loop=containing[0];assert(loop.pid===anchors[0].pid&&loop.tid===anchors[0].tid);
 assert(Number.isFinite(loop.tdur)&&loop.tdur>=0&&loop.tdur<=loop.dur+1000);
 const jsStart=loop.ts/1000-offset,jsEnd=(loop.ts+loop.dur)/1000-offset;
 const gaps=[[jsStart,top[0].startMs],[top[0].endMs,top[1].startMs],[top[1].endMs,jsEnd]];
 assert(gaps.every(([a,b])=>b>=a));
 const nested=events.filter(e=>e.ph==='X'&&e.pid===loop.pid&&e.tid===loop.tid&&e.ts>=loop.ts&&e.ts+e.dur<=loop.ts+loop.dur);
 paired.push({serial,loopTraceStartUs:loop.ts,loopWallMs:loop.dur/1000,loopThreadCpuMs:loop.tdur/1000,
  offCpuMs:(loop.dur-loop.tdur)/1000,mainMarkerMs:top[0].jsMs,uiMarkerMs:top[1].jsMs,
  outsideMarkerWallMs:gaps.reduce((n,[a,b])=>n+b-a,0),gapWallMs:gaps.map(([a,b])=>b-a),gaps,
  nativeJsEvents:nested.filter(e=>e.name!=='FunctionCall'&&e.dur>=500).sort((a,b)=>b.dur-a.dur).slice(0,10).map(e=>({name:e.name,durMs:e.dur/1000,threadCpuMs:e.tdur/1000})),
  outsideSamples:0,outsideSampleWeightUs:0,outside9978WeightUs:0,outsideLeafWeightUs:{}});
}
assert.equal(new Set(paired.map(p=>p.loopTraceStartUs)).size,paired.length,'Distinct selected actual MainLoops');
const nodes=new Map(profile.nodes.map(n=>[n.id,n])),parents=new Map();for(const node of profile.nodes)for(const child of node.children||[])parents.set(child,node.id);
const stack=id=>{const names=[];for(let n=id,depth=0;n!==undefined&&depth<500;n=parents.get(n),depth++)names.push(nodes.get(n).callFrame.functionName||'(anonymous)');return names;};
assert.equal(profile.samples.length,profile.timeDeltas.length);
let at=profile.startTime;const negativeDeltas=[];
for(let i=0;i<profile.samples.length;i++){
 const delta=profile.timeDeltas[i],from=at/1000-offset;at+=delta;const until=at/1000-offset;
 if(delta<0){negativeDeltas.push({index:i,deltaUs:delta});continue;}
 const owners=paired.filter(p=>p.gaps.some(([a,b])=>from-uncertainty>a&&until+uncertainty<b));
 assert(owners.length<=1);if(!owners.length)continue;
 const p=owners[0],names=stack(profile.samples[i]);p.outsideSamples++;p.outsideSampleWeightUs+=delta;
 if(names.some(n=>/^wasm-function\[9978\](?:$|:)/.test(n)))p.outside9978WeightUs+=delta;
 const leaf=names[0];p.outsideLeafWeightUs[leaf]=(p.outsideLeafWeightUs[leaf]||0)+delta;
}
const mean=k=>paired.reduce((n,p)=>n+p[k],0)/paired.length,aggregate={};for(const p of paired)for(const[k,v]of Object.entries(p.outsideLeafWeightUs))aggregate[k]=(aggregate[k]||0)+v;
const result={status:'DERIVED_DIRECT_LOOP_ENVELOPE',inputSha256:hashes,clock:{offsetMs:offset,uncertaintyMs:uncertainty},selectedLoops:paired.length,
 mean:Object.fromEntries(['loopWallMs','loopThreadCpuMs','offCpuMs','mainMarkerMs','uiMarkerMs','outsideMarkerWallMs'].map(k=>[k,mean(k)])),
 totalOutsideSamples:paired.reduce((n,p)=>n+p.outsideSamples,0),totalOutsideSampleWeightUs:paired.reduce((n,p)=>n+p.outsideSampleWeightUs,0),
 totalOutside9978WeightUs:paired.reduce((n,p)=>n+p.outside9978WeightUs,0),outsideLeafStatisticalWeights:Object.entries(aggregate).sort((a,b)=>b[1]-a[1]).map(([name,us])=>({name,us})),
 negativeDeltas,frames:paired,boundary:'Offline immutable raw reparse. Each selected main/UI marker pair is certainly inside one same-thread actual MainLoop. Outside marker wall gaps are actual disjoint envelope gaps, not thread CPU or a named production algorithm. CPU sample intervals crossing any boundary are rejected; weights are statistical, not exact function timing. No optimization A/B, FPS gain, GC cause or mobile acceptance.'};
for(const[name,expected]of Object.entries(hashes))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(dir,name))).digest('hex'),expected,'Input unchanged');
fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({output:out,selectedLoops:result.selectedLoops,mean:result.mean,totalOutsideSampleWeightUs:result.totalOutsideSampleWeightUs,totalOutside9978WeightUs:result.totalOutside9978WeightUs,topOutside:result.outsideLeafStatisticalWeights.slice(0,12)},null,2));

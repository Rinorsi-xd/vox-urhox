// Read-only raw audit; writes a new derived artifact, never alters capture inputs.
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const cpu=require('./sparse-combat-cpu.cjs'),stage=require('./sparse-combat-run.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const [directory,output]=process.argv.slice(2);assert(directory&&output);assert(!fs.existsSync(output),'Fresh derived artifact required');
const read=name=>JSON.parse(fs.readFileSync(path.join(directory,name),'utf8'));
const capture=read('capture.json'),bridge=read('sparse-sync.json'),profile=read('drive.cpuprofile'),metadata=read('sparse-cpu.json');
const spans=cpu.intervals(bridge),lua=stage.analyze(capture);
const mainSpans=spans.filter(s=>s.owner===8),mainRows=mainSpans.map(s=>{
 const children=spans.filter(x=>x.depth===s.depth+1&&x.startMs>=s.startMs&&x.endMs<=s.endMs);
 const childJs=children.reduce((n,c)=>n+c.jsMs,0),childLua=children.reduce((n,c)=>n+c.luaMs,0);
 return {serial:s.serial,mainJsMs:s.jsMs,mainLuaMs:s.luaMs,childJsMs:childJs,childLuaMs:childLua,
  remainderJsMs:s.jsMs-childJs,remainderLuaMs:s.luaMs-childLua};
});
let attribution=false,audit=false;
if(metadata.status==='COLLECTED'){
 attribution=cpu.attribute(profile,bridge,metadata.clockAnchors);
 const nodes=new Map(profile.nodes.map(n=>[n.id,n])),parents=new Map();
 for(const n of profile.nodes)for(const c of n.children||[])parents.set(c,n.id);
 const under9978=id=>{for(let d=0;id!==undefined&&d<500;d++,id=parents.get(id))
  if(/wasm-function\[9978\](?:$|:)/.test(nodes.get(id)?.callFrame?.functionName||''))return true;return false;};
 const negative=[],parentFallback=[],exclusiveStatisticalUs={};let t=profile.startTime,last=t;
 let positives=0,zero=0,outsideBounds=0;
 for(let i=0;i<profile.samples.length;i++){
  const delta=profile.timeDeltas[i];assert(Number.isFinite(delta));last=t;t+=delta;
  const from=last/1000-attribution.offsetMs,at=t/1000-attribution.offsetMs,u=attribution.uncertaintyMs;
  if(t<profile.startTime||t>profile.endTime)outsideBounds++;
  if(delta<0){negative.push({index:i,deltaUs:delta,node:profile.samples[i],
   functionName:nodes.get(profile.samples[i])?.callFrame?.functionName,jsMs:at,under9978:under9978(profile.samples[i]),
   overlappingSpans:spans.filter(s=>at+u>=s.startMs&&from-u<=s.endMs).map(s=>({serial:s.serial,owner:s.owner}))});continue;}
  if(delta===0){zero++;continue;}positives++;
  if(!under9978(profile.samples[i]))continue;
  const candidates=spans.filter(s=>from-u>s.startMs&&at+u<s.endMs).sort((a,b)=>b.depth-a.depth);
  if(!candidates.length)continue;
  const selected=candidates[0],overlap=spans.filter(s=>s.depth>selected.depth&&from-u<s.endMs&&at+u>s.startMs);
  if(overlap.length){parentFallback.push({index:i,deltaUs:delta,owner:selected.owner,serial:selected.serial,
   childOwners:[...new Set(overlap.map(s=>s.owner))]});continue;}
  exclusiveStatisticalUs[selected.owner]=(exclusiveStatisticalUs[selected.owner]||0)+delta;
 }
 audit={sampleCount:profile.samples.length,deltaCount:profile.timeDeltas.length,positiveDeltas:positives,
  zeroDeltas:zero,negativeDeltas:negative,samplesOutsideProfileBounds:outsideBounds,
  profileEndMinusLastSampleUs:profile.endTime-t,
  parentFallbackCount:parentFallback.length,parentFallbackWeightUs:parentFallback.reduce((n,r)=>n+r.deltaUs,0),
  parentFallback,exclusiveStatisticalUs,
  boundary:'Negative intervals retained as anomalies, not clamped. Existing deepest-wholly-contained attribution may fall back to an enclosing owner when the sample interval crosses a child; that bucket is not exclusive self CPU. Derived exclusive weights reject any such overlap. CPU profiler labels/interval weights remain statistical, not exact call durations.'};
}
const inputNames=['capture.json','sparse-sync.json','drive.cpuprofile','sparse-cpu.json','report.json'];
const report={status:'DERIVED_STAGE_AND_SAMPLE_AUDIT',overallCapture:read('report.json').status,
 inputSha256:Object.fromEntries(inputNames.map(n=>[n,sha(fs.readFileSync(path.join(directory,n)))])),
 luaStageAnalysis:lua,mainRows,mainRemainder:{frames:mainRows.length,
  jsMs:mainRows.reduce((n,r)=>n+r.remainderJsMs,0),luaMs:mainRows.reduce((n,r)=>n+r.remainderLuaMs,0)},
 cpuAttribution:attribution,sampleAudit:audit,
 boundary:'Offline reparse only. Raw capture status retained, no FPS improvement comparison, no GPU attribution, no target-device acceptance. Main remainder includes uninstrumented services, fixed-step side work and observer overhead. Natural combat evolution and other preview tabs prevent controlled phase comparisons.'};
fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:report.status,overallCapture:report.overallCapture,mainRemainder:report.mainRemainder,
 negativeDeltas:audit&&audit.negativeDeltas,parentFallbackCount:audit&&audit.parentFallbackCount,
 parentFallbackWeightUs:audit&&audit.parentFallbackWeightUs,exclusiveStatisticalUs:audit&&audit.exclusiveStatisticalUs},null,2));

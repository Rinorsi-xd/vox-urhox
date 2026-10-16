// Offline CDP sampling attribution with bounded performance-clock alignment.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const round=n=>Math.round(n*1000)/1000;
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const overlap=(a,b,c,d)=>Math.max(0,Math.min(b,d)-Math.max(a,c));
const add=(map,key,value)=>map.set(key,(map.get(key)||0)+value);
const rank=map=>[...map].sort((a,b)=>b[1]-a[1]).slice(0,15).map(([name,ms])=>({name,sampledIntervalMs:round(ms)}));
function buildSamples(profile){
 if(!Array.isArray(profile.samples)||profile.samples.length!==profile.timeDeltas.length)throw Error('Samples/deltas mismatch');
 const nodes=new Map(profile.nodes.map(n=>[n.id,n])),parents=new Map(),stacks=new Map();
 for(const node of profile.nodes)for(const child of node.children||[])parents.set(child,node.id);
 const frame=node=>{
  const f=node.callFrame,name=f.functionName||'(anonymous)';
  return name+(f.url?' @ '+f.url+':'+(f.lineNumber+1):'');
 };
 function stack(id){
  if(stacks.has(id))return stacks.get(id);
  const out=[],seen=new Set();
  for(let n=id;n!==undefined;n=parents.get(n)){
   if(seen.has(n)||!nodes.has(n))throw Error('Invalid CPU profile parent tree');
   seen.add(n);out.push(frame(nodes.get(n)));
  }
  stacks.set(id,out);return out;
 }
 let at=0;
 return profile.samples.map((id,i)=>{
  const delta=profile.timeDeltas[i]/1000;
  if(!Number.isFinite(delta)||delta<0)throw Error('Invalid sample delta');
  const begin=at;at+=delta;const names=stack(id),leaf=names[0];
  const kind=leaf==='(idle)'?'idle':names.some(n=>/garbage collector|GCController|GCJob/.test(n))?'gc-observed-stack':
   names.some(n=>/xhr\.onload|XMLHttpRequest|fetch|onreadystatechange/.test(n))?'network-callback-observed-stack':
   names.some(n=>/wasm-function\[|wasm:/.test(n))?'wasm-observed-stack':'js-browser-other';
  return {begin,end:at,delta,names,kind};
 });
}
function attribute(samples,window,bounds){
 const [low,high]=bounds,mid=(low+high)/2,begin=window.at,end=begin+window.duration;
 const self=new Map(),inclusive=new Map(),classes=new Map(),stacks=new Map();
 let possible=0,certain=0,nominal=0,count=0,maxDelta=0;
 for(const s of samples){
  possible+=overlap(s.begin,s.end,begin-high,end-low);
  if(end-high>begin-low)certain+=overlap(s.begin,s.end,begin-low,end-high);
  const weight=overlap(s.begin,s.end,begin-mid,end-mid);
  if(weight===0)continue;
  nominal+=weight;count++;maxDelta=Math.max(maxDelta,s.delta);
  add(self,s.names[0],weight);add(classes,s.kind,weight);
  for(const name of new Set(s.names))add(inclusive,name,weight);
  add(stacks,s.names.slice(0,36).join(' > '),weight);
 }
 return {nominalAttributedIntervalMs:round(nominal),alignmentEnvelopeAttributedMs:{common:round(certain),union:round(possible)},
  sampleIntervals:count,maxIntersectingSampleDeltaMs:round(maxDelta),classes:rank(classes),topSelf:rank(self),topInclusive:rank(inclusive),topStacks:rank(stacks)};
}
function analyze(reportFile){
 const directory=path.dirname(reportFile),reportRaw=fs.readFileSync(reportFile),report=JSON.parse(reportRaw);
 const prefix=path.basename(reportFile,'.json'),profileFile=path.join(directory,report.exitCpuProfile?.file||prefix+'-exit.cpuprofile');
 const timelineFile=path.join(directory,prefix+'-audio-timeline.json');
 const bounds=report.exitCpuProfile?.startPerformanceBoundsMs;
 if(!Array.isArray(bounds)||bounds.length!==2||!bounds.every(Number.isFinite)||bounds[1]<bounds[0])throw Error('Missing/invalid profile start bounds');
 const profileRaw=fs.readFileSync(profileFile),timelineRaw=fs.readFileSync(timelineFile);
 const profile=JSON.parse(profileRaw),timeline=JSON.parse(timelineRaw),samples=buildSamples(profile);
 const duration=(profile.endTime-profile.startTime)/1000,mid=(bounds[0]+bounds[1])/2;
 const local=at=>new Date(timeline.timeOrigin+at).toISOString();
 const nearestState=at=>{
  const target=timeline.timeOrigin+at;let nearest;
  for(const state of report.samples||[])if(!nearest||Math.abs(state.at-target)<Math.abs(nearest.at-target))nearest=state;
  return nearest?{shot:nearest.shot,age:nearest.age,offsetMs:round(nearest.at-target)}:null;
 };
 const tasks=(timeline.longTasks||[]).filter(t=>t.at+t.duration>=bounds[0]&&t.at<=bounds[1]+duration);
 const selected=tasks.filter(t=>t.duration>=100).sort((a,b)=>b.duration-a.duration).slice(0,12);
 const windows=selected.map(t=>({...t,utcStart:local(t.at),utcEnd:local(t.at+t.duration),nearestObservedState:nearestState(t.at),
  nominalProfileOverlapMs:round(overlap(t.at,t.at+t.duration,mid,mid+duration)),...attribute(samples,t,bounds),
  alignmentEndpointClasses:bounds.map(offset=>({offsetMs:offset,classes:attribute(samples,t,[offset,offset]).classes}))}));
 const slowCalls=[];
 const logFile=path.join(directory,prefix+'.log');
 if(fs.existsSync(logFile))for(const line of fs.readFileSync(logFile,'utf8').split(/\r?\n/))if(line.includes('[QAUpdateTiming]')||line.includes('[OpeningTiming]')||line.includes('[OpeningRetirement] done'))slowCalls.push(line);
 const latestStats=[...(report.samples||[])].reverse().find(s=>s.performance?.updateTiming)?.performance.updateTiming||{};
 const result={generatedAt:new Date().toISOString(),report:reportFile,manifest:report.identity?.servedManifest,
  identity:report.identity?.identity?.scriptFingerprint,
  inputs:[{file:reportFile,sha256:sha(reportRaw)},{file:profileFile,sha256:sha(profileRaw)},{file:timelineFile,sha256:sha(timelineRaw)}],
  result:report.result,functionality:report.functionality,continuity:report.continuity,
  alignment:{startPerformanceBoundsMs:bounds,widthMs:round(bounds[1]-bounds[0]),durationMs:round(duration),
   startUtcBounds:bounds.map(local),endUtcBounds:bounds.map(b=>local(b+duration)),
   sampleDeltaTotalMs:round(samples.at(-1)?.end||0),maxSampleDeltaMs:round(Math.max(0,...samples.map(s=>s.delta)))},
  scope:{longTasksOverlappingProfile:tasks.length,selectedTasks:windows.length,latestOpeningUpdateTimingLabels:Object.keys(latestStats)},
  wholeProfile:attribute(samples,{at:mid,duration},bounds),windows,slowCalls,
  limitations:[
   'Profiler sampling adds overhead. This is a diagnostic run, not an uninstrumented performance baseline or an optimization A/B.',
   'Profile start maps somewhere within the two recorded performance.now bounds. Midpoint rankings are approximate; endpoint class rankings show sensitivity at both bounds.',
   'Alignment envelope common/union totals are intersections/unions across possible relative task windows, not a minimum/maximum CPU-time estimate; the union may exceed task duration.',
   'Each timeDelta interval is attributed to its recorded sample stack. Intervals are not exact CPU durations, and long sampler gaps can overweight a single observed stack.',
   'GC observed in a stack is evidence for that sampled interval only. Unnamed WASM indexes are not decoded into engine functions or lock owners.',
   'Network callback stacks identify dispatch context, not a proven blocking I/O or mutex owner. Native GC and spin waits may remain unnamed WASM.',
   'Inclusive rows overlap; class rows are mutually exclusive. No GPU timing, audible discontinuity or target-device performance is established.',
   'Nearest observed state has an explicit timing offset. Browser shot labels are QA markers and can lag actual shot or hall return.',
   'Module wrappers using package.loaded did not appear in live boot samples; do not infer module costs from absent labels or the offline helper test.'
  ]};
 for(const input of result.inputs)if(sha(fs.readFileSync(input.file))!==input.sha256)throw Error('Input changed during analysis: '+input.file);
 return result;
}
if(require.main===module){
 if(!process.argv[2])throw Error('Usage: node summarize-intro-exit-profile.cjs REPORT.json [OUTPUT.json]');
 const result=analyze(path.resolve(process.argv[2]));
 if(process.argv[3])fs.writeFileSync(path.resolve(process.argv[3]),JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({manifest:result.manifest,alignment:result.alignment,scope:result.scope,
  windows:result.windows.map(w=>({at:w.at,duration:w.duration,shot:w.shot,nearest:w.nearestObservedState,
   classes:w.classes,topSelf:w.topSelf.slice(0,4),topStacks:w.topStacks.slice(0,2)}))},null,2));
}
module.exports={buildSamples,attribute,analyze};

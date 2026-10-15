const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),prefix=process.argv[2]||'intro-natural-web-1600x900-prewarm-standalone-b8b63ade';
const dir=path.join(root,'docs/migration/evidence'),report=JSON.parse(fs.readFileSync(path.join(dir,prefix+'.json')));
const log=fs.readFileSync(path.join(dir,prefix+'.log'),'utf8').split(/\r?\n/);
const timelinePath=path.join(dir,prefix+'-audio-timeline.json');
const timeline=fs.existsSync(timelinePath)?JSON.parse(fs.readFileSync(timelinePath,'utf8')):null;
const snapshotAssets=report.identity?.source_directory&&path.join(report.identity.source_directory,'assets');
const metadataRoot=snapshotAssets&&fs.existsSync(snapshotAssets)?snapshotAssets:path.join(root,'assets');
const shaderPaths=new Map();
function Register(uuid,entry){
 const key=uuid.replaceAll('-','_');
 const old=shaderPaths.get(key);
 shaderPaths.set(key,shaderPaths.has(key)&&(!old||old.uuid!==entry.uuid)?null:entry);
}
function ShaderMetadata(directory){for(const e of fs.readdirSync(directory,{withFileTypes:true})){
 const file=path.join(directory,e.name);if(e.isDirectory())ShaderMetadata(file);
 else if(file.endsWith('.shader.meta')){const data=JSON.parse(fs.readFileSync(file,'utf8'));if(data.uuid)Register(data.uuid,{uuid:data.uuid,path:'assets/'+path.relative(metadataRoot,file.slice(0,-5)).replaceAll('\\','/')});}
}}
ShaderMetadata(metadataRoot);
let active='boot',afterWarm=false;const shaders=[],warm=[];
for(const line of log){
 const shot=line.match(/\[Intro\] ([\w-]+)\s*$/);if(shot)active=shot[1];
 if(line.includes('[IntroWarmup]')){warm.push(line);if(line.includes('restored frames='))afterWarm=true;}
 if(afterWarm&&line.includes('Succeed to compile shader')){
  const uuid=line.match(/surface_(?:pbr|unlit|clearcoat|light)_([A-Za-z0-9_]{24})_/)?.[1];
  const stamp=line.match(/^\[(\d{4})-(\d\d)-(\d\d) (\d\d)_(\d\d)_(\d\d)_(\d{3})\]/);
  const wall=stamp&&timeline?.timeOrigin?Date.UTC(...stamp.slice(1).map(Number).map((v,i)=>i===1?v-1:v))+timeline.timezoneOffset*60000:null;
  const at=wall===null?null:wall-timeline.timeOrigin;
  const inside=interval=>at!==null&&at>=interval.at-interval.dt&&at<=interval.at;
  const metadata=uuid&&shaderPaths.get(uuid);
  shaders.push({shot:active,line,uuid:uuid||null,sourceUuid:metadata?.uuid||null,sourcePath:metadata?.path||null,defines:line.match(/defines \[(.*?)\]/)?.[1]||null,
   at,overlappingAudioGaps:report.audioContinuity.starvationCandidates.filter(inside),overlappingRafFreezes:report.audioContinuity.rafFreezes.filter(inside)});
 }
}
const result={identity:report.identity,functionality:report.functionality,continuity:report.continuity,enemyHit:report.enemyHit,driveDistance:report.driveDistance,
 lifecycleErrors:log.filter(line=>/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(line)),
 audioWorst:report.audioContinuity.starvationCandidates.slice().sort((a,b)=>b.dt-a.dt).slice(0,12),
 rafWorst:report.audioContinuity.rafFreezes.slice().sort((a,b)=>b.dt-a.dt).slice(0,12),
 warmup:warm,afterWarmShaderCount:shaders.length,shaders,metadataRoot,
 boundary:'Shader sourcePath resolves the immutable served snapshot metadata when available, otherwise current assets. Runtime shader identifiers normalize UUID hyphens to underscores; sourceUuid preserves the actual metadata UUID, and ambiguous or unmatched identifiers remain null. at and overlaps require recorded performance.timeOrigin and local timezone offset; older evidence leaves them null. A compile log completion inside a callback/frame gap is correlation only, not a CPU-duration attribution. Screenshot instrumentation and competing runtime workload come from the report.'};
result.observedLifecycle=result.lifecycleErrors.length?'FAIL':'NO_ERRORS_OBSERVED';
if(timeline?.timeOrigin){
 const origin=timeline.timeOrigin;
 const snapshot=s=>s&&({at:s.at-origin,shot:s.shot,age:s.age,step:s.sortie?.step,line:s.line,
  luaMiB:s.performance?.luaKiB/1024,soundBytes:s.performance?.soundBytes,
  voice:s.audio?.voice.resource,voicePlaying:s.audio?.voice.playing,prepared:s.audio?.prepared,openingTiming:s.openingTiming});
 result.audioGapContexts=report.audioContinuity.starvationCandidates.map(g=>{
  const start=g.at-g.dt;
  const before=report.samples.findLast(s=>s.at-origin<=start);
  const after=report.samples.find(s=>s.at-origin>=g.at);
  const during=report.samples.filter(s=>s.at-origin>start&&s.at-origin<g.at);
  const overlap=(a,b,c,d)=>Math.max(0,Math.min(b,d)-Math.max(a,c));
  const timingWindow={};
  for(const [name,end]of Object.entries(after?.openingTiming||{})){
   const begin=before?.openingTiming?.[name]||{calls:0,totalMs:0,maxMs:0};
   timingWindow[name]={calls:end.calls-begin.calls,totalMs:end.totalMs-begin.totalMs,maxMs:end.maxMs,
    newMaximum:end.maxMs>begin.maxMs,maxShot:end.maxShot,maxAge:end.maxAge};
  }
  return {...g,before:snapshot(before),during:during.map(snapshot),after:snapshot(after),timingWindow,
   shaderEvents:shaders.filter(s=>s.at>=start&&s.at<=g.at).map(s=>({at:s.at,sourcePath:s.sourcePath,defines:s.defines})),
   longTaskOverlapMs:timeline.longTasks.reduce((n,t)=>n+overlap(start,g.at,t.at,t.at+t.duration),0)};
 });
 result.methodTiming=Object.fromEntries(Object.entries(report.samples.findLast(s=>s.openingTiming)?.openingTiming||{}).map(([name,value])=>[name,{...value,meanMs:value.calls?value.totalMs/value.calls:0}]));
 result.methodRanking=Object.entries(result.methodTiming).map(([name,value])=>({name,...value})).sort((a,b)=>b.totalMs-a.totalMs);
 result.worstGapMethodRanking=result.audioGapContexts.slice().sort((a,b)=>b.dt-a.dt).slice(0,8).map(g=>({
  at:g.at,dt:g.dt,beforeShot:g.before?.shot,afterShot:g.after?.shot,longTaskOverlapMs:g.longTaskOverlapMs,
  methods:Object.entries(g.timingWindow).map(([name,value])=>({name,...value})).filter(v=>v.calls>0).sort((a,b)=>b.totalMs-a.totalMs)
 }));
 result.timingBoundary='Method wrappers measure inclusive instance calls at millisecond granularity and add probe overhead. Parent/child methods overlap, so durations must not be summed. Gap timingWindow spans the nearest sampled state before and after the PCM interval, possibly several frames beyond it; it is a bounded sample window, not an exact callback stack or uninstrumented CPU trace.';
}
fs.writeFileSync(path.join(dir,prefix+'-analysis.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify({afterWarmShaderCount:shaders.length,byShot:shaders.reduce((out,s)=>(out[s.shot]=(out[s.shot]||0)+1,out),{}),audioWorst:result.audioWorst.slice(0,3),rafWorst:result.rafWorst.slice(0,3)},null,2));

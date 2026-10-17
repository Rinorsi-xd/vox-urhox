const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const defaultEvidence='docs/migration/evidence/salvage-natural-manifest-8d107d95-2026-10-16T15-36-48-056Z';
function analyze(bytes){
 const lines=bytes.toString('utf8').split(/\r?\n/),states=[],records=[],fatals=[],parseErrors=[];
 for(let i=0;i<lines.length;i++){
  if(/^Aborted\(OOM\)/.test(lines[i]))fatals.push({line:i+1,message:lines[i]});
  for(const [tag,out]of [['OUTGAME_STATE ',states],['VOX_PERF ',records]]){
   const at=lines[i].indexOf(tag);if(at<0)continue;
   try{out.push({line:i+1,data:JSON.parse(lines[i].slice(at+tag.length))});}
   catch(error){parseErrors.push({line:i+1,tag,error:error.message});}
  }
 }
 const samples=records.filter(x=>x.data.type==='sample'),groups=new Map(),seen=new Set(),types={};
 for(const record of records){const row=types[record.data.type]??={count:0,jsonUtf8Bytes:0};row.count++;row.jsonUtf8Bytes+=Buffer.byteLength(JSON.stringify(record.data));}
 for(const {line,data:s}of samples){
  if(s.context?.map!=='salvage'||s.context.loading)continue;
  let g=groups.get(s.context.vehicles);
  if(!g)groups.set(s.context.vehicles,g={vehicles:s.context.vehicles,windows:0,firstLine:line,lastLine:line,frames:[],stages:{},details:{},lua:0,steps:0,monitor:[]});
  g.windows++;g.lastLine=line;g.monitor.push(s.monitorMs);
  for(const r of s.frameSamples){
   if(r.context?.map!=='salvage'||r.context.loading)continue;
   const id=s.session+':'+r.frame;assert.ok(!seen.has(id),'Duplicate detailed frame '+id);seen.add(id);
   g.frames.push(r.frameMs);g.lua+=r.scriptMs;g.steps+=r.steps;
   for(let i=0;i<r.stageTimes.length;i+=5){
    const name=s.stageNames[r.stageTimes[i]-1];assert.ok(name,'Every numeric stage id has its emitted dictionary');g.stages[name]=(g.stages[name]||0)+r.stageTimes[i+1];
    const stat=g.details[name]??={ms:0,selfMs:0,calls:0,maxMs:0};stat.ms+=r.stageTimes[i+1];stat.selfMs+=r.stageTimes[i+2];stat.calls+=r.stageTimes[i+3];stat.maxMs=Math.max(stat.maxMs,r.stageTimes[i+4]);
   }
  }
 }
 const average=a=>a.reduce((sum,n)=>sum+n,0)/a.length,percentile=(a,p)=>[...a].sort((a,b)=>a-b)[Math.ceil(a.length*p)-1];
 const salvage=states.filter(x=>x.data.salvageRun),timelineLines=[2687,3183,3195,3308,3417,3556,3643,3721,3807,3921,3923];
 return {
  logSha256:crypto.createHash('sha256').update(bytes).digest('hex'),logBytes:bytes.length,parseErrors,fatals,
  stateRows:states.length,salvageStateRows:salvage.length,monitorTypes:types,
  monitorSamples:samples.length,maxSampleFrames:Math.max(...samples.map(x=>x.data.frameSamples.length)),maxStageDictionary:Math.max(...samples.map(x=>x.data.stageNames.length)),
  salvageLuaKiB:{min:Math.min(...salvage.map(x=>x.data.performance.luaKiB)),max:Math.max(...salvage.map(x=>x.data.performance.luaKiB))},
  timeline:timelineLines.map(line=>{
   const row=states.find(x=>x.line===line);if(!row)return{line,missing:true};const d=row.data,p=d.performance;
   return{line,time:d.salvageRun.time,luaKiB:p.luaKiB,resourceBytes:p.resourceBytes,modelBytes:p.modelBytes,soundBytes:p.soundBytes,enemies:d.salvageRun.enemies,shots:d.weapons.shots,hits:d.weapons.hits,kills:d.salvageRun.kills};
  }),
  completeSampledSalvageFrames:seen.size,
  groups:[...groups.values()].map(g=>({vehiclesAtWindowEnd:g.vehicles,windows:g.windows,firstLine:g.firstLine,lastLine:g.lastLine,frames:g.frames.length,
   frameMeanMs:average(g.frames),p50Ms:percentile(g.frames,.5),p95Ms:percentile(g.frames,.95),maxMs:Math.max(...g.frames),luaMeanMs:g.lua/g.frames.length,stepsMean:g.steps/g.frames.length,
   vehicleMeanInclusiveMs:(g.stages['vehicle.Step']||0)/g.frames.length,aiMeanMs:(g.stages['ai.Step']||0)/g.frames.length,physicsMeanMs:(g.stages['physics.Step']||0)/g.frames.length,
   monitorFinalizeMeanMs:average(g.monitor),monitorFinalizeMaxMs:Math.max(...g.monitor),
   top20Self:Object.entries(g.details).sort((a,b)=>b[1].selfMs-a[1].selfMs).slice(0,20).map(([name,s])=>({name,selfMsPerFrame:s.selfMs/g.frames.length,inclusiveMsPerFrame:s.ms/g.frames.length,callsPerFrame:s.calls/g.frames.length,maxSingleCallMs:s.maxMs})),
   allStages:Object.entries(g.details).map(([name,s])=>({name,selfMsPerFrame:s.selfMs/g.frames.length,inclusiveMsPerFrame:s.ms/g.frames.length,callsPerFrame:s.calls/g.frames.length,maxSingleCallMs:s.maxMs}))})),
  boundary:'Same original enabled-monitor QA log. Grouping uses end-of-sample vehicle count and includes changing positions, inputs, spawns and firing. Not controlled scaling, isolated thread CPU, old/new A/B, presented FPS or total WASM/native/GPU allocation. Inclusive vehicle tree is already inside Lua. Monitor finalization excludes all wrapper overhead. Complete sampled frames do not cover missing tail at abort.',
 };
}
if(require.main===module){
 const directory=path.resolve(process.argv[2]||defaultEvidence),result=analyze(fs.readFileSync(path.join(directory,'salvage-natural-web.log')));
 assert.equal(result.parseErrors.length,0,'All captured JSON records parse');
 const out=path.join(directory,'salvage-oom-readonly-analysis.json');fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({result:'ANALYZED',out,states:result.stateRows,salvage:result.salvageStateRows,frames:result.completeSampledSalvageFrames,fatals:result.fatals,elevenVehicles:result.groups.find(g=>g.vehiclesAtWindowEnd===11)}));
}
module.exports={analyze};

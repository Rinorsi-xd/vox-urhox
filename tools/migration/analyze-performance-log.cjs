const fs=require('node:fs'),path=require('node:path'),readline=require('node:readline');
function stats(values){const sorted=values.filter(Number.isFinite).sort((a,b)=>a-b),count=sorted.length;if(!count)return {count:0};const at=p=>sorted[Math.max(0,Math.ceil(count*p)-1)];return {count,meanMs:sorted.reduce((a,b)=>a+b,0)/count,p50Ms:at(.5),p95Ms:at(.95),p99Ms:at(.99),maxMs:sorted[count-1]}}
function sceneOf(record){
 const c=record.context||{},mode=String(record.mode??c.mode??c.tab??'unknown');
 let scene=record.scene??c.scene;
 if(scene==null){
  const map=c.map||'unknown-map';
  if(c.loading)scene='loading:'+map+':'+(c.loadingStepId??c.loadingStep??c.loadingPhase??c.loaderPhase??'pending');
  else if(c.map){scene=String(map);if(c.story)scene+=':story:'+c.story+':step:'+(c.storyStep??'unknown');else if(c.matchState)scene+=':match:'+c.matchState}
  else scene=c.tab??c.screen??(mode==='unknown'?'unknown':mode);
 }
 return {scene:String(scene),mode};
}
function finite(value){return typeof value==='number'&&Number.isFinite(value)?value:null}
function emptyTable(value){return value&&typeof value==='object'&&!Array.isArray(value)&&Object.keys(value).length===0}
function frameStageDetails(frame){
 if(frame._fullStageSource){
  return {status:'available',source:frame._fullStageSource,rows:(Array.isArray(frame.stages)?frame.stages:[]).filter(s=>s&&typeof s.name==='string').map(s=>({...s}))};
 }
 if(!Object.prototype.hasOwnProperty.call(frame,'stageTimes'))return frame._fallbackStages?{status:'available',source:'sample_frame',rows:frame._fallbackStages.map(s=>({...s}))}:{status:'unavailable',source:'none',rows:[]};
 const times=frame.stageTimes,names=frame._stageNames;
 if(emptyTable(times))return {status:'available',source:'compact',rows:[]};
 if(!Array.isArray(times)||times.length%5!==0)return {status:'unavailable',source:'invalid_compact',rows:[]};
 const rows=[];
 for(let i=0;i<times.length;i+=5){
  const id=times[i],name=Array.isArray(names)?names[id-1]:names?.[id];
  if(!Number.isInteger(id)||id<1||typeof name!=='string'||!times.slice(i+1,i+5).every(Number.isFinite))return {status:'unavailable',source:'unresolved_compact',rows:[]};
  rows.push({name,ms:times[i+1],selfMs:times[i+2],calls:times[i+3],maxMs:times[i+4]});
 }
 return {status:'available',source:'compact',rows};
}
function csvCell(value){const text=value==null?'':String(value);return /[",\r\n]/.test(text)?'"'+text.replaceAll('"','""')+'"':text}
function framesCsv(frames){
 const columns=['session','scene','mode','frame','frameMs','wallMs','scriptMs','steps','stage','inclusiveMs','selfMs','calls','maxMs','detailStatus','detailSource'];
 const lines=[columns.join(',')];
 for(const frame of frames){
  const base=[frame.session,frame.scene,frame.mode,frame.frame,frame.frameMs,frame.wallMs,frame.scriptMs,frame.steps];
  if(!frame.stages.length)lines.push([...base,'','','','','',frame.detailStatus==='available'?'available_empty':'unavailable',frame.detailSource].map(csvCell).join(','));
  else for(const stage of frame.stages)lines.push([...base,stage.name,stage.ms,stage.selfMs,stage.calls,stage.maxMs,frame.detailStatus,frame.detailSource].map(csvCell).join(','));
 }
 return lines.join('\r\n')+'\r\n';
}
async function analyze(inputs,options={}){
 const groups=new Map(),sessions=new Map(),seen=new Set(),framesById=new Map();let lines=0,invalidLines=0,duplicates=0;
 function group(record){const scene=sceneOf(record),key=JSON.stringify([scene.scene,scene.mode]);if(!groups.has(key))groups.set(key,{...scene,records:0,types:{},frames:new Map(),stages:new Map(),slowFrames:[],browserLongtasks:[],errors:[],markers:[],sampleDrops:0});return groups.get(key)}
 function addFrame(g,record,parent){
  if(!Number.isFinite(record.frame))return;
  const key=parent.session+':'+record.frame,previous=framesById.get(key),old=previous?.value,full=(parent.type==='slow_frame'||parent.type==='error_frame')&&(Array.isArray(record.stages)||emptyTable(record.stages));
  const value={session:parent.session,...record};
  if(parent.type==='sample'&&parent.frame===record.frame&&(Array.isArray(parent.stages)||emptyTable(parent.stages)))value._fallbackStages=Array.isArray(parent.stages)?parent.stages.filter(s=>s&&typeof s.name==='string'):[];
  if(parent.stageNames)value._stageNames=parent.stageNames;
  if(full)value._fullStageSource=parent.type;
  const target=old?full||!old._fullStageSource?g:previous.group:g;
  const merged=!old||full||!old._fullStageSource?{...old,...value}:{...value,...old,...(value._stageNames?{_stageNames:value._stageNames}:{})};
  if(previous&&previous.group!==target)previous.group.frames.delete(key);
  target.frames.set(key,merged);framesById.set(key,{group:target,value:merged});
 }
 for(const file of inputs){const reader=readline.createInterface({input:fs.createReadStream(file),crlfDelay:Infinity});for await(const line of reader){
  if(!line.trim())continue;lines++;let r;try{r=JSON.parse(line);if(!r||typeof r!=='object'||Array.isArray(r)||typeof r.type!=='string'||typeof r.session!=='string')throw Error('record')}catch{invalidLines++;continue}
  const session=sessions.get(r.session)||{session:r.session,transportRecords:0,records:0,duplicateTransportRecords:0,types:{},collectorDrops:0,pagehideUnflushed:0};session.transportRecords++;sessions.set(r.session,session);
  const id=r._collector&&typeof r._collector.pageId==='string'&&Number.isFinite(r._collector.sequence)?r._collector.pageId+':'+r._collector.sequence:null;if(id){if(seen.has(id)){duplicates++;session.duplicateTransportRecords++;continue}seen.add(id)}
  const g=group(r);g.records++;g.types[r.type]=(g.types[r.type]||0)+1;
  session.records++;session.types[r.type]=(session.types[r.type]||0)+1;if(r.type==='collector_drop'||r.type==='collector_pagehide')session.collectorDrops=Math.max(session.collectorDrops,r.droppedRecords||0);if(r.type==='collector_pagehide')session.pagehideUnflushed=Math.max(session.pagehideUnflushed,r.unflushedRecords||0);
  if(r.type==='sample'||r.type==='sample_tail'){
   g.sampleDrops+=r.sampleDrops||0;
   if(Array.isArray(r.frameSamples)){
    for(const f of r.frameSamples)addFrame(f.context||f.scene||f.mode?group({...f,session:r.session}):g,f,r);
    if(Number.isFinite(r.frame)&&!r.frameSamples.some(f=>f.frame===r.frame))addFrame(g,r,r);
   }
   else addFrame(g,r,r);
  }else if(r.type==='slow_frame'||r.type==='error_frame')addFrame(g,r,r);
  if(Array.isArray(r.stages))for(const stage of r.stages){
   if(typeof stage.name!=='string')continue;
   const key=r.type+':'+stage.name,s=g.stages.get(key)||{type:r.type,name:stage.name,observations:0,inclusiveMs:0,selfMs:0,calls:0,maxMs:0};s.observations++;s.inclusiveMs+=finite(stage.ms)||0;s.selfMs+=finite(stage.selfMs)||0;s.calls+=finite(stage.calls)||0;s.maxMs=Math.max(s.maxMs,finite(stage.maxMs)||0);g.stages.set(key,s);
  }
  if(r.type==='slow_frame'){
   const stages=Array.isArray(r.stages)?r.stages:[],wall=finite(r.wallMs)??finite(r.frameMs),script=finite(r.scriptMs)??finite(r.cpuMs),unattributed=finite(r.unattributedMs)??(wall!==null&&script!==null?wall-script:null);
   g.slowFrames.push({...r,wallMs:wall,scriptMs:script,intervalIncomplete:r.intervalIncomplete===true,unattributedMs:unattributed,topSelf:stages.slice().sort((a,b)=>(b.selfMs||0)-(a.selfMs||0)).slice(0,6),topInclusive:stages.slice().sort((a,b)=>(b.ms||0)-(a.ms||0)).slice(0,6)});
  }
  if(r.type==='browser_longtask')g.browserLongtasks.push({session:r.session,atMs:r.atMs,durationMs:r.durationMs});
  if(r.type==='browser_error')g.errors.push({session:r.session,atMs:r.atMs,source:r.source,message:r.message});
  if(r.type==='error_frame'||r.errors?.length||r.error)g.errors.push({...r});
  if(r.type==='marker')g.markers.push({session:r.session,frame:r.frame,atMs:r.atMs,label:r.label||r.name});
 }}
 const exportedFrames=[];
 const byScene=[...groups.values()].map(g=>{
  const frames=[...g.frames.values()],metric=name=>stats(frames.map(f=>finite(f[name])).filter(v=>v!==null));
  const stages=[...g.stages.values()].sort((a,b)=>b.selfMs-a.selfMs);
  const steps=stats(frames.map(f=>finite(f.steps)).filter(v=>v!==null));
  let availableFrames=0;const frameStageMap=new Map(),unavailableSources={};
  for(const frame of frames){
   const detail=frameStageDetails(frame);
   if(detail.status==='available'){
    availableFrames++;
    for(const stage of detail.rows){
     let s=frameStageMap.get(stage.name);if(!s){s={name:stage.name,observedFrames:0,calledFrames:0,calls:0,inclusiveMs:0,selfMs:0,maxMs:0,inclusiveValues:[],selfValues:[]};frameStageMap.set(stage.name,s)}
     s.observedFrames++;if(stage.calls>0)s.calledFrames++;s.calls+=stage.calls||0;s.inclusiveMs+=stage.ms||0;s.selfMs+=stage.selfMs||0;s.maxMs=Math.max(s.maxMs,stage.maxMs||0);s.inclusiveValues.push(stage.ms||0);s.selfValues.push(stage.selfMs||0);
    }
   }else unavailableSources[detail.source]=(unavailableSources[detail.source]||0)+1;
   if(options.includeFrames)exportedFrames.push({session:frame.session,scene:g.scene,mode:g.mode,frame:frame.frame,frameMs:frame.frameMs,wallMs:frame.wallMs,scriptMs:finite(frame.scriptMs)??finite(frame.cpuMs),steps:frame.steps,detailStatus:detail.status,detailSource:detail.source,stages:detail.rows});
  }
  const frameStages=[...frameStageMap.values()].map(s=>{
   const zeros=Array(Math.max(0,availableFrames-s.observedFrames)).fill(0),{inclusiveValues,selfValues,...summary}=s;
   return {...summary,availableFrames,inclusivePerFrame:stats(inclusiveValues.concat(zeros)),selfPerFrame:stats(selfValues.concat(zeros))};
  }).sort((a,b)=>b.selfMs-a.selfMs||a.name.localeCompare(b.name));
  return {scene:g.scene,mode:g.mode,records:g.records,types:g.types,uniqueFrames:frames.length,frameMs:metric('frameMs'),wallMs:metric('wallMs'),scriptMs:stats(frames.map(f=>finite(f.scriptMs)??finite(f.cpuMs)).filter(v=>v!==null)),incompleteIntervals:frames.filter(f=>f.intervalIncomplete).length,steps:{count:steps.count,mean:steps.meanMs,p50:steps.p50Ms,p95:steps.p95Ms,p99:steps.p99Ms,max:steps.maxMs},sampleDrops:g.sampleDrops,frameStageCoverage:{availableFrames,unavailableFrames:frames.length-availableFrames,unavailableSources},frameStages,stagesByRecordType:stages,slowFrames:g.slowFrames.sort((a,b)=>(b.frameMs||b.wallMs||0)-(a.frameMs||a.wallMs||0)),browserLongtasks:g.browserLongtasks,errors:g.errors,markers:g.markers};
 }).sort((a,b)=>a.scene.localeCompare(b.scene)||a.mode.localeCompare(b.mode));
 return {schema:2,inputs,lines,invalidLines,duplicateTransportRecords:duplicates,sessions:[...sessions.values()],byScene,...(options.includeFrames?{frames:exportedFrames.sort((a,b)=>a.session.localeCompare(b.session)||a.frame-b.frame)}:{}),boundaries:['Frame percentiles use recorded sample/sample_tail frameSamples plus slow/error frames, deduplicated globally by session/frame. Full slow/error context takes precedence when compact loading context has fewer fields. Missing or dropped samples are not reconstructed.','frameStages uses one detailed observation per frame, preferring full slow/error stages over compact stageTimes. Per-frame averages and percentiles include zero calls in available frames; unavailable old/invalid compact detail is excluded, never treated as zero. CSV emits only recorded stages, plus one explicit empty/unavailable row when no stages exist.','frameMs is the complete Update-to-next-Update interval, finalized on the next Update; wallMs is that same frame Update-to-EndFrame. Lua stages/context belong to that frame. Do not add frameMs and wallMs. intervalIncomplete marks the final frame with wallMs only.','Stage inclusive and self totals are separate. Nested inclusive rows must never be summed; record types are separated because sample and slow_frame can overlap. A sample record stages array describes its emitting frame, not every frame in its frameSamples window.','scriptMs/cpuMs are elapsed Lua scope timings, not precise thread CPU time. Unattributed wall time is not a GPU measurement.','Page or renderer crashes can prevent final delivery; browser events and collector drop counts only describe observed delivery.']};
}
function listInputs(target){const resolved=path.resolve(target);if(fs.statSync(resolved).isDirectory())return fs.readdirSync(resolved,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?listInputs(path.join(resolved,entry.name)):entry.name.endsWith('.jsonl')?[path.join(resolved,entry.name)]:[]);return [resolved]}
async function main(){const args=process.argv.slice(2),target=args.find(a=>!a.startsWith('--'));if(!target)throw Error('Usage: node analyze-performance-log.cjs <session.jsonl|directory> [--out=<summary.json>] [--frames]');const inputs=listInputs(target).sort();if(!inputs.length)throw Error('No JSONL logs found');const report=await analyze(inputs,{includeFrames:args.includes('--frames')}),output=path.resolve(args.find(a=>a.startsWith('--out='))?.slice(6)||(fs.statSync(target).isDirectory()?path.join(target,'performance-summary.json'):target+'.summary.json'));if(report.frames){const csv=output.replace(/\.json$/i,'')+'.frames.csv';await fs.promises.writeFile(csv,framesCsv(report.frames));report.framesCsv={file:csv,frames:report.frames.length};delete report.frames;console.log('Per-frame stages: '+csv)}await fs.promises.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log('Performance log: '+output);console.log(`${report.lines} lines, ${report.invalidLines} invalid, ${report.duplicateTransportRecords} transport duplicates`);for(const scene of report.byScene){console.log(`${scene.scene}/${scene.mode}: ${scene.uniqueFrames} recorded frames, P50/P95/P99 ${scene.frameMs.p50Ms??'-'}/${scene.frameMs.p95Ms??'-'}/${scene.frameMs.p99Ms??'-'} ms, ${scene.slowFrames.length} slow records, stage detail ${scene.frameStageCoverage.availableFrames}/${scene.uniqueFrames}`);for(const slow of scene.slowFrames.slice(0,5))console.log(`  frame ${slow.frame}: wall ${slow.wallMs} ms, Lua ${slow.scriptMs} ms, unattributed ${slow.unattributedMs} ms; self ${slow.topSelf.slice(0,3).map(s=>s.name+'='+s.selfMs).join(', ')}`)}console.log('Unattributed time is not GPU time.');}
module.exports={analyze,stats,listInputs,sceneOf,frameStageDetails,framesCsv};if(require.main===module)main().catch(error=>{console.error(error.message);process.exitCode=1});

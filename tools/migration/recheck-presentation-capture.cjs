'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const dir=path.resolve(process.argv[2]);
const read=name=>JSON.parse(fs.readFileSync(path.join(dir,name),'utf8'));
const saved=read('frame-pipeline-summary.json'),result=read('result.json');
const all=fs.readFileSync(path.join(dir,'frame-pipeline.jsonl'),'utf8').trim().split(/\r?\n/).map(JSON.parse);
const records=all.filter(r=>r.frame.frame>saved.afterFrame&&r.frame.frame<=saved.throughFrame);
assert.equal(records.length,saved.throughFrame-saved.afterFrame);
const beforeStepMode=records[0].identity.beforeStepPipeline===true;
const beforeNames=['before.Vehicle','before.Driver','before.Weapons','before.Pick','before.Flush','before.Regenerate'];
const vehicleMode=records[0].identity.vehiclePipeline===true;
const vehicleNames=['vehicle.Sample','vehicle.Apply','vehicle.Legs','vehicle.Hover','vehicle.Contact','vehicle.LegHitboxes'];
const names=['main.Update','envelope.AppUpdate','envelope.TrialUpdate','envelope.TrialTick','presentation.CombatView','presentation.Effects','presentation.HudUpdate','main.PostUpdate','main.FramePresented','ui.Update','ui.Render'];
const parent={'envelope.AppUpdate':'main.Update','envelope.TrialUpdate':'envelope.AppUpdate','envelope.TrialTick':'envelope.TrialUpdate'};
for(const name of ['fixed.BeforeStep','fixed.WorldStep','fixed.AfterStep','presentation.CombatView','presentation.Effects','presentation.HudUpdate'])parent[name]='envelope.TrialTick';
if(beforeStepMode)for(const name of beforeNames)parent[name]='fixed.BeforeStep';
if(vehicleMode)for(const name of vehicleNames)parent[name]='before.Vehicle';
const totals={},callDurations={},frames=[],identity=JSON.stringify(records[0].identity);
let fixedSteps=0;
for(const [index,{frame:f,identity:id,dropped}]of records.entries()){
 assert.equal(f.frame,saved.afterFrame+index+1);assert(!f.partialStart&&!f.partialEnd);assert.equal(dropped,0);assert.equal(f.droppedEvents,0);assert.equal(f.callsAfterFramePresented,0);
 assert.equal(JSON.stringify(id),identity);assert.equal(Object.keys(id.presentationSources).length,5);
 if(beforeStepMode)assert.equal(Object.keys(id.beforeStepSources).length,5);
 if(vehicleMode){assert(beforeStepMode);assert.equal(Object.keys(id.vehicleSources).length,5);}
 const stack=[],observed={};let cursor=0;
 for(const [name,phase,at]of f.events){
  assert(Number.isInteger(at)&&at>=cursor&&at<=f.wallMs);cursor=at;
  if(phase==='enter'){
   if(parent[name])assert.equal(stack.at(-1)?.name,parent[name]);
   stack.push({name,at,children:0});
  }else{
   assert.equal(phase,'leave');const entry=stack.pop();assert.equal(entry.name,name);
   const elapsed=at-entry.at,row=observed[name]||={calls:0,inclusiveMs:0,selfMs:0,maxMs:0};
   row.calls++;row.inclusiveMs+=elapsed;row.selfMs+=elapsed-entry.children;row.maxMs=Math.max(row.maxMs,elapsed);
   const buckets=callDurations[name]||={lt5:{calls:0,ms:0},gte5:{calls:0,ms:0},gte20:{calls:0,ms:0}};
   const bucket=elapsed<5?buckets.lt5:buckets.gte5;bucket.calls++;bucket.ms+=elapsed;
   if(elapsed>=20){buckets.gte20.calls++;buckets.gte20.ms+=elapsed;}
   if(stack.length)stack.at(-1).children+=elapsed;
  }
 }
 assert.equal(stack.length,0);
 for(const name of new Set([...Object.keys(observed),...Object.keys(f.scopes)])){
  const row=f.scopes[name];assert.equal(row.errors,0);
  for(const key of ['calls','inclusiveMs','selfMs','maxMs'])assert.equal(observed[name][key],row[key]);
  const sum=totals[name]||={selfMs:0,inclusiveMs:0,calls:0,maxMs:0};
  sum.selfMs+=row.selfMs;sum.inclusiveMs+=row.inclusiveMs;sum.calls+=row.calls;sum.maxMs=Math.max(sum.maxMs,row.maxMs);
 }
 for(const name of names)assert.equal(f.scopes[name].calls,1);
 const scope=name=>f.scopes[name]||{calls:0,inclusiveMs:0,selfMs:0,maxMs:0},inc=name=>scope(name).inclusiveMs;
 const fixed=['fixed.BeforeStep','fixed.WorldStep','fixed.AfterStep'];
 for(const name of fixed){assert.equal(scope(name).calls,scope(fixed[0]).calls);if(!beforeStepMode||name!=='fixed.BeforeStep')assert.equal(scope(name).selfMs,inc(name));}
 if(beforeStepMode){
  assert.equal(inc('fixed.BeforeStep'),scope('fixed.BeforeStep').selfMs+beforeNames.reduce((sum,name)=>sum+inc(name),0));
  for(const name of beforeNames)if(!vehicleMode||name!=='before.Vehicle')assert.equal(scope(name).selfMs,inc(name));
  for(const name of ['before.Vehicle','before.Weapons','before.Flush','before.Regenerate'])assert(scope(name).calls>=scope('fixed.BeforeStep').calls);
  assert.equal(scope('before.Driver').calls,scope('before.Pick').calls);
 }
 if(vehicleMode){
  assert.equal(inc('before.Vehicle'),scope('before.Vehicle').selfMs+vehicleNames.reduce((sum,name)=>sum+inc(name),0));
  for(const name of vehicleNames){assert.equal(scope(name).selfMs,inc(name));assert(scope(name).calls<=scope('before.Vehicle').calls);}
 }
 const fixedMs=fixed.reduce((sum,name)=>sum+inc(name),0);fixedSteps+=scope(fixed[0]).calls;
 assert.equal(inc('main.Update'),scope('main.Update').selfMs+inc('envelope.AppUpdate'));
 assert.equal(inc('envelope.AppUpdate'),scope('envelope.AppUpdate').selfMs+inc('envelope.TrialUpdate'));
 assert.equal(inc('envelope.TrialUpdate'),scope('envelope.TrialUpdate').selfMs+inc('envelope.TrialTick'));
 assert.equal(inc('envelope.TrialTick'),scope('envelope.TrialTick').selfMs+fixedMs+inc('presentation.CombatView')+inc('presentation.Effects')+inc('presentation.HudUpdate'));
 const self=Object.values(f.scopes).reduce((sum,row)=>sum+row.selfMs,0);
 assert.equal(self,f.measuredWallMs);assert.equal(f.wallMs,self+f.unscopedWallMs);
 const presentationMs=inc('presentation.CombatView')+inc('presentation.Effects')+inc('presentation.HudUpdate');
 const endPresented=f.events.find(e=>e[0]==='main.FramePresented'&&e[1]==='leave')[2];
 frames.push({frame:f.frame,wallMs:f.wallMs,updateMs:inc('main.Update'),fixedMs,remainderMs:inc('main.Update')-fixedMs,presentationMs,unscopedMs:f.unscopedWallMs,afterPresentedMs:f.wallMs-endPresented,
  dominantExclusive:Object.entries(f.scopes).map(([name,row])=>({name,ms:row.selfMs})).concat({name:'unscoped',ms:f.unscopedWallMs}).sort((a,b)=>b.ms-a.ms)[0],steps:scope(fixed[0]).calls});
}
const sum=key=>frames.reduce((n,f)=>n+f[key],0),n=frames.length,total=sum('wallMs');
const quantile=(values,q)=>values.sort((a,b)=>a-b)[Math.max(0,Math.ceil(values.length*q)-1)];
const scopeRows=Object.entries(totals).map(([name,row])=>({name,...row,meanSelfMs:row.selfMs/n,pctFrame:row.selfMs/total*100})).sort((a,b)=>b.selfMs-a.selfMs);
for(const [name,buckets]of Object.entries(callDurations)){
 assert.equal(buckets.lt5.calls+buckets.gte5.calls,totals[name].calls);
 assert.equal(buckets.lt5.ms+buckets.gte5.ms,totals[name].inclusiveMs);
 assert(buckets.gte20.calls<=buckets.gte5.calls&&buckets.gte20.ms<=buckets.gte5.ms);
}
assert.equal(total/n,saved.meanWallMs);assert.equal(sum('remainderMs')/n,saved.presentation.means.updateRemainderMs);
assert.equal(scopeRows.reduce((n,r)=>n+r.selfMs,0)+sum('unscopedMs'),total);
let beforeStep;
if(beforeStepMode){
 beforeStep={meanBeforeMs:totals['fixed.BeforeStep'].inclusiveMs/n,meanSelfMs:totals['fixed.BeforeStep'].selfMs/n,
  means:Object.fromEntries(beforeNames.map(name=>[name,(totals[name]?.inclusiveMs||0)/n]))};
 assert.equal(beforeStep.meanBeforeMs,saved.beforeStep.meanBeforeMs);assert.equal(beforeStep.meanSelfMs,saved.beforeStep.meanSelfMs);
 for(const name of beforeNames)assert.equal(beforeStep.means[name],saved.beforeStep.means[name]);
}
let vehicle;
if(vehicleMode){
 vehicle={meanVehicleMs:totals['before.Vehicle'].inclusiveMs/n,meanSelfMs:totals['before.Vehicle'].selfMs/n,
  means:Object.fromEntries(vehicleNames.map(name=>[name,(totals[name]?.inclusiveMs||0)/n]))};
 assert.equal(vehicle.meanVehicleMs,saved.vehicle.meanVehicleMs);assert.equal(vehicle.meanSelfMs,saved.vehicle.meanSelfMs);
 for(const name of vehicleNames)assert.equal(vehicle.means[name],saved.vehicle.means[name]);
}
const out={result:'PASS',capture:path.basename(dir),rawRows:all.length,completeFrames:n,afterFrame:saved.afterFrame,throughFrame:saved.throughFrame,totalWallMs:total,meanWallMs:total/n,p50Ms:quantile(frames.map(f=>f.wallMs),.5),p95Ms:quantile(frames.map(f=>f.wallMs),.95),p99Ms:quantile(frames.map(f=>f.wallMs),.99),
 fixedSteps,fixedMeanMsPerStep:sum('fixedMs')/fixedSteps,fixedMeanMsPerFrame:sum('fixedMs')/n,remainderMeanMs:sum('remainderMs')/n,presentationMeanMs:sum('presentationMs')/n,presentationPctRemainder:sum('presentationMs')/sum('remainderMs')*100,unscopedMeanMs:sum('unscopedMs')/n,
 scopes:scopeRows,framesOver80:frames.filter(f=>f.wallMs>80),callbacksOver80:scopeRows.filter(r=>r.maxMs>80),framesOver50:frames.filter(f=>f.wallMs>50),
 callDurations:Object.fromEntries(Object.entries(callDurations).map(([name,buckets])=>[name,{...buckets,gte5PctInclusive:totals[name].inclusiveMs?buckets.gte5.ms/totals[name].inclusiveMs*100:0,gte20PctInclusive:totals[name].inclusiveMs?buckets.gte20.ms/totals[name].inclusiveMs*100:0}])),
 ...(beforeStepMode?{beforeStep}:{}),
 ...(vehicleMode?{vehicle}:{}),
 runFlags:{cdp:result.cdpCaptureRequested,presentation:result.presentationPipelineRequested,monitorDisabled:result.identity.monitorDisabled,shutdown:result.shutdown},
 probeIssues:result.probeIssues||[],runtimeErrors:result.errors||[],
 checked:['Independent raw event replay, no import of capture analyzer','Consecutive engine frames and single identity','Events match scope calls, inclusive, self and maximum','Exact direct parents and per-frame conservation','Exact sum of exclusive owners plus unscoped equals wall','Independent means match saved summary'],
 boundary:'QA integer wall times include observers, allocations, automatic GC and scheduling. This run has no zero-observer A/B, CPU/GPU split or named internal VM event. Inclusive parents overlap. Unscoped and after-presented gaps have no assigned cause. Endpoint game state is not evidence of every intervening frame. Desktop Chrome QA is not sustained Snapdragon 845/TapTap acceptance.'};
const target=path.join(dir,'independent-recheck.json');fs.writeFileSync(target,JSON.stringify(out,null,2));
console.log(JSON.stringify({...out,scopes:scopeRows.slice(0,6),callDurations:undefined,callDurationScopes:Object.keys(callDurations).length,framesOver50:out.framesOver50.length,output:target},null,2));

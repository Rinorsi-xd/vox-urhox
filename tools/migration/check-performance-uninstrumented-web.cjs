// Public controls with the gameplay PerformanceMonitor disabled. QA observers remain.
'use strict';
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const DRIVE_MS=30000;
const POLL_MS=500;
const VIEWPORT={width:1600,height:900};
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const CDP_CATEGORIES='devtools.timeline,disabled-by-default-devtools.timeline,v8,disabled-by-default-v8.wasm,blink,cc,gpu,viz,toplevel,renderer.scheduler,disabled-by-default-devtools.timeline.frame,disabled-by-default-gpu.service';

function driveDuration(value){
 const duration=Number(value===undefined?DRIVE_MS:value);
 assert.ok(Number.isInteger(duration)&&duration>=10000&&duration<=120000,'VOX_PERF_DRIVE_MS must be 10000-120000');return duration;
}

function runtimeUrl(base){
 assert.match(base||'',/^http:\/\/127\.0\.0\.1:\d+$/);
 return base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1';
}
function verifyMonitorIdentity(identity){
 assert.equal(identity.qa,true,'Explicit QA server');
 assert.equal(identity.monitorDisabled,true,'QA service explicitly disables the gameplay monitor');
}
function verifyProfileIdentity(identity,driveSections,captureCdp,trialSections=false,framePipeline=false,afterStep=false,fixedStepPipeline=false,correlateFrameTrace=false,presentationPipeline=false,beforeStepPipeline=false,vehiclePipeline=false){
 assert.ok(!identity.loadProfile&&!identity.combatProfile&&!identity.renderExperiment,'No injected performance experiment');
 assert.ok(!identity.loadingFailureTest,'Loading failure injection belongs to the separate recovery runner');
 assert.equal(identity.driveSectionsProfile===true,driveSections,'Detailed scopes require a dedicated explicit runner and QA service');
 assert.equal(identity.trialSectionsProfile===true,trialSections,'Trial sections require the explicit matching runner and QA service');
 assert.ok(!trialSections||driveSections,'Trial sections extend drive scopes');
 assert.equal(identity.afterStepProfile===true,afterStep,'AfterStep sections require the explicit matching runner and QA service');
 assert.ok(!afterStep||trialSections,'AfterStep sections extend trial scopes');
 assert.ok(!(captureCdp&&driveSections),'Keep CDP and detailed section overhead in separate runs');
 assert.equal(identity.framePipelineProfile===true,framePipeline,'Frame pipeline requires its dedicated QA service');
 assert.equal(identity.fixedStepPipelineProfile===true,fixedStepPipeline,'Fixed-step pipeline requires its dedicated QA service');
 assert.ok(!fixedStepPipeline||framePipeline,'Fixed-step pipeline extends frame pipeline');
 assert.equal(identity.presentationPipelineProfile===true,presentationPipeline,'Presentation pipeline requires its dedicated QA service');
 assert.equal(identity.beforeStepPipelineProfile===true,beforeStepPipeline,'BeforeStep pipeline requires its dedicated QA service');
 assert.ok(!beforeStepPipeline||presentationPipeline,'BeforeStep extension requires presentation pipeline');
 assert.equal(identity.vehiclePipelineProfile===true,vehiclePipeline,'Vehicle pipeline requires its dedicated QA service');
 assert.ok(!vehiclePipeline||beforeStepPipeline,'Vehicle extension requires BeforeStep pipeline');
 assert.ok(!presentationPipeline||(framePipeline&&fixedStepPipeline&&!captureCdp&&!correlateFrameTrace&&!identity.qaAimEngine&&!identity.qaSalvageStock),'Presentation pipeline requires fixed mode without trace or fixtures');
 assert.ok(!correlateFrameTrace||(framePipeline&&captureCdp),'Frame trace correlation requires both explicit captures');
 assert.ok(!framePipeline||(!driveSections&&(!captureCdp||correlateFrameTrace)&&!identity.homeRoute&&!identity.storyRoute),'Keep frame pipeline separate from other diagnostic profiles');
}
function verifyFramePipeline(snapshot,identity){
 assert.equal(snapshot?.available,true,'Frame pipeline available');
 const fixed=identity.fixedStepPipelineProfile===true;
 const presentation=identity.presentationPipelineProfile===true;
 const beforeStep=identity.beforeStepPipelineProfile===true;
 const vehicle=identity.vehiclePipelineProfile===true;
 assert.equal(snapshot.bindings,vehicle?28:beforeStep?22:presentation?16:fixed?10:7,'Exact explicit frame boundary count');
 assert.equal(snapshot.identity?.fixedSteps===true,fixed,'Actual fixed-step instrumentation identity');
 if(fixed){
  const expected=Object.fromEntries(['combat/BattleController.lua','drive/TrackWorld.lua'].map(name=>[name,identity.identity.scripts[name]]));
  assert.deepEqual(snapshot.identity.fixedStepSources,expected,'Exactly two frozen modules for three fixed-step methods');
 }
 assert.equal(snapshot.identity?.presentationPipeline===true,presentation,'Actual presentation instrumentation identity');
 if(presentation){
  const expected=Object.fromEntries(require('./build-frame-pipeline-probe.cjs').presentationModules.map(name=>[name,identity.identity.scripts[name]]));
  assert.deepEqual(snapshot.identity.presentationSources,expected,'Exactly five frozen presentation modules');
 }
 assert.equal(snapshot.identity?.beforeStepPipeline===true,beforeStep,'Actual BeforeStep instrumentation identity');
 if(beforeStep){
  const expected=Object.fromEntries(require('./build-frame-pipeline-probe.cjs').beforeStepModules.map(name=>[name,identity.identity.scripts[name]]));
  assert.deepEqual(snapshot.identity.beforeStepSources,expected,'Exactly five frozen BeforeStep modules');
 }
 assert.equal(snapshot.identity?.vehiclePipeline===true,vehicle,'Actual Vehicle instrumentation identity');
 if(vehicle){
  const expected=Object.fromEntries(require('./build-frame-pipeline-probe.cjs').vehicleModules.map(name=>[name,identity.identity.scripts[name]]));
  assert.deepEqual(snapshot.identity.vehicleSources,expected,'Exactly five frozen Vehicle modules');
 }
 assert.equal(snapshot.identity?.mainSha256,identity.identity.scripts['main.lua'],'Actual frozen pipeline entry');
 assert.equal(snapshot.identity?.probeSha256,sha(require('./build-frame-pipeline-probe.cjs').pipelineSource(presentation,beforeStep,vehicle)),'Actual pipeline observer source');
 assert.equal(snapshot.dropped,0,'No dropped frame pipeline records');
}
function verifyDriveBindings(snapshot,trialSections,afterStep=false){
 assert.equal(snapshot.trialSectionsProfile===true,trialSections,'Actual runtime trial profile matches requested identity');
 const spec=require('./trial-section-bindings.cjs').forProfile(afterStep);
 assert.equal(snapshot.bindings,trialSections?spec.expectedBindings:57,'Exact unique method binding count');
 if(trialSections){
  assert.equal(snapshot.expectedBindings,spec.expectedBindings);assert.equal(snapshot.profile,spec.profile);
  assert.deepEqual(snapshot.instanceLabels,spec.instanceLabels,'Exact unique HUD instance bindings');
 }
}
function driveSourceIdentity(identity,trialSections,afterStep=false){
 const scripts=identity.identity.scripts;
 const sources={LegGait:scripts['drive/LegGait.lua'],ContactControl:scripts['drive/ContactControl.lua']};
 if(trialSections)for(const name of require('./trial-section-bindings.cjs').forProfile(afterStep).sourceModules){
  const hash=scripts[name.replaceAll('.','/')+'.lua'];assert.equal(typeof hash,'string','Frozen trial module source '+name);sources[name]=hash;
 }
 return sources;
}
function monitorState(state){
 const perf=state?.performance;
 if(typeof perf?.monitor?.enabled==='boolean')return perf.monitor;
 if(typeof perf?.monitorEnabled==='boolean')return {enabled:perf.monitorEnabled};
 return null;
}
function activeState(state,route,storyId){
 return state?.mode==='trial'&&!state.loadingFlow?.active&&state.pointer?.captured===true&&
  (route==='match'?state.battle?.state==='live':state.story?.id===storyId);
}
function frameWindow(state){
 const frames=state?.frames;if(!frames)return null;
 assert.ok(Number.isInteger(frames.count)&&frames.count>=10,'FrameStats count >= 10');
 const result={count:frames.count};
 for(const name of ['p50','p95','p99','max']){
  assert.ok(Number.isFinite(frames[name])&&frames[name]>0,'Finite engine FrameStats '+name);
  result[name]=frames[name];
 }
 assert.ok(result.p50<=result.p95&&result.p95<=result.p99&&result.p99<=result.max,'Ordered FrameStats quantiles');
 return result;
}
function wallWindow(state){
 const wall=state?.framesWall;if(!wall)return null;
 assert.ok(Number.isInteger(wall.count)&&wall.count>0&&wall.count<=4096,'Wall interval count');
 assert.equal(wall.dropped,0,'No wall intervals dropped');
 assert.equal(wall.samplesMs.length,wall.count,'Every wall interval retained');
 assert.ok(wall.samplesMs.every(value=>Number.isInteger(value)&&value>=0),'Wall intervals use integer milliseconds');
 const total=wall.samplesMs.reduce((sum,value)=>sum+value,0);
 assert.equal(total,wall.totalMs,'Wall total matches every interval');
 assert.equal(wall.lastClockMs-wall.firstClockMs,total,'Wall window clock span matches intervals');
 const ordered=[...wall.samplesMs].sort((a,b)=>a-b);
 for(const [key,fraction]of [['p50',.5],['p95',.95],['p99',.99],['max',1]])
  assert.equal(wall[key],ordered[Math.ceil(ordered.length*fraction)-1],'Wall '+key+' derived from actual intervals');
 assert.match(wall.source,/QA Update entry wall interval/);
 return wall;
}
function wallSummary(windows){
 const retained=windows.filter(window=>window.accepted),samples=retained.flatMap(window=>window.framesWall.samplesMs);
 const excluded=windows.filter(window=>!window.accepted);
 const exclusions={windows:excluded.length,count:excluded.reduce((sum,window)=>sum+window.framesWall.count,0),
  totalMs:excluded.reduce((sum,window)=>sum+window.framesWall.totalMs,0),max:Math.max(0,...excluded.map(window=>window.framesWall.max))};
 if(!samples.length)return {windows:0,count:0,totalMs:0,excluded:exclusions};
 for(let i=1;i<retained.length;i++)assert.equal(retained[i].framesWall.firstClockMs,retained[i-1].framesWall.lastClockMs,'Consecutive wall windows without missing intervals');
 const ordered=[...samples].sort((a,b)=>a-b),totalMs=samples.reduce((sum,value)=>sum+value,0);
 return {windows:retained.length,count:samples.length,totalMs,meanMs:totalMs/samples.length,excluded:exclusions,
  p50:ordered[Math.ceil(samples.length*.5)-1],p95:ordered[Math.ceil(samples.length*.95)-1],
  p99:ordered[Math.ceil(samples.length*.99)-1],max:ordered.at(-1),over80:samples.filter(value=>value>80).length,
  boundary:'Actual consecutive QA Update entry wall intervals, including engine/waits/observers. First input window retained from a confirmed pre-input wall drain; input dispatch and the bounded pre-input boundary may be included. Not CPU time, presented FPS, or engine TimeStep.'};
}
function verifyWallCoverage(coverage,observedInputMs){
 assert.ok(Number.isFinite(observedInputMs)&&observedInputMs>0,'Positive observed input wall duration');
 assert.ok(coverage.count>0,'Actual wall intervals retained independently of engine TimeStep windows');
 // Allow endpoint delivery/Update quantization, never an unbounded missing prefix.
 const toleranceMs=Math.max(POLL_MS*2,observedInputMs*.05);
 assert.ok(Math.abs(coverage.totalMs-observedInputMs)<=toleranceMs,'Actual wall coverage must match observed input duration within '+toleranceMs+' ms');
 assert.ok(coverage.excluded.totalMs<=toleranceMs,'Excluded wall intervals exceed the bounded input boundary allowance');
 return {observedInputMs,coveredMs:coverage.totalMs,ratio:coverage.totalMs/observedInputMs,toleranceMs};
}
function truncatedState(error,payload){
 return /Unexpected end of JSON input/.test(error.message)&&!payload.trimEnd().endsWith('}');
}
function summary(windows){
 const retained=windows.filter(window=>window.accepted);
 return {
  windows:retained.length,frames:retained.reduce((sum,window)=>sum+window.frames.count,0),
  windowsOver80ms:retained.filter(window=>window.frames.max>80).map(window=>window.index),
  statistics:'Each entry is one drained, nonoverlapping engine FrameStats window. No global percentile, mean, or FPS is inferred from window quantiles or browser receive timestamps.'
 };
}
function verifyScoreboardViewport(state){
 const board=state.matchHud?.scoreboard;
 assert.equal(board?.visible,true,'Actual native scoreboard ScrollView is visible');
 const rect=board.rect;
 assert.ok(Array.isArray(rect)&&rect.length===4&&rect.every(Number.isFinite),'Actual scoreboard rectangle');
 const [x,y,w,h]=rect;
 assert.ok(w>0&&h>0,'Scoreboard has positive layout');
 assert.ok(x>=-1&&y>=-1&&x+w<=state.width+1&&y+h<=state.height+1,'Scoreboard stays inside actual viewport');
 for(const name of ['scrollX','scrollY','contentWidth','contentHeight'])assert.ok(Number.isFinite(board[name]),'Actual native '+name);
 assert.ok(board.contentWidth>0&&board.contentHeight>0,'Native scroll content has positive size');
 assert.ok(board.scrollX>=-1&&board.scrollY>=-1,'Scroll settled at nonnegative offset');
 assert.ok(board.scrollX<=Math.max(0,board.contentWidth-w)+2&&board.scrollY<=Math.max(0,board.contentHeight-h)+2,'Scroll offset stays within actual content');
 return board;
}
function scoreboardLayoutReady(state,viewport){
 const board=state.matchHud?.scoreboard;
 const actual=state.physical;
 return Array.isArray(actual)&&Math.abs(actual[0]-viewport.width)<1&&Math.abs(actual[1]-viewport.height)<1&&
  Math.abs(state.width/state.height-viewport.width/viewport.height)<.01&&
  board?.visible===true&&Array.isArray(board.rect)&&board.rect[2]>0&&board.rect[3]>0&&
  board.contentWidth>0&&board.contentHeight>0;
}
function selfTest(){
 const boardState={width:960,height:432,physical:[960,432],matchHud:{scoreboard:{visible:true,rect:[28,13,904,406],scrollX:0,scrollY:10,contentWidth:1000,contentHeight:690}}};
 verifyScoreboardViewport(boardState);
 assert.equal(scoreboardLayoutReady(boardState,{width:960,height:432}),true);
 assert.equal(scoreboardLayoutReady({...boardState,physical:[1920,864]},{width:960,height:432}),false);
 assert.equal(scoreboardLayoutReady({...boardState,width:1200,height:540},{width:960,height:432}),true);
 assert.equal(scoreboardLayoutReady({...boardState,matchHud:{scoreboard:{...boardState.matchHud.scoreboard,rect:[0,0,0,0]}}},{width:960,height:432}),false);
 assert.throws(()=>verifyScoreboardViewport({...boardState,matchHud:{scoreboard:{...boardState.matchHud.scoreboard,rect:[28,-30,904,690]}}}),/inside actual viewport/);
 assert.throws(()=>verifyScoreboardViewport({...boardState,matchHud:{scoreboard:{...boardState.matchHud.scoreboard,scrollY:900}}}),/within actual content/);
 assert.throws(()=>verifyScoreboardViewport({...boardState,matchHud:{scoreboard:{...boardState.matchHud.scoreboard,visible:false}}}),/is visible/);
 verifyProfileIdentity({},false,false);verifyProfileIdentity({driveSectionsProfile:true},true,false);
 verifyProfileIdentity({framePipelineProfile:true},false,false,false,true);
 assert.throws(()=>verifyProfileIdentity({framePipelineProfile:true},false,false),/dedicated QA service/);
 assert.throws(()=>verifyProfileIdentity({framePipelineProfile:true},false,true,false,true),/other diagnostic profiles/);
 verifyProfileIdentity({framePipelineProfile:true},false,true,false,true,false,false,true);
 assert.throws(()=>verifyProfileIdentity({},false,true,false,false,false,false,true),/both explicit captures/);
 assert.throws(()=>verifyProfileIdentity({framePipelineProfile:true},false,false,false,true,false,false,true),/both explicit captures/);
 assert.throws(()=>verifyProfileIdentity({framePipelineProfile:true,homeRoute:true},false,true,false,true,false,false,true),/other diagnostic profiles/);
 assert.throws(()=>verifyProfileIdentity({framePipelineProfile:true,driveSectionsProfile:true},true,false,false,true),/other diagnostic profiles/);
 assert.throws(()=>verifyProfileIdentity({loadingFailureTest:true},false,false),/separate recovery runner/);
 assert.throws(()=>verifyProfileIdentity({driveSectionsProfile:true},false,false),/dedicated explicit runner/);
 assert.throws(()=>verifyProfileIdentity({driveSectionsProfile:true},true,true),/separate runs/);
 verifyProfileIdentity({driveSectionsProfile:true,trialSectionsProfile:true},true,false,true);
 assert.throws(()=>verifyProfileIdentity({driveSectionsProfile:true,trialSectionsProfile:true},true,false),/matching runner/);
 assert.throws(()=>verifyProfileIdentity({trialSectionsProfile:true},false,false,true),/extend drive/);
 verifyDriveBindings({bindings:57},false);
 const trialSpec=require('./trial-section-bindings.cjs');
 const trialState={bindings:trialSpec.expectedBindings,expectedBindings:trialSpec.expectedBindings,trialSectionsProfile:true,profile:trialSpec.profile,instanceLabels:trialSpec.instanceLabels};
 verifyDriveBindings(trialState,true);
 assert.throws(()=>verifyDriveBindings({...trialState,bindings:57},true),/binding count/);
 assert.throws(()=>verifyDriveBindings({...trialState,instanceLabels:[...trialState.instanceLabels,'hud.Update']},true),/instance bindings/);
 assert.equal(runtimeUrl('http://127.0.0.1:4471'),'http://127.0.0.1:4471/outgame.html?-game_url=http://127.0.0.1:4471/game-dist/&-log=info&cached=1');
 assert.equal(runtimeUrl('http://127.0.0.1:4471').includes('vox-perf'),false);
 assert.throws(()=>runtimeUrl('https://example.com'));
 verifyMonitorIdentity({qa:true,monitorDisabled:true});
 assert.throws(()=>verifyMonitorIdentity({qa:true}));
 assert.throws(()=>verifyMonitorIdentity({qa:true,monitorDisabled:false}));
 assert.throws(()=>verifyMonitorIdentity({qa:false,monitorDisabled:true}));
 assert.deepEqual(monitorState({performance:{monitor:{enabled:false}}}),{enabled:false});
 assert.equal(monitorState({performance:{}}),null);
 const sample={mode:'trial',pointer:{captured:true},battle:{state:'live'},frames:{count:12,p50:20,p95:35,p99:85,max:90}};
 assert.equal(activeState(sample,'match'),true);
 assert.equal(activeState({...sample,loadingFlow:{active:true}},'match'),false);
 assert.equal(activeState({...sample,story:{id:'s1'}},'story','s1'),true);
 assert.deepEqual(frameWindow(sample),sample.frames);
 assert.throws(()=>frameWindow({frames:{count:10,p50:40,p95:20,p99:50,max:60}}));
 const totals=summary([{index:0,accepted:false,frames:sample.frames},{index:1,accepted:true,frames:sample.frames}]);
 assert.equal(totals.frames,12);assert.equal(totals.windows,1);assert.deepEqual(totals.windowsOver80ms,[1]);
 assert.equal('meanMs' in totals,false);assert.equal('p95' in totals,false);
 const wall={count:3,dropped:0,samplesMs:[17,174,9],totalMs:200,firstClockMs:100,lastClockMs:300,p50:17,p95:174,p99:174,max:174,source:'QA Update entry wall interval'};
 assert.equal(wallWindow({framesWall:wall}).max,174);
 assert.throws(()=>wallWindow({framesWall:{...wall,totalMs:199}}));
 assert.throws(()=>wallWindow({framesWall:{...wall,dropped:1}}));
 assert.throws(()=>wallWindow({framesWall:{...wall,p95:72}}));
 assert.equal(wallSummary([{accepted:true,framesWall:wall}]).over80,1);
 assert.throws(()=>wallSummary([{accepted:true,framesWall:wall},{accepted:true,framesWall:wall}]));
 const stalled={...wall,count:1,samplesMs:[30000],totalMs:30000,firstClockMs:100,lastClockMs:30100,p50:30000,p95:30000,p99:30000,max:30000};
 const tail={...wall,count:1,samplesMs:[33],totalMs:33,firstClockMs:30100,lastClockMs:30133,p50:33,p95:33,p99:33,max:33};
 wallWindow({framesWall:stalled});wallWindow({framesWall:tail});
 const hiddenStall=wallSummary([{accepted:false,framesWall:stalled},{accepted:true,framesWall:tail}]);
 assert.deepEqual(hiddenStall.excluded,{windows:1,count:1,totalMs:30000,max:30000});
 assert.throws(()=>verifyWallCoverage(hiddenStall,30033),/coverage must match/);
 const retainedStall=wallSummary([{accepted:true,framesWall:stalled},{accepted:true,framesWall:tail}]);
 assert.equal(retainedStall.max,30000);assert.equal(retainedStall.over80,1);
 assert.equal(verifyWallCoverage(retainedStall,30033).ratio,1);
 assert.equal(verifyWallCoverage(retainedStall,30100).coveredMs,30033);
 assert.throws(()=>verifyWallCoverage(retainedStall,10000),/coverage must match/);
 assert.throws(()=>verifyWallCoverage(wallSummary([]),30000),/wall intervals retained/);
 assert.throws(()=>verifyWallCoverage(retainedStall,NaN),/Positive observed/);
 assert.equal(truncatedState(new SyntaxError('Unexpected end of JSON input'),'{"garage":{"cards":[[0,0,'),true);
 assert.equal(truncatedState(new SyntaxError('Unexpected end of JSON input'),'{"garage":}'),false);
 assert.equal(truncatedState(new Error('FrameStats count >= 10'),'{'),false);
 assert.equal(driveDuration(),30000);assert.equal(driveDuration('10000'),10000);
 for(const value of ['9999','NaN','120001',''])assert.throws(()=>driveDuration(value));
 console.log('PASS: separate TimeStep/wall metrics, retained first-input stalls, bounded wall coverage, excluded-window diagnostics, disabled-monitor identity and public route contracts');
}

async function main(){
 const base=process.env.VOX_QA_BASE,url=runtimeUrl(base);
 const route=process.env.VOX_PERF_ROUTE||'match';assert.ok(['match','story'].includes(route));
 const matchMode=process.env.VOX_PERF_MATCH_MODE||'elimination';
 assert.ok(['elimination','conquest','escort'].includes(matchMode),'Known production match mode');
 const responsiveBoard=process.argv.includes('--scoreboard-responsive-check');
 assert.ok(!responsiveBoard||route==='match','Responsive scoreboard requires competitive route');
 const driveMs=driveDuration(process.env.VOX_PERF_DRIVE_MS);
 const captureCdp=process.argv.includes('--cdp-profile-trace');
 const driveSections=process.argv.includes('--drive-sections');
 const trialSections=process.argv.includes('--trial-sections');
 const afterStep=process.argv.includes('--after-step');
 const framePipeline=process.argv.includes('--frame-pipeline');
 const fixedStepPipeline=process.argv.includes('--fixed-step-pipeline');
 const presentationPipeline=process.argv.includes('--presentation-pipeline');
 const beforeStepPipeline=process.argv.includes('--before-step-pipeline');
 const vehiclePipeline=process.argv.includes('--vehicle-pipeline');
 const correlateFrameTrace=process.argv.includes('--correlate-frame-trace');
 const identityResponse=await fetch(base+'/identity.json');assert.equal(identityResponse.status,200);
 const identity=await identityResponse.json();verifyMonitorIdentity(identity);
 verifyProfileIdentity(identity,driveSections,captureCdp,trialSections,framePipeline,afterStep,fixedStepPipeline,correlateFrameTrace,presentationPipeline,beforeStepPipeline,vehiclePipeline);
 if(process.env.VOX_EXPECT_MANIFEST)assert.equal(identity.servedManifest,process.env.VOX_EXPECT_MANIFEST);
 const production={};
 for(const name of ['main.lua','diagnostics/PerformanceMonitor.lua']){
  const hash=sha(fs.readFileSync(path.join(__dirname,'../../scripts',name)));
  assert.equal(identity.identity?.scripts?.[name],hash,'Actual packaged monitor contract '+name);production[name]=hash;
 }
 const out=path.resolve('docs/migration/evidence/performance-'+(vehiclePipeline?'vehicle-pipeline-':beforeStepPipeline?'before-step-pipeline-':presentationPipeline?'presentation-pipeline-':fixedStepPipeline?'fixed-step-pipeline-':framePipeline?'frame-pipeline-':afterStep?'after-step-':trialSections?'trial-sections-':driveSections?'drive-sections-':'uninstrumented-')+route+'-'+Date.now());
 fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',route,matchMode,url,identity,production,driveMs,pollMs:POLL_MS,cdpCaptureRequested:captureCdp,driveSectionsRequested:driveSections,trialSectionsRequested:trialSections,afterStepRequested:afterStep,framePipelineRequested:framePipeline,fixedStepPipelineRequested:fixedStepPipeline,toolSha256:sha(fs.readFileSync(__filename)),
  startedAt:new Date().toISOString(),checks:[],errors:[],httpErrors:[],probeIssues:[],perfRecords:[],windows:[],wallWindows:[],polls:[],
  boundary:'QA service monitorDisabled=true supplies the disabled-monitor argument to Start without changing the engine URL or production main bytes; runtime monitor.enabled=false must also be observed. QA wrappers, wall sampler and F8/automatic state output add overhead. Desktop Chrome only; not Snapdragon 845, TapTap, or a zero-observer baseline. Engine TimeStep FrameStats and actual QA Update entry wall intervals are separate metrics; receive timestamps are not engine frame durations. No FPS or global mean/percentiles inferred from TimeStep window quantiles.'};
 report.frameTraceCorrelationRequested=correlateFrameTrace;
 if(presentationPipeline)report.presentationPipelineRequested=true;
 if(beforeStepPipeline)report.beforeStepPipelineRequested=true;
 if(vehiclePipeline)report.vehiclePipelineRequested=true;
 if(correlateFrameTrace)report.boundary+=' Combined coarse pipeline/CDP capture is explicitly diagnostic. Its timings cannot establish performance gain or observer overhead relative to another run. Console engine-frame anchors and CDP clock bounds must be checked before joining individual frames.';
 const driveRecords=[];
 const pipelineRecords=[];
 let browser,page,state,seq=0,frameSeq=0,wallSeq=0,lastWall=null,measuring=false,startMs=0,windowBoundary=null,storyId=null;
 let cdp,profileRunning=false,traceRunning=false,traceComplete,captureFinished=false,lineNumber=0;
 const now=()=>Number(process.hrtime.bigint()/1000000n);
 const check=(condition,label)=>{assert.ok(condition,label);report.checks.push(label)};
 const persist=()=>fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2));
 async function clockAnchor(label){
  const hostBeforeMs=now(),wallBeforeMs=Date.now();
  const metrics=await cdp.send('Performance.getMetrics');
  const timestamp=metrics.metrics.find(metric=>metric.name==='Timestamp')?.value;
  assert.ok(Number.isFinite(timestamp),'CDP monotonic Timestamp metric available');
  const hostAfterMs=now(),wallAfterMs=Date.now();
  const syncId='vox-'+label+'-'+hostBeforeMs;
  await cdp.send('Tracing.recordClockSyncMarker',{syncId});
  report.cdp.clockAnchors.push({label,syncId,hostBeforeMs,hostAfterMs,wallBeforeMs,wallAfterMs,
   cdpMonotonicSeconds:timestamp,boundary:'CDP Timestamp is browser monotonic seconds. Host request/response bounds express alignment uncertainty; trace clock_sync marker is the explicit trace reference. Console timestamps are epoch milliseconds, not trace microseconds.'});
 }
 async function startCapture(){
  report.cdp={boundary:require('./analyze-combat-cdp.cjs').BOUNDARY,categories:CDP_CATEGORIES,samplingIntervalUs:1000,clockAnchors:[],startSequence:seq};
  report.boundary+=' CDP profile/trace explicitly enabled: instrumented diagnostic run, not comparable to no-trace acceptance timing.';
  cdp=await page.context().newCDPSession(page);
  await cdp.send('Runtime.enable');await cdp.send('Performance.enable');await cdp.send('Profiler.enable');
  cdp.on('Runtime.consoleAPICalled',event=>{
   if(!traceRunning)return;
   const text=(event.args||[]).map(arg=>arg.value??arg.description??'').join(' ');
   if(!/OUTGAME_STATE |VOX_PERF |Succeed to compile shader|LoadingFlow|ERROR:|Aborted\(/.test(text))return;
   const row={hostReceivedMonotonicMs:now(),hostReceivedWallMs:Date.now(),cdpEpochMs:event.timestamp,
    executionContextId:event.executionContextId,type:event.type,text};
   fs.appendFileSync(path.join(out,'console-timeline.jsonl'),JSON.stringify(row)+'\n');
  });
  traceComplete=new Promise(resolve=>cdp.once('Tracing.tracingComplete',resolve));
  await cdp.send('Tracing.start',{categories:CDP_CATEGORIES,transferMode:'ReturnAsStream'});traceRunning=true;
  await cdp.send('Profiler.setSamplingInterval',{interval:1000});await cdp.send('Profiler.start');profileRunning=true;
  await clockAnchor('drive-start');report.cdp.startedHostMonotonicMs=now();
 }
 async function stopCapture(reason){
  if(!cdp||captureFinished)return;
  report.cdp.stopReason=reason;report.cdp.stopSequence=seq;
  if(traceRunning)await clockAnchor('drive-stop');
  if(profileRunning){const {profile}=await cdp.send('Profiler.stop');profileRunning=false;fs.writeFileSync(path.join(out,'drive.cpuprofile'),JSON.stringify(profile))}
  if(traceRunning){
   await cdp.send('Tracing.end');traceRunning=false;
   let timeout;
   const complete=await Promise.race([traceComplete,new Promise((_,reject)=>{timeout=setTimeout(()=>reject(new Error('Trace completion timeout')),30000)})]).finally(()=>clearTimeout(timeout));
   assert.ok(complete.stream,'Trace stream');const fd=fs.openSync(path.join(out,'drive.trace.json'),'w');
   try{while(true){const chunk=await cdp.send('IO.read',{handle:complete.stream});fs.writeSync(fd,chunk.base64Encoded?Buffer.from(chunk.data,'base64'):chunk.data);if(chunk.eof)break}}
   finally{fs.closeSync(fd);await cdp.send('IO.close',{handle:complete.stream})}
  }
  captureFinished=true;report.cdp.stoppedHostMonotonicMs=now();
  const analysis=require('./analyze-combat-cdp.cjs').analyze(JSON.parse(fs.readFileSync(path.join(out,'drive.cpuprofile'))),JSON.parse(fs.readFileSync(path.join(out,'drive.trace.json'))));
  fs.writeFileSync(path.join(out,'cdp-summary.json'),JSON.stringify(analysis,null,2));
  report.cdp.summary=analysis;persist();
 }
 try{
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});page=await browser.newPage({viewport:VIEWPORT});
  page.on('console',message=>{
   const line=message.text();lineNumber++;fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   const pipelineAt=line.indexOf('VOX_FRAME_PIPELINE ');
   if(pipelineAt>=0){try{
    assert.ok(framePipeline,'Unexpected frame pipeline output');
    assert.ok(Buffer.byteLength(line)<64*1024,'Bounded frame pipeline message');
    const record=JSON.parse(line.slice(pipelineAt+'VOX_FRAME_PIPELINE '.length));pipelineRecords.push(record);
    fs.appendFileSync(path.join(out,'frame-pipeline.jsonl'),JSON.stringify(record)+'\n');
   }catch(error){report.errors.push('VOX_FRAME_PIPELINE parse: '+error.message)}}
   const driveAt=line.indexOf('VOX_DRIVE_SECTIONS ');
   if(driveAt>=0){try{
    assert.ok(driveSections,'Unexpected detail output in default baseline');
    assert.ok(Buffer.byteLength(line)<256*1024,'Bounded detail console message');
    const record=JSON.parse(line.slice(driveAt+19));driveRecords.push(record);
    fs.appendFileSync(path.join(out,'drive-sections.jsonl'),JSON.stringify(record)+'\n');
   }catch(error){report.errors.push('VOX_DRIVE_SECTIONS parse: '+error.message)}}
   if(traceRunning)fs.appendFileSync(path.join(out,'runtime-alignment.jsonl'),JSON.stringify({line:lineNumber,hostReceivedMonotonicMs:now(),hostReceivedWallMs:Date.now()})+'\n');
   const perfAt=line.indexOf('VOX_PERF ');
   if(perfAt>=0){try{report.perfRecords.push(JSON.parse(line.slice(perfAt+9)))}catch(error){report.errors.push('VOX_PERF parse: '+error.message)}}
   const at=line.indexOf('OUTGAME_STATE ');
   if(at>=0){try{
    state=JSON.parse(line.slice(at+14));seq++;
    if(measuring&&driveSections)verifyDriveBindings(state.driveSections,trialSections,afterStep);
    if(measuring&&framePipeline){verifyFramePipeline(state.framePipeline,identity);assert.equal(state.framePipeline.enabled,true)}
    const receivedAt=now(),entry={sequence:seq,receivedAtMs:receivedAt,state};
    fs.appendFileSync(path.join(out,'states.jsonl'),JSON.stringify(entry)+'\n');
    const frames=frameWindow(state),framesWall=wallWindow(state);
    if(framesWall){wallSeq++;lastWall={sequence:seq,wallSequence:wallSeq,receivedAtMs:receivedAt,framesWall}}
    if(measuring&&framesWall){
     const active=activeState(state,route,storyId),previous=report.wallWindows.at(-1)?.framesWall||report.inputWallAnchor.framesWall;
     assert.equal(framesWall.firstClockMs,previous.lastClockMs,'Input wall window continues the confirmed pre-input drain');
     report.wallWindows.push({sequence:seq,receivedAfterInputMs:receivedAt-startMs,accepted:active,
      reason:active?'Active input from confirmed pre-input wall drain':'Not active gameplay',framesWall});
    }
    for(const issue of report.probeIssues){
     if(issue.transportTruncated&&!issue.recoveredBySequence){issue.recoveredBySequence=seq;issue.recoveredMode=state.mode}
    }
    if(frames){
     frameSeq++;
     if(measuring){
      const active=activeState(state,route,storyId),first=report.windows.length===0;
      report.windows.push({index:report.windows.length,sequence:seq,frameSequence:frameSeq,
       receivedAfterInputMs:receivedAt-startMs,previousDrain:windowBoundary,frames,
       accepted:!first&&active,reason:first?'Initial boundary may include pre-input frames':active?'Active continuous input':'Not active gameplay',
       route:{mode:state.mode,map:state.map,matchState:state.battle?.state,story:state.story?.id,step:state.story?.step},
       pointer:state.pointer,monitor:monitorState(state),performance:state.performance,vehicle:state.vehicle,weapons:state.weapons});
     }
     windowBoundary={sequence:seq,frameSequence:frameSeq,receivedAtMs:receivedAt};
    }
   }catch(error){
    const issue={error:error.message,afterSequence:seq,duringMeasurement:measuring,
     transportTruncated:truncatedState(error,line.slice(at+14)),bytes:Buffer.byteLength(line),tail:line.slice(-180),rawLog:'runtime.log'};
    report.probeIssues.push(issue);
    if(!issue.transportTruncated||measuring)report.errors.push('OUTGAME_STATE parse/validation: '+error.message);
   }}
   if(/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|ERROR:/.test(line))report.errors.push(line);
  });
  page.on('pageerror',error=>report.errors.push(error.message));page.on('crash',()=>report.errors.push('Renderer crash'));
  page.on('response',response=>{if(response.status()>=400)report.httpErrors.push({status:response.status(),url:response.url()})});
  async function poll(){report.polls.push({afterInputMs:startMs?now()-startMs:null,sequence:seq});await page.keyboard.press('F8')}
  function healthy(){assert.equal(report.errors.length,0,report.errors.join('\n'));assert.equal(report.perfRecords.length,0,'VOX_PERF must remain silent while disabled')}
  async function wait(predicate,label,timeout=240000){
   const deadline=now()+timeout;let nextPoll=0;
   while(!state||!predicate(state)){
    healthy();assert.ok(now()<deadline,'Timeout '+label);
    if(now()>=nextPoll){nextPoll=now()+POLL_MS;await poll()}await sleep(60);
   }return state;
  }
  async function click(text){
   const rows=s=>Array.isArray(s.widgets)?s.widgets:[];
   await wait(s=>rows(s).some(widget=>widget.text===text&&!widget.disabled&&widget.rect?.[2]>0),'button '+text);
   const widget=rows(state).find(widget=>widget.text===text&&!widget.disabled&&widget.rect?.[2]>0),old=seq;
   await page.mouse.click((widget.rect[0]+widget.rect[2]/2)/state.width*VIEWPORT.width,(widget.rect[1]+widget.rect[3]/2)/state.height*VIEWPORT.height);
   await wait(()=>seq>old,'button state '+text);
  }
  await page.goto(url);await page.bringToFront();
  await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow?.active,'hall');
  check(monitorState(state)?.enabled===false,'Direct runtime PerformanceMonitor.enabled=false');
  check(state.performance?.battleTiming?.enabled===false,'QA battle method wrappers disabled');
  await click('出战');
  if(route==='match'){
   await click({elimination:'歼灭战',conquest:'站点争夺',escort:'推车'}[matchMode]);await click('开始匹配');
   await wait(s=>s.mode==='trial'&&s.battle&&!s.loadingFlow?.active,'match',300000);
   if(state.intro?.active){await page.keyboard.press('Space');await wait(s=>!s.intro?.active,'cinematic skip')}
  }else{
   await click('剧情模式');await wait(s=>s.tab==='story'&&s.story?.ready,'story selector');
   const level=require('../../assets/Story/Mission/Level1.json').level;storyId=level.id;
   await click(level.no+'  '+level.name);await click('开始任务');
   await wait(s=>s.mode==='trial'&&s.story?.id===storyId&&!s.loadingFlow?.active,'story',300000);
  }
  await page.mouse.click(800,450);await wait(s=>activeState(s,route,storyId),'active gameplay with actual pointer capture',30000);
  await page.screenshot({path:path.join(out,'before-drive.png'),timeout:15000});
  const beforeDrain=frameSeq;await poll();await wait(()=>frameSeq>beforeDrain,'initial engine frame drain',15000);
  if(driveSections){
   check(state.driveSections?.available===true&&state.driveSections.enabled===false,'Detailed QA scopes available and initially off');
   await page.keyboard.press('ScrollLock');await poll();
   await wait(s=>s.driveSections?.enabled&&s.driveSections?.installed,'Detailed QA instrumentation installed',15000);
   check(state.driveSections.calibration?.repeats?.length===3,'Actual runtime wrapper calibration retained separately');
   verifyDriveBindings(state.driveSections,trialSections,afterStep);
   check(true,afterStep?'Exactly 108 unique drive/trial/HUD/AfterStep method wrappers':trialSections?'Exactly 102 unique drive/trial/HUD method wrappers':'Exactly 57 unique drive method wrappers, with no duplicate outer scopes');
   report.driveCalibration=state.driveSections.calibration;
   report.boundary+=' Detailed drive wrappers/source section calls explicitly enabled; synthetic wrapper calibration is recorded without subtracting it from gameplay.';
  }
  if(framePipeline){
   check(state.framePipeline?.available===true&&state.framePipeline.enabled===false,'Frame pipeline is initially off');
   await page.keyboard.press('F9');await poll();
   await wait(s=>s.framePipeline?.enabled===true,'Explicit frame pipeline capture enabled',15000);
   verifyFramePipeline(state.framePipeline,identity);
   report.boundary+=' Seven UI/main callback wrappers are an explicit diagnostic, including the existing QA callbacks. Engine frame IDs align scopes; unscoped time has no assigned owner. This run cannot establish optimization gain.';
  }
  report.beforeDrive={sequence:seq,state};windowBoundary=null;
  if(captureCdp){
   check(activeState(state,route,storyId),'CDP capture starts in active gameplay after screenshot/frame drain');
   await startCapture();
  }
  // Drain after optional trace setup, then start observing before input dispatch:
  // the first movement/fire stall must remain in the raw wall measurement.
  const inputDrain=wallSeq;await poll();await wait(()=>wallSeq>inputDrain,'confirmed pre-input wall drain',15000);
  check(activeState(state,route,storyId),'Wall input anchor is active gameplay');
  report.inputWallAnchor=lastWall;
  if(driveSections)report.driveSectionsAnchorFrame=state.driveSections.frames;
  if(framePipeline){
   report.framePipelineAnchorFrame=state.framePipeline.currentFrame;
   report.framePipelineEpoch=state.framePipeline.epoch;
   report.framePipelineIdentity=state.framePipeline.identity;
  }
  startMs=now();measuring=true;
  report.inputWallAnchorLeadMs=startMs-lastWall.receivedAtMs;
  check(report.inputWallAnchorLeadMs<=POLL_MS*2,'Pre-input wall anchor was received within the bounded endpoint allowance');
  if(captureCdp)report.cdp.inputStartedHostMonotonicMs=startMs;
  await page.keyboard.down('w');await page.mouse.down();
  const heldInputStartMs=now();report.inputDispatchMs=heldInputStartMs-startMs;
  while(now()-heldInputStartMs<driveMs){
   if(presentationPipeline){healthy();await sleep(Math.max(0,Math.min(100,driveMs-(now()-heldInputStartMs))));continue}
   healthy();const tick=now();await poll();
   await sleep(Math.max(0,Math.min(POLL_MS-(now()-tick),driveMs-(now()-heldInputStartMs))));
  }
  const finalDrain=frameSeq;await poll();await wait(()=>frameSeq>finalDrain,'final continuous-input engine drain',15000);
  measuring=false;report.observedInputMs=now()-startMs;report.observedHeldInputMs=now()-heldInputStartMs;
  if(captureCdp)report.cdp.inputEndedHostMonotonicMs=now();
  await page.mouse.up();await page.keyboard.up('w');
  report.afterDrive={sequence:seq,state};report.coverage=summary(report.windows);report.wallCoverage=wallSummary(report.wallWindows);
  // End the trace before the pipeline serializes its retained frame records.
  if(captureCdp)await stopCapture('continuous-input-finished');
  if(framePipeline){
   const throughFrame=report.afterDrive.state.framePipeline.currentFrame;
   assert.ok(Number.isInteger(report.framePipelineAnchorFrame)&&Number.isInteger(throughFrame),'Actual frame pipeline input boundaries');
   await page.keyboard.press('F9');await poll();
   await wait(s=>s.framePipeline?.enabled===false,'Frame pipeline stopped before serialization',15000);
   await wait(()=>pipelineRecords.some(row=>row.frame?.frame>=throughFrame),'All frame pipeline input records emitted',15000);
   const retained=pipelineRecords.filter(row=>row.frame.frame>report.framePipelineAnchorFrame&&row.frame.frame<=throughFrame);
   assert.equal(retained.length,throughFrame-report.framePipelineAnchorFrame,'Every input engine frame retained, including both boundaries');
   for(let i=0;i<retained.length;i++){
    const row=retained[i];
    assert.equal(row.frame.frame,report.framePipelineAnchorFrame+i+1,'Exact ordered input engine frame coverage');
    assert.equal(row.frame.epoch,report.framePipelineEpoch,'Single input capture epoch');
    assert.deepEqual(row.identity,report.framePipelineIdentity,'Exact input observer/source identity');
   }
   const analysis=require('./analyze-frame-pipeline.cjs').analyze(retained);
   assert.ok(analysis.completeFrames>0,'Complete actual frame pipeline frames');
   assert.equal(analysis.reportedDropped,0,'No dropped pipeline frames');
   assert.deepEqual(analysis.issues,[],'Actual frame pipeline accounting and callback coverage');
   if(fixedStepPipeline)assert.ok(analysis.fixedSteps?.total>0,'Actual fixed-step calls observed with three-boundary instrumentation');
   if(presentationPipeline)assert.ok(analysis.presentation?.frames.length>0,'Actual presentation/envelope boundaries observed and conserved');
   if(beforeStepPipeline)assert.ok(analysis.beforeStep?.frames.length>0,'Actual BeforeStep direct children observed and conserved');
   if(vehiclePipeline)assert.ok(analysis.vehicle?.frames.length>0,'Actual Vehicle direct children observed and conserved');
   report.framePipelineSummary={afterFrame:report.framePipelineAnchorFrame,throughFrame,...analysis};
   fs.writeFileSync(path.join(out,'frame-pipeline-summary.json'),JSON.stringify(report.framePipelineSummary,null,2));
   check(true,'Engine-frame UI/main boundaries and nested self accounting');
  }
  if(driveSections){
   report.driveSectionsSummary=require('./analyze-drive-sections-web.cjs').summarize(driveRecords,{
    afterFrame:report.driveSectionsAnchorFrame,throughFrame:state.driveSections.frames,
    sourceIdentity:driveSourceIdentity(identity,trialSections,afterStep)});
   fs.writeFileSync(path.join(out,'drive-sections-summary.json'),JSON.stringify(report.driveSectionsSummary,null,2));
   check(report.driveSectionsSummary.frames>0&&state.driveSections.dropped===0,'Raw detailed input frames and exact frozen source retained');
   await page.keyboard.press('ScrollLock');await poll();await wait(s=>s.driveSections?.enabled===false,'Detailed timing disabled before returning',15000);
  }
  check(report.observedHeldInputMs>=driveMs,'Requested '+driveMs+' ms of held drive/fire input');
  if(presentationPipeline){
   check(report.wallCoverage.windows>0,'Complete entry-wall window retained without mid-input state requests');
   report.presentationQuietInput=true;
   report.boundary+=' Presentation capture suppresses mid-input full-state requests; automatic dumps are already disabled by the frame-pipeline probe. Endpoint roster/focus evidence does not prove every intervening frame state.';
  }else check(report.coverage.windows>0,'Consecutive nonoverlapping active FrameStats windows retained');
  report.wallCoverageCheck=verifyWallCoverage(report.wallCoverage,report.observedInputMs);
  check(report.wallWindows.every(window=>window.accepted),'No intervening inactive wall window');
  check(report.windows.every(window=>window.reason.startsWith('Initial boundary')||window.accepted),'No intervening inactive gameplay window');
  check(report.windows.every(window=>window.monitor?.enabled===false),'Monitor disabled throughout measurement');
  check(report.windows.every(window=>window.performance?.battleTiming?.enabled===false),'QA battle timing disabled throughout measurement');
  check(report.windows.some(window=>window.pointer?.left&&window.pointer?.fire),'Real held fire reached gameplay');
  check(report.windows.every(window=>window.performance?.focus===true&&window.performance?.minimized===false),'Foreground and non-minimized gameplay throughout measurement');
  report.measurementResult='PASS';
  await page.screenshot({path:path.join(out,'after-drive.png'),timeout:15000});
  if(process.argv.includes('--scoreboard-check')||responsiveBoard){
   check(route==='match','Scoreboard check requires competitive route');
   await page.keyboard.down('Tab');
   try{
    const beforeBoard=seq;await poll();
    await wait(s=>seq>beforeBoard&&s.battle?.boardOn===true,'first TAB press opens actual scoreboard',15000);
    await sleep(300);
    await page.screenshot({path:path.join(out,'scoreboard.png'),timeout:15000});
    report.scoreboard={sequence:seq,state,sourceSha256:identity.identity.scripts['ui/MatchScoreboard.lua'],
     boundary:'Actual TAB toggle input, runtime boardOn and screenshot after measurement. Text, fonts and fit require visual inspection; this is not a pixel parity assertion.'};
    check(true,'Actual scoreboard toggled open and captured outside measurement');
   }finally{await page.keyboard.up('Tab')}
   if(responsiveBoard){
    report.scoreboardResponsive=[];
    for(const viewport of [{width:1920,height:1080},{width:2400,height:1080},{width:960,height:432},{width:800,height:360}]){
     const beforeResize=seq;await page.setViewportSize(viewport);await sleep(350);await poll();
     await wait(s=>seq>beforeResize&&scoreboardLayoutReady(s,viewport),'actual scoreboard resize and completed native layout',15000);
     const board=verifyScoreboardViewport(state);
     const sample={viewport,sequence:seq,state:structuredClone(state),before:structuredClone(board)};
     await page.screenshot({path:path.join(out,'scoreboard-'+viewport.width+'x'+viewport.height+'.png'),timeout:15000});
     const overflowY=board.contentHeight-board.rect[3]>2,overflowX=board.contentWidth-board.rect[2]>2;
     if(overflowY||overflowX){
      await page.mouse.move((board.rect[0]+board.rect[2]/2)/state.width*viewport.width,(board.rect[1]+board.rect[3]/2)/state.height*viewport.height);
      const beforeWheel=seq;await page.mouse.wheel(overflowX?500:0,overflowY?500:0);await sleep(700);await poll();
      await wait(()=>seq>beforeWheel,'actual scrollbar after wheel',15000);
      const after=verifyScoreboardViewport(state);sample.after=structuredClone(after);
      check(!overflowY||after.scrollY>board.scrollY+1,'Actual vertical wheel moves scoreboard '+viewport.width);
      check(!overflowX||after.scrollX>board.scrollX+1,'Actual horizontal wheel moves scoreboard '+viewport.width);
      await page.screenshot({path:path.join(out,'scoreboard-'+viewport.width+'x'+viewport.height+'-scrolled.png'),timeout:15000});
     }
     report.scoreboardResponsive.push(sample);persist();
    }
    await page.setViewportSize(VIEWPORT);await sleep(350);await poll();
    await wait(s=>Math.abs(s.width/s.height-VIEWPORT.width/VIEWPORT.height)<.01,'restore original viewport',15000);
    check(true,'Actual scoreboard responsive layout and native scrolling');
   }
   const beforeClose=seq;await page.keyboard.press('Tab');
   await poll();await wait(s=>seq>beforeClose&&s.battle?.boardOn===false,'second TAB press closes scoreboard',15000);
   check(true,'Second TAB press closes actual scoreboard');
  }
  const old=seq;await page.keyboard.press('Escape');await wait(()=>seq>old,'pause');
  await click('返回车库');if(route==='match')await click('确定');
  await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'return hall',120000);
  await sleep(2200);const returnSeq=seq;await poll();await wait(()=>seq>returnSeq,'returned lifecycle');
  const trial=state.performance?.lifecycle?.trial;
  check(trial===false||(trial?.disposed===true&&!trial.scene&&!trial.world&&!trial.effects&&!trial.view&&!trial.hud),'Retired battle session no longer owns live scene/world/effects/view/HUD');
  check(monitorState(state)?.enabled===false,'Monitor remains disabled after return');
  report.returnState=state;
  await page.screenshot({path:path.join(out,'returned.png'),timeout:15000});
  const finalIdentity=await fetch(base+'/identity.json').then(response=>response.json());
  check(JSON.stringify(finalIdentity)===JSON.stringify(identity),'Same server and packaged identity throughout route');
  healthy();check(report.httpErrors.length===0,'No HTTP errors');check(report.perfRecords.length===0,'No VOX_PERF session or gameplay scopes');
  check(report.probeIssues.every(issue=>issue.transportTruncated&&!issue.duringMeasurement&&issue.recoveredBySequence),'Any incomplete QA state outside measurement recovered through a later complete state');
  report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;throw error}
 finally{
  measuring=false;
  try{if(page&&!page.isClosed()){await page.mouse.up();await page.keyboard.up('w')}}catch(error){report.cleanupInputError=error.message}
  if(captureCdp&&!captureFinished){try{await stopCapture('failure-cleanup')}catch(error){report.cdpCleanupError=error.stack}}
  await browser?.close();report.shutdown='CLOSED';report.finishedAt=new Date().toISOString();
  fs.writeFileSync(path.join(out,'windows.json'),JSON.stringify(report.windows,null,2));persist();
  fs.writeFileSync(path.join(out,'wall-windows.json'),JSON.stringify(report.wallWindows,null,2));
  console.log(JSON.stringify({result:report.result,route,out,coverage:report.coverage,failure:report.failure}));
 }
}
module.exports={runtimeUrl,verifyMonitorIdentity,verifyProfileIdentity,verifyFramePipeline,verifyDriveBindings,driveSourceIdentity,monitorState,activeState,frameWindow,wallWindow,wallSummary,verifyWallCoverage,truncatedState,driveDuration,summary,verifyScoreboardViewport,selfTest};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else main().catch(error=>{console.error(error.message);process.exitCode=1})}

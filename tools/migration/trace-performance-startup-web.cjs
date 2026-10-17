// Separate browser session: sample the real engine boot without changing gameplay.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function main(){
 const base=process.env.VOX_QA_BASE;assert.match(base||'',/^http:\/\/127\.0\.0\.1:\d+$/);
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.perfMonitor);
 const out=path.resolve('docs/migration/evidence/startup-cpu-'+Date.now());fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',identity,out,errors:[],boundary:'CDP sampling and tracing add overhead. Unattributed Lua time is not GPU time; sampled durations are not exact function wall durations. A fresh browser context is not a platform download cold-cache benchmark.'};
 const records=[],runtimeEvents=[];let browser,cdp,traceComplete,profileRunning=false,tracing=false,lineNumber=0;
 try{
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
  const page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',message=>{
   const line=message.text();lineNumber++;fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   if(/\[(LoadingFlow|CommsWarmup)\]|Succeed to compile shader/.test(line))runtimeEvents.push({line:lineNumber,text:line});
   const at=line.indexOf('VOX_PERF ');if(at>=0){try{records.push(JSON.parse(line.slice(at+9)))}catch(error){report.errors.push('Timing parse: '+error.message)}}
   if(/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|ERROR:/.test(line))report.errors.push(line);
  });
  page.on('pageerror',error=>report.errors.push(error.message));page.on('crash',()=>report.errors.push('Renderer crash'));
  cdp=await page.context().newCDPSession(page);await cdp.send('Profiler.enable');
  await cdp.send('Profiler.setSamplingInterval',{interval:1000});
  await cdp.send('Profiler.start');profileRunning=true;
  traceComplete=new Promise(resolve=>cdp.once('Tracing.tracingComplete',resolve));
  await cdp.send('Tracing.start',{categories:'devtools.timeline,v8,disabled-by-default-v8.wasm',transferMode:'ReturnAsStream'});tracing=true;
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  const deadline=Date.now()+240000;
  while(!records.some(r=>r.type==='sample'&&r.context?.mode==='hangar'&&!r.context.loading)){
   assert.equal(report.errors.length,0,report.errors.join('\n'));assert.ok(Date.now()<deadline,'Startup timeout');await pause(250);
  }
  await pause(5000);await page.screenshot({path:path.join(out,'ready.png'),timeout:15000});
  const {profile}=await cdp.send('Profiler.stop');profileRunning=false;
  fs.writeFileSync(path.join(out,'startup.cpuprofile'),JSON.stringify(profile));
  const nodes=new Map(profile.nodes.map(node=>[node.id,{...node,sampledUs:0,samples:0}]));
  for(let i=0;i<(profile.samples||[]).length;i++){const node=nodes.get(profile.samples[i]);if(node){node.sampledUs+=profile.timeDeltas[i]||0;node.samples++}}
  report.cpu={durationMs:(profile.endTime-profile.startTime)/1000,samples:profile.samples?.length||0,top:[...nodes.values()].sort((a,b)=>b.sampledUs-a.sampledUs).slice(0,60).map(node=>({name:node.callFrame.functionName,url:node.callFrame.url,line:node.callFrame.lineNumber+1,samples:node.samples,sampledMs:node.sampledUs/1000}))};
  await cdp.send('Tracing.end');tracing=false;const {stream}=await traceComplete;assert.ok(stream,'Trace stream');
  const tracePath=path.join(out,'startup.trace.json'),fd=fs.openSync(tracePath,'w');
  try{while(true){const chunk=await cdp.send('IO.read',{handle:stream});fs.writeSync(fd,chunk.base64Encoded?Buffer.from(chunk.data,'base64'):chunk.data);if(chunk.eof)break}}finally{fs.closeSync(fd);await cdp.send('IO.close',{handle:stream})}
  const trace=JSON.parse(fs.readFileSync(tracePath,'utf8'));
  report.traceLongEvents=trace.traceEvents.filter(event=>event.ph==='X'&&event.dur>=80000).sort((a,b)=>b.dur-a.dur).slice(0,60).map(event=>({name:event.name,category:event.cat,ts:event.ts,durationMs:event.dur/1000,thread:event.tid,args:event.args}));
  report.slowFrames=records.filter(r=>r.type==='slow_frame').map(r=>({frame:r.frame,atMs:r.atMs,frameMs:r.frameMs,wallMs:r.wallMs,scriptMs:r.scriptMs,context:r.context,top:r.stages?.slice().sort((a,b)=>b.selfMs-a.selfMs).slice(0,8)}));
  report.samples=records.filter(r=>r.type==='sample').map(r=>({atMs:r.atMs,frame:r.frame,context:r.context}));
  const observed=new Set();
  for(const record of records){
   for(const stage of Array.isArray(record.stages)?record.stages:[])if(stage.calls>0)observed.add(stage.name);
   for(const frame of Array.isArray(record.frameSamples)?record.frameSamples:[]){
    const values=Array.isArray(frame.stageTimes)?frame.stageTimes:[];
    for(let i=0;i<values.length;i+=5)if(values[i+3]>0&&record.stageNames?.[values[i]-1])observed.add(record.stageNames[values[i]-1]);
   }
  }
  report.observedStages=[...observed].sort();
  const closed=runtimeEvents.find(event=>event.text.includes('[LoadingFlow] Closed'));
  const compiled=runtimeEvents.filter(event=>event.text.includes('Succeed to compile shader'));
  report.shaderOrdering={closedLine:closed?.line,beforeClose:compiled.filter(event=>closed&&event.line<closed.line).length,
   afterClose:compiled.filter(event=>closed&&event.line>closed.line),events:runtimeEvents};
  assert.ok(closed,'Actual loading cover close observed');
  if(process.argv.includes('--require-grid-warmup'))for(const [name,id]of [['Boundary','AT5hIb4kiyn9f3ZZtINF1oNF'],['Guide','HSzRaWbLWbfUPryKwziiuZOz']]){
   const shaders=compiled.filter(event=>event.text.includes(id));
   assert.ok(shaders.length>0,'Actual '+name+' shader compile observed');
   assert.ok(shaders.every(event=>event.line<closed.line),name+' shaders compile under loading cover');
  }
  if(process.argv.includes('--require-home-scopes'))for(const name of ['app.Install','hangar.Bind','hangarHud.Create','vehicleView.Rebuild','hangarPanels.Render','hangar.Update'])assert.ok(observed.has(name),'Observed actual startup stage '+name);
  for(const [flag,name,id,marker]of [
   ['--require-hangar-fx','Weapon Glow','Ac51sZjFOh9_McPNZh9X7KZH','[LoadingFlow] Hangar FX warm-up'],
   ['--require-comms-warmup','Communications portrait','GdAjyRHA3i_PWlaERvsARWOX','[CommsWarmup] Presented'],
  ])if(process.argv.includes(flag)){
   const shaders=compiled.filter(event=>event.text.includes(id));
   assert.ok(shaders.length>=2,'Actual '+name+' vertex and pixel shader compilation observed');
   assert.ok(shaders.every(event=>event.line<closed.line),name+' compiles under loading cover');
   assert.ok(runtimeEvents.some(event=>event.line<closed.line&&event.text.includes(marker)),name+' presentation gate completes before close');
  }
  await page.evaluate(()=>window.__voxPerfCollector.flush());await pause(300);
  report.collector=await page.evaluate(()=>window.__voxPerfCollector.status());
  assert.equal(report.errors.length,0,report.errors.join('\n'));assert.equal(report.collector.parseErrors,0);assert.equal(report.collector.droppedRecords,0);
  report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;process.exitCode=1}
 finally{
  if(profileRunning)await cdp?.send('Profiler.stop').catch(()=>{});
  if(tracing)await cdp?.send('Tracing.end').catch(()=>{});
  await browser?.close();report.shutdown='CLOSED';fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({result:report.result,out,cpu:report.cpu?.top.slice(0,10),longEvents:report.traceLongEvents?.slice(0,8).map(e=>({name:e.name,ms:e.durationMs})),failure:report.failure}));
 }
}
main().catch(error=>{console.error(error);process.exitCode=1});

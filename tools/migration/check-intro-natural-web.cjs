// Natural public opening: real elapsed audio, mouse lock, W/LMB, ink and gate.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4269),sleep=ms=>new Promise(r=>setTimeout(r,ms));
const source=JSON.parse(fs.readFileSync(path.join(root,'assets/Intro/Intro.json')));
const migrationSource=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const memoryProbe=process.env.VOX_INTRO_MEMORY==='1'?require('./web-memory-probe.cjs'):null;
const abortProbe=process.env.VOX_INTRO_OOM_ONLY==='1'?require('./web-memory-probe.cjs'):null;
function RunOptions(env){
 const bootOnly=env.VOX_INTRO_BOOT_ONLY==='1',returnOnly=env.VOX_INTRO_RETURN_ONLY==='1';
 assert.ok(!(bootOnly&&returnOnly),'VOX_INTRO_BOOT_ONLY and VOX_INTRO_RETURN_ONLY are mutually exclusive');
 return {bootOnly,returnOnly,scope:returnOnly?'public-ad-skip-contract-gate-return':bootOnly?'opening-boot-only':'full-natural-opening',prefix:returnOnly?'intro-return-web':'intro-natural-web'};
}
function CheckReturnRoute(samples,route,check){
 check(route.skipStage==='ad'&&route.skipKey==='Escape','return-only route uses actual public Escape during advertisement');
 check(route.realityObserved===true,'public advertisement skip reaches actual reality stage');
 check(samples.some(s=>s.shot==='comms'),'return-only route observes actual communications');
 check(route.choiceKey==='3'&&route.choiceReply==='v07','actual public third option reaches original v07 reply');
 check(samples.some(s=>s.shot==='contract'),'return-only route reaches actual contract');
 check(!samples.some(s=>s.shot==='sortie-play'||s.shot?.startsWith('m-')),'return-only scope does not execute driving lesson or montage');
}
const {bootOnly,returnOnly,scope,prefix:scopePrefix}=RunOptions(process.env);
const traceNetwork=process.env.VOX_INTRO_NETWORK==='1';
function AudioMeter(){
 const qa=window.__introNaturalQA={audio:[],processors:[],contexts:[],raf:[],longTasks:[],marks:[],clips:{},marker:{shot:'boot'},started:performance.now(),timeOrigin:performance.timeOrigin,timezoneOffset:new Date().getTimezoneOffset()};
 let last=performance.now();function frame(now){qa.raf.push({at:now,dt:now-last,shot:qa.marker.shot});last=now;requestAnimationFrame(frame);}requestAnimationFrame(frame);
 try{new PerformanceObserver(list=>{for(const e of list.getEntries())qa.longTasks.push({at:e.startTime,duration:e.duration,shot:qa.marker.shot});}).observe({entryTypes:['longtask']});}catch{}
 const Context=window.AudioContext||window.webkitAudioContext;if(!Context)return;
 const original=Context.prototype.createScriptProcessor,contexts=new WeakMap();let processorSerial=0,contextSerial=0;
 Context.prototype.createScriptProcessor=function(...args){
  const node=original.apply(this,args),ctx=this,id=++processorSerial;let contextId=contexts.get(ctx);
  if(!contextId){contextId=++contextSerial;contexts.set(ctx,contextId);const record=()=>qa.contexts.push({id:contextId,at:performance.now(),time:ctx.currentTime,state:ctx.state});record();ctx.addEventListener('statechange',record);}
  qa.processors.push({id,contextId,at:performance.now(),bufferSize:node.bufferSize,inputChannels:args[1],outputChannels:args[2]});
  let p=node,descriptor;
  while(p&&!descriptor){descriptor=Object.getOwnPropertyDescriptor(p,'onaudioprocess');p=Object.getPrototypeOf(p);}
  if(!descriptor?.set){qa.hookError='Missing native onaudioprocess setter';return node;}
  let callback;
  Object.defineProperty(node,'onaudioprocess',{configurable:true,get(){return callback;},set(fn){
   callback=fn;descriptor.set.call(node,fn&&function(event){
    const begin=performance.now(),contextBegin=ctx.currentTime;
    fn.call(this,event);const end=performance.now(),contextEnd=ctx.currentTime,buffer=event.outputBuffer,a=buffer.getChannelData(0);let sum=0,peak=0,count=0;
    for(let i=0;i<a.length;i+=16){const v=a[i];sum+=v*v;peak=Math.max(peak,Math.abs(v));count++;}
    const marker=qa.marker;qa.audio.push({at:performance.now(),begin,end,mixMs:end-begin,contextBegin,contextEnd,scheduledLeadMs:(event.playbackTime-contextBegin)*1000,id,contextId,playbackTime:event.playbackTime,duration:buffer.duration,rate:buffer.sampleRate,rms:Math.sqrt(sum/count),peak,shot:marker.shot,line:marker.line,context:ctx.state});
    const key=marker.shot==='idyll'?'idyll':marker.shot==='m-drive'?'montage-drive':marker.shot==='comms'&&['v01','v03'].includes(marker.line)?marker.line:null;
    if(key){const clip=qa.clips[key]||(qa.clips[key]={rate:buffer.sampleRate,frames:0,chunks:[]});if(clip.frames<clip.rate*3){
     const take=Math.min(a.length,Math.ceil(clip.rate*3-clip.frames)),pcm=new Int16Array(take);for(let i=0;i<take;i++)pcm[i]=Math.round(Math.max(-1,Math.min(1,a[i]))*32767);clip.chunks.push(pcm);clip.frames+=take;
    }}
   });
  }});return node;
 };
}
function Wave(clip){const pcm=Buffer.from(clip.base64,'base64'),header=Buffer.alloc(44);header.write('RIFF');header.writeUInt32LE(36+pcm.length,4);header.write('WAVEfmt ',8);header.writeUInt32LE(16,16);header.writeUInt16LE(1,20);header.writeUInt16LE(1,22);header.writeUInt32LE(clip.rate,24);header.writeUInt32LE(clip.rate*2,28);header.writeUInt16LE(2,32);header.writeUInt16LE(16,34);header.write('data',36);header.writeUInt32LE(pcm.length,40);return Buffer.concat([header,pcm]);}
function Percentile(a,p){const sorted=a.slice().sort((x,y)=>x-y);return sorted[Math.min(sorted.length-1,Math.floor(sorted.length*p))]||0;}
async function Run(){
 const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa,'read-only QA probe required');
 const test={width:Number(process.env.VOX_INTRO_WIDTH||1600),height:Number(process.env.VOX_INTRO_HEIGHT||900)};
 const screenshots=process.env.VOX_INTRO_NO_SCREENSHOTS!=='1';
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:test,deviceScaleFactor:1});await page.addInitScript(AudioMeter);
 if(traceNetwork)await page.addInitScript(()=>performance.setResourceTimingBufferSize(16000));
 const tag=process.env.VOX_INTRO_TAG||'',prefix=scopePrefix+'-'+test.width+'x'+test.height+(tag?'-'+tag:''),log=path.join(out,prefix+'.log');fs.writeFileSync(log,'');
 const report={result:'RUNNING',functionality:'RUNNING',continuity:'NOT_MEASURED',identity,baseline:source.commit,sourceDataBaseline:source.commit,migrationBaseline:{branch:migrationSource.branch,commit:migrationSource.commit},viewport:test,workload:process.env.VOX_QA_LOAD||'unspecified',instrumentation:{screenshots,methodTiming:identity.combatProfile?'QA instance wrappers around actual session/physics/actors/weapons/views/effects/UI/audio methods; Time:GetSystemTime milliseconds; wrapper overhead included, not an uninstrumented performance baseline':'Public F8 state probe with MeasureOpening method timing wrappers, browser RAF/audio callback sampling and screenshots; no additional combat method timing wrappers; not an uninstrumented performance baseline'},checks:[],errors:[],httpFailures:[],samples:[],shots:[],startedAt:new Date().toISOString()};
 report.shutdown='PENDING';
 report.scope=scope;
 if(returnOnly)report.returnRoute={acceptance:'Only public ad skip, communications, real signature, gate and hall return. Does not accept full natural opening, driving lesson or montage.'};
 report.instrumentation.networkTiming=traceNetwork;
 if(traceNetwork)report.network=require('./trace-resource-downloads.cjs').attach(page,identity);
 if(memoryProbe)report.memory={diagnostic:true,method:'Read-only heap/VFS checkpoints; filesystem scan may take up to 500 ms and workers up to 750 ms. Not an uninstrumented performance run.',samples:[],oom:[]};
 if(abortProbe)report.oomDiagnostics={method:'Abort-only hook: logs requested bytes, heap capacity and stack only on allocation abort; no filesystem scan or CPU sampler.',oom:[]};
 function persist(){fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));}
 let exitProfiler;
 let state,revision=0,started,driveOrigin,driveDistance=0,fired=false,released=false,recaptured=false,lastStep=-1,keyboardHeld=false,mouseHeld=false,braking=false;
 let aimMouse={x:test.width*.5,y:test.height*.55};
 const shotNames=new Set(),captured=new Set();
 page.on('console',m=>{const line=m.text();fs.appendFileSync(log,line+'\n');let i=line.indexOf('OUTGAME_STATE ');
  if(i>=0){try{state=JSON.parse(line.slice(i+14));revision++;if(state.mode==='opening')report.samples.push({at:Date.now(),...state});}catch(e){if(line.trimEnd().endsWith('}'))report.errors.push(e.message);}}
  const match=line.match(/\[Intro\] ([\w-]+)\s*$/);if(match){shotNames.add(match[1]);report.shots.push({shot:match[1],at:Date.now()});}
  if(memoryProbe&&line.startsWith('WASM_OOM ')){try{report.memory.oom.push({at:Date.now(),...JSON.parse(line.slice(9))});}catch(e){report.memory.oom.push({at:Date.now(),raw:line,parseError:e.message});}}
  if(abortProbe&&line.startsWith('WASM_OOM ')){try{report.oomDiagnostics.oom.push({at:Date.now(),...JSON.parse(line.slice(9))});}catch(e){report.oomDiagnostics.oom.push({at:Date.now(),raw:line,parseError:e.message});}}
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(line)||memoryProbe&&line.startsWith('WASM_OOM ')){report.errors.push(line);report.result='FAIL';report.lastState=state;persist();}
 });page.on('pageerror',e=>{report.errors.push(e.message);report.result='FAIL';report.lastState=state;persist();});page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
 const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
 async function key(name){await page.keyboard.down(name);await sleep(90);await page.keyboard.up(name);}
 async function wait(fn,label,timeout=240000){const at=Date.now();let next=at+700;while(!state||!fn(state)){
  if(report.errors.length)throw Error(report.errors.join('\n'));if(state?.failed)throw Error(state.error);if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
  if(Date.now()>next){next=Date.now()+700;await key('F8');}await sleep(80);
 }return state;}
 async function dump(){const old=revision;await key('F8');await wait(()=>revision>old,'fresh state',15000);return state;}
 async function mark(){if(state)await page.evaluate(m=>{const q=window.__introNaturalQA;q.marker=m;q.marks.push({at:performance.now(),...m});},{mode:state.mode,tab:state.tab,shot:state.mode==='opening'?state.shot:'hall-return',line:state.line,time:state.time,age:state.age});}
 async function point(r,fx=.5,fy=.5){const c=await page.locator('canvas').boundingBox();return {x:c.x+(r.x+r.w*fx)/state.width*c.width,y:c.y+(r.y+r.h*fy)/state.height*c.height};}
 async function click(r){const p=await point(r);await page.mouse.click(p.x,p.y);}
 async function shot(id){if(!screenshots||captured.has(id))return;captured.add(id);await page.screenshot({path:path.join(out,prefix+'-'+id+'.png'),timeout:15000});}
 async function memoryPoint(label,install=false){
  if(!memoryProbe)return;
  const started=Date.now();let timer;
  try{
   const data=await Promise.race([install?memoryProbe.install(page):memoryProbe.read(page),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Memory checkpoint timed out')),2000);})]);
   report.memory.samples.push({label,at:started,elapsedMs:Date.now()-started,mode:state?.mode,shot:state?.shot,performance:state?.performance,tutorial:state?.tutorial,...data});
  }catch(e){report.memory.samples.push({label,at:started,elapsedMs:Date.now()-started,unavailable:e.message});}
  finally{clearTimeout(timer);persist();}
 }
 persist();
 try{
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active&&!s.loading?.busy,'actionable actual hall');await dump();
  if(abortProbe)await abortProbe.installAbort(page);
  await memoryPoint('hall-ready',true);
  const entry=state.widgets.find(w=>w.text==='开场动画'&&!w.disabled);assert.ok(entry,'public original opening entry');const [x,y,w,h]=entry.rect;await click({x,y,w,h});
  await wait(s=>s.mode==='opening'&&s.ready,'opening resources, audio decode and real scene',300000);await shot('ready');
  if(traceNetwork)await require('./trace-resource-downloads.cjs').snapshot(page,report.network);
  await memoryPoint('opening-ready');
  check(state.openingLoad?.leaveCapture?.ready&&state.openingLoad.leaveCapture.frames===3&&state.openingLoad.leaveCapture.texture&&!state.openingLoad.leaveCapture.node&&!state.openingLoad.leaveCapture.viewport,'original paid-leave scene is frozen before playback with no live capture viewport');
  if(bootOnly){check(!report.errors.length,'opening boot completes without game errors');report.functionality='PASS';return;}
  started=Date.now();await page.mouse.click(test.width*.5,test.height*.65);await wait(s=>s.stage==='ad','public opening begins');
  if(returnOnly){
   await dump();await mark();report.returnRoute.skipStage=state.stage;report.returnRoute.skipKey='Escape';await key('Escape');
   await wait(s=>s.mode==='opening'&&s.stage==='reality','public advertisement skip enters reality');report.returnRoute.realityObserved=true;
  }
  const deadline=Date.now()+600000;
  while(state.mode==='opening'&&state.shot!=='contract'){
   if(Date.now()>deadline)throw Error('Natural opening did not reach contract');await dump();await mark();
   const current=state.shot;shotNames.add(current);
   if(['idyll','leave','no','familiar','galaxy','payslip','m-build','m-drive','m-missile','m-salvage','master','tvcut','comms'].includes(current))await shot(current);
   if(current==='leave'&&state.age>=.5)await shot('leave-settled');
   if(current==='familiar'&&state.age>=2)await shot('familiar-complete');
   if(current==='payslip'&&state.age>=1.8)await shot('payslip-stamped');
   if(current==='motto'&&state.age>=1.4)await shot('motto-text');
   if(current==='disclaimer'&&state.age>=.6)await shot('disclaimer-text');
   if(current==='comms'&&state.line==='v03'&&state.lineAge>=1)await shot('comms-text');
   if(current==='sortie-brief'&&state.age>2.3){await page.mouse.click(test.width*.5,test.height*.55);await sleep(250);}
   if(current==='sortie-play'){
    const s=state.sortie||{},status=state.sortieStatus;
    if(state.sortieCombat?.hit>0)await shot('sortie-hit-feedback');
    if(Object.values(state.sortieCombat?.pops||{}).some(p=>p.t<1&&p.amount>0))await shot('sortie-damage-feedback');
    if(status&&!status.controlling&&s.step<4){await page.mouse.click(test.width*.5,test.height*.55);await sleep(250);}
    if(s.step!==lastStep){lastStep=s.step;await shot('sortie-'+s.step);}
    if(status?.pos){driveOrigin=driveOrigin||status.pos;driveDistance=Math.max(driveDistance,Math.hypot(status.pos[0]-driveOrigin[0],status.pos[2]-driveOrigin[2]));}
    if(s.step===1&&s.elapsed>1&&!released){
     if(keyboardHeld){await page.keyboard.up('w');keyboardHeld=false;}await key('Escape');await wait(q=>!q.sortieStatus?.controlling,'actual ESC release');const held=state.sortie.elapsed;await sleep(850);await dump();
     check(Math.abs(state.sortie.elapsed-held)<.2,'unlocked live lesson clock pauses');released=true;await shot('released');await page.mouse.click(test.width*.5,test.height*.55);await wait(q=>q.sortieStatus?.controlling,'actual re-capture');recaptured=true;
    }
    if(s.step===1&&!keyboardHeld){await page.keyboard.down('w');keyboardHeld=true;}
    if(s.step!==1&&keyboardHeld){await page.keyboard.up('w');keyboardHeld=false;}
    if(s.step===2&&!braking){await page.keyboard.down('Space');braking=true;}
    if(s.step!==2&&braking){await page.keyboard.up('Space');braking=false;}
    if(s.step===2&&status?.targetScreen){
     const [tx,ty]=status.targetScreen;const dx=Math.max(-120,Math.min(120,(tx/state.width-.5)*test.width*.5));const dy=Math.max(-90,Math.min(90,(ty/state.height-.5)*test.height*.5-5));
     aimMouse={x:aimMouse.x+dx,y:aimMouse.y+dy};await page.mouse.move(aimMouse.x,aimMouse.y);
    }
    if(s.step===2&&!mouseHeld){await page.mouse.down();mouseHeld=true;fired=true;}
    if(s.step!==2&&mouseHeld){await page.mouse.up();mouseHeld=false;}
   }
   if(current==='decide'&&state.age>1.3){await page.keyboard.down('Space');await sleep(1450);await page.keyboard.up('Space');}
   if(state.page?.choosing){await shot('choice-options');await key('3');await sleep(90);await dump();
    if(returnOnly){report.returnRoute.choiceKey='3';await wait(s=>s.line==='v07'&&!s.page?.choosing,'public third dialogue option response');report.returnRoute.choiceReply=state.line;}
    await shot('choice-exit');}
   await sleep(220);
  }
  if(keyboardHeld){await page.keyboard.up('w');keyboardHeld=false;}if(mouseHeld){await page.mouse.up();mouseHeld=false;}
  if(!returnOnly){
  check(Date.now()-started>110000,'opening played in natural wall-clock time without advertisement/dialogue skip');
  check(driveDistance>1,'actual held W moves live rigid-body player');check(fired,'actual held LMB fires during original shooting lesson');check(released&&recaptured,'actual pointer release and re-capture both occurred');
  for(const id of ['logo','idyll','prosper','order','leave','no','sortie-brief','sortie-countdown','sortie-play','familiar','galaxy','payslip','decide','decided','m-build','m-drive','m-missile','m-salvage','recruit','peacekeeper','master','mechanic','motto','disclaimer','tvcut','comms','contract'])check(shotNames.has(id),'natural original shot '+id);
  const moved=report.samples.filter(s=>s.sortie?.step===2),finished=report.samples.find(s=>s.sortie?.step===5);
  check(moved.length>0&&finished,'real lesson reached shooting and destruction');report.enemyHit=moved.some(s=>s.sortieStatus?.enemyHit)||report.samples.some(s=>s.sortie?.mine);report.driveDistance=driveDistance;
  check(report.samples.some(s=>s.sortie?.mine===true),'real player damages easy enemy before scripted timeout destruction');
  check(moved.some(s=>s.sortieCombat?.feedbackBound&&s.sortieCombat?.firing),'shared damage feedback is bound while actual LMB fires');
  check(moved.some(s=>s.audioContext?.target===.3&&Math.abs(s.audioContext.gain-.3)<.02),'opening live battle uses original low vehicle/weapons/damage mix');
  check(report.samples.some(s=>s.shot==='sortie-play'&&s.audioContext?.buses?.feedback?.gain===1),'hit confirmation bus retains full contextual gain');
  check(report.samples.some(s=>s.shot==='sortie-play'&&s.sortieCombat?.hit>0),'actual damage reaches rendered reticle hit confirmation');
  check(report.samples.some(s=>s.shot==='sortie-play'&&Object.values(s.sortieCombat?.pops||{}).some(p=>p.t<1&&p.amount>0)),'actual enemy damage creates visible pooled damage numbers');
  check(report.samples.some(s=>s.shot==='sortie-play'&&Object.entries(s.sortieCombat?.feedbackAudio?.counts||{}).some(([id,n])=>['hit_tick','break_tick','kill_confirm'].includes(id)&&n>0)),'actual hits play shared confirmation audio');
  check(report.samples.some(s=>s.shot==='m-missile'&&s.sortieStatus?.missileLaunched),'original prepared montage hero launches real missiles during natural playback');
  for(const id of ['m-drive','m-missile'])check(report.samples.some(s=>s.shot===id&&s.openingLoad?.presentation?.driversParked),'source montage parks live invader drivers: '+id);
  const payslips=report.samples.filter(s=>s.shot==='payslip'&&s.age>.1&&!s.openingLoad?.presentation?.impactAt);
  check(payslips.length>0,'natural payslip exposes its original moving scene camera');
  check(payslips.every(s=>{const p=s.openingLoad.presentation;return p.camera&&p.payslipAt&&Math.abs(p.camera[0]-(p.payslipAt[0]-s.age*2))<.25;}),'native payslip camera retains original two meters per second lateral motion');
  check(report.samples.some(s=>s.shot==='payslip'&&s.openingLoad?.presentation?.impactAt>0),'actual payslip hit triggers its restored camera and UI impact');
  }else CheckReturnRoute(report.samples,report.returnRoute,check);
  await dump();await mark();await shot('contract');await memoryPoint('contract');
  await wait(s=>s.shot==='contract'&&s.age>=1.3,'original terminal and signing pad finish their entrances');
  const storyCameraAt=report.samples.find(s=>s.shot==='comms')?.openingLoad?.presentation?.storyCameraAt;
  check(Number.isFinite(storyCameraAt)&&state.openingLoad?.presentation?.storyCameraAt===storyCameraAt,'comms camera clock continues through contract instead of restarting');
  await shot('contract-settled');
  if(process.env.VOX_INTRO_EXIT_PROFILE==='1'){
   exitProfiler=await page.context().newCDPSession(page);await exitProfiler.send('Profiler.enable');await exitProfiler.send('Profiler.setSamplingInterval',{interval:1000});
   const before=await page.evaluate(()=>performance.now());await exitProfiler.send('Profiler.start');const after=await page.evaluate(()=>performance.now());
   report.exitCpuProfile={diagnostic:true,samplingIntervalUs:1000,startPerformanceBoundsMs:[before,after],note:'CPU sampling adds overhead; profile start aligns within the recorded browser performance bounds, not an exact wall-clock timestamp.'};
  }
  if(process.env.VOX_INTRO_CONTRACT_RESIZE==='1'){
   for(const size of [{name:'tablet-4-3',width:1024,height:768},{name:'tablet-16-10',width:1280,height:800},{name:'phone-20-9',width:840,height:378}]){
    await page.setViewportSize({width:size.width,height:size.height});await sleep(350);await dump();
    check(state.shot==='contract','Contract survives actual resize '+size.name);
    for(const [name,r]of Object.entries({field:state.page.field,signature:state.page.signature,terms:state.page.terms}))
     check(r.w>0&&r.h>0&&r.x>=0&&r.y>=0&&r.x+r.w<=state.width+1&&r.y+r.h<=state.height+1,name+' fits '+size.name);
    check(state.page.field.x>=state.page.terms.x+state.page.terms.w,'Foreground pad does not cover terms '+size.name);
    await shot('contract-'+size.name);
   }
   await page.setViewportSize({width:test.width,height:test.height});await sleep(350);await dump();
   check(state.shot==='contract','Contract restored after landscape resize');
  }
  await click(state.page.field);await page.keyboard.press('Control+A');await page.keyboard.insertText('自然验收');
  const r=state.page.signature,a=await point(r,.15,.45),b=await point(r,.6,.7),c=await point(r,.82,.25);await page.mouse.move(a.x,a.y);await page.mouse.down();await page.mouse.move(b.x,b.y,{steps:15});await page.mouse.move(c.x,c.y,{steps:15});await page.mouse.up();await dump();
  check(state.page.ink>=30,'actual signature stroke accepted');const submit=state.page.buttons.find(b=>b.id==='submit');assert.ok(submit);await click(submit);
  await wait(s=>s.signed,'original signed profile');
  await wait(s=>s.shot==='stamp'&&s.age>=.9,'contract remains visible under the settled stamp');await shot('contract-stamp');
  await wait(s=>s.shot==='gate','original gate');await mark();await shot('gate');
  check(state.openingRetirement?.craterDetached===true,'unseen crater battle detached after the final crater shot');
  check(state.openingRetirement.pending===false&&state.openingRetirement.jobs===0,'owned crater scene and assets finish retirement before the gate handoff');
  await memoryPoint('gate');
  await wait(s=>s.shot==='gate'&&s.age>=4,'original split gate and pressure release');await shot('gate-open');
  if(process.env.VOX_INTRO_CONTRACT_RESIZE==='1'){
   await page.setViewportSize({width:840,height:378});await sleep(200);await dump();await shot('gate-open-phone-20-9');
   await page.setViewportSize({width:test.width,height:test.height});await sleep(200);await dump();
  }
  const exitDeadline=Date.now()+15000;
  while(state.mode==='opening'&&!state.finishing){if(Date.now()>exitDeadline)throw Error('Opening gate did not enter its exit fade');await dump();await mark();await sleep(80);}
  check(state.mode==='opening'&&state.finishing&&state.fadeOutDuration===.7,'actual opening retains its overlay for the original 700 ms exit fade');
  await shot('exit-fade');
  await wait(s=>s.mode!=='opening'&&s.tab==='hangar'&&!s.loadingFlow?.active,'actual hall and tutorial restoration');await mark();await shot('restored');
  await memoryPoint('hall-return');
  await sleep(2000);await dump();check(state.mode!=='opening'&&state.tab==='hangar'&&!state.loadingFlow?.active,'restored hall remains responsive during tutorial resource handoff');
  check(state.audioSettings?.introAudioTail?.active===false,'detached opening audio tail releases after its original 1400 ms wall deadline');
  await memoryPoint('tutorial-ready');
  check(await page.evaluate(()=>document.pointerLockElement===null),returnOnly?'pointer ownership released after public return route':'pointer ownership released after full opening');check(!report.errors.length,returnOnly?'zero game errors during public return route':'zero game errors during full natural opening');report.functionality='PASS';
 }catch(e){report.failure=e.stack;report.lastState=state;report.functionality='FAIL';report.result='FAIL';persist();await memoryPoint('failure');if(screenshots)await page.screenshot({path:path.join(out,prefix+'-failure.png'),timeout:15000}).catch(()=>{});}
 finally{
  persist();
  if(exitProfiler){
   try{const {profile}=await exitProfiler.send('Profiler.stop');const file=prefix+'-exit.cpuprofile';fs.writeFileSync(path.join(out,file),JSON.stringify(profile));report.exitCpuProfile.file=file;await exitProfiler.detach();}
   catch(e){report.exitCpuProfile.failure=e.stack;}persist();
  }
  await page.keyboard.up('w').catch(()=>{});await page.keyboard.up('Space').catch(()=>{});await page.mouse.up().catch(()=>{});
  const metrics=await page.evaluate(()=>{
   const q=window.__introNaturalQA,clips={};if(!q)return null;
   for(const [key,clip]of Object.entries(q.clips)){const bytes=new Uint8Array(clip.frames*2);let offset=0;for(const a of clip.chunks){bytes.set(new Uint8Array(a.buffer),offset);offset+=a.byteLength;}let binary='';for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));clips[key]={rate:clip.rate,frames:clip.frames,base64:btoa(binary)};}
   return {audio:q.audio,processors:q.processors,contexts:q.contexts,raf:q.raf,longTasks:q.longTasks,marks:q.marks,clips,hookError:q.hookError,timeOrigin:q.timeOrigin,timezoneOffset:q.timezoneOffset};
  }).catch(e=>{report.metricsFailure=e.stack;persist();return null;});
  if(metrics){
   for(const [key,clip]of Object.entries(metrics.clips))fs.writeFileSync(path.join(out,prefix+'-'+key+'.wav'),Wave(clip));delete metrics.clips;
   const during=metrics.audio.filter(s=>!['boot','ready'].includes(s.shot)),gaps=[];for(let i=1;i<during.length;i++){const dt=during[i].at-during[i-1].at;if(dt>Math.max(250,during[i].duration*3000))gaps.push({at:during[i].at,dt,shot:during[i].shot,line:during[i].line});}
   const raf=metrics.raf.filter(s=>!['boot','ready'].includes(s.shot));report.audioContinuity={callbacks:during.length,nonzero:during.filter(s=>s.peak>.001).length,maxCallbackGap:Math.max(0,...during.slice(1).map((s,i)=>s.at-during[i].at)),starvationCandidates:gaps,rafP95:Percentile(raf.map(s=>s.dt),.95),rafP99:Percentile(raf.map(s=>s.dt),.99),maxRaf:Math.max(0,...raf.map(s=>s.dt)),rafFreezes:raf.filter(s=>s.dt>250),longTasks:metrics.longTasks};
   report.audioContinuity.processorDiagnostics=(metrics.processors||[]).map(processor=>{
    const samples=during.filter(s=>s.id===processor.id),intervals=samples.slice(1).map((s,i)=>({at:s.begin,deliveryGapMs:s.begin-samples[i].end,playbackDeltaMs:(s.playbackTime-samples[i].playbackTime)*1000,peakBefore:samples[i].peak,peakAfter:s.peak,shot:s.shot}));
    return {...processor,callbacks:samples.length,nonzero:samples.filter(s=>s.peak>.001).length,maxMixMs:Math.max(0,...samples.map(s=>s.mixMs)),maxDeliveryGapMs:Math.max(0,...intervals.map(s=>s.deliveryGapMs)),delayed:intervals.filter(s=>s.deliveryGapMs>250)};
   });
   report.continuity=!metrics.hookError&&during.length>100&&report.audioContinuity.nonzero>100&&gaps.length===0&&report.audioContinuity.rafFreezes.length===0?'PASS':'FAIL';
   fs.writeFileSync(path.join(out,prefix+'-audio-timeline.json'),JSON.stringify(metrics));
  }
  if(bootOnly)report.continuity='NOT_MEASURED';
  report.functionalityBeforeShutdown=report.functionality;const priorErrors=report.errors.length;
  persist();
  try{
   await page.close();report.pageClosed=true;persist();
   await browser.close();report.shutdown='CLOSED';
  }catch(e){report.shutdownFailure=e.stack;report.functionality='FAIL';report.result='FAIL';persist();throw e;}
  report.shutdownErrors=report.errors.slice(priorErrors);
  if(report.errors.length)report.functionality='FAIL';
  report.result=report.functionality==='PASS'&&(bootOnly||report.continuity==='PASS')?'PASS':'FAIL';report.finishedAt=new Date().toISOString();persist();
 }
 console.log(JSON.stringify({result:report.result,functionality:report.functionality,continuity:report.continuity,checks:report.checks.length,errors:report.errors.length,audio:report.audioContinuity&&{callbacks:report.audioContinuity.callbacks,nonzero:report.audioContinuity.nonzero,maxCallbackGap:report.audioContinuity.maxCallbackGap,starvationCandidates:report.audioContinuity.starvationCandidates.length,rafP95:report.audioContinuity.rafP95,rafP99:report.audioContinuity.rafP99,maxRaf:report.audioContinuity.maxRaf,rafFreezes:report.audioContinuity.rafFreezes.length}}));if(report.result!=='PASS')throw Error(report.failure||'Natural opening audio/frame continuity failed; retain measured timeline');
}
module.exports={RunOptions,CheckReturnRoute};
if(require.main===module)Run().catch(e=>{console.error(e);process.exitCode=1;});

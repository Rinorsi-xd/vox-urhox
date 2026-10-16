// One browser, public gameplay inputs, inclusive Lua CPU timings and wall rAF.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {finishMvp,assertNewRoster}=require('./combat-result-flow.cjs');
const {readWasmHeapCapacity}=require('./wasm-heap-capacity.cjs');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4313);
const width=Number(process.env.VOX_QA_WIDTH||1920),height=Number(process.env.VOX_QA_HEIGHT||1080);
const touch=process.env.VOX_QA_TOUCH==='1',hudOnly=process.env.VOX_QA_HUD_ONLY==='1';
const dpr=Number(process.env.VOX_QA_DPR||(touch?3:1));
assert(Number.isFinite(dpr)&&dpr>=1&&dpr<=4,'DPR must be 1..4');
const repeatCount=Number(process.env.VOX_QA_MATCH_REPEATS||1);
assert(Number.isInteger(repeatCount)&&repeatCount>=1&&repeatCount<=5,'Match repeats must be 1..5');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function main(){
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa);
 const out=path.join(root,'docs/migration/evidence/combat-performance-'+new Date().toISOString().replace(/[:.]/g,'-'));fs.mkdirSync(out,{recursive:true});
 const report={identity,stages:[],errors:[],profiles:[],startedAt:new Date().toISOString(),boundary:identity.combatProfile?'Single automated desktop Chrome. Inclusive CPU wrappers subtract coroutine suspension and add overhead; wall rAF is uncapped. No mobile or sustained thermal acceptance.':'Single automated desktop Chrome with public input/state probe only; no fine-grained Lua CPU wrappers. Wall rAF is uncapped. No mobile or sustained thermal acceptance.'};
 const manifest=JSON.parse(fs.readFileSync(identity.manifest_path));
 report.aimShaders=['Shaders/BLGL/AimLine.shader','Shaders/BLGL/Combat/Glow.shader'].map(name=>{
  const resource=manifest.files.find(file=>file.fs_path===name);assert(resource,'Packaged '+name);
  return {name,key:resource.uuid.replaceAll('-','_')+'_'+resource.hash+'_',loads:[]};
 });
 report.memory={samples:[],checkpoints:[],instrumentationErrors:[],boundary:'Read-only exposed Emscripten typed-array buffer capacity; not WASM allocated/free bytes. JS performance.memory is separate and may be approximate. No native allocator or private engine API is called.'};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:dpr,...(touch?{isMobile:true,hasTouch:true}:{})});let state,revision=0,phase='boot';
 let lastMeasurements={frames:[],gl:{},slowGL:[]},measurementCheckpoint=null,fatalClose=null;
 function persist(){report.final=state;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));}
 function fatal(reason){
  if(report.fatal)return;
  report.fatal={at:new Date().toISOString(),phase,reason};report.result='FAIL';report.failure=reason;
  report.frames=lastMeasurements.frames;report.gl=lastMeasurements.gl;report.slowGL=lastMeasurements.slowGL;
  report.measurements={truncated:true,checkpoint:measurementCheckpoint,boundary:'Fatal runtime stopped collection. Only the last completed checkpoint is retained; no samples after that checkpoint are implied.'};persist();
  // Close only this tool's browser so blocked keyboard/evaluate calls reject.
  report.closing=true;fatalClose=browser.close().catch(error=>{report.closeError=String(error)});
 }
 report.viewport={width,height,touch,dpr};
 page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,'console.log'),line+'\n');
  const i=line.indexOf('OUTGAME_STATE ');if(i>=0){try{state=JSON.parse(line.slice(i+14));revision++;}catch{}}
  if(line.includes('Shader::BeginLoad:'))for(const shader of report.aimShaders){if(line.includes(shader.key))shader.loads.push({at:Date.now(),phase,line});}
  const p=line.indexOf('COMBAT_PROFILE ');if(p>=0){try{report.profiles.push({at:Date.now(),phase,...JSON.parse(line.slice(p+15))});}catch{}}
  const heapAt=line.indexOf('WASM_HEAP_SAMPLE ');if(heapAt>=0){try{report.memory.samples.push({receivedAt:Date.now(),...JSON.parse(line.slice(heapAt+17))});}catch(error){report.memory.instrumentationErrors.push({message:error.message,length:line.length});}}
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  if(/Aborted\(|\bOOM\b|out of memory/i.test(line))fatal(line);
 });page.on('pageerror',e=>report.errors.push(String(e)));
 page.on('crash',()=>{report.crashedAt=new Date().toISOString();fatal('Browser page crashed')});
 browser.on('disconnected',()=>{if(!report.closing)report.disconnectedAt=new Date().toISOString()});
 await page.addInitScript({content:'globalThis.__voxReadWasmHeapCapacity='+readWasmHeapCapacity.toString()+';'});
 await page.addInitScript(({measureGL})=>{
  window.__combatFrames={phase:'boot',frames:[],gl:{},slowGL:[]};let prev=performance.now();
  let lastHeap=-Infinity;
  function tick(now){
   window.__combatFrames.frames.push({at:now,ms:now-prev,phase:window.__combatFrames.phase});prev=now;
   if(now-lastHeap>=1000&&typeof globalThis.__voxReadWasmHeapCapacity==='function'){
    lastHeap=now;
    console.log('WASM_HEAP_SAMPLE '+JSON.stringify({...globalThis.__voxReadWasmHeapCapacity(),phase:window.__combatFrames.phase}));
   }
   requestAnimationFrame(tick);
  }requestAnimationFrame(tick);
  if(!measureGL)return;
  const seen=new Set();
  for(const proto of [window.WebGLRenderingContext?.prototype,window.WebGL2RenderingContext?.prototype]){
   if(!proto)continue;
   for(const name of ['compileShader','linkProgram','getShaderParameter','getProgramParameter','texImage2D','texImage3D','compressedTexImage2D','compressedTexImage3D','bufferData','finish']){
    const original=proto[name];if(!original||seen.has(original))continue;seen.add(original);
    proto[name]=function(...args){const at=performance.now();try{return original.apply(this,args)}finally{
     const ms=performance.now()-at,id=window.__combatFrames.phase+':'+name;
     const stat=window.__combatFrames.gl[id]??={calls:0,totalMs:0,maxMs:0};stat.calls++;stat.totalMs+=ms;stat.maxMs=Math.max(stat.maxMs,ms);
     if(ms>=20)window.__combatFrames.slowGL.push({at,ms,phase:window.__combatFrames.phase,name});
    }};
   }
  }
 },{measureGL:process.env.VOX_QA_GL==='1'});
 const cdp=await page.context().newCDPSession(page);await cdp.send('Profiler.enable');await cdp.send('Profiler.setSamplingInterval',{interval:2000});
 async function key(k){await page.keyboard.press(k,{delay:60})}
 async function wait(fn,label,ms=300000){const at=Date.now();let last=0;while(!state||!fn(state)){
  if(report.errors.length)throw Error(report.errors.join('\n'));
  if(state?.loadingFlow?.failed)throw Error('Scene loading failed: '+state.loadingFlow.error);
  if(Date.now()-at>ms)throw Error('Timeout '+label);
  if(Date.now()-last>1000){last=Date.now();await key('F8')}await sleep(100);
 }return state}
 async function dump(){const n=revision;await key('F8');return wait(()=>revision>n,'fresh probe',15000)}
 async function tap(x,y){
  if(touch)await page.touchscreen.tap(x,y);
  else {await page.mouse.move(x,y);await sleep(180);await page.mouse.click(x,y,{delay:180})}
 }
 async function unlock(){await key('Escape');await wait(s=>!s.pointer?.captured,'release');await page.waitForFunction(()=>!document.pointerLockElement);await sleep(250)}
 async function click(text){await dump();const w=state.widgets.find(w=>w.text===text&&!w.disabled);assert(w,'Control '+text);const r=w.rect;await tap((r[0]+r[2]/2)/state.width*width,(r[1]+r[3]/2)/state.height*height);await sleep(200)}
 async function mark(name){phase=name;await page.evaluate(name=>{if(window.__combatFrames)window.__combatFrames.phase=name},name);console.log(name)}
 async function begin(name){await mark(name);await cdp.send('Profiler.start')}
 async function checkpoint(name){
  lastMeasurements=await page.evaluate(()=>window.__combatFrames);measurementCheckpoint={name,at:new Date().toISOString(),phase,samples:lastMeasurements.frames.length,lastSample:lastMeasurements.frames.at(-1)||null};
  report.memory.checkpoints.push({name,phase,...await page.evaluate(readWasmHeapCapacity)});
  report.frames=lastMeasurements.frames;report.gl=lastMeasurements.gl;report.slowGL=lastMeasurements.slowGL;
  report.measurements={truncated:true,checkpoint:measurementCheckpoint,boundary:'Intermediate checkpoint only; run has not completed.'};persist();
 }
 async function end(name){const p=await cdp.send('Profiler.stop');fs.writeFileSync(path.join(out,name+'.cpuprofile'),JSON.stringify(p.profile));await dump();report.stages.push({name,at:Date.now(),state:structuredClone(state)});await checkpoint(name);}
 async function live(name){await begin(name);await tap(width/2,height/2);await sleep(1500);await page.keyboard.down('w');await sleep(2500);await page.keyboard.up('w');await page.mouse.down();await sleep(3500);await page.mouse.up();await sleep(3500);await end(name);await page.screenshot({path:path.join(out,name+'.png')});}
 try{
  await begin('boot');await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'hall');await end('boot');
  if(process.env.VOX_QA_UI_SOUND==='1'){
   await wait(s=>s.audioSettings?.uiSound?.ready>=2,'approved UI sounds prepared');
   const soundCount=()=>state.audioSettings.uiSound.counts.press||0;
   const start=soundCount();const widget=state.widgets.find(w=>w.text==='出战');assert(widget,'public battle button');
   const r=widget.rect,x=(r[0]+r[2]/2)/state.width*width,y=(r[1]+r[3]/2)/state.height*height;
   await page.mouse.move(x,y);await sleep(180);await dump();assert.equal(soundCount(),start,'hover stays silent');
   report.uiSoundInputs=[];
   for(const button of ['right','middle']){
    await page.mouse.click(x,y,{button,delay:80});await sleep(180);await dump();
    report.uiSoundInputs.push({button,tab:state.tab,count:soundCount()});
    assert.equal(soundCount(),start,button+' click stays silent');
    assert.equal(state.tab,'hangar',button+' click must not navigate');
   }
   await click('出战');await dump();assert.equal(soundCount(),start+1,'normal primary pointerdown plays original press once');
   report.uiSound={pass:true,before:start,after:soundCount(),state:structuredClone(state.audioSettings.uiSound),
    boundary:'Actual public hover/right/middle/primary pointer input and production playback counters. Does not establish audible quality or tutorial confirm playback.'};
  }
  report.lifecycleChecks=[];let previousCaptureSequence=0;
  for(let round=0;round<repeatCount;round++){
  const prefix=round?'repeat'+round+'-':'';
  if((await dump()).tab!=='battle')await click('出战');await wait(s=>s.tab==='battle','mode');await click('歼灭战');await begin(prefix+'match-load');await click('开始匹配');await wait(s=>s.mode==='trial'&&s.battle&&!s.loadingFlow?.active,'match');await end(prefix+'match-load');
  await key('Space');await wait(s=>!s.intro?.active,'intro skip');
  if(process.env.VOX_QA_MATCH_FEEDBACK==='1'&&round===0){
   await wait(s=>s.matchHud?.feedback?.prepCount===3,'natural prep countdown 3');
   report.matchFeedback={countdown:{sourceFrame:state.matchHud.feedback.frame,state:structuredClone(state),
    source:'shared/ui/matchHud.js preparation countdown, frozen source identity recorded by package',
    boundary:'Actual ordinary prep clock and read-only HUD sample; no QA state injection. Screenshot is captured after this probe and may be a later animation frame.'}};
   await page.screenshot({path:path.join(out,'match-countdown.png')});
  }
  if(hudOnly){
   await tap(width/2,height/2);await wait(s=>s.battle.state==='live'&&s.matchHud?.minimap?.base&&s.matchHud.minimap.frames>1,'live HUD with real map base');
   await sleep(1200);await dump();
   const mm=state.matchHud.minimap,r=mm.rect;
   report.hudChecks=[{name:'offscreen minimap render callback ran',pass:mm.frames>1},{name:'scene map texture attached (pixel content not asserted)',pass:mm.base===true},
    {name:'minimap remains alive',pass:mm.disposed===false},
    {name:'map bounds fit viewport',pass:r.length===4&&r.every(Number.isFinite)&&r[2]>0&&r[3]>0&&r[0]>=0&&r[1]>=0&&r[0]+r[2]<=state.width&&r[1]+r[3]<=state.height},
    {name:'actual touch policy matches viewport case',pass:state.matchHud.touch===touch}];
   assert(report.hudChecks.every(c=>c.pass),'HUD runtime checks');
   report.stages.push({name:'match-hud',at:Date.now(),state:structuredClone(state)});
   await page.screenshot({path:path.join(out,'match-hud.png')});
   await page.screenshot({path:path.join(out,'match-minimap.png'),clip:{x:r[0]/state.width*width,y:r[1]/state.height*height,width:r[2]/state.width*width,height:r[3]/state.height*height}});
   report.result='HUD_STATE_PASS';report.visualReview={status:'PENDING',required:[
    'Full screenshot: team score/timer and compass do not overlap; labels and fonts remain readable',
    'Minimap crop: actual varied terrain/roads/landmarks are visible, not a flat fill or only frame/gradient',
    'Minimap crop: white player arrow plus visible team arrows are intact and map is not inverted',
    'Touch case: landscape HUD and touch controls stay onscreen without overlapping critical readouts'
   ],boundary:'Probe base/frame counters prove attachment and callbacks only; screenshot inspection is required for map pixels and visual parity'};return;
  }
  if(repeatCount>1){
   const c=state.performance.lifecycle.capture;
   assert(c&&c.baked&&c.ready&&!c.gate&&!c.bakePending,'Baked minimap finished and download ownership released');
   assert(c.sequence>previousCaptureSequence,'Each match creates a fresh capture');
   previousCaptureSequence=c.sequence;
   await wait(s=>s.matchHud?.minimap?.base&&s.matchHud.minimap.frames>1&&!s.matchHud.minimap.disposed,'Current match minimap attached and rendered');
   report.lifecycleChecks.push({round,phase:'live',capture:c,pass:true});
  }
  await live(prefix+'match-live');
  report.aimLines??=[];report.aimLines.push({phase:prefix+'match-live',state:structuredClone(state.aimLines),
   boundary:'Read-only actual state. Nonzero counts establish active geometry only; wall/body occlusion and pixel parity require rendered review.'});
  if(process.env.VOX_QA_MATCH_ACTIONS==='1'){
   report.actionChecks??=[];
   function actionCheck(name,value){report.actionChecks.push({name,pass:!!value});assert(value,name)}
   await key('Tab');await dump();actionCheck('Tab opens scoreboard after release',state.battle.boardOn);
   await page.screenshot({path:path.join(out,prefix+'board-open.png')});
   await key('Tab');await dump();actionCheck('Second Tab closes scoreboard',!state.battle.boardOn);
   await key('t');await dump();actionCheck('Competitive T does not exit',state.mode==='trial');
   await unlock();await click('退出对局');await dump();
   actionCheck('Leave button opens confirmation',state.battle.leaveConfirm);
   const pausedTime=state.battle.time,gameCount=state.battle.profile.games;
   await sleep(1200);await dump();actionCheck('Leave confirmation freezes world',state.battle.time===pausedTime);
   actionCheck('Pending confirmation does not charge defeat',state.battle.profile.games===gameCount);
   await page.screenshot({path:path.join(out,prefix+'leave-confirm.png')});
   await click('取消');await dump();actionCheck('Cancel stays in match without defeat',state.mode==='trial'&&!state.battle.leaveConfirm&&state.battle.profile.games===gameCount);
   await sleep(500);await dump();actionCheck('World continues after cancel',state.battle.time>pausedTime);
   await click('设置');await click('返回车库');await dump();
   actionCheck('Unified settings return uses same confirmation',state.battle.leaveConfirm);
   await click('取消');await dump();
   actionCheck('Settings return cancellation does not charge defeat',state.battle.profile.games===gameCount&&!state.battle.leaveConfirm);
   report.expectedGamesAfterLeave=gameCount+1;
  }
  if(process.env.VOX_QA_SCOPE_CHECK==='1'){
   report.scopeChecks??=[];
   async function scopeCheck(name,expected){await sleep(350);await dump();const actual=state.reticle?.scope;report.scopeChecks.push({name,expected,actual});assert.equal(actual,expected,name)}
   await page.mouse.click(960,540,{button:'right',delay:50});await scopeCheck('short click enters scope',true);await page.screenshot({path:path.join(out,'scope.png')});
   await page.mouse.click(960,540,{button:'right',delay:50});await scopeCheck('short click exits scope',false);
   await page.mouse.down({button:'right'});await sleep(500);await scopeCheck('hold enters scope',true);await page.mouse.up({button:'right'});await scopeCheck('long release exits scope',false);
  }
  if(state.pointer?.captured)await unlock();await page.screenshot({path:path.join(out,prefix+'match-paused.png')});await begin(prefix+'match-return');await click('退出对局');await click('确定');await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'return');await sleep(2000);await end(prefix+'match-return');
  if(process.env.VOX_QA_MATCH_ACTIONS==='1')assert.equal(state.matchProfile.games,report.expectedGamesAfterLeave,'Confirmed leave records exactly one defeat');
  if(repeatCount>1){
   const lifecycle=state.performance.lifecycle;
   for(const name of ['trial','minimap']){
    const value=lifecycle[name];
    assert(!value||(value.disposed&&Object.entries(value).every(([k,v])=>k==='disposed'||!v)),name+' disposed or collected without owned scene/render state');
   }
   const c=lifecycle.capture;
   assert.equal(c?.sequence,previousCaptureSequence,'Return observes the same match capture');
   assert(c&&c.disposed&&['gate','bakePending','scene','worker','texture','result','node','camera','image','uploadTexture'].every(k=>!c[k]),'Capture cancelled and all owned resources released');
   assert.equal(state.performance.retiredTargets,0,'Retired render targets drained');
   report.lifecycleChecks.push({round,phase:'returned',lifecycle,performance:state.performance,pass:true});
   await page.screenshot({path:path.join(out,prefix+'returned.png')});
  }
  }
  if(process.env.VOX_QA_MATCH_ACTIONS==='1'){
   if((await dump()).tab!=='battle')await click('出战');await click('歼灭战');await click('开始匹配');
   await wait(s=>s.mode==='trial'&&s.battle&&!s.loadingFlow?.active,'spectator match');
   await key('Space');await wait(s=>!s.intro?.active,'spectator intro');
   await tap(width/2,height/2);await key('F3');await wait(s=>s.battle&&!s.battle.playerAlive,'QA core destruction');
   const allies=state.battle.units.filter(u=>u.alive&&u.team==='blue'&&!u.player);
   assert(allies.length>1,'Multiple surviving teammates for spectator switching');
   const index=state.battle.spectate;await key('d');await dump();
   assert.equal(state.battle.spectate,index+1,'D advances spectator');assert.equal(state.battle.watched,allies[(index+1)%allies.length].name);
   await key('a');await dump();assert.equal(state.battle.spectate,index,'A returns spectator');
   await page.screenshot({path:path.join(out,'spectator.png')});
   report.spectatorChecks={pass:true,allies:allies.map(u=>u.name),watched:state.battle.watched,boundary:'QA destroys player core through actual damage/flush; subsequent spectator input and render use production code. Not natural combat-death acceptance.'};
   const sequence=state.performance.lifecycle.capture.sequence;
   const previousRoster=state.battle.units.filter(u=>!u.player).map(u=>u.name);
   await key('F2');await wait(s=>s.battle?.state==='over','QA match result');
   report.mvpChecks={pass:true,snapshots:await finishMvp({key,dump,wait}),boundary:'Actual production MVP readiness/skip/fade and visible result button; no pixel parity assertion.'};
   await page.screenshot({path:path.join(out,'match-result.png')});await click('再来一局');
   await wait(s=>s.loadingFlow?.active&&s.loadingFlow.match?.mode==='elimination'&&['queue','found','roster'].includes(s.loadingFlow.match.stage),'rematch enters production matching flow');
   const rematchQueue=structuredClone(state.loadingFlow.match);
   await wait(s=>s.mode==='trial'&&['prep','live'].includes(s.battle?.state)&&!s.loadingFlow?.active&&s.performance?.lifecycle?.capture?.sequence>sequence,'actual rematch queue and load');
   await dump();const nextRoster=state.battle.units.filter(u=>!u.player).map(u=>u.name);assertNewRoster(previousRoster,nextRoster);report.rematch={pass:true,queue:rematchQueue,state:structuredClone(state),previousRoster,nextRoster,boundary:'QA completes prior match; real result button returns/disposes world and invokes observed production queue/new roster/loading. Name exclusion assumes successful profile storage, as in the frozen source recent-name pool.'};
   await key('Space');await wait(s=>!s.intro?.active,'rematch intro skip');await dump();if(state.pointer?.captured)await unlock();await click('退出对局');await click('确定');await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'rematch cleanup');
  }
  if(process.env.VOX_QA_SCOPE==='match'){report.result='MEASURED';return}
  if((await dump()).tab!=='battle')await click('出战');await click('剧情模式');await wait(s=>s.story?.ready,'story page');
  const level=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Outgame.json'))).levels[Number(process.env.VOX_QA_STORY_LEVEL||1)-1];await click(level.no+'  '+level.name);await begin('story-load');await click('开始任务');await wait(s=>s.mode==='trial'&&s.story&&!s.loadingFlow?.active,'story');await end('story-load');
  await live('story-live');await key('Escape');await wait(s=>!s.pointer?.captured,'story release');
  await begin('story-return');await key('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'story return');await sleep(2000);await end('story-return');
  report.result='MEASURED';
 }catch(e){report.result='FAIL';report.failure??=e.stack;if(!report.fatal)await page.screenshot({path:path.join(out,'failure.png'),timeout:5000}).catch(()=>{})}
 finally{
  if(!report.fatal){
   let timer;try{
    const measurements=await Promise.race([page.evaluate(()=>window.__combatFrames),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Final frame read timed out')),5000)})]);
    lastMeasurements=measurements;report.frames=measurements.frames;report.gl=measurements.gl;report.slowGL=measurements.slowGL;
    report.measurements={truncated:false,checkpoint:measurementCheckpoint,boundary:'Final frame read completed. Runtime and scenario acceptance remain separate.'};
   }catch(error){report.frames=lastMeasurements.frames;report.gl=lastMeasurements.gl;report.slowGL=lastMeasurements.slowGL;report.measurements={truncated:true,checkpoint:measurementCheckpoint,reason:String(error),boundary:'Final frame read failed; only the last completed checkpoint is retained.'};}
   finally{clearTimeout(timer)}
  }
  report.finishedAt=new Date().toISOString();report.closing=true;persist();await (fatalClose||browser.close());console.log(out)
 }
 if(report.result==='FAIL')process.exitCode=1;
}
main().catch(e=>{console.error(e);process.exitCode=1});

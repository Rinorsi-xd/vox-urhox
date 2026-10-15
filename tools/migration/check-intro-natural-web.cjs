// Natural public opening: real elapsed audio, mouse lock, W/LMB, ink and gate.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4269),sleep=ms=>new Promise(r=>setTimeout(r,ms));
const source=JSON.parse(fs.readFileSync(path.join(root,'assets/Intro/Intro.json')));
function AudioMeter(){
 const qa=window.__introNaturalQA={audio:[],raf:[],longTasks:[],marks:[],clips:{},marker:{shot:'boot'},started:performance.now(),timeOrigin:performance.timeOrigin,timezoneOffset:new Date().getTimezoneOffset()};
 let last=performance.now();function frame(now){qa.raf.push({at:now,dt:now-last,shot:qa.marker.shot});last=now;requestAnimationFrame(frame);}requestAnimationFrame(frame);
 try{new PerformanceObserver(list=>{for(const e of list.getEntries())qa.longTasks.push({at:e.startTime,duration:e.duration,shot:qa.marker.shot});}).observe({entryTypes:['longtask']});}catch{}
 const Context=window.AudioContext||window.webkitAudioContext;if(!Context)return;
 const original=Context.prototype.createScriptProcessor;
 Context.prototype.createScriptProcessor=function(...args){
  const node=original.apply(this,args),ctx=this;let p=node,descriptor;
  while(p&&!descriptor){descriptor=Object.getOwnPropertyDescriptor(p,'onaudioprocess');p=Object.getPrototypeOf(p);}
  if(!descriptor?.set){qa.hookError='Missing native onaudioprocess setter';return node;}
  let callback;
  Object.defineProperty(node,'onaudioprocess',{configurable:true,get(){return callback;},set(fn){
   callback=fn;descriptor.set.call(node,fn&&function(event){
    fn.call(this,event);const buffer=event.outputBuffer,a=buffer.getChannelData(0);let sum=0,peak=0,count=0;
    for(let i=0;i<a.length;i+=16){const v=a[i];sum+=v*v;peak=Math.max(peak,Math.abs(v));count++;}
    const marker=qa.marker;qa.audio.push({at:performance.now(),playbackTime:event.playbackTime,duration:buffer.duration,rate:buffer.sampleRate,rms:Math.sqrt(sum/count),peak,shot:marker.shot,line:marker.line,context:ctx.state});
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
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa,'read-only QA probe required');
 const test={width:Number(process.env.VOX_INTRO_WIDTH||1600),height:Number(process.env.VOX_INTRO_HEIGHT||900)};
 const screenshots=process.env.VOX_INTRO_NO_SCREENSHOTS!=='1';
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:test,deviceScaleFactor:1});await page.addInitScript(AudioMeter);
 const tag=process.env.VOX_INTRO_TAG||'',prefix='intro-natural-web-'+test.width+'x'+test.height+(tag?'-'+tag:''),log=path.join(out,prefix+'.log');fs.writeFileSync(log,'');
 const report={result:'RUNNING',functionality:'RUNNING',continuity:'NOT_MEASURED',identity,baseline:source.commit,viewport:test,workload:process.env.VOX_QA_LOAD||'unspecified',instrumentation:{screenshots,methodTiming:'QA instance wrappers around actual session/physics/actors/weapons/views/effects/UI/audio methods; Time:GetSystemTime milliseconds; wrapper overhead included, not an uninstrumented performance baseline'},checks:[],errors:[],httpFailures:[],samples:[],shots:[],startedAt:new Date().toISOString()};
 let state,revision=0,started,driveOrigin,driveDistance=0,fired=false,released=false,recaptured=false,lastStep=-1,keyboardHeld=false,mouseHeld=false,braking=false;
 let aimMouse={x:test.width*.5,y:test.height*.55};
 const shotNames=new Set(),captured=new Set();
 page.on('console',m=>{const line=m.text();fs.appendFileSync(log,line+'\n');let i=line.indexOf('OUTGAME_STATE ');
  if(i>=0){try{state=JSON.parse(line.slice(i+14));revision++;if(state.mode==='opening')report.samples.push({at:Date.now(),...state});}catch(e){if(line.trimEnd().endsWith('}'))report.errors.push(e.message);}}
  const match=line.match(/\[Intro\] ([\w-]+)\s*$/);if(match){shotNames.add(match[1]);report.shots.push({shot:match[1],at:Date.now()});}
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(line))report.errors.push(line);
 });page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
 const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
 async function key(name){await page.keyboard.down(name);await sleep(90);await page.keyboard.up(name);}
 async function wait(fn,label,timeout=240000){const at=Date.now();let next=at+700;while(!state||!fn(state)){
  if(report.errors.length)throw Error(report.errors.join('\n'));if(state?.failed)throw Error(state.error);if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
  if(Date.now()>next){next=Date.now()+700;await key('F8');}await sleep(80);
 }return state;}
 async function dump(){const old=revision;await key('F8');await wait(()=>revision>old,'fresh state',15000);return state;}
 async function mark(){if(state?.mode==='opening')await page.evaluate(m=>{const q=window.__introNaturalQA;q.marker=m;q.marks.push({at:performance.now(),...m});},{shot:state.shot,line:state.line,time:state.time,age:state.age});}
 async function point(r,fx=.5,fy=.5){const c=await page.locator('canvas').boundingBox();return {x:c.x+(r.x+r.w*fx)/state.width*c.width,y:c.y+(r.y+r.h*fy)/state.height*c.height};}
 async function click(r){const p=await point(r);await page.mouse.click(p.x,p.y);}
 async function shot(id){if(!screenshots||captured.has(id))return;captured.add(id);await page.screenshot({path:path.join(out,prefix+'-'+id+'.png')});}
 try{
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active&&!s.loading?.busy,'actionable actual hall');await dump();
  const entry=state.widgets.find(w=>w.text==='开场动画'&&!w.disabled);assert.ok(entry,'public original opening entry');const [x,y,w,h]=entry.rect;await click({x,y,w,h});
  await wait(s=>s.mode==='opening'&&s.ready,'opening resources, audio decode and real scene',300000);await shot('ready');
  started=Date.now();await page.mouse.click(test.width*.5,test.height*.65);await wait(s=>s.stage==='ad','public opening begins');
  const deadline=Date.now()+600000;
  while(state.mode==='opening'&&state.shot!=='contract'){
   if(Date.now()>deadline)throw Error('Natural opening did not reach contract');await dump();await mark();
   const current=state.shot;shotNames.add(current);
   if(['idyll','no','familiar','galaxy','payslip','m-build','m-drive','m-missile','m-salvage','master','tvcut','comms'].includes(current))await shot(current);
   if(current==='sortie-brief'&&state.age>2.3){await page.mouse.click(test.width*.5,test.height*.55);await sleep(250);}
   if(current==='sortie-play'){
    const s=state.sortie||{},status=state.sortieStatus;
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
   if(state.page?.choosing)await key('3');
   await sleep(220);
  }
  if(keyboardHeld){await page.keyboard.up('w');keyboardHeld=false;}if(mouseHeld){await page.mouse.up();mouseHeld=false;}
  check(Date.now()-started>110000,'opening played in natural wall-clock time without advertisement/dialogue skip');
  check(driveDistance>1,'actual held W moves live rigid-body player');check(fired,'actual held LMB fires during original shooting lesson');check(released&&recaptured,'actual pointer release and re-capture both occurred');
  for(const id of ['logo','idyll','prosper','order','leave','no','sortie-brief','sortie-countdown','sortie-play','familiar','galaxy','payslip','decide','decided','m-build','m-drive','m-missile','m-salvage','recruit','peacekeeper','master','mechanic','motto','disclaimer','tvcut','comms','contract'])check(shotNames.has(id),'natural original shot '+id);
  const moved=report.samples.filter(s=>s.sortie?.step===2),finished=report.samples.find(s=>s.sortie?.step===5);
  check(moved.length>0&&finished,'real lesson reached shooting and destruction');report.enemyHit=moved.some(s=>s.sortieStatus?.enemyHit)||report.samples.some(s=>s.sortie?.mine);report.driveDistance=driveDistance;
  check(report.samples.some(s=>s.shot==='m-missile'&&s.sortieStatus?.missileLaunched),'original prepared montage hero launches real missiles during natural playback');
  await dump();await mark();await shot('contract');await click(state.page.field);await page.keyboard.press('Control+A');await page.keyboard.insertText('自然验收');
  const r=state.page.signature,a=await point(r,.15,.45),b=await point(r,.6,.7),c=await point(r,.82,.25);await page.mouse.move(a.x,a.y);await page.mouse.down();await page.mouse.move(b.x,b.y,{steps:15});await page.mouse.move(c.x,c.y,{steps:15});await page.mouse.up();await dump();
  check(state.page.ink>=30,'actual signature stroke accepted');const submit=state.page.buttons.find(b=>b.id==='submit');assert.ok(submit);await click(submit);
  await wait(s=>s.signed,'original signed profile');await wait(s=>s.shot==='gate','original gate');await mark();await shot('gate');
  await wait(s=>s.mode!=='opening'&&s.tab==='hangar'&&!s.loadingFlow?.active,'actual hall and tutorial restoration');await shot('restored');
  await sleep(2000);await dump();check(state.mode!=='opening'&&state.tab==='hangar'&&!state.loadingFlow?.active,'restored hall remains responsive during tutorial resource handoff');
  check(await page.evaluate(()=>document.pointerLockElement===null),'pointer ownership released after full opening');check(!report.errors.length,'zero game errors during full natural opening');report.functionality='PASS';
 }catch(e){report.failure=e.stack;report.lastState=state;report.functionality='FAIL';if(screenshots)await page.screenshot({path:path.join(out,prefix+'-failure.png')}).catch(()=>{});}
 finally{
  await page.keyboard.up('w').catch(()=>{});await page.keyboard.up('Space').catch(()=>{});await page.mouse.up().catch(()=>{});
  const metrics=await page.evaluate(()=>{
   const q=window.__introNaturalQA,clips={};if(!q)return null;
   for(const [key,clip]of Object.entries(q.clips)){const bytes=new Uint8Array(clip.frames*2);let offset=0;for(const a of clip.chunks){bytes.set(new Uint8Array(a.buffer),offset);offset+=a.byteLength;}let binary='';for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));clips[key]={rate:clip.rate,frames:clip.frames,base64:btoa(binary)};}
   return {audio:q.audio,raf:q.raf,longTasks:q.longTasks,marks:q.marks,clips,hookError:q.hookError,timeOrigin:q.timeOrigin,timezoneOffset:q.timezoneOffset};
  }).catch(()=>null);
  if(metrics){
   for(const [key,clip]of Object.entries(metrics.clips))fs.writeFileSync(path.join(out,prefix+'-'+key+'.wav'),Wave(clip));delete metrics.clips;
   const during=metrics.audio.filter(s=>!['boot','ready'].includes(s.shot)),gaps=[];for(let i=1;i<during.length;i++){const dt=during[i].at-during[i-1].at;if(dt>Math.max(250,during[i].duration*3000))gaps.push({at:during[i].at,dt,shot:during[i].shot,line:during[i].line});}
   const raf=metrics.raf.filter(s=>!['boot','ready'].includes(s.shot));report.audioContinuity={callbacks:during.length,nonzero:during.filter(s=>s.peak>.001).length,maxCallbackGap:Math.max(0,...during.slice(1).map((s,i)=>s.at-during[i].at)),starvationCandidates:gaps,rafP95:Percentile(raf.map(s=>s.dt),.95),rafP99:Percentile(raf.map(s=>s.dt),.99),maxRaf:Math.max(0,...raf.map(s=>s.dt)),rafFreezes:raf.filter(s=>s.dt>250),longTasks:metrics.longTasks};
   report.continuity=!metrics.hookError&&during.length>100&&report.audioContinuity.nonzero>100&&gaps.length===0&&report.audioContinuity.rafFreezes.length===0?'PASS':'FAIL';
   fs.writeFileSync(path.join(out,prefix+'-audio-timeline.json'),JSON.stringify(metrics));
  }
  report.functionalityBeforeShutdown=report.functionality;const priorErrors=report.errors.length;
  await page.close();await browser.close();report.shutdownErrors=report.errors.slice(priorErrors);
  if(report.errors.length)report.functionality='FAIL';
  report.result=report.functionality==='PASS'&&report.continuity==='PASS'?'PASS':'FAIL';report.finishedAt=new Date().toISOString();fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));
 }
 console.log(JSON.stringify({result:report.result,functionality:report.functionality,continuity:report.continuity,checks:report.checks.length,errors:report.errors.length,audio:report.audioContinuity&&{callbacks:report.audioContinuity.callbacks,nonzero:report.audioContinuity.nonzero,maxCallbackGap:report.audioContinuity.maxCallbackGap,starvationCandidates:report.audioContinuity.starvationCandidates.length,rafP95:report.audioContinuity.rafP95,rafP99:report.audioContinuity.rafP99,maxRaf:report.audioContinuity.maxRaf,rafFreezes:report.audioContinuity.rafFreezes.length}}));if(report.result!=='PASS')throw Error(report.failure||'Natural opening audio/frame continuity failed; retain measured timeline');
})().catch(e=>{console.error(e);process.exitCode=1;});

// Public drive-first tutorial handoff. No QA completion keys or gameplay writes.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const runtime='C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const baseline={branch:'2026-10-15',commit:'b276064942ae09c0227ec28d4cfda1d5ff006455',
 content:'edd9d0de1b29843c739f0dfd13eb0086977d6f3b1422954f5c8cf31085232d68',files:{
  'shared/story/tutorial.js':'19980997a549df6fbfff96f32e3df8f40c29a86c763081cf2604aae00de3a961',
  'shared/ui/tutorial.js':'e83ab17998d41797ad5b5b774067fe656697b1d0af6a9abe0cf6753065ee2962',
  'shared/ui/shell.js':'2b2e30c3dc5c1cab613749dc38553d7df9e88d484d862006f060121881feee43'}};
const scripts=['story/Tutorial.lua','story/TutorialRules.lua','ui/TutorialPage.lua','ui/PauseMenu.lua',
 'ui/GarageHud.lua','ui/StoryPage.lua','app/HangarApp.lua','app/LoadingFlow.lua','app/TrialSession.lua',
 'story/Mission.lua','story/MissionRules.lua','audio/StoryComms.lua',
 'app/BuildSession.lua','controls/BuildInput.lua','controls/BuildCamera.lua','controls/FreeFlight.lua',
 'construction/Inventory.lua','ui/InventoryPanel.lua','ui/BuildHud.lua'];
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function numberEnv(name,fallback,min,max){const value=Number(process.env[name]||fallback);assert.ok(Number.isFinite(value)&&value>=min&&value<=max,name+' range '+min+'..'+max);return value;}
function localBaseline(){
 const source=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
 assert.equal(source.branch,baseline.branch);assert.equal(source.commit,baseline.commit);
 for(const [name,hash]of Object.entries(baseline.files)){
  assert.equal(source.files[name].sha256,hash,'Source registry '+name);
  assert.equal(sha(path.join(source.snapshot,name)),hash,'Frozen source bytes '+name);
 }
 const tutorial=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Tutorial.json')));
 assert.equal(tutorial.source.branch,baseline.branch);assert.equal(tutorial.source.commit,baseline.commit);
 assert.equal(tutorial.source.scriptSha256,baseline.files['shared/story/tutorial.js']);
 assert.equal(tutorial.source.presentation['shared/ui/tutorial.js'],baseline.files['shared/ui/tutorial.js']);
 assert.deepEqual(tutorial.flows.drive,['hello','car','bays','choose','story','go','debrief','leave','edit','bag','pick','place','save','back','graduate']);
 return {sourceSnapshot:source.snapshot,sourceFiles:baseline.files,tutorialSha256:sha(path.join(root,'assets/UI/Tutorial.json')),
  scripts:Object.fromEntries(scripts.map(name=>[name,sha(path.join(root,'scripts',name))])),
  probeSha256:sha(path.join(__dirname,'probe-outgame-web.lua'))};
}
async function bounded(promise,ms,label){let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Timeout '+label)),ms);})]);}finally{clearTimeout(timer);}}
async function identityAt(base){const response=await fetch(base+'/identity.json',{signal:AbortSignal.timeout(12000),cache:'no-store'});assert.equal(response.status,200,'Identity HTTP');return response.json();}
async function tutorialAsset(base,identity,local){
 const manifestBytes=fs.readFileSync(identity.manifest_path),manifest=JSON.parse(manifestBytes);
 const file=manifest.files.find(f=>f.fs_path==='UI/Tutorial.json');assert.ok(file,'Packaged tutorial data asset');
 const leaf=file.uuid+'-'+file.hash+file.ext,url=base+'/game-dist/assets/'+leaf;
 const response=await fetch(url,{signal:AbortSignal.timeout(12000),cache:'no-store'});assert.equal(response.status,200,'Tutorial asset HTTP');
 const bytes=Buffer.from(await response.arrayBuffer()),hash=crypto.createHash('sha256').update(bytes).digest('hex');
 assert.equal(hash,local.tutorialSha256,'Actual served tutorial JSON bytes');
 assert.equal(sha(path.join(identity.source_directory,'assets/UI/Tutorial.json')),hash,'Packaged tutorial source bytes');
 return {url,sha256:hash,manifestSha256:crypto.createHash('sha256').update(manifestBytes).digest('hex')};
}
function verifyIdentity(identity,local,manifest){
 assert.equal(identity.qa,true,'Explicit QA server required');assert.equal(identity.servedManifest,manifest,'Pinned immutable manifest');
 assert.equal(identity.identity.sourceBranch,baseline.branch);assert.equal(identity.identity.sourceCommit,baseline.commit);
 assert.equal(identity.identity.sourceContentSha256,baseline.content,'Frozen source content');
 assert.equal(identity.probeSha256,local.probeSha256,'Current read-only observer');
 for(const [name,hash]of Object.entries(local.scripts))assert.equal(identity.identity.scripts[name],hash,'Actual package script '+name);
 const fingerprint=crypto.createHash('sha256').update(JSON.stringify(Object.entries(identity.identity.scripts).sort())).digest('hex');
 assert.equal(identity.identity.scriptFingerprint,fingerprint,'Package script fingerprint');
}
function immutableIdentity(identity){return {manifest:identity.servedManifest,source:identity.source_directory,processId:identity.processId,
 probe:identity.probeSha256,payload:identity.identity,qa:identity.qa};}
function verifyCompletion(route,state){
 assert.deepEqual(route.stages.map(s=>s.id),['bag','pick','place','save','back','graduate','done'],'All real build lessons observed in source order');
 assert.ok(Number.isInteger(route.originalParts)&&route.originalParts>0,'Original authored vehicle part count');
 assert.ok(Number.isInteger(route.addedParts)&&route.addedParts>0,'A real added part is required');
 assert.equal(route.saved.parts,route.originalParts+route.addedParts,'Saved blueprint includes actual addition');
 assert.equal(state.parts,route.saved.parts,'Edited blueprint survives return');
 assert.ok(!state.build&&state.mode==='hangar','Actual hall after editor exit');
 assert.ok(!state.tutorial.running&&state.tutorial.record.done&&!state.tutorial.record.skipped&&!state.tutorial.replay&&state.tutorial.path==='drive','Main drive tutorial completed without replay/skip');
}
function nextObserved(state,step){
 const tutorial=state.tutorial;
 return Boolean(tutorial&&(tutorial.id!==step||step==='graduate'&&tutorial.running===false&&tutorial.record?.done===true));
}
function completionSelfCheck(){
 const route={stages:['bag','pick','place','save','back','graduate','done'].map(id=>({id})),originalParts:42,addedParts:1,saved:{parts:43}};
 const state={parts:43,build:false,mode:'hangar',tutorial:{running:false,path:'drive',record:{done:true},replay:false}};
 verifyCompletion(route,state);let count=1;
 for(const mutate of [r=>r.stages.splice(2,1),r=>r.addedParts=0,r=>r.addedParts=-1,r=>r.saved.parts=42,
  (_,s)=>s.tutorial.record.done=false,(_,s)=>s.tutorial.record.skipped=true,(_,s)=>s.parts=42,
  (_,s)=>s.tutorial.replay=true,(_,s)=>s.tutorial.path='build',(_,s)=>s.build=true]){
  const r=structuredClone(route),s=structuredClone(state);mutate(r,s);assert.throws(()=>verifyCompletion(r,s));count++;
 }
 assert.equal(nextObserved({...state,tutorial:{...state.tutorial,id:'graduate'}},'graduate'),true);count++;
 assert.equal(nextObserved({...state,tutorial:{...state.tutorial,id:'graduate',running:true,record:{}}},'graduate'),false);count++;
 assert.equal(nextObserved({...state,tutorial:{...state.tutorial,id:'place'}},'place'),false);count++;
 assert.equal(nextObserved({},'graduate'),false);count++;
 return count;
}
// Observe real output samples after the engine's mixer callback without changing them.
function audioObserver(){
 const qa=window.__tutorialDriveAudio={callbacks:0,nonzero:0,peak:0,rms:0,contexts:[],hooked:0};
 const Context=window.AudioContext||window.webkitAudioContext;if(!Context){qa.unavailable='No AudioContext';return;}
 const original=Context.prototype.createScriptProcessor;if(!original){qa.unavailable='No ScriptProcessor mixer';return;}
 const seen=new WeakSet();
 Context.prototype.createScriptProcessor=function(...args){
  const node=original.apply(this,args),context=this;
  if(!seen.has(context)){seen.add(context);const update=()=>qa.contexts.push({at:performance.now(),state:context.state,time:context.currentTime});update();context.addEventListener('statechange',update);}
  let parent=node,descriptor;while(parent&&!descriptor){descriptor=Object.getOwnPropertyDescriptor(parent,'onaudioprocess');parent=Object.getPrototypeOf(parent);}
  if(!descriptor?.set){qa.unavailable='Missing native callback setter';return node;}
  let callback;Object.defineProperty(node,'onaudioprocess',{configurable:true,get(){return callback;},set(fn){callback=fn;descriptor.set.call(node,fn&&function(event){
   fn.call(this,event);const samples=event.outputBuffer.getChannelData(0);let sum=0,peak=0,count=0;
   for(let i=0;i<samples.length;i+=32){sum+=samples[i]*samples[i];peak=Math.max(peak,Math.abs(samples[i]));count++;}
   qa.callbacks++;if(peak>1e-6)qa.nonzero++;qa.peak=Math.max(qa.peak,peak);qa.rms=Math.sqrt(sum/count);qa.lastAt=performance.now();
  });}});qa.hooked++;return node;
 };
}
async function main(){
 if(process.argv.includes('--check')){console.log(JSON.stringify({result:'PASS',observerChecks:completionSelfCheck(),scope:'Offline frozen-source/local inputs and completion observer positive/negative controls only; no HTTP or browser',...localBaseline()},null,2));return;}
 const complete=process.env.VOX_TUTORIAL_COMPLETE==='1';
 const tag=process.env.VOX_TUTORIAL_TAG||new Date().toISOString().replace(/[:.]/g,'-')+'-'+crypto.randomBytes(4).toString('hex');
 assert.match(tag,/^[A-Za-z0-9._-]{1,100}$/,'Unique output tag');
 const out=path.join(root,'docs/migration/evidence','tutorial-drive-route-'+tag);
 fs.mkdirSync(out);const report={result:'RUNNING',shutdown:'PENDING',tag,startedAt:new Date().toISOString(),
  scope:'PC public pause-menu tutorial; drive-first choice; real first mission; held W short drive; normal T return; debrief, leave, E and bag. Stops at bag, without inventory/edit/save. No mission victory, complete tutorial, audible-quality, performance or mobile acceptance.',
  checks:[],errors:[],probeErrors:[],httpFailures:[],requestFailures:[],samples:[],voices:[],screenshots:[],inputs:[]};
 report.completeRequested=complete;
 if(complete)report.scope='PC public pause-menu drive-first tutorial: actual first mission/W/T return, debrief/leave/edit, B inventory, select cube, real left-button part addition, save bay, return hall, graduate. No QA completion keys, part deletion, teleport, script state writes, mission victory, pixel/audio-quality, performance or mobile acceptance.';
 const persist=()=>fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2));
 persist();console.log('Evidence: '+out);
 let server,browser,page,state,revision=0,held=new Set(),deadline,watchdog;
 const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);persist();};
 const error=message=>{report.errors.push({at:new Date().toISOString(),message});persist();};
 try{
  assert.ok(process.env.VOX_QA_BASE||process.env.VOX_QA_PORT,'Set VOX_QA_BASE or VOX_QA_PORT explicitly');
  const base=new URL(process.env.VOX_QA_BASE||'http://127.0.0.1:'+numberEnv('VOX_QA_PORT',0,1,65535)).origin;
  assert.ok(process.env.VOX_EXPECT_MANIFEST,'Set VOX_EXPECT_MANIFEST explicitly');
  const manifest=process.env.VOX_EXPECT_MANIFEST,local=localBaseline();report.local=local;report.base=base;
  const identity=await identityAt(base);verifyIdentity(identity,local,manifest);report.identity=identity;
  report.tutorialAsset=await tutorialAsset(base,identity,local);persist();
  check(true,'Pinned new QA package, current observer and frozen source verified before launch');
  const stageMs=numberEnv('VOX_TUTORIAL_STAGE_SECONDS',120,20,300)*1000;
  const totalMs=numberEnv('VOX_TUTORIAL_TOTAL_SECONDS',720,180,1200)*1000;
  deadline=Date.now()+totalMs;
  const {chromium}=require(path.join(runtime,'playwright')),sharp=require(path.join(runtime,'sharp'));
  server=await chromium.launchServer({headless:true,channel:'chrome',timeout:30000,args:['--use-angle=d3d11']});
  report.browserPid=server.process().pid;report.shutdown='OPEN';persist();
  watchdog=setTimeout(()=>{report.deadlineExpired=true;error('Global route deadline');server.kill().catch(e=>error('Watchdog kill: '+e.message));},totalMs);
  browser=await chromium.connect(server.wsEndpoint(),{timeout:15000});
  page=await browser.newPage({viewport:{width:1600,height:900},deviceScaleFactor:1});
  page.setDefaultTimeout(12000);page.setDefaultNavigationTimeout(30000);await page.addInitScript(audioObserver);
  page.on('console',message=>{
   const line=message.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');
   if(at>=0){try{
    state=JSON.parse(line.slice(at+14));revision++;const t=state.tutorial;
    if(t?.visible&&t.voicePlaying&&!report.voices.some(v=>v.id===t.id&&v.voiceId===t.voiceId&&v.voicePlayed===t.voicePlayed))
     report.voices.push({at:Date.now(),id:t.id,voiceId:t.voiceId,voicePlayed:t.voicePlayed,state:structuredClone(state)});
   }catch(e){report.probeErrors.push({at:Date.now(),message:e.message,bytes:line.length,tail:line.slice(-100)});}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(line))error(line);
  });
  page.on('pageerror',e=>error(e.message));page.on('crash',()=>error('Renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({at:Date.now(),status:r.status(),url:r.url()});});
  page.on('requestfailed',r=>report.requestFailures.push({at:Date.now(),url:r.url(),failure:r.failure()}));
  function healthy(){assert.ok(Date.now()<deadline,'Global route deadline');assert.equal(report.errors.length,0,'Runtime errors: '+JSON.stringify(report.errors));if(state?.failed)throw Error(state.error||'Probe reported failure');}
  async function key(name){healthy();report.inputs.push({at:Date.now(),key:name});await bounded(page.keyboard.down(name),12000,'keydown '+name);held.add(name);await sleep(90);await bounded(page.keyboard.up(name),12000,'keyup '+name);held.delete(name);}
  async function wait(fn,label,timeout=stageMs){const until=Math.min(deadline,Date.now()+timeout);let next=0;
   while(true){healthy();if(state&&fn(state))return state;if(Date.now()>until)throw Error('Timeout '+label+'; latest '+JSON.stringify(state));if(Date.now()>next){next=Date.now()+650;await key('F8');}await sleep(80);}
  }
  async function dump(){const before=revision;await key('F8');return wait(()=>revision>before,'fresh bounded F8 state',18000);}
  async function clickRect(rect,label){healthy();const r=Array.isArray(rect)?{x:rect[0],y:rect[1],w:rect[2],h:rect[3]}:rect;
   assert.ok(r&&r.w>0&&r.h>0,label+' rect');const canvas=await page.locator('canvas').first().boundingBox();assert.ok(canvas,'Canvas bounds');
   report.inputs.push({at:Date.now(),click:label,rect:r});await bounded(page.mouse.click(canvas.x+(r.x+r.w/2)/state.width*canvas.width,canvas.y+(r.y+r.h/2)/state.height*canvas.height),12000,'click '+label);
  }
  async function widget(text){await dump();await wait(s=>Array.isArray(s.widgets)&&s.widgets.some(w=>w.text===text&&!w.disabled&&w.rect[2]>0&&w.rect[3]>0),'visible widget '+text,30000);await clickRect(state.widgets.find(w=>w.text===text&&!w.disabled).rect,text);}
  async function tutorial(id){await wait(s=>s.tutorial?.running&&s.tutorial.visible&&s.tutorial.id===id,'visible tutorial '+id);await dump();check(state.tutorial.id===id&&state.tutorial.visible,'Actual visible '+id);}
  async function shot(name){await dump();const snapshot=structuredClone(state),screenshot=path.join(out,name+'.png');let complete=false;
   // Continue passive F8 sampling while PNG capture waits on a busy renderer.
   const taking=page.screenshot({path:screenshot,timeout:15000}).finally(()=>{complete=true;});
   const sampling=(async()=>{while(!complete){await sleep(500);if(!complete)await key('F8');}})();
   await Promise.all([taking,sampling]);
   const stats=await sharp(screenshot).stats();check(stats.channels.slice(0,3).some(c=>c.stdev>3),'Nonblank rendered '+name);
   report.screenshots.push({name,path:screenshot,channels:stats.channels.map(c=>({min:c.min,max:c.max,stdev:c.stdev}))});
   report.samples.push({name,at:Date.now(),state:snapshot,audio:await bounded(page.evaluate(()=>structuredClone(window.__tutorialDriveAudio)),5000,'audio snapshot')});persist();
  }
  async function voice(step,id,name){await tutorial(step);
   await wait(()=>report.voices.some(v=>v.id===step&&v.voiceId===id),'original playing '+id,60000);
   const observed=report.voices.find(v=>v.id===step&&v.voiceId===id);
   check(observed.state.tutorial.voicePlaying&&observed.state.tutorial.visible,'Original '+id+' actually playing');await shot(name||id);
  }
  async function finishVoice(step,id){await wait(s=>s.tutorial.id===step&&s.tutorial.voiceId===id&&!s.tutorial.voicePlaying,'natural voice finish '+id,60000);await sleep(350);await dump();}
  async function button(id){await dump();const b=state.tutorial?.buttons?.find(b=>b.id===id);assert.ok(b,'Visible tutorial button '+id);await clickRect(b,'tutorial '+id);}
  async function next(step){await button('next');await wait(s=>nextObserved(s,step),step+' actual next',10000);}
  async function target(text){await dump();const r=state.tutorial.target;check(r&&r.w>2&&r.h>2,'Live target for '+state.tutorial.id);
   if(text){const b=state.widgets.find(w=>w.text===text);assert.ok(b,'Target widget '+text);const [x,y,w,h]=b.rect;
    check(r.x<=x+.5&&r.y<=y+.5&&r.x+r.w>=x+w-.5&&r.y+r.h>=y+h-.5,'Live target encloses '+text);}
  }
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow?.active&&!s.loading?.busy,'actionable hall');
  await key('Escape');await wait(s=>s.pauseMenu?.rows?.tutorial&&!s.pauseMenu.rows.tutorial.disabled,'public pause tutorial entry',15000);
  await shot('pause-public-entry');await clickRect(state.pauseMenu.rows.tutorial.rect,'新手引导');
  await voice('hello','T-01','hello-line1');await voice('hello','T-02','hello-line2');await finishVoice('hello','T-02');await next('hello');
  await voice('car','T-03','car');await target();await finishVoice('car','T-03');await next('car');
  await voice('bays','T-04','bays');await target();await finishVoice('bays','T-04');await next('bays');
  await voice('choose','T2-01','choose-drive');await finishVoice('choose','T2-01');await button('drive');
  await voice('story','T-12','story');check(state.tutorial.path==='drive'&&state.tab==='battle','Real drive choice selects drive route and battle page');
  await target('剧情模式');await finishVoice('story','T-12');await widget('剧情模式');
  await voice('go','T-13','go');check(state.tab==='story','Actual story selector');await target('开始任务');await finishVoice('go','T-13');
  await widget('01  坠舰');await dump();check(state.tutorial.id==='go','First mission selected while tutorial remains go');await widget('开始任务');
  await wait(s=>s.mode==='trial'&&s.map==='story1'&&s.story?.id==='s1'&&!s.loadingFlow.active&&s.story.index>=1,'actual first mission begins');
  check(state.sceneVisible&&state.story.alive&&state.vehicle,'Live mission scene, player and vehicle');
  assert.ok(state.tutorial,'DumpTrial tutorial observer required; screenshots alone cannot pass');
  check(state.tutorial.running&&!state.tutorial.visible&&state.tutorial.id==='go'&&state.tutorial.path==='drive','Tutorial remains hidden on go during actual mission');
  await wait(s=>s.story.voicePlayed>0&&s.story.voicePlaying,'Actual mission communication playback',60000);await shot('mission-comms-hidden-tutorial');
  if(!state.pointer.captured){const canvas=await page.locator('canvas').first().boundingBox();await page.mouse.click(canvas.x+canvas.width*.5,canvas.y+canvas.height*.55);}
  await wait(s=>s.pointer.captured,'Actual mission mouse capture',15000);await dump();
  const origin=[...state.vehicle.position];let distance=0;
  for(let attempt=0;attempt<4&&distance<=.25;attempt++){
   await page.keyboard.down('w');held.add('w');report.inputs.push({at:Date.now(),hold:'w',ms:750});await sleep(750);await page.keyboard.up('w');held.delete('w');
   await page.keyboard.down('Space');held.add('Space');await sleep(200);await page.keyboard.up('Space');held.delete('Space');await dump();
   check(state.mode==='trial'&&state.story?.alive&&state.vehicle,'Player remains alive through real short drive');
   distance=Math.hypot(state.vehicle.position[0]-origin[0],state.vehicle.position[2]-origin[2]);
  }
  report.drive={origin,end:state.vehicle.position,distance};check(distance>.25,'Held real W moves vehicle more than 0.25m');
  check(!state.tutorial.visible&&state.tutorial.id==='go','Tutorial still hidden on go after actual driving');await shot('mission-short-drive');
  await key('t');await wait(s=>s.mode==='hangar'&&s.tab==='story'&&!s.loadingFlow.active,'Normal T return to original story selector');
  await voice('debrief','T2-02','debrief-line1');check(state.tutorial.path==='drive','Same drive route survives normal return');
  await voice('debrief','T2-03','debrief-line2');await finishVoice('debrief','T2-03');await next('debrief');
  await voice('leave','T2-04','leave');await target('选择模式');await finishVoice('leave','T2-04');await key('Escape');
  await voice('edit','T-05','edit-after-return');check(state.tab==='battle'&&!state.build,'Public Escape leaves story selector');await finishVoice('edit','T-05');
  await key('e');await voice('bag','T-06','bag-after-real-return');
  check(state.build&&!state.inventory&&state.tutorial.path==='drive','Public E continues drive-first tutorial into real editor bag lesson');
  check(!state.tutorial.record.done&&!state.tutorial.record.skipped&&!state.tutorial.replay,'Tutorial remains active, incomplete and unskipped at scoped stop');
  if(complete){
   report.buildRoute={stages:[],placementAttempts:[]};
   const stage=id=>{report.buildRoute.stages.push({id,at:Date.now(),parts:state.parts,record:structuredClone(state.tutorial.record)});persist();};
   stage('bag');await finishVoice('bag','T-06');await key('b');
   await voice('pick','T-07','inventory-pick');check(state.inventory&&state.build,'Real B opens actual inventory');stage('pick');
   await wait(s=>Array.isArray(s.widgets)&&s.widgets.some(w=>w.part==='cube'&&w.kind!=='slot'&&!w.disabled),'visible original cube inventory card',20000);
   const cube=state.widgets.find(w=>w.part==='cube'&&w.kind!=='slot'&&!w.disabled);
   await clickRect(cube.rect,'inventory cube');await dump();check(state.inventoryState?.current==='cube','Real cube card selects hotbar part');
   await finishVoice('pick','T-07');await widget('关闭');
   await voice('place','T-08','place-before');check(state.build&&!state.inventory,'Inventory closes into real assembly');stage('place');
   const originalCount=state.parts;report.buildRoute.originalParts=originalCount;await finishVoice('place','T-08');
   const canvas=await page.locator('canvas').first().boundingBox();let mouse={x:canvas.x+canvas.width*.5,y:canvas.y+canvas.height*.5};
   await page.mouse.click(mouse.x,mouse.y);await wait(s=>s.buildInput?.captured,'actual construction mouse capture',15000);await key('l');await dump();
   for(let attempt=0;attempt<18&&state.parts===originalCount;attempt++){
    healthy();assert.equal(state.tutorial.id,'place','No skipped assembly condition');assert.equal(state.buildInput.tool,'build','Actual placement build tool');
    const preview=state.buildInput.preview;
    if(preview?.type==='cube'&&preview.ok&&state.ghost?.ready){
     report.inputs.push({at:Date.now(),button:'left',action:'place original cube',preview:structuredClone(preview)});
     await page.mouse.down({button:'left'});await sleep(90);await page.mouse.up({button:'left'});await sleep(200);await dump();
    }else{
     const targets=(Array.isArray(state.buildTargets)?state.buildTargets:[]).filter(t=>Number.isFinite(t.x)&&Number.isFinite(t.y)&&t.x>.05&&t.x<.95&&t.y>.05&&t.y<.9).sort((a,b)=>Math.hypot(a.x-.5,a.y-.5)-Math.hypot(b.x-.5,b.y-.5));
     const target=targets[Math.min(Math.floor(attempt/4),Math.max(0,targets.length-1))];assert.ok(target,'Visible authored vehicle cell to aim toward');
     const tangent=Math.tan(state.camera.fov*Math.PI/360),sensitivity=.0022;
     // Real relative input, bounded below the source camera's spike guard.
     const dx=Math.max(-85,Math.min(85,Math.atan((target.x-.5)*2*tangent*state.width/state.height)/sensitivity));
     const dy=Math.max(-85,Math.min(85,Math.atan((target.y-.5)*2*tangent)/sensitivity));
     const offset=attempt%4===3?12:0;mouse={x:mouse.x+dx+offset,y:mouse.y+dy};
     report.inputs.push({at:Date.now(),relativeMouse:{dx:dx+offset,dy},target});await page.mouse.move(mouse.x,mouse.y);await sleep(150);await dump();
    }
    report.buildRoute.placementAttempts.push({attempt,parts:state.parts,preview:state.buildInput.preview,hit:state.buildSelection?.hit,camera:state.camera});persist();
   }
   check(state.parts>originalCount,'Real left mouse adds a part; deletion does not satisfy this route');
   report.buildRoute.addedParts=state.parts-originalCount;await voice('save','T-09','save-after-add');stage('save');
   const savedCount=state.parts;await finishVoice('save','T-09');await key('Escape');await target('保存');await widget('保存');
   await voice('back','T-10','saved-bay');stage('back');
   const slot=state.garage?.active;check(Number.isInteger(slot)&&slot>=1,'Successful save has an actual active bay');
   const saved=state.garage.slots[slot-1];check(saved&&saved.parts===savedCount,'Saved bay contains actual edited part count');
   report.buildRoute.saved={slot,parts:savedCount,name:saved.name};await finishVoice('back','T-10');await target('机库');await widget('机库');
   await voice('graduate','T2-05','graduate');stage('graduate');check(!state.build&&state.mode==='hangar','Public back command returns actual hall');
   check(state.parts===savedCount,'Edited blueprint survives return');await finishVoice('graduate','T2-05');await next('graduate');
   await wait(s=>!s.tutorial.running&&s.tutorial.record.done&&!s.tutorial.record.skipped,'actual tutorial graduation');stage('done');
   check(!state.tutorial.replay,'Graduation is main drive route, not replay');verifyCompletion(report.buildRoute,state);check(true,'Complete source-order build route, actual addition, saved bay and unskipped graduation');await shot('tutorial-complete');
  }
  const audio=report.samples.at(-1).audio;check(audio?.callbacks>0&&audio.nonzero>0,'Actual engine audio output callbacks contain nonzero samples');
  const finalIdentity=await identityAt(base);verifyIdentity(finalIdentity,local,manifest);
  assert.deepEqual(immutableIdentity(finalIdentity),immutableIdentity(identity),'QA identity unchanged throughout route');
  assert.deepEqual(await tutorialAsset(base,finalIdentity,local),report.tutorialAsset,'Served tutorial data and manifest unchanged throughout route');
  assert.deepEqual(localBaseline(),local,'Local checked production/source/observer inputs unchanged');report.finalIdentity=finalIdentity;
  check(!report.httpFailures.some(f=>new URL(f.url).pathname.startsWith('/game-dist/')),'No failed game package HTTP resources');
  check(!report.requestFailures.some(f=>new URL(f.url).pathname.startsWith('/game-dist/')),'No failed game package network requests');
  check(report.errors.length===0,'No runtime errors');report.functionality='PASS';report.result='PASS';
 }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;persist();if(page&&!page.isClosed())await bounded(page.screenshot({path:path.join(out,'failure.png'),timeout:10000}),12000,'failure screenshot').catch(e=>{report.failureScreenshotError=e.message;});}
 finally{
  clearTimeout(watchdog);report.functionality??=report.result;
  if(page&&!page.isClosed())for(const name of held)await bounded(page.keyboard.up(name),1500,'cleanup key '+name).catch(e=>{report.cleanupErrors??=[];report.cleanupErrors.push(e.message);});
  held.clear();
  if(browser)await bounded(browser.close(),10000,'browser.close').catch(e=>{report.cleanupErrors??=[];report.cleanupErrors.push(e.message);});
  if(server){
   const process=server.process();
   await bounded(server.close(),10000,'browser server close').catch(async e=>{report.cleanupErrors??=[];report.cleanupErrors.push(e.message);await bounded(server.kill(),10000,'browser server kill').catch(e=>report.cleanupErrors.push(e.message));});
   if(process.exitCode===null&&process.signalCode===null)await bounded(new Promise(resolve=>process.once('exit',resolve)),10000,'Chrome process exit').catch(e=>{report.cleanupErrors??=[];report.cleanupErrors.push(e.message);});
   report.browserExit={code:process.exitCode,signal:process.signalCode};
   report.shutdown=process.exitCode!==null||process.signalCode!==null?'CLOSED':'NOT_CLOSED';
  }else{report.shutdown='CLOSED';report.browserExit={notStarted:true};}
  if(report.shutdown!=='CLOSED'||report.errors.length)report.result='FAIL';
  report.endedAt=new Date().toISOString();persist();
  console.log(JSON.stringify({result:report.result,functionality:report.functionality,shutdown:report.shutdown,checks:report.checks.length,errors:report.errors.length,evidence:out,failure:report.failure}));
 }
 if(report.result!=='PASS')process.exitCode=1;
}
main().catch(e=>{console.error(e.stack);process.exitCode=1;});

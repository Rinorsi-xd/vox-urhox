const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const memoryProbe=require('./web-memory-probe.cjs');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4261);
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true}];
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(c.name))){
 const prefix='boss-wing-web-'+test.name+(process.env.VOX_QA_TAG?'-'+process.env.VOX_QA_TAG:'');
 const report={base,viewport:test,checks:[],errors:[],httpFailures:[],samples:[],resourceTimeline:[],downloadRequests:[],route:'Production story5 resource gate and real Boss/Vehicle/physics; QA advances boss phase, hits source weakpoint, requests ending page, loads authored wing pair and positions player. Does not replace natural complete playthrough or visual parity acceptance.'};
 const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{hasTouch:true,isMobile:true}:{})});
 let state,sequence=0,wingReady=false;const requestRecords=new Map(),assetNames=new Map();fs.writeFileSync(path.join(out,prefix+'.log'),'');
 page.on('request',request=>{
  if(!request.url().includes('/game-dist/assets/'))return;
  const name=new URL(request.url()).pathname.split('/').pop();
  const item={url:request.url(),resource:assetNames.get(name)??null,startedAt:Date.now(),phase:state?.loading?.phase,map:state?.loading?.pending};
  requestRecords.set(request,item);report.downloadRequests.push(item);
 });
 page.on('requestfinished',request=>{const item=requestRecords.get(request);if(item){item.finishedAt=Date.now();requestRecords.delete(request);}});
 page.on('requestfailed',request=>{const item=requestRecords.get(request);if(item){item.finishedAt=Date.now();item.failure=request.failure()?.errorText;requestRecords.delete(request);}});
 page.on('console',msg=>{const line=msg.text();fs.appendFileSync(path.join(out,prefix+'.log'),line+'\n');
  const i=line.indexOf('OUTGAME_STATE ');if(i>=0){try{state=JSON.parse(line.slice(i+14));sequence++;if(state.performance)report.resourceTimeline.push({at:Date.now(),mode:state.mode,map:state.map,loading:state.loadingFlow?.active,story:state.story?.id,phase:state.story?.boss?.flow,...state.performance});}catch(e){if(line.trimEnd().endsWith('}'))report.errors.push(e.message);}}
  if(line.includes('[WingQA] Source pair ready'))wingReady=true;
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
 });
 page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Browser renderer crashed'));
 page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
 const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
 let memoryAt=0;
 async function wait(predicate,label,timeout=180000){const at=Date.now();let next=at+800;while(!state||!predicate(state)){
  if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
  if(report.initialMemory&&Date.now()-memoryAt>8000){memoryAt=Date.now();const memory={stage:label,...await Promise.race([memoryProbe.read(page),sleep(4000).then(()=>({probeTimeout:true}))])};report.memorySamples??=[];report.memorySamples.push(memory);fs.appendFileSync(path.join(out,prefix+'.log'),'WEB_MEMORY '+JSON.stringify(memory)+'\n');}
  if(Date.now()>next){next=Date.now()+800;await page.keyboard.press('F8');}await sleep(80);
 }return state;}
 async function dump(){const old=sequence;await page.keyboard.press('F8');await wait(()=>sequence>old,'state probe',15000);return state;}
 async function key(k){await page.keyboard.down(k);await sleep(100);await page.keyboard.up(k);await sleep(100);}
 async function shot(name){await dump();report.samples.push(structuredClone(state));report.memorySamples??=[];report.memorySamples.push({stage:name,...await memoryProbe.read(page)});const png=await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});
  check((await sharp(png).stats()).channels.some(c=>c.stdev>20),'nonblank '+name);}
 async function tap(x,y){if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
 async function capture(){await tap(test.width*.5,test.height*.5);await wait(s=>s.pointer.captured,'actual input capture');}
 async function actualFeedback(){
  await dump();const before=state.camera.playerModels.visible;check(before>0,'third-person real player geometry visible');
  let cdp;
  if(test.touch){cdp=await page.context().newCDPSession(page);const [x,y,w,h]=state.touchControls.rects.primary;
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:81,x:(x+w/2)/state.width*test.width,y:(y+h/2)/state.height*test.height}]});
  }else await page.mouse.down();
  await sleep(900);await dump();check(Object.values(state.camera.feedback).some(v=>typeof v==='number'&&Math.abs(v)>.001),'own held real weapon fire produces camera feedback');await shot('own-shot-feedback');
  if(test.touch)await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});else await page.mouse.up();
  if(test.touch){const [x,y,w,h]=state.touchControls.rects.scope;await tap((x+w/2)/state.width*test.width,(y+h/2)/state.height*test.height);}
  else await page.mouse.down({button:'right'});
  await wait(s=>s.reticle.scope&&s.camera.firstPerson,'actual scoped camera');check(state.camera.playerModels.visible===0,'first-person hides every player child StaticModel');await shot('actual-scope');
  if(test.touch){const [x,y,w,h]=state.touchControls.rects.scope;await tap((x+w/2)/state.width*test.width,(y+h/2)/state.height*test.height);}
  else await page.mouse.up({button:'right'});
  await wait(s=>!s.reticle.scope&&!s.camera.firstPerson,'actual scope release');check(state.camera.playerModels.visible===before,'scope release restores original child geometry masks');
 }
 async function naturalEpilogue(){
  const begun=Date.now(),observed=new Set(),lines=new Set(),panels=new Set();report.naturalEpilogue={observations:[],route:'Actual Mission.StartEpilogue after boss ending; no input, clock, stage, HP or queue manipulation during complete playback. Fifth mission has no authored voice recordings.'};
  while(state.story?.naturalEpilogue){
   const detail=state.story.naturalEpilogueDetail;
   if(detail){
    const id=detail.index+':'+detail.kind;
    if(!observed.has(id)){observed.add(id);report.naturalEpilogue.observations.push(structuredClone(detail));check(detail.voicePlayed===0,'fifth mission preserves authored subtitles-only speech '+detail.index);}
    if(detail.kind==='say'&&detail.voice?.text)lines.add(detail.voice.text);
    if(detail.kind==='panel')panels.add(detail.index);
    if(detail.kind==='stamp'&&!report.naturalEpilogue.stamp){report.naturalEpilogue.stamp=true;await shot('natural-stamp');}
   }
   if(Date.now()-begun>180000)throw Error('Natural ending stalled '+JSON.stringify(detail));
   await sleep(600);await dump();
  }
  report.naturalEpilogue.lines=[...lines];report.naturalEpilogue.panelSteps=[...panels];report.naturalEpilogue.durationMs=Date.now()-begun;
  check(lines.size===8&&panels.size===4&&report.naturalEpilogue.stamp,'natural ending plays all eight lines, four panels, and rejection stamp');
  await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'natural ending releases and returns');
 }
 async function leave(){await key('Escape');await key('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active||s.story?.naturalEpilogue,'return or source ending');
  if(state.story?.naturalEpilogue){if(process.env.VOX_QA_NATURAL_EPILOGUE==='1')await naturalEpilogue();else{await key('Escape');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'source ending releases and returns');}}}
 try{
  const identity=await (await fetch(base+'/identity.json')).json();report.build=identity.source_directory;report.manifest=identity.servedManifest;report.identity=identity;
  const manifest=JSON.parse(fs.readFileSync(identity.manifest_path,'utf8'));
  for(const item of manifest.files)assetNames.set(item.uuid+'-'+item.hash+item.ext,item.fs_path??item.uuid);
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow.active,'hangar');
  report.initialMemory=await memoryProbe.install(page);
  await tap(test.width*.5,test.height*.4);await sleep(300);
  await key('F4');await wait(s=>s.loadingFlow?.visible,'story5 loading screen');await shot('loading');
  await wait(s=>s.mode==='trial'&&s.story?.id==='s5'&&!s.loadingFlow.active,'real EnginePit');await capture();await shot('engine-pit');
  check(state.sceneVisible&&state.loadingFlow.warmFrames>=2,'EnginePit presents after actual render warmup');
  await key('Home');await wait(s=>s.story?.boss?.flow==='fight','source FOX assembly',120000);await shot('fox');
  check(state.story.boss.parts>2000&&state.story.boss.feet===4,'actual original FOX has 2227 parts and four native T5 feet');
  if(process.env.VOX_QA_FLOW_ONLY==='1')report.skipped=['Camera feedback/scope route intentionally excluded from this story-flow run; its independent post-update scope report is required for camera acceptance.'];else await actualFeedback();
  if(process.env.VOX_QA_SCOPE_ONLY==='1'){
   check(state.samplePhase==='post-update','scope geometry sampled after actual production PostUpdate');
   await leave();report.gameHttpFailures=report.httpFailures.filter(f=>!f.url.includes('/cached-engine-source/')||!f.url.includes('assets@windows.7z'));
   check(!report.errors.length&&!report.gameHttpFailures.length,'scope route has no Lua, engine, shader, game HTTP or browser errors');report.result='PASS';continue;
  }
  await key('F9');await wait(s=>s.story?.boss?.kneel,'actual weakpoint hit');await shot('kneel');
  check(state.story.boss.nodes[0].broken,'real source foot node permanently breaks');
  await key('F10');await wait(s=>s.story?.boss?.phase===2&&s.story.boss.planes===3&&s.story.enemies===3,'source delayed drills and bomber raid');await shot('raid');
  check(state.story.enemies===3,'second phase spawns three actual drill enemies');
  await key('F12');await wait(s=>s.story?.epilogue?.active&&s.story.epilogue.time>.85,'actual ending image render');await shot('epilogue');
  check(state.story.epilogue.panels===1,'source version-six first comic panel is actually rendered');
  await key('F12');await wait(s=>s.story?.epilogue&&!s.story.epilogue.active,'ending releases UI');
  await key('F11');await wait(s=>s.story?.boss?.cinematic,'real boss death');await shot('ending');
  await page.keyboard.down('Enter');await sleep(1400);await page.keyboard.up('Enter');
  if(process.env.VOX_QA_NATURAL_EPILOGUE==='1')await wait(s=>s.story?.finished,'actual mission completion after Boss cinematic',120000);
  await leave();check(state.performance.arrayBytes===0,'EnginePit return releases terrain texture arrays');
  if(process.env.VOX_QA_NATURAL_EPILOGUE==='1')check(report.naturalEpilogue?.lines?.length===8,'production Mission.StartEpilogue actually ran complete authored ending');
  await key('End');await wait(()=>wingReady,'original feather wing5 vehicle resources');await dump();check(state.parts===84,'source feather vehicle built after model gate');
  await key('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'wing trial');await capture();await key('Home');
  await page.keyboard.down('a');await page.keyboard.down('Space');await sleep(500);await page.keyboard.up('a');await page.keyboard.up('Space');await shot('wing');
  check(state.wing.count===4&&state.wing.state&&Number.isFinite(state.wing.telemetry.airspeed),'real source feather wings and rudders receive actual input and flight telemetry');
  await leave();await key('Delete');await wait(s=>s.mode==='trial'&&s.map==='crater'&&!s.loadingFlow.active,'crater boundary map');await capture();await key('Home');await sleep(500);await shot('boundary');
  check(state.boundary&&state.boundary.walls===4&&state.boundary.ceiling&&state.boundary.enabled,'actual Web crater boundary has walls, ceiling and shader');
  await leave();report.gameHttpFailures=report.httpFailures.filter(f=>!f.url.includes('/cached-engine-source/')||!f.url.includes('assets@windows.7z'));
  check(report.errors.length===0&&report.gameHttpFailures.length===0,'no Lua, engine, shader, game resource HTTP or browser errors');report.result='PASS';
 }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;
  fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));
  if(!report.errors.some(s=>/Aborted\(OOM\)|renderer crashed/i.test(s)))await page.screenshot({path:path.join(out,prefix+'-failure.png'),timeout:10000}).catch(()=>{});throw e;}
 finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await Promise.race([page.close().catch(()=>{}),sleep(5000)]);}
 console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length,httpFailures:report.httpFailures.length}));
}}finally{await Promise.race([browser.close().catch(()=>{}),sleep(5000)]);}
})().catch(e=>{console.error(e);process.exitCode=1;});

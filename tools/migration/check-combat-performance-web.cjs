// One browser, public gameplay inputs, inclusive Lua CPU timings and wall rAF.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4313);
const width=Number(process.env.VOX_QA_WIDTH||1920),height=Number(process.env.VOX_QA_HEIGHT||1080);
const touch=process.env.VOX_QA_TOUCH==='1',hudOnly=process.env.VOX_QA_HUD_ONLY==='1';
const repeatCount=Number(process.env.VOX_QA_MATCH_REPEATS||1);
assert(Number.isInteger(repeatCount)&&repeatCount>=1&&repeatCount<=5,'Match repeats must be 1..5');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function main(){
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa);
 const out=path.join(root,'docs/migration/evidence/combat-performance-'+new Date().toISOString().replace(/[:.]/g,'-'));fs.mkdirSync(out,{recursive:true});
 const report={identity,stages:[],errors:[],profiles:[],startedAt:new Date().toISOString(),boundary:identity.combatProfile?'Single automated desktop Chrome. Inclusive CPU wrappers subtract coroutine suspension and add overhead; wall rAF is uncapped. No mobile or sustained thermal acceptance.':'Single automated desktop Chrome with public input/state probe only; no fine-grained Lua CPU wrappers. Wall rAF is uncapped. No mobile or sustained thermal acceptance.'};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:touch?3:1,...(touch?{isMobile:true,hasTouch:true}:{})});let state,revision=0,phase='boot';
 report.viewport={width,height,touch};
 page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,'console.log'),line+'\n');
  const i=line.indexOf('OUTGAME_STATE ');if(i>=0){try{state=JSON.parse(line.slice(i+14));revision++;}catch{}}
  const p=line.indexOf('COMBAT_PROFILE ');if(p>=0){try{report.profiles.push({at:Date.now(),phase,...JSON.parse(line.slice(p+15))});}catch{}}
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
 });page.on('pageerror',e=>report.errors.push(String(e)));
 page.on('crash',()=>{report.crashedAt=new Date().toISOString()});
 browser.on('disconnected',()=>{if(!report.closing)report.disconnectedAt=new Date().toISOString()});
 await page.addInitScript(({measureGL})=>{
  window.__combatFrames={phase:'boot',frames:[],gl:{},slowGL:[]};let prev=performance.now();
  function tick(now){window.__combatFrames.frames.push({at:now,ms:now-prev,phase:window.__combatFrames.phase});prev=now;requestAnimationFrame(tick)}requestAnimationFrame(tick);
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
 async function tap(x,y){if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y)}
 async function click(text){await dump();const w=state.widgets.find(w=>w.text===text&&!w.disabled);assert(w,'Control '+text);const r=w.rect;await tap((r[0]+r[2]/2)/state.width*width,(r[1]+r[3]/2)/state.height*height);await sleep(200)}
 async function mark(name){phase=name;await page.evaluate(name=>{if(window.__combatFrames)window.__combatFrames.phase=name},name);console.log(name)}
 async function begin(name){await mark(name);await cdp.send('Profiler.start')}
 async function end(name){const p=await cdp.send('Profiler.stop');fs.writeFileSync(path.join(out,name+'.cpuprofile'),JSON.stringify(p.profile));await dump();report.stages.push({name,at:Date.now(),state:structuredClone(state)});fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));}
 async function live(name){await begin(name);await tap(width/2,height/2);await sleep(1500);await page.keyboard.down('w');await sleep(2500);await page.keyboard.up('w');await page.mouse.down();await sleep(3500);await page.mouse.up();await sleep(3500);await end(name);await page.screenshot({path:path.join(out,name+'.png')});}
 try{
  await begin('boot');await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'hall');await end('boot');
  report.lifecycleChecks=[];let previousCaptureSequence=0;
  for(let round=0;round<repeatCount;round++){
  const prefix=round?'repeat'+round+'-':'';
  if((await dump()).tab!=='battle')await click('出战');await wait(s=>s.tab==='battle','mode');await click('歼灭战');await begin(prefix+'match-load');await click('开始匹配');await wait(s=>s.mode==='trial'&&s.battle&&!s.loadingFlow?.active,'match');await end(prefix+'match-load');
  await key('Space');await wait(s=>!s.intro?.active,'intro skip');
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
  if(process.env.VOX_QA_SCOPE_CHECK==='1'){
   report.scopeChecks??=[];
   async function scopeCheck(name,expected){await sleep(350);await dump();const actual=state.reticle?.scope;report.scopeChecks.push({name,expected,actual});assert.equal(actual,expected,name)}
   await page.mouse.click(960,540,{button:'right',delay:50});await scopeCheck('short click enters scope',true);await page.screenshot({path:path.join(out,'scope.png')});
   await page.mouse.click(960,540,{button:'right',delay:50});await scopeCheck('short click exits scope',false);
   await page.mouse.down({button:'right'});await sleep(500);await scopeCheck('hold enters scope',true);await page.mouse.up({button:'right'});await scopeCheck('long release exits scope',false);
  }
  await key('Escape');await wait(s=>!s.pointer?.captured,'release');await page.screenshot({path:path.join(out,prefix+'match-paused.png')});await begin(prefix+'match-return');await click('退出对局');await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'return');await sleep(2000);await end(prefix+'match-return');
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
  if(process.env.VOX_QA_SCOPE==='match'){report.result='MEASURED';return}
  if((await dump()).tab!=='battle')await click('出战');await click('剧情模式');await wait(s=>s.story?.ready,'story page');
  const level=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Outgame.json'))).levels[Number(process.env.VOX_QA_STORY_LEVEL||1)-1];await click(level.no+'  '+level.name);await begin('story-load');await click('开始任务');await wait(s=>s.mode==='trial'&&s.story&&!s.loadingFlow?.active,'story');await end('story-load');
  await live('story-live');await key('Escape');await wait(s=>!s.pointer?.captured,'story release');
  await begin('story-return');await key('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'story return');await sleep(2000);await end('story-return');
  report.result='MEASURED';
 }catch(e){report.result='FAIL';report.failure=e.stack;await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{})}
 finally{const measurements=await page.evaluate(()=>window.__combatFrames).catch(()=>({frames:[]}));report.frames=measurements.frames;report.gl=measurements.gl;report.slowGL=measurements.slowGL;report.final=state;report.finishedAt=new Date().toISOString();report.closing=true;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));await browser.close();console.log(out)}
 if(report.result==='FAIL')process.exitCode=1;
}
main().catch(e=>{console.error(e);process.exitCode=1});

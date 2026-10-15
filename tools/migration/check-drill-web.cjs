const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(c.name))){
 const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{hasTouch:true,isMobile:true}:{})});
 const prefix='drill-web-'+test.name,report={build:prepared.source_directory,manifest:path.basename(prepared.manifest_path),viewport:test,checks:[],errors:[],httpFailures:[],samples:[]};
 let state,seq=0,ready='';fs.writeFileSync(path.join(out,prefix+'.log'),'');
 page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),line+'\n');const i=line.indexOf('OUTGAME_STATE ');
  if(i>=0){try{state=JSON.parse(line.slice(i+14));seq++;}catch(e){if(line.trimEnd().endsWith('}'))report.errors.push(e.message);}}
  if(line.includes('[DrillQA] Original prefab ready '))ready=line.split('[DrillQA] Original prefab ready ')[1].trim();
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
 });page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
 const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
 async function wait(fn,label,timeout=150000){const at=Date.now();let next=at+600;while(!state||!fn(state)){
  if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
  if(Date.now()>next){next=Date.now()+600;await page.keyboard.press('F8');}await sleep(40);
 }return state;}
 async function dump(){const old=seq;await page.keyboard.press('F8');await wait(()=>seq>old,'dump',15000);return state;}
 async function key(k){await page.keyboard.down(k);await sleep(80);await page.keyboard.up(k);await sleep(80);}
 async function shot(name){await dump();report.samples.push(structuredClone(state));const bytes=await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});check((await sharp(bytes).stats()).channels.some(c=>c.stdev>20),'nonblank '+name);}
 async function speedPixels(variant){
  await key('PageUp');await sleep(600);await shot(variant+'-rush');
  await key('PageDown');await sleep(300);await page.screenshot({path:path.join(out,prefix+'-'+variant+'-rush-base.png')});
  const a=await sharp(path.join(out,prefix+'-'+variant+'-rush.png')).removeAlpha().raw().toBuffer({resolveWithObject:true});
  const b=await sharp(path.join(out,prefix+'-'+variant+'-rush-base.png')).removeAlpha().raw().toBuffer();
  let changed=0,white=0;const deltas=[];
  for(let i=0;i<b.length;i+=3){const delta=Math.max(a.data[i]-b[i],a.data[i+1]-b[i+1],a.data[i+2]-b[i+2]);
   if(delta>8){changed++;deltas.push(delta);if(a.data[i]>250&&a.data[i+1]>250&&a.data[i+2]>250)white++;}}
  deltas.sort((x,y)=>x-y);const pixels=a.info.width*a.info.height;
  report.pixelChecks=report.pixelChecks||[];report.pixelChecks.push({variant,changed,pixels,whiteFraction:white/changed,p95:deltas[Math.floor(deltas.length*.95)]});
  check(changed>pixels*.001&&changed<pixels*.35,'speed shader changes a bounded set of canvas pixels');
  check(white/changed<.3,'speed streaks preserve translucency without turning into solid white rays');
  await key('PageDown');await key('PageUp');
 }
 let cdp;
 async function fire(pressed){
  if(!test.touch){if(pressed)await page.mouse.down();else await page.mouse.up();return;}
  cdp=cdp||await page.context().newCDPSession(page);
  const [x,y,w,h]=state.touchRects.fire,canvas=await page.locator('canvas').boundingBox();
  await cdp.send('Input.dispatchTouchEvent',{type:pressed?'touchStart':'touchEnd',touchPoints:pressed?[{x:canvas.x+(x+w/2)/state.width*canvas.width,y:canvas.y+(y+h/2)/state.height*canvas.height,id:4}]:[]});
 }
 try{
  await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&!s.loadingFlow.active,'hall');
  for(const variant of ['tianyuan','fuyuan']){
   ready='';await key('Home');await wait(()=>ready===variant,'source prefab gate');await dump();
   check(state.parts>50,'original '+variant+' prefab downloaded and assembled');
   await key('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'trial');
   if(test.touch)await page.touchscreen.tap(test.width*.5,test.height*.5);else await page.mouse.click(test.width*.5,test.height*.5);
   await wait(s=>s.pointer.captured,'capture');await key('End');await dump();
   check(state.drill.kind===variant+'Drill','actual source drill weapon selected');
   const hits=state.weapons.hits,health=state.drill.targetHealth;
   await fire(true);await sleep(900);await dump();
   check(state.drill.held&&state.drill.charge>.4,'held '+(test.touch?'touch fire':'mouse')+' charges drill');
   check(state.reticle.fire.word==='蓄力'&&state.reticle.fire.sub==='松开左键突进','source reticle charge state and subtitle');await shot(variant+'-charge');
   await sleep(800);await fire(false);await sleep(90);await dump();await speedPixels(variant);
   check(state.drill.visible&&state.drill.rush>.01,'source streak shader draws during dash');
   await wait(s=>s.weapons.hits>hits,'real car hit',15000);await dump();
   check(state.drill.targetHealth<health,'swept drill damages actual target car');
   if(variant==='fuyuan'){
    await wait(s=>s.drill.phase==='latched','latch',8000);check(state.drill.nativeKinematic&&state.reticle.fire.word==='咬住','native latch and original HUD state');await shot(variant+'-latched');
   }else await shot(variant+'-grind');
   await wait(s=>!s.drill.phase,'attack finish',15000);await dump();
   check(!state.drill.nativeKinematic&&state.drill.cool>0,'finish restores dynamic vehicle and shared cooldown');
   check(state.drill.queryCasts>0&&state.drill.viewports===2,'reused volumetric sweeps and one speed overlay viewport');
   await key('Escape');await dump();check(!state.drill.visible&&!state.drill.held&&!state.drill.phase,'pause clears speed and attack state');
   await key('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'return');check(report.errors.length===0,'no runtime or shader errors after '+variant);
  }
  report.result='PASS';
 }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await page.screenshot({path:path.join(out,prefix+'-failure.png')}).catch(()=>{});throw e;}
 finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
 console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));
}}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

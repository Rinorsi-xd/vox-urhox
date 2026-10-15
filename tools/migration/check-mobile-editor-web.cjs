const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4269),sleep=ms=>new Promise(r=>setTimeout(r,ms));
const cases=[{name:'20-9',width:840,height:378,dpr:3},{name:'16-9',width:800,height:450,dpr:2}];
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa);
 const source=JSON.parse(fs.readFileSync(path.join(out,'source-mobile-editor.json')));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE===c.name)){
  let state,revision=0;const prefix='mobile-editor-web-'+test.name;
  const report={identity,viewport:test,result:'RUNNING',checks:[],errors:[],httpFailures:[],samples:[]};
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,hasTouch:true,isMobile:true});
  fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',m=>{const t=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),t+'\n');const i=t.indexOf('OUTGAME_STATE ');
   if(i>=0){try{state=JSON.parse(t.slice(i+14));revision++;}catch(e){if(t.trimEnd().endsWith('}'))report.errors.push(e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(t))report.errors.push(t);
  });page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
  await page.addInitScript(()=>{window.voxTouchEvents=[];for(const type of ['touchstart','touchend','touchcancel'])document.addEventListener(type,e=>{window.voxTouchEvents.push({type,time:performance.now(),points:Array.from(e.changedTouches,t=>({id:t.identifier,x:t.clientX,y:t.clientY}))});},true);});
  async function key(name){await page.keyboard.down(name);await sleep(90);await page.keyboard.up(name);await sleep(90);}
  async function wait(fn,label,timeout=180000){const at=Date.now();let next=at+800;while(!state||!fn(state)){
   if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
   if(Date.now()>next){next=Date.now()+800;await key('F8');}await sleep(60);
  }return state;}
  async function dump(){const prev=revision;await key('F8');await wait(()=>revision>prev,'fresh probe',15000);return state;}
  async function point(r){const c=await page.locator('canvas').boundingBox();return {x:c.x+(r[0]+r[2]/2)/state.width*c.width,y:c.y+(r[1]+r[3]/2)/state.height*c.height};}
  async function tapRect(r){const p=await point(r);await page.touchscreen.tap(p.x,p.y);await sleep(220);await dump();}
  async function tap(id){await dump();assert.ok(state.touchControls.rects[id],id);await tapRect(state.touchControls.rects[id]);}
  async function text(label,kind){await dump();const item=(Array.isArray(state.widgets)?state.widgets:[]).find(w=>w.text===label&&(!kind||w.kind===kind));assert.ok(item,'visible '+label);await tapRect(item.rect);}
  async function shot(name){await dump();report.samples.push(structuredClone(state));const bytes=await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});check((await sharp(bytes).stats()).channels.some(c=>c.stdev>20),'nonblank '+name);}
  const cdp=await page.context().newCDPSession(page),contacts=new Map();
  async function touch(type,id,p){let points;if(type==='touchCancel'){contacts.clear();points=[];}else if(type==='touchEnd'){points=contacts.has(id)?[contacts.get(id)]:[];contacts.delete(id);}else{contacts.set(id,{id,...p});points=[...contacts.values()];}await cdp.send('Input.dispatchTouchEvent',{type,touchPoints:points});}
  try{
   const at=Date.now();await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'actionable hall');report.coldHallMs=Date.now()-at;
   await key('e');await wait(s=>s.build&&s.touchControls?.editor&&!s.loadingFlow?.active,'mobile construction');await dump();
   check(state.touchControls.prefs.build==='tap'&&!state.touchControls.rects.primary,'original default tap composition');
   const refs=source.layouts.find(v=>v.width===test.width&&v.height===test.height).states.tap;
   for(const ref of refs.filter(r=>['me-rotate','me-mirror','me-pick','up','down'].includes(r.action))){const r=state.touchControls.rects[ref.action];const actual=[r[0]/state.width*test.width,r[1]/state.height*test.height,r[2]/state.width*test.width,r[3]/state.height*test.height];check(actual.every((v,i)=>Math.abs(v-ref.rect[i])<=1),'frozen rail rectangle '+ref.action);}
   await shot('tap');await tap('me-tools');check(state.touchControls.editor.sheet==='tools','tools sheet opens');await text('上色');check(state.buildInput.tool==='paint','source paint tool selects actual editor');
   await tap('me-paint');check(state.touchControls.editor.sheet==='paint','source palette opens');await text('装饰色');check(state.buildInput.channel==='accent','paint channel changes');await shot('paint');
   await tap('me-tools');await text('建造','row');check(state.buildInput.tool==='build','return to actual build tool');
   await tap('me-more');check(state.touchControls.editor.sheet==='more','more sheet opens');await text('准星');check(state.touchControls.prefs.build==='aim'&&!!state.touchControls.rects.primary,'aim mode exposes original action button');await text('点哪放哪');check(!state.touchControls.rects.primary,'tap mode hides centre action');await shot('more');await tap('me-more');
   const targets=state.buildTargets.filter(p=>p.x>.36&&p.x<.73&&p.y>.2&&p.y<.7).sort((a,b)=>b.y-a.y);assert.ok(targets.length,'visible vehicle targets');const canvas=await page.locator('canvas').boundingBox();
   const count=state.parts;let p;report.placementAttempts=[];
   for(const target of targets){
    p={x:canvas.x+target.x*canvas.width,y:canvas.y+target.y*canvas.height};
    await touch('touchStart',21,p);await sleep(200);await touch('touchEnd',21);await sleep(400);await dump();
    report.placementAttempts.push({target,preview:state.buildInput.preview,parts:state.parts});if(state.parts>count)break;
   }
   check(state.parts>count,'finger tap adds an actual part');
   const added=state.parts;await touch('touchStart',22,p);await sleep(510);await touch('touchEnd',22);await sleep(200);await dump();check(state.parts<added,'450ms long press removes an actual part without release placement');
   const after=state.parts;await touch('touchStart',23,p);await sleep(40);await touch('touchCancel');await sleep(200);await dump();
   report.cancel={before:after,after:state.parts,events:await page.evaluate(()=>window.voxTouchEvents.slice(-4))};
   if(state.parts===after)check(true,'cancellation preserves actual blueprint');else report.unresolved=['browser touchcancel places a part: engine exposes TouchEnd without cancellation metadata'];
   const beforeDrag=state.parts,forward=state.camera.forward.slice();await touch('touchStart',24,p);await sleep(40);await touch('touchMove',24,{x:p.x+30,y:p.y+8});await sleep(150);await touch('touchEnd',24);await sleep(200);await dump();check(state.parts===beforeDrag&&state.camera.forward.some((v,i)=>Math.abs(v-forward[i])>.001),'drag changes camera without editing');
   await tap('me-stats');check(state.touchControls.editor.statsOpen,'original statistics toggles');await shot('stats');await tap('me-stats');
   await tap('me-back');await wait(s=>!s.build&&s.tab==='hangar'&&!s.loadingFlow?.active,'actual hall return');check(report.errors.length===0,'no game errors');report.result=report.unresolved?.length?'FAIL':'PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await page.screenshot({path:path.join(out,prefix+'-failure.png')}).catch(()=>{});}
  finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));if(report.result!=='PASS')process.exitCode=1;
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

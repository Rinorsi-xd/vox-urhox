const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4267),sleep=ms=>new Promise(r=>setTimeout(r,ms));
const cases=[{name:'20-9',width:840,height:378,dpr:3},{name:'16-9',width:800,height:450,dpr:2}];
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa);
 const source=JSON.parse(fs.readFileSync(path.join(out,'source-touch.json')));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE===c.name)){
  let state,revision=0;const prefix='touch-drive-web-'+test.name;
  const report={identity,viewport:test,result:'RUNNING',checks:[],errors:[],httpFailures:[],samples:[]};
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,hasTouch:true,isMobile:true});
  fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',m=>{const t=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),t+'\n');const i=t.indexOf('OUTGAME_STATE ');
   if(i>=0){try{state=JSON.parse(t.slice(i+14));revision++;}catch(e){if(t.trimEnd().endsWith('}'))report.errors.push(e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(t))report.errors.push(t);
  });page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
  async function key(name){await page.keyboard.down(name);await sleep(100);await page.keyboard.up(name);await sleep(100);}
  async function wait(fn,label,timeout=180000){const at=Date.now();let next=at+800;while(!state||!fn(state)){
   if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
   if(Date.now()>next){next=Date.now()+800;await key('F8');}await sleep(60);
  }return state;}
  async function dump(){const prev=revision;await key('F8');await wait(()=>revision>prev,'fresh probe',15000);return state;}
  async function point(r){const c=await page.locator('canvas').boundingBox();return {x:c.x+(r[0]+r[2]/2)/state.width*c.width,y:c.y+(r[1]+r[3]/2)/state.height*c.height};}
  async function tap(id){await dump();const p=await point(state.touchControls.rects[id]);await page.touchscreen.tap(p.x,p.y);await sleep(300);await dump();}
  async function shot(name){await dump();report.samples.push(structuredClone(state));const bytes=await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});check((await sharp(bytes).stats()).channels.some(c=>c.stdev>20),'rendered nonblank '+name);}
  const cdp=await page.context().newCDPSession(page),contacts=new Map();
  async function touch(type,id,p){let points;
   if(type==='touchCancel'){contacts.clear();points=[];}
   else if(type==='touchEnd'){points=contacts.has(id)?[contacts.get(id)]:[];contacts.delete(id);}
   else{contacts.set(id,{id,...p});points=[...contacts.values()];}
   await cdp.send('Input.dispatchTouchEvent',{type,touchPoints:points});await sleep(120);}
  try{
   const at=Date.now();await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'actionable hall');report.coldHallMs=Date.now()-at;
   await key('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow?.active,'production trial');await dump();
   check(!!state.touchControls,'source drive overlay attached');
   const refs=source.layouts.find(v=>v.width===test.width&&v.height===test.height).modes.drive;
   for(const ref of refs){const r=state.touchControls.rects[ref.action==='move'?'stick':ref.action];const actual=[r[0]/state.width*test.width,r[1]/state.height*test.height,r[2]/state.width*test.width,r[3]/state.height*test.height];check(actual.every((v,i)=>Math.abs(v-ref.rect[i])<=1),'frozen CSS rectangle '+ref.action);}
   await shot('idle');const a={x:test.width*.27,y:test.height*.64},fire=await point(state.touchControls.rects.primary);
   await touch('touchStart',1,a);await dump();const center=await point(state.touchControls.rects.stick);
   check(Math.abs(center.x-a.x)<1&&Math.abs(center.y-a.y)<1,'actual left-zone contact positions floating stick');
   await touch('touchMove',1,{x:a.x,y:a.y-28});await touch('touchStart',2,fire);const yaw=state.camera.yaw;
   await touch('touchMove',2,{x:fire.x-22,y:fire.y-6});await dump();
   check(state.touchControls.contacts===2&&state.pointer.fire,'independent move and held fire contacts');check(Math.abs(state.camera.yaw-yaw)>1,'held fire drag aims');await shot('held');
   await touch('touchEnd',2);await dump();check(state.touchControls.contacts===1&&!state.pointer.fire,'fire release preserves moving contact');
   await touch('touchCancel');await dump();check(state.touchControls.contacts===0,'cancel clears all production contacts');
   const b={x:test.width*.55,y:test.height*.4},c={x:test.width*.72,y:test.height*.4},distance=state.camera.dist;
   await touch('touchStart',3,b);await touch('touchStart',4,c);await touch('touchMove',4,{x:c.x+30,y:c.y});await dump();
   check(state.camera.dist<distance&&state.camera.dist>distance*.5,'source two-contact pinch remains smooth');await touch('touchCancel');
   await tap('scope');check(state.reticle.scope,'scope toggles via actual touch release');await tap('menu');
   check(state.touchControls.menu&&!state.pointer.fire&&!state.reticle.scope,'menu releases fire and scope');await shot('menu');
   await tap('option-menu');check(!state.touchControls.menu,'continue restores touch drive');await tap('menu');await tap('option-exit');
   await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'real hall return');check(report.errors.length===0,'no game errors');report.result='PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await page.screenshot({path:path.join(out,prefix+'-failure.png')}).catch(()=>{});}
  finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));if(report.result!=='PASS')throw Error(report.failure);
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

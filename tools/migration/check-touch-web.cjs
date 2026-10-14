const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json'))),source=JSON.parse(fs.readFileSync(path.join(out,'source-touch.json')));
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'phone-16-9',width:800,height:450,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(c.name))){
 const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{hasTouch:true,isMobile:true}:{})});
 const report={build:prepared.source_directory,manifest:path.basename(prepared.manifest_path),viewport:test,checks:[],errors:[],httpFailures:[],samples:[]};let state,seq=0;
 const prefix='touch-web-'+test.name;fs.writeFileSync(path.join(out,prefix+'.log'),'');
 page.on('console',m=>{const text=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),text+'\n');const i=text.indexOf('OUTGAME_STATE ');if(i>=0){try{state=JSON.parse(text.slice(i+14));seq++;}catch(e){if(text.trimEnd().endsWith('}'))report.errors.push(e.message);}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))report.errors.push(text);});
 page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
 const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
 async function key(name){await page.keyboard.down(name);await sleep(80);await page.keyboard.up(name);await sleep(80);}
 async function wait(fn,label,timeout=150000){const at=Date.now();let next=at+600;while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));if(Date.now()>next){next=Date.now()+600;await key('F8');}await sleep(40);}return state;}
 async function dump(){const previous=seq;await key('F8');await wait(()=>seq>previous,'state',15000);return state;}
 async function xy(rect){const [x,y,w,h]=rect,c=await page.locator('canvas').boundingBox();return {x:c.x+(x+w/2)/state.width*c.width,y:c.y+(y+h/2)/state.height*c.height};}
 async function tapRect(rect){const p=await xy(rect);if(test.touch)await page.touchscreen.tap(p.x,p.y);else await page.mouse.click(p.x,p.y);await sleep(180);await dump();}
 async function tap(id){
  for(let attempt=0;attempt<12;attempt++){
   await dump();assert.ok(state.touchControls?.rects[id],'live source control '+id);const rect=state.touchControls.rects[id],p=await xy(rect);
   if(p.y>72&&p.y<test.height-10||id==='menu'){
    const before={menu:state.touchControls.menu,expanded:state.touchControls.expanded};
    await tapRect(rect);
    const after=state.touchControls;
    if(!after||id==='menu'&&after.menu!==before.menu||id==='option-extra'&&after.expanded!==before.expanded||id!=='menu'&&id!=='option-extra'&&!after.menu)return;
    await sleep(500);continue;
   }
   const desired=(62+test.height-8)/2-p.y,limit=(test.height-90)*.5;
   const delta=Math.max(-limit,Math.min(limit,desired));
   const x=test.width*.5,startY=delta>0?test.height*.35:test.height*.78,endY=Math.max(70,Math.min(test.height-16,startY+delta));
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:9,x,y:startY}]});
   for(let i=1;i<=12;i++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:9,x,y:startY+(endY-startY)*i/12}]});await sleep(20);}
   await sleep(180);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await sleep(600);
  }
  throw Error('Offscreen source control '+id);
 }
 async function command(text){await dump();const w=state.widgets.find(w=>w.text===text);assert.ok(w,'source command '+text);await tapRect(w.rect);}
 async function shot(name){await dump();report.samples.push(structuredClone(state));const data=await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});check((await sharp(data).stats()).channels.some(c=>c.stdev>20),'nonblank '+name);}
 const cdp=await page.context().newCDPSession(page);const contacts=new Map();
 async function touch(type,id,p){
  let points;
  if(type==='touchStart'||type==='touchMove'){contacts.set(id,{id,...p});points=[...contacts.values()];}
  else if(type==='touchCancel'){contacts.clear();points=[];}
  else{points=contacts.has(id)?[contacts.get(id)]:[];contacts.delete(id);}
  // CDP touchEnd lists the contacts ending, unlike touchStart/touchMove.
  await cdp.send('Input.dispatchTouchEvent',{type,touchPoints:points});await sleep(90);
 }
 function compare(mode){const golden=source.layouts.find(v=>v.width===test.width&&v.height===test.height).modes[mode];
  for(const item of golden){const r=state.touchControls.rects[item.action==='move'?'stick':item.action];assert.ok(r,'source action '+item.action);const actual=[r[0]/state.width*test.width,r[1]/state.height*test.height,r[2]/state.width*test.width,r[3]/state.height*test.height];check(actual.every((x,i)=>Math.abs(x-item.rect[i])<=1),'source computed rectangle '+mode+' '+item.action);}
 }
 try{
  await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&!s.loadingFlow.active,'hall');
  await command('改装');await wait(s=>s.build,'source construction');await dump();
  check(state.buildInput.mode==='fp','source first-person construction on this platform');
  if(!test.touch){
   check(!state.touchControls,'PC does not receive touch overlay');await page.mouse.click(test.width*.5,test.height*.5);await wait(s=>s.buildInput.captured,'PC lock');
   const parts=state.parts,before=state.camera.position;await page.keyboard.down('w');await sleep(500);await page.keyboard.up('w');await dump();check(state.camera.position.some((v,i)=>Math.abs(v-before[i])>.1),'PC manual free camera');
   await key('Escape');await dump();check(!state.buildInput.captured&&state.parts===parts,'PC release does not edit blueprint');await shot('build');await command('机库');
  }else{
   check(!!state.touchControls,'source touch overlay attached');compare('edit');await shot('build');
   const parts=state.parts,p=await xy(state.touchControls.rects.stick),look={x:test.width*.55,y:test.height*.46};
   await touch('touchStart',1,p);await touch('touchMove',1,{x:p.x+24,y:p.y-24});await touch('touchStart',2,look);await dump();
   check(state.touchControls.contacts===2&&state.buildInput.captured,'two actual contacts own camera controls');const before=state.camera.position;
   await touch('touchMove',2,{x:look.x+35,y:look.y+10});await sleep(400);await dump();check(state.camera.position.some((v,i)=>Math.abs(v-before[i])>.05),'analog stick moves actual first-person camera');
   check(state.parts===parts,'playfield look never places a part');await shot('build-held');await touch('touchCancel');await dump();check(state.touchControls.contacts===0,'browser cancellation retires owned contacts');
   await tap('menu');check(state.touchControls.menu,'touch menu opens');await shot('build-menu');
   await tap('option-extra');check(state.touchControls.expanded&&state.touchControls.menu,'source extra disclosure expands without closing menu');await shot('build-extra');
   await tap('option-tool-erase');check(!state.touchControls.menu&&state.buildInput.tool==='erase','menu editor action closes and applies');
   await tap('menu');await tap('option-focus');await sleep(600);await dump();check(!!state.buildSelection.hit,'source focus traces actual car');const erased=state.parts;await tap('primary');check(state.parts<erased,'center touch primary deletes an actual part');
   await tap('menu');await tap('option-undo');check(state.parts===erased,'touch undo restores actual part');
   const slot=state.buildInput.slot;await tap('slot-next');check(state.buildInput.slot!==slot,'touch next part selects real hotbar slot');
   await tap('menu');await tap('option-inventory');await wait(s=>s.inventory,'source inventory');check(state.touchControls.blocked,'inventory blocks touch gameplay');await key('Escape');await wait(s=>!s.inventory,'close inventory');
   await tap('menu');await tap('option-test');
  }
  if(!test.touch){await wait(s=>s.tab==='hangar'&&!s.loadingFlow.active,'hall return');await key('t');}
  await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'trial');await dump();
  if(!test.touch){await page.mouse.click(test.width*.5,test.height*.5);await wait(s=>s.pointer.captured,'PC trial capture');await key('Escape');await shot('trial');await key('t');}
  else{
   compare('drive');await shot('drive');const fire=await xy(state.touchControls.rects.primary),stick=await xy(state.touchControls.rects.stick),before=state.camera.yaw;
   await touch('touchStart',1,stick);await touch('touchMove',1,{x:stick.x,y:stick.y-25});await touch('touchStart',2,fire);await touch('touchMove',2,{x:fire.x-22,y:fire.y-6});await dump();
   check(state.touchControls.contacts===2&&state.pointer.fire,'stick and fire coexist');check(Math.abs(state.camera.yaw-before)>1,'primary drag aims while firing');await shot('drive-held');
   await touch('touchEnd',2);await dump();check(state.touchControls.contacts===1&&!state.pointer.fire,'fire release preserves stick');await touch('touchEnd',1);
   const a={x:test.width*.4,y:test.height*.48},b={x:test.width*.58,y:test.height*.48},distance=state.camera.dist;
   await touch('touchStart',3,a);await touch('touchStart',4,b);await touch('touchMove',4,{x:b.x+35,y:b.y});await dump();check(state.camera.dist<distance&&state.camera.dist>distance*.5,'source pinch changes distance smoothly and in correct direction');
   await touch('touchCancel');await tap('scope');check(state.reticle.scope,'scope toggles on release');
   await tap('menu');check(state.touchControls.menu&&!state.pointer.captured&&!state.pointer.fire&&!state.reticle.scope,'menu resets scope and all firing input');await shot('drive-menu');
   await tap('option-aux-strafe-left');check(state.touchControls.aux==='strafe-left'&&!state.touchControls.menu,'source auxiliary assignment');
   await tap('menu');await tap('option-exit');
  }
  await wait(s=>s.tab==='hangar'&&!s.loadingFlow.active,'final hall');check(report.errors.length===0,'no unexpected Lua or shader errors');report.result='PASS';
 }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await page.screenshot({path:path.join(out,prefix+'-failure.png')}).catch(()=>{});throw e;}
 finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
 console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));
}}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

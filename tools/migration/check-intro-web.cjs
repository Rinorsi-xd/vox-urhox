// Real UI entry and signature flow. No Lua state or gameplay input is injected.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const port=Number(process.env.VOX_QA_PORT||4254),base='http://127.0.0.1:'+port;
const tag=process.env.VOX_INTRO_WEB_TAG||new Date().toISOString().replace(/[:.]/g,'-');
const comicPlayback=process.env.VOX_INTRO_CAPTURE_COMIC==='1';
const memoryProbe=process.env.VOX_INTRO_MEMORY==='1'?require('./web-memory-probe.cjs'):null;
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const cases=[{name:'pc',width:1920,height:1080},{name:'landscape-20-9',width:840,height:378},{name:'flat-wide',width:1605,height:388}];
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa,'Server must enable read-only QA probe');
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(c.name))){
  const prefix='intro-web-'+test.name+'-'+tag,log=path.join(out,prefix+'.log');fs.writeFileSync(log,'');
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:1});
  let state,revision=0;const report={result:'RUNNING',baseline:identity.identity?.sourceCommit,build:identity.source_directory,
   identity,viewport:[test.width,test.height],checks:[],errors:[],samples:[],startedAt:new Date().toISOString()};
  if(memoryProbe)report.memory={diagnostic:true,method:'Read-only heap/VFS checkpoints; filesystem scan may take up to 500 ms and workers up to 750 ms. Not an uninstrumented performance run.',samples:[],oom:[]};
  page.on('console',message=>{
   const text=message.text();fs.appendFileSync(log,text+'\n');const index=text.indexOf('OUTGAME_STATE ');
   if(index>=0){try{state=JSON.parse(text.slice(index+14));revision++;if(state.mode==='opening')report.samples.push({at:Date.now(),stage:state.stage,shot:state.shot,age:state.age,voice:state.voice,performance:state.performance});}catch(e){report.errors.push('Probe parse: '+e.message);}}
   if(memoryProbe&&text.startsWith('WASM_OOM ')){try{report.memory.oom.push({at:Date.now(),...JSON.parse(text.slice(9))});}catch(e){report.memory.oom.push({at:Date.now(),raw:text,parseError:e.message});}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text)||memoryProbe&&text.startsWith('WASM_OOM '))report.errors.push(text);
  });
  page.on('pageerror',e=>report.errors.push(e.message));
  page.on('requestfailed',r=>{if(r.failure()?.errorText!=='net::ERR_ABORTED')report.errors.push(r.url()+' '+r.failure()?.errorText);});
  function check(condition,label){assert.ok(condition,label);report.checks.push(label);}
  async function wait(predicate,label,timeout=240000){const start=Date.now();let nextDump=start+1000;while(!state||!predicate(state)){
   if(state?.mode==='opening'&&state.failed)throw Error('Opening failed: '+state.error);
   if(report.errors.length)throw Error(report.errors.join('\n'));
   if(Date.now()-start>timeout)throw Error('Timeout '+label);
   if(Date.now()>nextDump){nextDump=Date.now()+1000;await page.keyboard.press('F8');}await sleep(100);
  }return state;}
  async function dump(){const previous=revision;await page.keyboard.press('F8',{delay:100});await wait(()=>revision>previous,'probe response',15000);return state;}
  async function point(r,fx=.5,fy=.5){const canvas=await page.locator('canvas').boundingBox();assert.ok(canvas,'Actual runtime canvas');return {x:canvas.x+(r.x+r.w*fx)/state.width*canvas.width,y:canvas.y+(r.y+r.h*fy)/state.height*canvas.height};}
  async function clickRect(r){const p=await point(r);await page.mouse.click(p.x,p.y);await sleep(180);}
  async function openingButton(id){await dump();const b=state.page?.buttons?.find(b=>b.id===id);assert.ok(b,'Actual opening '+id+' button');await clickRect(b);}
  async function screenshot(name){await page.screenshot({path:path.join(out,prefix+'-'+name+'.png'),timeout:15000});}
  async function memoryPoint(label,install=false){
   if(!memoryProbe)return;
   const started=Date.now();let timer;
   try{
    const data=await Promise.race([install?memoryProbe.install(page):memoryProbe.read(page),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Memory checkpoint timed out')),2000);})]);
    report.memory.samples.push({label,at:started,elapsedMs:Date.now()-started,mode:state?.mode,shot:state?.shot,tutorial:state?.tutorial,...data});
   }catch(e){report.memory.samples.push({label,at:started,elapsedMs:Date.now()-started,unavailable:e.message});}
   finally{clearTimeout(timer);}
  }
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active&&!s.loading?.busy,'actual actionable hall');await sleep(500);await dump();
   await memoryPoint('hall-ready',true);
   const entry=state.widgets.find(w=>w.text==='开场动画'&&!w.disabled);assert.ok(entry,'Actual opening navigation');
   const [x,y,w,h]=entry.rect;await clickRect({x,y,w,h});await wait(s=>s.mode==='opening','opening owns UI');
   await wait(s=>s.ready,'opening downloads, audio decode and actual scene ready');await screenshot('boot');
   await memoryPoint('opening-ready');
   await page.mouse.click(test.width*.5,test.height*.65);await wait(s=>s.stage==='ad','real user gesture starts opening');
   if(comicPlayback){
    const captured=new Set(),deadline=Date.now()+120000;
    while(Date.now()<deadline){
     await dump();
     if(['prosper','order','leave'].includes(state.shot)&&state.age>.32&&!captured.has(state.shot)){
      await screenshot('comic-'+state.shot);captured.add(state.shot);
     }
     if(captured.has('leave'))break;
     if(state.shot==='no')throw Error('Natural comic shot passed without all three captures');
     await sleep(130);
    }
    for(const id of ['prosper','order','leave'])check(captured.has(id),'Natural unskipped comic '+id+' rendered');
   }
   check(state.shot!=='contract','Normal public opening entry used');await page.keyboard.press('Escape');
   await wait(s=>s.stage==='reality'&&s.shot==='comms','advertisement skips to original communications');await screenshot('comms');
   const advanceUntil=Date.now()+180000;
   while(state.shot!=='contract'){
    if(Date.now()>advanceUntil)throw Error('Original communications did not reach contract');
    await dump();if(state.shot==='contract')break;
    if(state.page?.choosing){
     await screenshot('dialog-choices');
     if(comicPlayback){
      const second=state.page.buttons.find(b=>b.id==='pick2');assert.ok(second,'Original second choice pointer rect');await clickRect(second);await wait(s=>s.line==='v06'&&!s.page.choosing,'real response to second choice');check(state.line==='v06','Real second dialog option mouse click enters original v06 reply');await screenshot('dialog-chosen');
     }else await page.keyboard.press('3');
    }else{if(comicPlayback&&state.line==='v01')await screenshot('dialog-v01');await page.keyboard.press('Space');}
    await sleep(450);
   }
   await dump();check(!!state.page?.field&&!!state.page?.signature,'Live native field and signature bounds exposed');
   await memoryPoint('contract');
   if(process.env.VOX_INTRO_CONTRACT_RESIZE==='1'){
    for(const size of [{name:'tablet-4-3',width:1024,height:768},{name:'tablet-16-10',width:1280,height:800},{name:'phone-20-9',width:840,height:378}]){
     await page.setViewportSize({width:size.width,height:size.height});await sleep(350);await dump();
     check(state.shot==='contract','Contract survives actual resize '+size.name);
     for(const [name,r]of Object.entries({field:state.page.field,signature:state.page.signature,terms:state.page.terms}))
      check(r.w>0&&r.h>0&&r.x>=0&&r.y>=0&&r.x+r.w<=state.width+1&&r.y+r.h<=state.height+1,name+' fits '+size.name);
     check(state.page.field.x>=state.page.terms.x+state.page.terms.w,'Foreground pad does not cover terms '+size.name);
     await screenshot('contract-'+size.name);
    }
    await page.setViewportSize({width:test.width,height:test.height});await sleep(350);await dump();
   }
   const layout=state.page;for(const [name,r]of Object.entries({field:layout.field,signature:layout.signature}))
    check(r.w>0&&r.h>0&&r.x>=0&&r.y>=0&&r.x+r.w<=state.width+1&&r.y+r.h<=state.height+1,name+' fits landscape viewport');
   await screenshot('contract');await clickRect(layout.field);await page.keyboard.press('Control+A');await page.keyboard.insertText('Web验收');await dump();
   check(state.page.name==='Web验收','Actual keyboard/IME field updates callsign');await openingButton('submit');await dump();
   check(state.shot==='contract'&&!state.signed&&state.error==='请先在签名框里签一笔。','Unsigned profile is rejected by real submit');
   const r=state.page.signature,a=await point(r,.15,.45),b=await point(r,.6,.7),c=await point(r,.82,.25);
   await page.mouse.move(a.x,a.y);await page.mouse.down();await page.mouse.move(b.x,b.y,{steps:15});await page.mouse.move(c.x,c.y,{steps:15});await page.mouse.up();await dump();
   check(state.page.ink>=30,'Actual mouse stroke passes original ink threshold');await screenshot('signature');await openingButton('submit');
   await wait(s=>s.signed,'Real signature stored');await wait(s=>s.mode==='opening'&&s.shot==='gate','Original identity gate');await screenshot('gate');
   await memoryPoint('gate');
   const returnDeadline=Date.now()+90000;
   while(state.mode==='opening'||state.tab!=='hangar'){
    if(Date.now()>returnDeadline)throw Error('Opening did not restore actual hall');
    await sleep(600);await dump();
   }
   await memoryPoint('hall-return');
   await screenshot('restored');
   check(state.mode!=='opening','Opening and native field are removed on finish');
   check(await page.evaluate(()=>document.pointerLockElement===null),'No pointer lock retained after opening');
   await wait(s=>s.tutorial?.running,'tutorial starts after actual opening resource release');
   await sleep(2500);await dump();check(state.tab==='hangar'&&state.tutorial?.running,'actual hall remains responsive after tutorial resource preparation');
   await memoryPoint('tutorial-ready');
   report.restored=structuredClone(state);
   check(report.errors.length===0,'No unexpected browser/Lua/resource errors');report.result='PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await memoryPoint('failure');await screenshot('failure').catch(()=>{});}
  finally{
   report.functionalityBeforeShutdown=report.result;report.shutdown='PENDING';
   fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));
   const before=report.errors.length;await page.close();await sleep(250);report.shutdown='CLOSED';
   report.shutdownErrors=report.errors.slice(before);if(report.errors.length)report.result='FAIL';
   report.finishedAt=new Date().toISOString();fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));
  }
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));
  if(report.result!=='PASS')throw Error(report.failure);
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

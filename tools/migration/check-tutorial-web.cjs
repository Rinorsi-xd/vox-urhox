const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4290);
const tag=process.env.VOX_TUTORIAL_TAG||new Date().toISOString().replace(/[:.]/g,'-');
const audioOnly=process.env.VOX_QA_AUDIO_ONLY==='1';
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.equal(identity.qa,true,'tutorial probes require explicit QA server');
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(c.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{hasTouch:true,isMobile:true}:{})});
  const report={identity,build:identity.source_directory,manifest:identity.servedManifest,viewport:test,checks:[],errors:[],httpFailures:[],samples:[],scope:'Real card clicks, route selection, inventory, keyboard/touch edit, saved bay, replay and skip. Live tutorial target enclosure at each actual build step. No synthetic completion of tutorial conditions. Touch emulation is not real-device acceptance.'};
  const prefix='tutorial-web-'+test.name+'-'+tag;let state,seq=0;fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),line+'\n');const i=line.indexOf('OUTGAME_STATE ');
   if(i>=0){try{state=JSON.parse(line.slice(i+14));seq++;}catch(e){if(line.trimEnd().endsWith('}'))report.errors.push(e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  async function wait(fn,label,timeout=150000){const start=Date.now();let nextDump=start+1000;while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-start>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));if(Date.now()>nextDump){nextDump=Date.now()+1000;await page.keyboard.press('F8');}await sleep(80);}return state;}
  async function dump(){const old=seq;await page.keyboard.press('F8');await wait(()=>seq>old,'dump',10000);return state;}
  const check=(value,label)=>{assert.ok(value,label);report.checks.push(label);};
  async function tap(x,y){if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
  async function rect(r){await tap((r.x+r.w/2)/state.width*test.width,(r.y+r.h/2)/state.height*test.height);}
  async function button(id){const s=await dump(),b=s.tutorial.buttons.find(b=>b.id===id);assert.ok(b,'tutorial '+id);
   check(b.x>=0&&b.y>=0&&b.x+b.w<=s.width&&b.y+b.h<=s.height,'tutorial '+id+' fits');await rect(b);}
  async function widget(text){const s=await dump(),b=s.widgets.find(b=>b.text===text);assert.ok(b,'widget '+text);const [x,y,w,h]=b.rect;await rect({x,y,w,h});}
  async function target(text){const s=await dump(),r=s.tutorial.target;check(r&&r.w>2&&r.h>2,'live '+s.tutorial.id+' target exists');
   const entries=text?s.widgets.filter(b=>b.text===text):s.widgets.filter(b=>b.kind==='slot');assert.ok(entries.length,'actual tutorial target controls '+(text||'slots'));
   for(const b of entries){const [x,y,w,h]=b.rect;check(r.x<=x+.5&&r.y<=y+.5&&r.x+r.w>=x+w-.5&&r.y+r.h>=y+h-.5,'target encloses '+s.tutorial.id+' '+(text||b.part||'empty slot'));}}
  async function shot(name){await dump();report.samples.push(structuredClone(state.tutorial));await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});}
  async function next(id){for(let i=0;i<6&&state.tutorial.id===id;i++){await button('next');await sleep(180);await dump();}await wait(s=>s.tutorial.id!==id,id+' advances',10000);}
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active&&!s.loading?.busy,'actionable hall');
   if(audioOnly)await wait(s=>s.audioSettings?.uiSound?.ready>=2,'UI cues decoded');
   const pressBefore=state.audioSettings?.uiSound?.counts?.press||0;
   await page.keyboard.press('F12');await wait(s=>s.tutorial?.visible&&s.tutorial.id==='hello','welcome');
   await wait(s=>s.tutorial.voicePlayed>0&&s.tutorial.voicePlaying,'original welcome voice');check(state.tutorial.voiceId,'welcome resolves original voice');await shot('hello');
   await next('hello');await shot('car');check(state.tutorial.target.w>0,'vehicle info target uses live layout');await next('car');await next('bays');
   if(audioOnly)check((state.audioSettings.uiSound.counts.press||0)>pressBefore,'actual tutorial primary buttons play approved press');
   await wait(s=>s.tutorial.id==='choose','route');await shot('choose');await button('build');await wait(s=>s.build&&s.tutorial.id==='bag','real build-first');
   check(state.tutorial.path==='build','actual editor selects source build route');await shot('bag');
   const confirmBeforeBag=state.audioSettings?.uiSound?.counts?.confirm||0;
   if(test.touch){await target('背包');await widget('背包');}else await page.keyboard.press('b');
   await wait(s=>s.inventory&&s.tutorial.id==='pick','actual bag');await shot('pick');
   if(audioOnly){
    check((state.audioSettings.uiSound.counts.confirm||0)>confirmBeforeBag,'real bag completion plays approved confirm');
    check(state.audioSettings.uiSound.voices===10,'original ten-voice UI pool');
    report.uiSound=structuredClone(state.audioSettings.uiSound);
    report.scope='Actual public tutorial buttons/build route/B inventory input and playback counters. Stops after bag completion; no edit/save/full-tutorial or audible-quality acceptance.';
    check(report.errors.length===0,'no unexpected runtime errors');report.result='PASS';
   }else{
   await widget('关闭');
   await wait(s=>!s.inventory&&s.tutorial.id==='place','assembly');await shot('place');
   if(test.touch)await target();
   const before=state.parts;
   if(!test.touch){await page.mouse.click(test.width*.5,test.height*.5);await wait(s=>s.buildInput.captured,'real editor capture');
    await page.mouse.click(test.width*.5,test.height*.5,{button:'right'});await sleep(300);await dump();
    // A visible center ray may initially miss the vehicle. Scan a bounded
    // source FP yaw/pitch region through actual relative mouse input.
    for(let i=0;i<24&&state.parts===before;i++){await page.mouse.move(test.width*.5+(i%2?24:-24),test.height*.5+8);await page.mouse.click(test.width*.5,test.height*.5,{button:'right'});await sleep(150);await dump();}
    await page.keyboard.press('Escape');
   }else{
    for(const [x,y] of [[.5,.5],[.45,.55],[.55,.55],[.5,.6],[.4,.5],[.6,.5]]){if(state.parts!==before)break;await tap(test.width*x,test.height*y);await sleep(250);await dump();}
    // The source touch toolbar uses tap-to-place and long-press-to-delete;
    // its old standalone erase button is hidden in the current dock.
    if(state.parts===before){
     const cdp=await page.context().newCDPSession(page);
     try{for(const [x,y] of [[.5,.5],[.45,.55],[.55,.55],[.5,.6]]){if(state.parts!==before)break;
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:test.width*x,y:test.height*y,id:1}]});
      await sleep(1100);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await sleep(250);await dump();
     }}finally{await cdp.send('Input.dispatchTouchEvent',{type:'touchCancel',touchPoints:[]}).catch(()=>{});await cdp.detach();}
    }
   }
   await wait(s=>s.parts!==before&&s.tutorial.id==='save','actual assembly change',15000);check(state.parts!==before,'real edit advances assembly condition');await shot('save');
   await target('保存');await widget('保存');await wait(s=>s.tutorial.id==='back','successful save',15000);await target('机库');await widget('机库');await wait(s=>!s.build&&s.tutorial.id==='battle','return retains lesson');
   check(state.tutorial.running,'tutorial survives root UI replacement');await button('skip');check(state.tutorial.running,'first skip does not end lesson');await button('skip');await wait(s=>!s.tutorial.running&&s.tutorial.record.skipped,'confirmed skip');
   await wait(s=>!s.tutorial.voicePlaying,'skip stops original voice');check(!state.tutorial.voicePlaying,'skip releases tutorial playback');
   await page.keyboard.press('e');await wait(s=>s.build,'replay editor');const record=JSON.stringify(state.tutorial.record);
   if(test.touch){await widget('更多');await widget('重看改车教学');}
   else{const help=state.widgets.find(w=>w.kind==='icon'&&w.icon==='help');assert.ok(help,'editor replay help');const [x,y,w,h]=help.rect;await rect({x,y,w,h});}
   await wait(s=>s.tutorial.replay&&s.tutorial.id==='bag','replay source build lesson');await shot('replay');await button('skip');await wait(s=>!s.tutorial.running,'close replay');
   check(JSON.stringify(state.tutorial.record)===record,'replay keeps completed or skipped main record');check(report.errors.length===0,'no unexpected runtime errors');report.result='PASS';
   }
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await page.screenshot({path:path.join(out,prefix+'-failure.png')}).catch(()=>{});throw e;}
  finally{
   report.functionalityBeforeShutdown=report.result;const before=report.errors.length;await page.close();await sleep(250);
   report.shutdownErrors=report.errors.slice(before);if(report.errors.length)report.result='FAIL';
   fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));
  }
  if(report.result!=='PASS')throw Error(report.failure||report.errors.join('\n'));
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

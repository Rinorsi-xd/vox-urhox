// Actual browser inputs only. F8 reads the existing QA snapshot; no state writes.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4299);
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const cases=[{name:'pc',width:1920,height:1080,touch:false},{name:'20-9',width:840,height:378,touch:true}].filter(test=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(test.name));
const visualOnly=process.env.VOX_QA_VISUAL_ONLY==='1';
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa,'QA build is required');
 if(process.env.VOX_EXPECT_MANIFEST)assert.equal(identity.servedManifest,process.env.VOX_EXPECT_MANIFEST,'Pinned final build');
 const out=path.join(root,'docs/migration/evidence/practice-web-'+identity.servedManifest.replace('.json','')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});
 const report={identity,result:'FAIL',cases:[],boundary:'Real T/canvas click/R/F8 keyboard and touch input. No gameplay state injection. Mobile browser emulation is not a device or sustained performance claim. Natural inverted contextual touch action remains OPEN unless it really appears.'};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases){
  const context=await browser.newContext({viewport:{width:test.width,height:test.height},hasTouch:test.touch,isMobile:test.touch,deviceScaleFactor:1});
  const page=await context.newPage();let state,serial=0;
  const result={test,checks:[],errors:[],states:[],screenshots:[],touchFlip:{result:'OPEN',reason:'No natural inversion encountered'}};report.cases.push(result);
  page.on('console',message=>{const text=message.text();fs.appendFileSync(path.join(out,test.name+'.log'),text+'\n');
   const marker=text.indexOf('OUTGAME_STATE ');if(marker>=0){try{state=JSON.parse(text.slice(marker+14));serial++;}catch(error){result.errors.push('Malformed QA snapshot: '+error.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))result.errors.push(text);
  });page.on('pageerror',error=>result.errors.push(String(error)));
  function check(ok,label){assert(ok,label);result.checks.push(label);}
  async function key(key){await page.keyboard.down(key);await sleep(55);await page.keyboard.up(key);}
  async function fresh(timeout=15000){const before=serial;await key('F8');const start=Date.now();let retry=Date.now()+500;while(serial<=before){if(Date.now()-start>timeout)throw Error('No fresh F8 snapshot');if(Date.now()>retry){retry=Date.now()+500;await key('F8');}await sleep(15);}return state;}
  async function wait(predicate,label,timeout=180000){const start=Date.now();while(!state||!predicate(state)){if(Date.now()-start>timeout)throw Error('Timeout '+label);await fresh(Math.max(1000,timeout-(Date.now()-start)));await sleep(90);}return state;}
  async function shot(name){const file=test.name+'-'+name+'.png';result.states.push({name,state:structuredClone(state)});await page.screenshot({path:path.join(out,file),timeout:15000});result.screenshots.push(file);}
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'actionable hangar');
   await key('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow?.active,'real T trial entry');
   if(state.intro?.active){await key('Space');await wait(s=>!s.intro?.active,'actual intro skip');}
   await fresh();check(state.map==='trial','Normal T enters original practice map');
   check(state.practice?.alive&&state.practice.life>0&&state.practice.parts>0&&state.practice.playerCount===1,'Real practice player is alive and registered exactly once');
   check(!!state.safeReset,'Read-only safe reset instrumentation is present');
   if(!state.pointer.captured){
    const x=test.width*.5,y=test.height*.45;
    if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);
    await wait(s=>s.pointer?.captured,'actual playfield capture',15000);
   }
   check(state.pointer.captured,'Real click or tap captures driving input');
   if(visualOnly){
    await key('r');await fresh();check(state.safeReset.active&&state.safeReset.dur===1.2,'Real R presents source reset progress');
    const readyBefore=state.safeReset.ready;
    result.resetPixel={scale:state.mouse.scale,dpr:1,width:state.width,height:state.height,cssWidth:test.width,expectedFont:13,expectedOffset:118,expectedBar:[180,3]};
    await shot('r-progress-css-pixels');
    await key('r');await fresh();check(!state.safeReset.active,'Visual specimen leaves no active channel after real R cleanup');
    result.specimenCleanup=state.safeReset.ready===readyBefore?'cancelled':'completed before screenshot cleanup';
   }else{
   await key('r');await fresh();check(state.safeReset.active&&state.safeReset.dur===1.2,'Real first R starts original 1.2 second channel');
   const initialReady=state.safeReset.ready;
   await key('r');await fresh();check(!state.safeReset.active&&state.safeReset.ready===initialReady,'Real second R cancels without consuming cooldown');
   await shot('r-cancelled');
   await key('r');await fresh();check(state.safeReset.active,'Real third R starts a fresh channel');
   await shot('r-progress');
   await wait(s=>!s.safeReset.active&&s.safeReset.ready>initialReady,'channel completion',10000);
   const ready=state.safeReset.ready;
   check(ready>state.safeReset.now&&ready-state.safeReset.now<=4000,'Completion starts original four second wall-clock cooldown');
   await key('r');await fresh();check(!state.safeReset.active&&state.safeReset.ready===ready,'Real R during cooldown is rejected without moving cooldown deadline');
   await shot('r-cooldown');
   check(state.practice.alive&&state.practice.playerCount===1,'Reset retains live singleton practice player');
   if(test.touch){
    check(state.touch===true&&!!state.touchControls,'20:9 is actual touch-control mode');
    await wait(s=>s.safeReset.now>=s.safeReset.ready,'cooldown expiry',8000);await fresh();
    const flip=state.widgets.find(widget=>widget.text==='翻正');
    if(flip){
     const [x,y,w,h]=flip.rect;await page.touchscreen.tap((x+w/2)*test.width/state.width,(y+h/2)*test.height/state.height);await fresh();
     check(state.safeReset.active,'Naturally visible contextual flip uses the real touch button');
     result.touchFlip={result:'PASS',reason:'Natural contextual button was visible and physically tapped'};await shot('touch-flip');
    }else await shot('touch-upright-no-flip');
   }
   }
  }catch(error){result.errors.push(error.stack||String(error));try{await shot('failure');}catch{}}
  result.final=state;result.result=result.errors.length?'FAIL':'PASS';
  fs.writeFileSync(path.join(out,test.name+'.json'),JSON.stringify(result,null,2));console.log(test.name+': '+result.result+' '+result.checks.length+' checks');
  await context.close();
 }}finally{await browser.close();}
 const finalIdentity=await fetch(base+'/identity.json').then(r=>r.json());report.finalIdentity=finalIdentity;
 assert.equal(finalIdentity.servedManifest,identity.servedManifest,'Both ratios used the same immutable build');
 report.result=report.cases.every(test=>test.result==='PASS')?'PASS':'FAIL';
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(out);if(report.result!=='PASS')process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1;});

// Actual UI inputs over the production Endless controller; QA keys only kill
// actual enemies and move the actual player to base to reach wave-rest surfaces.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const {closeRuntime,createRuntimeWatchdog,guardPage}=require('./salvage-runtime-watchdog.cjs');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4265);
const restoredSupply=process.argv.includes('--restored-supply');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const cases=[{name:'pc',width:1600,height:900},{name:'landscape-20-9',width:1440,height:648}];
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa);
 const out=path.resolve('docs/migration/evidence/endless-'+path.basename(identity.manifest_path,'.json')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));fs.mkdirSync(out,{recursive:true});console.log('Evidence: '+out);
 const browser=await chromium.launch({headless:!restoredSupply,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const c of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE===c.name)){
  const prefix='endless-web-'+c.name,rawPage=await browser.newPage({viewport:{width:c.width,height:c.height}});
  let state,seq=0;const report={identity,viewport:c,checks:[],errors:[],probeErrors:[],startedAt:new Date().toISOString(),boundary:'QA F2 destroys actual enemies; QA F3 moves actual player. This is UI/retained-world evidence, not natural full-wave battle or mobile performance acceptance.'};
  const watchdog=createRuntimeWatchdog({onFatal:event=>{report.fatalRuntime=event;report.errors.push(event.message);
   report.result='FAIL';fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));}});
  const guarded=guardPage(rawPage,watchdog);
  const page=restoredSupply?new Proxy(rawPage,{get(target,key){
   if(Object.hasOwn(guarded,key))return guarded[key];
   if(key==='evaluate'||key==='waitForFunction')return(...args)=>watchdog.operation('page.'+key,()=>target[key](...args));
   const value=target[key];return typeof value==='function'?value.bind(target):value;
  }}):rawPage;
  if(restoredSupply)report.boundary='QA PageDown opens the production selector and F2 destroys actual spawned enemies. Checkpoint save/restore, settings Continue pointer capture/release, supply claim and return use production public UI. Same runtime storage only; no real account, reload persistence, natural full-wave battle, pixel or performance acceptance.';
  fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',m=>{const t=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),t+'\n');const at=t.indexOf('OUTGAME_STATE ');
   if(at>=0){try{state=JSON.parse(t.slice(at+14));seq++;}catch(e){report.probeErrors.push(e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t))report.errors.push(t);
  });page.on('pageerror',e=>report.errors.push(e.message));
  page.on('crash',()=>report.errors.push('Browser page crashed'));
  if(restoredSupply)await page.addInitScript(()=>{
   window.__restSupplyPointerEvents=[];
   document.addEventListener('pointerlockchange',()=>window.__restSupplyPointerEvents.push({at:performance.now(),locked:!!document.pointerLockElement}));
   document.addEventListener('pointerlockerror',()=>window.__restSupplyPointerEvents.push({at:performance.now(),error:true}));
  });
  async function wait(fn,label,limit=180000){const start=Date.now();let probe=0;while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-start>limit)throw Error('Timeout '+label);if(Date.now()-probe>750){probe=Date.now();await page.keyboard.press('F8');}await delay(100);}return state;}
  async function dump(){const prior=seq;await page.keyboard.press('F8');await wait(()=>seq>prior,'fresh UI probe',15000);return state;}
  function check(cond,name){assert.ok(cond,name);report.checks.push(name);}
  function widgets(s=state){if(Array.isArray(s.widgets))return s.widgets;
   if(s.widgets&&typeof s.widgets==='object'&&Object.keys(s.widgets).length===0)return[];
   throw Error('Malformed observer widget list');}
  async function click(name){await dump();const b=state.widgets.find(w=>w.text===name&&!w.disabled);assert.ok(b,'Actual button '+name);const canvas=await page.locator('canvas').boundingBox();const r=b.rect;
   await page.mouse.click(canvas.x+(r[0]+r[2]/2)*canvas.width/state.width,canvas.y+(r[1]+r[3]/2)*canvas.height/state.height);await delay(250);}
  async function shot(name){await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});}
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'actionable hall');
   await page.keyboard.press('PageDown');await wait(s=>Array.isArray(s.widgets)&&s.widgets.some(w=>w.text==='先锋 · 轮式激光'),'actual source-hidden selection');await dump();await shot('select');
   check(state.widgets.some(w=>w.text==='先锋 · 轮式激光'),'Actual source starter selection is mounted');await click('先锋 · 轮式激光');
   await wait(s=>s.endless&&!s.loadingFlow?.active,'production map entry');await wait(s=>s.endless.state==='combat'&&s.endless.pending===0&&s.endless.enemies>0,'natural countdown/spawn',90000);await shot('combat');
   check(state.endless.wave===1&&state.endless.lives===3,'Real countdown enters first wave with three lives');
   await page.keyboard.press('F2');await wait(s=>s.endless.state==='rest','actual enemy destruction wave rest');await shot('supply');
   if(restoredSupply){
    function choices(){return widgets().filter(w=>w.text&&!w.disabled&&Math.abs(w.rect[3]-164)<2);}
    async function returnToHall(){
     await page.keyboard.press('Escape');await wait(s=>s.pauseMenu?.rows?.return,'public pause return');await click('返回车库');
     await wait(s=>!s.endless&&(s.tab==='hangar'||s.mode==='hangar')&&!s.loadingFlow?.active,'public return to hall');
    }
    async function restore(){
     await page.keyboard.press('PageDown');await wait(s=>widgets(s).some(w=>w.text==='继续上次进度'),'public checkpoint Continue');
     await click('继续上次进度');await wait(s=>s.endless?.state==='rest'&&!s.loadingFlow?.active,'restored checkpoint map');await dump();
    }
    await dump();check(choices().length===3,'Wave-clear production save has three unclaimed supply cards');
    const saved={wave:state.endless.wave,lives:state.endless.lives,tier:state.endless.tier,score:state.endless.score,
      cards:choices().map(w=>w.text)};report.savedBeforeRestore=saved;
    await shot('unclaimed-before-return');await returnToHall();await restore();
    check(['wave','lives','tier','score'].every(k=>state.endless[k]===saved[k]),'Restored checkpoint preserves wave lives tier score');
    check(JSON.stringify(choices().map(w=>w.text))===JSON.stringify(saved.cards),'Restored original three supply choices match saved cards');await shot('restored-unclaimed');
    await page.keyboard.press('Escape');await wait(s=>s.pauseMenu?.rows?.resume,'restored public pause Continue');await shot('restored-pause');
    report.beforeResume=structuredClone(state);await click('继续');await dump();
    await wait(s=>!s.pauseMenu&&!s.dialog&&!s.pointer.captured&&!s.pointer.pending,'restored supplies release Continue capture',15000);
    await page.waitForFunction(()=>!document.pointerLockElement,{},{timeout:15000});
    await delay(700);await dump();
    check(!state.pointer.captured&&!state.pointer.pending,'Public Continue cannot retain locked or pending input over restored supplies');
    check(!state.pauseMenu&&!state.dialog,'Input release does not reopen the settings overlay');
    check(choices().length===3,'All restored supply cards remain available after public Continue');await shot('restored-after-continue');
    report.afterResume=structuredClone(state);
    const selected=choices()[0].text;await click(selected);await wait(s=>s.endless?.state==='rest'&&choices().length===0,'real mouse restored supply claim',20000);
    check(['wave','lives','tier','score'].every(k=>state.endless[k]===saved[k]),'Mouse claim preserves the restored run state');
    check(choices().length===0,'Real mouse claim retires all three choices');await shot('restored-claimed');
    await returnToHall();await restore();
    check(choices().length===0,'Second public restore does not offer the already claimed supply again');
    check(['wave','lives','tier','score'].every(k=>state.endless[k]===saved[k]),'Second restore preserves the same run');
    await shot('claimed-checkpoint-restored');
    report.pointerEvents=await page.evaluate(()=>window.__restSupplyPointerEvents);
    report.boundary+=' Pointer lock DOM event history is recorded, but instantaneous native pending/captured state may fall between observer samples; that edge is separately covered by actual-function offline replay. Inventory grant cardinality is covered offline, not inferred from hidden cards.';
    await returnToHall();
   }else{
   await dump();const supply=state.widgets.find(w=>/^激光枪|^转|^加特林|^机|^狙击|^驱动|^重轮|^履带|^悬浮|^战地维修|^跳跃/.test(w.text));assert.ok(supply,'Original three supply choices');await click(supply.text);
   await page.keyboard.press('F3');await delay(400);await page.keyboard.press('g');await wait(s=>s.endless.editing,'actual G retained editor');await delay(1000);await shot('edit');
   check(state.endless.state==='editing'&&state.endless.wave===1,'Same wave retained while actual editor owns input');
   check(state.camera.playerModels.total>0&&state.camera.playerModels.visible===0,'Actual battle vehicle children stay hidden during retained editor');
   await dump();const shop=state.widgets.find(w=>w.text.startsWith('整备商店'));assert.ok(shop);await click(shop.text);await delay(1000);await dump();await shot('shop');
   check(state.widgets.some(w=>w.text==='激光枪 T1'),'Actual shop original weapon cards rendered');await page.keyboard.press('Escape');await delay(400);
   await click('Enter · 出发');await wait(s=>!s.endless.editing&&s.endless.state==='rest','actual depart returns to same paused battlefield');
   check(state.endless.wave===1&&state.endless.lives===3,'Departure preserves wave/lives');await dump();await shot('return');
   check(state.camera.playerModels.visible>0,'Actual living battle vehicle children restore after departure');
   }
   check(report.errors.length===0,'No browser/Lua/resource errors');report.result='PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await shot('failure').catch(()=>{});}
  finally{report.finishedAt=new Date().toISOString();report.lastState=state;
   if(restoredSupply){report.shutdown=await closeRuntime(page,browser);if(report.shutdown.status!=='CLOSED'){report.result='FAIL';report.failure='Browser shutdown '+report.shutdown.status;}}
   else await page.close();
   fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));}
  console.log(JSON.stringify({case:c.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));if(report.result!=='PASS')throw Error(report.failure);
  if(restoredSupply)break;
 }}finally{
  if(restoredSupply){const shutdown=await closeRuntime({close:async()=>{}},browser);if(shutdown.status!=='CLOSED')throw Error('Browser final shutdown '+shutdown.status);}
  else await browser.close();
 }
})().catch(e=>{console.error(e);process.exitCode=1;});

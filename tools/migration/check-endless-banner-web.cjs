// Public controls and existing QA F2/F3 only. Never rewrite wave/tier or clocks.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4341);
const width=Number(process.env.VOX_QA_WIDTH||1600),height=Number(process.env.VOX_QA_HEIGHT||900);
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function main(){
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa,'QA identity');
 const out=path.resolve('docs/migration/evidence/endless-banner-'+path.basename(identity.manifest_path,'.json')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log('Evidence: '+out);
 const report={identity,viewport:{width,height},checks:[],errors:[],probeErrors:[],samples:[],stages:[],supplyCards:[],repairScreenshots:[],open:[],startedAt:new Date().toISOString(),
  boundary:'Desktop Chrome. Only existing QA F2 destroys actual enemies and F3 places actual player at base. Countdown, spawning, deaths, supply, tier unlocks and editor run production code. No wave/tier/clock mutation, natural full-wave battle, real account, pixel parity or mobile performance acceptance.'};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:{width,height}});let state,revision=0,stage='boot';
 function persist(){report.lastState=state;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));}
 page.on('console',message=>{const line=message.text();fs.appendFileSync(path.join(out,'console.log'),line+'\n');
  const at=line.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(line.slice(at+14));revision++;
   if(state.endless)report.samples.push({receivedAt:Date.now(),stage,endless:state.endless,camera:state.camera,pointer:state.pointer,vehicle:state.vehicle,loading:state.loadingFlow?.active});
  }catch(error){report.probeErrors.push({stage,message:error.message,length:line.length});}}
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(line)){report.errors.push(line);persist();}
 });page.on('pageerror',error=>{report.errors.push(String(error));persist();});
 page.on('crash',()=>{report.errors.push('Browser page crashed');persist();});
 await page.addInitScript(()=>{window.__endlessFrames={stage:'boot',timeOrigin:performance.timeOrigin,samples:[]};let before=performance.now(),previousStage='boot';
  function frame(now){const stage=window.__endlessFrames.stage;window.__endlessFrames.samples.push({at:now,ms:now-before,stage,fromStage:previousStage});before=now;previousStage=stage;requestAnimationFrame(frame);}requestAnimationFrame(frame);
 });
 async function key(name){await page.keyboard.press(name,{delay:60});}
 async function mark(name){stage=name;report.stages.push({name,at:Date.now()});await page.evaluate(name=>{window.__endlessFrames.stage=name;},name);console.log(name);persist();}
 async function wait(predicate,label,timeout=240000){const start=Date.now();let probeAt=0;
  while(!state||!predicate(state)){
   if(report.errors.length)throw Error(report.errors.join('\n'));
   if(state?.loadingFlow?.failed)throw Error('Loading failed '+state.loadingFlow.error);
   if(Date.now()-start>timeout)throw Error('Timeout '+label);
   if(Date.now()-probeAt>200){probeAt=Date.now();await key('F8');}await delay(50);
  }return state;
 }
 async function dump(){const prior=revision;await key('F8');return wait(()=>revision>prior,'fresh probe',20000);}
 function check(condition,name){assert(condition,name);report.checks.push(name);persist();}
 async function shot(name){await page.screenshot({path:path.join(out,name+'.png')});}
 async function click(text){await dump();const button=state.widgets?.find(item=>item.text===text&&!item.disabled);assert(button,'Actual button '+text);
  const box=await page.locator('canvas').boundingBox();assert(box,'Rendered canvas');const r=button.rect;
  await page.mouse.move(box.x+(r[0]+r[2]/2)*box.width/state.width,box.y+(r[1]+r[3]/2)*box.height/state.height);
  await delay(100);await page.mouse.click(box.x+(r[0]+r[2]/2)*box.width/state.width,box.y+(r[1]+r[3]/2)*box.height/state.height,{delay:100});
 }
 async function collect(ms){const until=Date.now()+ms;while(Date.now()<until){await dump();await delay(60);}}
 async function supply(){await dump();const choices=(state.widgets||[]).filter(item=>item.text&&Math.abs(item.rect[3]-164)<2);
  assert.equal(choices.length,3,'Three actual supply cards');
  report.supplyCards.push({wave:state.endless.wave,stage,cards:structuredClone(choices)});
  const repair=choices.find(item=>item.text==='战地维修');
  if(repair&&!report.repairScreenshots.length){
   const name='wave-'+state.endless.wave+'-repair';await shot(name);
   const box=await page.locator('canvas').boundingBox();assert(box,'Rendered repair canvas');const r=repair.rect;
   const x=Math.max(0,box.x+r[0]*box.width/state.width),y=Math.max(0,box.y+r[1]*box.height/state.height);
   const clip={x,y,width:Math.min(width-x,r[2]*box.width/state.width),height:Math.min(height-y,r[3]*box.height/state.height)};
   assert(clip.width>0&&clip.height>0,'Actual repair card visible screenshot bounds');
   await page.screenshot({path:path.join(out,name+'-card.png'),clip});
   report.repairScreenshots.push({wave:state.endless.wave,name:name+'.png',card:name+'-card.png',clip,button:structuredClone(repair)});persist();
  }
  await click(choices[0].text);
  await wait(s=>s.endless.state==='rest'&&!(s.widgets||[]).some(item=>item.text&&Math.abs(item.rect[3]-164)<2),'supply consumed',20000);
 }
 function sampleSpawns(label){const rows=report.samples.filter(row=>row.stage===label&&!row.loading&&row.endless.alive&&!row.endless.editing&&row.endless.spawn&&!row.endless.spawn.firstPerson);
  const observed=rows.filter(row=>row.endless.spawn.riseUntil>row.endless.worldTime&&row.endless.spawn.basePosition);
  if(observed.length){for(const row of observed){const e=row.endless,p=e.spawn;
    const expected=Math.max(0,p.riseUntil-e.worldTime)/.6*Math.max(3,p.height+2);
    assert(Math.abs(p.basePosition[1]-p.rootPosition[1]-expected)<1e-3,'Actual root rise offset follows source formula');
   }check(true,label+' actual visual root follows source height/time rise');
  }else report.open.push(label+' rise not observed inside loading/presentation window');
  const immune=rows.filter(row=>row.endless.worldTime<row.endless.spawn.invulnerableUntil);
  const shown=new Set();for(const row of immune){const e=row.endless,p=e.spawn,expected=Math.floor(e.worldTime/.12)%2===0;
   assert.equal(p.rootEnabled,expected,label+' actual immunity root blink');
   shown.add(expected);
   if(!expected)assert.equal(row.camera.playerModels.visible,0,'Blink hides actual child models');
   else assert(row.camera.playerModels.visible>0,'Blink shows actual effective child models');
  }
  if(shown.size===2)check(true,label+' protection visibly alternates both phases on actual models');
  else report.open.push(label+' both protection phases not observed');
  const final=rows.find(row=>row.endless.worldTime>=row.endless.spawn.invulnerableUntil&&row.camera.playerModels.visible>0);
  if(final)check(true,label+' actual child models restore after protection');else report.open.push(label+' post-protection sample not observed');
 }
 try{
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'actionable hall');await mark('selection');
  await key('PageDown');await wait(s=>(s.widgets||[]).some(item=>item.text==='先锋 · 轮式激光'),'source hidden selection');
  await mark('initial-spawn');await click('先锋 · 轮式激光');
  await wait(s=>s.endless&&!s.loadingFlow?.active,'real endless map');
  check(state.endless.banner!==undefined&&state.endless.spawn!==undefined,'Read-only banner and actual model probes available');
  await wait(s=>s.endless.worldTime>=s.endless.spawn.invulnerableUntil+.1,'initial protection elapsed');
  sampleSpawns('initial-spawn');await shot('initial-ready');
  for(let wave=1;wave<=5;wave++){
   await mark('wave-'+wave);await wait(s=>s.endless.wave===wave&&s.endless.state==='combat'&&s.endless.enemies>0,'natural wave '+wave+' spawning',90000);
   check(state.endless.wave===wave,'Production countdown enters wave '+wave);
   const start=Date.now();let killedAt=0;
   while(state.endless.state!=='rest'){
    if(Date.now()-start>150000)throw Error('Timeout actual destruction wave '+wave);
    if(state.endless.enemies>0&&Date.now()-killedAt>500){await key('F2');killedAt=Date.now();}
    await dump();await delay(60);
   }
   check(state.endless.wave===wave&&state.endless.lives===3,'Actual destruction clears wave '+wave+' with three lives');
   const expected=wave===5?'第 5 波完成 · 敌人升到 T2':'第 '+wave+' 波完成';
   check(state.endless.banner?.text===expected,'Actual wave '+wave+' banner matches frozen source');await shot('wave-'+wave+'-clear');
   if(wave===5){
    check(state.endless.tier===2,'Boss clear advances production tier to T2');
    report.compoundBanner=structuredClone(state.endless);
    await wait(s=>!s.pointer.captured,'rest releases pointer',15000);await page.waitForFunction(()=>!document.pointerLockElement);
    await supply();await key('F3');await delay(200);await key('g');await wait(s=>s.endless.editing,'real G editor');
    check(state.camera.playerModels.visible===0,'Retained editor hides battle models');await mark('editor');report.editStart=structuredClone(state.endless);
    if(report.editStart.banner?.untilAt>report.editStart.wallNow)check(true,'Compound banner was still live when actual paused editor opened');
    else report.open.push('Editor opened after compound banner expiry; active-banner pause transition was not observed.');
    await shot('wave-5-editor');await collect(4000);report.editEnd=structuredClone(state.endless);
    check(report.editEnd.worldTime===report.editStart.worldTime,'Actual world time stays paused throughout editor');
    check(report.editEnd.wallNow-report.editStart.wallNow>=3500,'Wall clock advances beyond source banner expiry during editor');
    await mark('edit-return');await click('Enter · 出发');await wait(s=>!s.endless.editing&&s.endless.state==='rest','real departure');
    check(!state.endless.banner,'Expired banner is absent when retained HUD resumes');await shot('edit-return-first');
    await wait(s=>s.endless.worldTime>=s.endless.spawn.invulnerableUntil+.1,'returned protection elapsed',45000);
    sampleSpawns('edit-return');await shot('edit-return-ready');
   }else{
    await wait(s=>!s.pointer.captured,'rest releases pointer',15000);await page.waitForFunction(()=>!document.pointerLockElement);
    await supply();await key('Enter');await wait(s=>s.endless.wave===wave+1,'actual next wave');
   }
  }
  check(report.errors.length===0,'No runtime/browser errors');
  if(!report.repairScreenshots.length)report.open.push('No repair card appeared in the five production supply rolls; repair glyph visual acceptance remains open.');
  report.open.push('Death/respawn spawn presentation was not triggered by this tool. Natural combat, final visual parity, real accounts and mobile sustained performance remain open.');
  report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;await shot('failure').catch(()=>{});}
 finally{
  report.frames=await page.evaluate(()=>window.__endlessFrames.samples).catch(()=>[]);
  report.frameTimeOrigin=await page.evaluate(()=>window.__endlessFrames.timeOrigin).catch(()=>null);
  const sorted=report.frames.map(row=>row.ms).sort((a,b)=>a-b);
  report.frameStats=sorted.length?{count:sorted.length,p50:sorted[Math.floor((sorted.length-1)*.5)],p95:sorted[Math.floor((sorted.length-1)*.95)],max:sorted.at(-1),over100:sorted.filter(ms=>ms>100).length}:null;
  report.performanceResult=report.frameStats?.over100?'FAIL':'NOT_ACCEPTED';
  report.finishedAt=new Date().toISOString();persist();await browser.close();
 }
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,errors:report.errors.length,open:report.open,frames:report.frameStats,evidence:out}));
 if(report.result!=='PASS')throw Error(report.failure);
}
main().catch(error=>{console.error(error);process.exitCode=1;});

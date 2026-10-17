const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4505);
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function run(){
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.equal(identity.qa,true);
 const collectorBefore=await fetch(base+'/__vox_perf_status').then(r=>r.json());
 const previousSessions=new Set((collectorBefore.sessions||[]).map(row=>row.session));
 const out=path.resolve('docs/migration/evidence/debug-settings-'+Date.now());fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',processId:process.pid,identity,checks:[],errors:[],httpErrors:[],boundary:'Desktop Chrome real mouse actions. F8 is used only for the QA read-only state observer, never to execute a game/debug/performance command.'};
 fs.writeFileSync(path.join(out,'running.json'),JSON.stringify({processId:process.pid,out}));console.log('Evidence: '+out);
 let browser,page,state,seq=0;const markerFrames={};
 const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label)};
 try{
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});
  page=await browser.newPage({viewport:{width:1600,height:900},deviceScaleFactor:1});
  page.on('console',msg=>{const line=msg.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   const at=line.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(line.slice(at+14));seq++;}catch(error){if(line.trimEnd().endsWith('}'))report.errors.push(error.message)}}
   if(/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|ERROR:/.test(line))report.errors.push(line);
  });
  page.on('pageerror',error=>report.errors.push(error.message));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({status:r.status(),url:r.url()})});
  async function snapshot(){const old=seq;await page.keyboard.press('F8');const end=Date.now()+1500;while(seq===old&&Date.now()<end)await delay(60);return state}
  async function wait(predicate,label,timeout=60000){const end=Date.now()+timeout;while(!state||!predicate(state)){
   assert.equal(report.errors.length,0,report.errors.join('\n'));assert.ok(Date.now()<end,'Timeout '+label);await snapshot();await delay(150);
  }return state}
  async function rectClick(rect){if(rect&&!Array.isArray(rect))rect=[rect.x,rect.y,rect.w,rect.h];assert.ok(Array.isArray(rect)&&rect[2]>0&&rect[3]>0,'Clickable rectangle');
   const canvas=await page.locator('canvas').boundingBox();const x=canvas.x+(rect[0]+rect[2]/2)/state.width*canvas.width,y=canvas.y+(rect[1]+rect[3]/2)/state.height*canvas.height;
   assert.ok(x>=0&&x<1600&&y>=0&&y<900,'Command inside viewport');await page.mouse.click(x,y);await delay(180);await snapshot();
  }
  async function widget(text){await wait(s=>s.widgets?.some(w=>w.text===text&&!w.disabled),'widget '+text);await rectClick(state.widgets.find(w=>w.text===text&&!w.disabled).rect)}
  async function settings(){await snapshot();const gear=state.widgets.find(w=>w.text==='设置'||w.icon==='gear');assert.ok(gear,'Mouse settings entry');await rectClick(gear.rect);await wait(s=>s.pauseMenu?.rows?.debug,'Settings debug row')}
  async function debugButton(id){await wait(s=>s.debugPanel?.buttons?.some(b=>b.id===id),'Debug command '+id);await rectClick(state.debugPanel.buttons.find(b=>b.id===id).rect)}
  async function shot(name){await page.screenshot({path:path.join(out,name+'.png')});fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(state,null,2))}
  async function savedMarker(label){
   const deadline=Date.now()+10000;let marker;
   while(Date.now()<deadline){
    const status=await fetch(base+'/__vox_perf_status').then(r=>r.json());
    for(const session of status.sessions||[]){
     if(previousSessions.has(session.session))continue;
     if(!fs.existsSync(session.file))continue;
     const records=fs.readFileSync(session.file,'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
     marker=records.findLast(row=>row.type==='marker'&&row.label==='user-mark'&&row.frame>(markerFrames[label]??-1)&&row.context?.mode===(label==='hall'?'hangar':'trial'));
     if(marker)break;
    }
    if(marker)break;await delay(200);
   }
   check(!!marker,'Mouse marker saved to disk '+label);
   check(label==='hall'||marker.context.map===state.map,'Marker matches current map '+label);
   markerFrames[label]=marker.frame;
   if(!process.argv.includes('--legacy-marker'))check(marker.context.playerMarker?.schema===1,'Collision marker schema '+label);
   if(label==='trial'&&!process.argv.includes('--legacy-marker')){
    check(marker.context.playerMarker.available===true,'Actual vehicle pose captured');
    check(marker.context.playerMarker.rays?.length===5,'Five actual collision probes');
    check(!marker.context.playerMarker.errors,'No native collision capture errors');
   }
   fs.writeFileSync(path.join(out,label+'-marker.json'),JSON.stringify(marker,null,2));
  }
  async function chain(label){
   await settings();await shot(label+'-settings');await rectClick(state.pauseMenu.rows.debug.rect);
   await wait(s=>s.debugPanel?.open,'Debug opens by mouse');check(state.overlayState?.owner==='app.debugPanel','Debug owns overlay '+label);await shot(label+'-debug');
   const visible=state.performanceControls.visible;await debugButton('perfVisible');await wait(s=>s.performanceControls.visible!==visible,'Panel toggled');
   await debugButton('perfVisible');await wait(s=>s.performanceControls.visible===visible,'Panel restored');
   await debugButton('perfMark');check(state.debugPanel.open,'Mark keeps debug open '+label);
   await savedMarker(label);
   await debugButton('close');await wait(s=>!s.debugPanel?.open&&s.pauseMenu?.rows?.debug,'Close returns to settings');
   check(!state.overlayState?.stack?.some(row=>row.owner==='app.debugPanel'),'Closed debug removed from overlay '+label);
   await rectClick(state.pauseMenu.rows.resume.rect);await wait(s=>!s.pauseMenu&&!s.dialog,'Continue closes settings');
  }
  async function craterLoad(){
   await settings();await rectClick(state.pauseMenu.rows.debug.rect);await wait(s=>s.debugPanel?.open,'Debug map entry');
   const cdp=await page.context().newCDPSession(page);let tracing=false,profiling=false,complete;
   try{
    await cdp.send('Profiler.enable');await cdp.send('Profiler.setSamplingInterval',{interval:1000});
    await cdp.send('Profiler.start');profiling=true;
    complete=new Promise(resolve=>cdp.once('Tracing.tracingComplete',resolve));
    await cdp.send('Tracing.start',{categories:'devtools.timeline,v8,disabled-by-default-v8.wasm',transferMode:'ReturnAsStream'});tracing=true;
    const started=Date.now();await debugButton('mapCrater');
    await wait(s=>s.mode==='trial'&&!s.loadingFlow?.active,'Crater installed',300000);report.craterLoadMs=Date.now()-started;
    await shot('crater-loaded');report.craterState=state;
    const {profile}=await cdp.send('Profiler.stop');profiling=false;fs.writeFileSync(path.join(out,'crater-load.cpuprofile'),JSON.stringify(profile));
    await cdp.send('Tracing.end');tracing=false;const {stream}=await complete;const fd=fs.openSync(path.join(out,'crater-load.trace.json'),'w');
    try{while(true){const chunk=await cdp.send('IO.read',{handle:stream});fs.writeSync(fd,chunk.base64Encoded?Buffer.from(chunk.data,'base64'):chunk.data);if(chunk.eof)break}}finally{fs.closeSync(fd);await cdp.send('IO.close',{handle:stream})}
    const trace=JSON.parse(fs.readFileSync(path.join(out,'crater-load.trace.json'),'utf8'));
    report.longTasks=trace.traceEvents.filter(e=>e.ph==='X'&&e.dur>=80000).sort((a,b)=>b.dur-a.dur).slice(0,60).map(e=>({name:e.name,category:e.cat,startUs:e.ts,durationMs:e.dur/1000,thread:e.tid,args:e.args}));
    check(state.map==='crater'||state.map?.id==='crater','Actual crater map');
    report.boundary+=' Crater load CPU profile and trace add diagnostic overhead; this is not an FPS or cold network benchmark.';
   }finally{if(profiling)await cdp.send('Profiler.stop').catch(()=>{});if(tracing)await cdp.send('Tracing.end').catch(()=>{});await cdp.detach()}
  }
  // No -vox-debug flag: settings must create the debug panel on demand.
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await page.bringToFront();
  await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow?.active,'Hall',240000);
  if(process.argv.includes('--scope-view')){
   report.boundary+=' Scope screenshots and real input verify presentation only; polling and screenshots make this unsuitable for FPS comparisons.';
   await settings();await rectClick(state.pauseMenu.rows.debug.rect);await wait(s=>s.debugPanel?.open,'Scope map entry');
   await debugButton('mapTest');await wait(s=>s.mode==='trial'&&!s.loadingFlow?.active,'Scope real test drive',240000);
   await page.mouse.click(800,450);await wait(s=>s.pointer?.captured===true,'Scope input capture');
   report.scopeSamples=[];
   const groups=state.reticle.groups;check(groups>0&&groups<=10,'Actual selectable weapon groups');
   for(let group=1;group<=groups;group++){
    await page.keyboard.press(group===10?'0':String(group));await delay(300);await snapshot();
    check(state.reticle.selected===group,'Actual weapon group '+group);
    await shot('group-'+group+'-normal');
    try{
     await page.mouse.down({button:'right'});await wait(s=>s.reticle?.scope===true,'Right-held scope');
     check(state.camera.firstPerson&&state.camera.playerModels.visible===0,'Scope hides actual own vehicle '+group);
     await shot('group-'+group+'-scope-idle');
     report.scopeSamples.push({group,phase:'idle',state});
     const before=state.weapons.shots;
     await page.mouse.down({button:'left'});
     for(let i=1;i<=8;i++){
      await delay(180);await snapshot();await shot('group-'+group+'-scope-fire-'+i);
      if(state.scopePresentation?.supported){
       check(state.scopePresentation.firstPerson&&state.scopePresentation.ownsWeapons,'Actual effect owner follows scope '+group+'/'+i);
       const fx=state.scopePresentation.weaponFx;
       if(fx)check(fx.visible===false&&Object.values(fx.batches).every(b=>!b.enabled),'Persistent own FX hidden '+group+'/'+i);
      }
      report.scopeSamples.push({group,phase:'firing',sample:i,state});
     }
     check(state.weapons.shots>before,'Weapon actually fired in scope '+group);
    }finally{
     await page.mouse.up({button:'left'});await page.mouse.up({button:'right'});
    }
    await wait(s=>s.reticle?.scope===false&&!s.camera?.firstPerson,'Release exits scope');
    check(state.camera.playerModels.visible===state.camera.playerModels.total,'Release restores own vehicle '+group);
    if(state.scopePresentation?.supported){
     check(!state.scopePresentation.firstPerson&&!state.scopePresentation.ownsWeapons,'Release clears scoped weapon reference '+group);
     const fx=state.scopePresentation.weaponFx;
     if(fx)check(fx.visible===true&&Object.values(fx.batches).every(b=>b.enabled===(b.count>0)),'Release restores live own FX '+group);
    }
    await shot('group-'+group+'-released');
   }
   await page.keyboard.press('Escape');await wait(s=>s.pauseMenu?.rows?.return,'Scope public pause');
   await rectClick(state.pauseMenu.rows.return.rect);await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'Scope public return');
   await shot('scope-returned');check(report.errors.length===0,'No Runtime errors');check(report.httpErrors.length===0,'No HTTP errors');
   report.result='PASS';return;
  }
  if(process.argv.includes('--crater-load')){await craterLoad();check(report.errors.length===0,'No Runtime errors');check(report.httpErrors.length===0,'No HTTP errors');report.result='PASS';return;}
  if(process.argv.includes('--crater-drive')){
   await settings();await rectClick(state.pauseMenu.rows.debug.rect);await wait(s=>s.debugPanel?.open,'Debug map entry');
   await debugButton('mapCrater');await wait(s=>s.mode==='trial'&&!s.loadingFlow?.active,'Crater installed',300000);
   await page.mouse.click(800,450);await wait(s=>s.pointer?.captured,'Crater drive input');
   report.drive=[];
   try{
    await page.keyboard.down('w');
    for(let second=1;second<=20;second++){
     await delay(1000);await snapshot();report.drive.push({second,trial:state.trial,vehicle:state.vehicle,physics:state.physics});
     fs.writeFileSync(path.join(out,'drive-'+second+'.json'),JSON.stringify(state,null,2));
     if(second%5===0)await shot('drive-'+second);
    }
   }finally{await page.keyboard.up('w')}
   await page.keyboard.press('Escape');await wait(s=>s.pauseMenu?.rows?.debug,'Crater pause');
   await rectClick(state.pauseMenu.rows.debug.rect);await wait(s=>s.debugPanel?.open,'Stopped collision debug');
   await debugButton('perfMark');await savedMarker('trial');await shot('crater-stopped');
   check(report.errors.length===0,'No Runtime errors');check(report.httpErrors.length===0,'No HTTP errors');
   report.result='PASS';report.boundary+=' Twenty seconds held forward from actual crater trial spawn, observer snapshots and explicit collision marker; no teleport or AI injection. PASS means test completed, not all map paths traversable.';return;
  }
  check(!state.debugPanel?.open,'Debug closed initially');check(!state.overlayState?.stack?.some(row=>row.owner==='app.debugPanel'),'No floating Debug overlay initially');
  await chain('hall');
  await settings();await rectClick(state.pauseMenu.rows.debug.rect);await wait(s=>s.debugPanel?.open,'Debug route');
  await debugButton('mapTest');await wait(s=>s.mode==='trial'&&!s.loadingFlow?.active,'Real test drive',240000);
  await chain('trial');
  await page.mouse.click(800,450);await wait(s=>s.pointer?.captured===true,'Resume restores pointer capture',20000);
  check(state.pointer.captured,'Drive input restored');await shot('trial-resumed');
  await page.keyboard.press('Escape');await wait(s=>s.pauseMenu?.rows?.return,'Unified pause');
  await rectClick(state.pauseMenu.rows.return.rect);await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'Public return');
  await shot('returned');check(report.errors.length===0,'No Runtime errors');check(report.httpErrors.length===0,'No HTTP errors');report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;if(page){await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});report.lastState=state}process.exitCode=1;
 }finally{if(browser)await browser.close();report.browser='CLOSED';fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({result:report.result,out,failure:report.failure,checks:report.checks}));}
}
run().catch(error=>{console.error(error);process.exitCode=1});

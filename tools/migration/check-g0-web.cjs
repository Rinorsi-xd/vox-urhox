const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const port=Number(process.env.VOX_G0_PORT||4219),normalPort=Number(process.env.VOX_G0_NORMAL_PORT||4218);
const origin='http://127.0.0.1:'+port,plain='http://127.0.0.1:'+normalPort;
const out=path.join(root,'docs/migration/evidence/full-parity',baseline.commit.slice(0,12),'G0',path.basename(prepared.manifest_path,'.json'),new Date().toISOString().replace(/[:.]/g,'-'));
fs.mkdirSync(out,{recursive:true});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const cases=[{id:'pc',width:1920,height:1080},{id:'20-9',width:840,height:378,dpr:3,touch:true}];
const url=base=>base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1';
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.VOX_QA_CHROME||'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=d3d11']});
 try{
  const identities={qa:await fetch(origin+'/identity.json').then(r=>r.json()),normal:await fetch(plain+'/identity.json').then(r=>r.json())};
  assert.equal(identities.qa.identity.sourceCommit,baseline.commit);assert.equal(identities.normal.qa,false);
  assert.equal(identities.qa.source_directory,prepared.source_directory);assert.equal(identities.normal.source_directory,prepared.source_directory);
  fs.writeFileSync(path.join(out,'servers.json'),JSON.stringify(identities,null,2));
  for(const test of cases.filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE===t.id)){
   const context=await browser.newContext({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,
    ...(test.touch?{isMobile:true,hasTouch:true}:{}),recordVideo:{dir:path.join(out,'video'),size:{width:test.width,height:test.height}}});
   const page=await context.newPage();let state,sequence=0,intentional=false;
   await page.addInitScript(()=>{window.__voxG0Frames=[];let previous=0;function frame(now){if(previous&&window.__voxG0Frames.length<20000)window.__voxG0Frames.push({at:now,ms:now-previous});previous=now;requestAnimationFrame(frame);}requestAnimationFrame(frame);});
   const report={sourceCommit:baseline.commit,build:identities.qa,viewport:test,checks:[],errors:[],expectedErrors:[],httpFailures:[],timings:[],frames:[],storageRisk:'QA is isolated from real cloud. Normal unauthenticated preview checked separately. Real-account refresh remains NOT_RUN.'};
   const log=path.join(out,test.id+'.log');fs.writeFileSync(log,'');
   page.on('console',m=>{
    const line=m.text();fs.appendFileSync(log,line+'\n');const at=line.indexOf('OUTGAME_STATE ');
    if(at>=0){try{state=JSON.parse(line.slice(at+14));sequence++;if(state.frames)report.frames.push({mode:state.mode,map:state.map,values:state.frames});}catch(e){if(line.endsWith('}'))report.errors.push(e.message);}}
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))
     (intentional&&line.includes('QA intentional preparation failure')?report.expectedErrors:report.errors).push(line);
   });
   page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
   page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({url:r.url(),status:r.status()});});
   const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
   async function wait(pred,label,timeout=180000){
    const start=Date.now();let next=start+1000;
    while(!state||!pred(state)){
     if(report.errors.length)throw Error(report.errors.slice(-3).join('\n'));
     if(Date.now()-start>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
     if(Date.now()>next){next=Date.now()+1000;await page.keyboard.press('F8');}await sleep(80);
    }
    return state;
   }
   async function dump(){const n=sequence;await page.keyboard.press('F8');await wait(()=>sequence>n,'fresh state',15000);return state;}
   async function tap(x,y){if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
   async function widget(text){const s=await dump(),w=s.widgets.find(w=>w.text===text);assert.ok(w,'Widget '+text);const [x,y,ww,hh]=w.rect;
    await tap((x+ww/2)/s.width*test.width,(y+hh/2)/s.height*test.height);}
   async function shot(name){await page.screenshot({path:path.join(out,test.id+'-'+name+'.png')});}
   async function touchControl(id){
    const s=await dump(),r=s.touchControls.rects[id];assert.ok(r,'Touch control '+id);
    await tap((r[0]+r[2]/2)/s.width*test.width,(r[1]+r[3]/2)/s.height*test.height);
   }
   async function capture(label){
    await tap(test.width/2,test.height/2);await wait(s=>s.pointer.captured&&!s.pointer.pending,label);
    if(!test.touch)check(await page.evaluate(()=>!!document.pointerLockElement),label+' browser pointer lock');
   }
   try{
    const started=Date.now();await page.goto(url(origin));await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow.active,'cold hall',240000);
    report.timings.push({stage:'cold-hall',ms:Date.now()-started});await shot('hall');check(state.widgets.some(w=>w.text==='改装'),'hall HUD visible and actionable');
    await widget('改装');await wait(s=>s.build,'construction');await shot('build');check(state.buildInput!==undefined,'construction input/HUD initialized');
    await page.keyboard.press('Escape');await sleep(150);await page.keyboard.press('Escape');await sleep(150);
    // Return through the actual editor back button, not a QA scene assignment.
    await dump();let back=state.widgets.find(w=>/^(机库|返回机库|返回大厅|大厅)$/.test(w.text));
    if(!back){await page.keyboard.press('Escape');await dump();back=state.widgets.find(w=>/^(机库|返回机库|返回大厅|大厅)$/.test(w.text));}
    if(back){const [x,y,w,h]=back.rect;await tap((x+w/2)/state.width*test.width,(y+h/2)/state.height*test.height);}
    else throw Error('Construction return button missing');
    await wait(s=>!s.build&&s.mode==='hangar','construction return');check(!state.build,'construction returns without losing vehicle');
    for(let cycle=1;cycle<=5;cycle++){
     const at=Date.now();await page.keyboard.press('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'trial '+cycle);
     report.timings.push({stage:'trial-'+cycle,ms:Date.now()-at});check(state.loadingFlow.warmFrames>=2,'trial '+cycle+' revealed after rendered frames');
     await capture('trial '+cycle+' capture');await sleep(300);const before=structuredClone(await dump());
     if(!test.touch){
      await page.keyboard.down('w');await sleep(1600);await page.keyboard.up('w');await sleep(100);
      const moved=await dump();check(Math.hypot(moved.vehicle.position[0]-before.vehicle.position[0],moved.vehicle.position[2]-before.vehicle.position[2])>1,'trial '+cycle+' actual held throttle');
      const yaw=moved.camera.yaw;await page.mouse.move(980,530);await page.mouse.move(1040,500,{steps:6});await sleep(150);
      check(Math.abs((await dump()).camera.yaw-yaw)>.1,'trial '+cycle+' actual look input');
      await page.keyboard.press('Escape');await wait(s=>!s.pointer.captured&&!s.pointer.pending,'pause');
      await sleep(2200);await capture('trial '+cycle+' resume');check((await dump()).pointer.captured,'trial '+cycle+' pause/resume');
      await page.keyboard.press('Escape');await wait(s=>!s.pointer.captured,'pause before return');
     }else{
      const r=before.touchControls.rects.stick;
      const x=(r[0]+r[2]/2)/before.width*test.width,y=(r[1]+r[3]/2)/before.height*test.height;
      const cdp=await context.newCDPSession(page);
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:1,x,y}]});
      await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:1,x,y:y-r[3]*.3/before.height*test.height}]});
      await sleep(1600);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();
      const moved=await dump();check(Math.hypot(moved.vehicle.position[0]-before.vehicle.position[0],moved.vehicle.position[2]-before.vehicle.position[2])>1,'trial '+cycle+' actual touch joystick');
      check(moved.touchControls.contacts===0,'trial '+cycle+' touch release clears contacts');
      await touchControl('menu');await wait(s=>s.touchControls.menu&&!s.pointer.captured,'touch pause');
      await touchControl('option-menu');await wait(s=>!s.touchControls.menu&&s.pointer.captured,'touch resume');
     }
     if(cycle===1)await shot('trial-hud');await page.keyboard.press('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'trial return '+cycle);
     check(!state.craterModelResident,'trial '+cycle+' no stale crater');
    }
    intentional=true;await page.keyboard.press('F2');await wait(s=>s.loadingFlow.failed&&s.loadingFlow.backRect,'intentional load failure');await shot('load-failure');
    const failureBack=state.loadingFlow.backRect;await tap((failureBack.x+failureBack.w/2)/state.width*test.width,(failureBack.y+failureBack.h/2)/state.height*test.height);
    await wait(s=>!s.loadingFlow.active&&s.mode==='hangar','failed load return');intentional=false;check(state.mode==='hangar','load failure keeps recoverable hall');
    await widget('出战');await wait(s=>s.tab==='battle','mode page');await widget('歼灭战');await widget('开始匹配');
    await wait(s=>s.loadingFlow.match?.stage==='queue','queue');await page.keyboard.press('Escape');await wait(s=>!s.loadingFlow.active&&s.mode==='hangar','queue cancel');check(!state.battle,'cancel queue retains hall');
    const battleAt=Date.now();await widget('开始匹配');await wait(s=>s.mode==='trial'&&s.battle&&!s.loadingFlow.active,'crater battle',240000);
    report.timings.push({stage:'cold-crater-battle',ms:Date.now()-battleAt});await wait(s=>s.intro?.active,'intro');await shot('intro');
    check(!state.pointer.captured,'intro owns input');const r=state.intro.skipRect;assert.ok(r,'clickable skip');
    await tap((r.x+r.w/2)/state.width*test.width,(r.y+r.h/2)/state.height*test.height);await wait(s=>!s.intro?.active,'intro skip');
    await capture('post-intro capture');await sleep(8000);await dump();check(state.battle.state==='live','intro-to-play reaches live battle');await shot('battle-hud');
    report.battleState=structuredClone(state);report.timings.push({stage:'battle-resident',resourceBytes:state.performance.resourceBytes,arrayBytes:state.performance.arrayBytes});
    if(!test.touch){await page.keyboard.press('Escape');await wait(s=>!s.pointer.captured,'battle pause');}
    if(test.touch){await touchControl('menu');await wait(s=>s.touchControls.menu,'battle menu');await touchControl('option-exit');}
    else await widget('退出对局');
    await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'battle return',60000);await sleep(500);await dump();
    check(state.performance.arrayBytes===0,'battle exit frees terrain arrays');check(!state.craterModelResident,'battle exit frees unused crater models');
    check(report.errors.length===0,'no unexpected Lua/shader/runtime errors');report.result='PASS';
   }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await shot('failure').catch(()=>{});}
   finally{report.browserFrames=await page.evaluate(()=>window.__voxG0Frames).catch(()=>[]);report.video=await page.video().path();await context.close();fs.writeFileSync(path.join(out,test.id+'.json'),JSON.stringify(report,null,2));}
   console.log(JSON.stringify({case:test.id,result:report.result,checks:report.checks.length,failure:report.failure,errors:report.errors.length}));
   if(report.result!=='PASS')process.exitCode=1;
  }
  // This page has no Lua probe or validation flag; boot is the actual release path.
  const page=await browser.newPage({viewport:{width:1920,height:1080}}),messages=[],errors=[];
  page.on('console',m=>{messages.push(m.text());if(/ERROR:|stack traceback|Aborted\(/.test(m.text()))errors.push(m.text());});
  page.on('pageerror',e=>errors.push(e.message));await page.goto(url(plain));
  const start=Date.now();while(!messages.some(l=>l.includes('[HangarApp] Ready'))&&Date.now()-start<240000)await sleep(200);
  await page.screenshot({path:path.join(out,'normal-hall.png')});
  const normal={build:identities.normal,ready:messages.some(l=>l.includes('[HangarApp] Ready')),noProbe:!messages.some(l=>l.includes('OUTGAME_STATE ')),sessionOnly:messages.some(l=>l.includes('[CloudStorage] Session-only preview')),errors,realAccountRefresh:'NOT_RUN'};
  fs.writeFileSync(path.join(out,'normal.json'),JSON.stringify(normal,null,2));fs.writeFileSync(path.join(out,'normal.log'),messages.join('\n'));
  if(!normal.ready||!normal.noProbe||errors.length)process.exitCode=1;await page.close();console.log(JSON.stringify({normal:{ready:normal.ready,noProbe:normal.noProbe,sessionOnly:normal.sessionOnly,errors:errors.length},out}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

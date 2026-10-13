const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json'),'utf8'));
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{hasTouch:true,isMobile:true}:{})});
  let state;let closed=false;const states=[],errors=[],expectedErrors=[],httpFailures=[];let intentional=false;
  page.on('crash',()=>{closed=true;errors.push('Browser renderer crashed');});page.on('close',()=>closed=true);
  const report={build:prepared.source_directory,manifest:path.basename(prepared.manifest_path),viewport:test,checks:[],states,errors,expectedErrors,httpFailures,memory:[],truncatedProbes:0};
  const prefix='loading-battle-web-'+test.name;
  fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',msg=>{const text=msg.text();fs.appendFileSync(path.join(out,prefix+'.log'),text+'\n');const index=text.indexOf('OUTGAME_STATE ');
   if(index>=0){const payload=text.slice(index+14);try{state=JSON.parse(payload);states.push(state);}catch(error){
    if(!payload.trimEnd().endsWith('}'))report.truncatedProbes++;else errors.push('PROBE '+error.message);
   }}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text)){
    (intentional&&text.includes('QA intentional preparation failure')?expectedErrors:errors).push(text);
   }
  });
  page.on('pageerror',e=>errors.push(e.message));page.on('response',response=>{if(response.status()>=400)httpFailures.push({status:response.status(),url:response.url()});});
  const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
  async function wait(predicate,label,timeout=180000){const start=Date.now();while(!state||!predicate(state)){if(closed)throw Error('Browser renderer stopped during '+label);if(errors.some(e=>/Aborted\(|WASM_OOM/.test(e)))throw Error('Runtime aborted during '+label);if(Date.now()-start>timeout)throw Error('Timed out '+label+' '+JSON.stringify(state));await sleep(80);}return state;}
  async function dump(){const count=states.length;await page.keyboard.press('F8');await wait(()=>states.length>count,'probe state',10000);return state;}
  async function tap(x,y){if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
  async function widget(text,kind){const s=await dump();const item=s.widgets.find(item=>kind?item.kind===kind:item.text===text);assert.ok(item,'Live widget '+text);const [x,y,w,h]=item.rect;await tap((x+w/2)/s.width*test.width,(y+h/2)/s.height*test.height);}
  async function shot(name){await page.screenshot({path:path.join(out,prefix+'-'+name+'.png'),timeout:10000});}
  try{
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
   await wait(s=>s.mode==='hangar'&&s.tab==='hangar','hall');
   await page.evaluate(()=>{
    const previous=abortOnCannotGrowMemory;
    abortOnCannotGrowMemory=requested=>{console.error('WASM_OOM requested='+requested+' heap='+HEAPU8.length+' '+new Error().stack);return previous(requested);};
   });
   intentional=true;await page.keyboard.press('F2');await wait(s=>s.loadingFlow?.failed&&s.loadingFlow.phase==='loading'&&s.loadingFlow.backRect,'failed preparation');await shot('failure');
   check(state.mode==='hangar'&&state.loadingFlow.active,'failed load preserves hall and exposes error');
   const back=state.loadingFlow.backRect;await tap((back.x+back.w/2)/state.width*test.width,(back.y+back.h/2)/state.height*test.height);
   await wait(s=>!s.loadingFlow.active,'failure return');intentional=false;
   await page.keyboard.press('t');await wait(s=>s.loadingFlow?.visible&&!s.loadingFlow.failed,'loading page');await shot('loading');
   await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'trial ready');await shot('trial');check(state.loadingFlow.progress===1&&state.loadingFlow.warmFrames>=2,'scene readiness follows rendered frames');
   const before=structuredClone(await dump());await tap(test.width*.5,test.height*.5);await wait(s=>s.pointer.captured,'capture');
   if(!test.touch){
    check(await page.evaluate(()=>!!document.pointerLockElement),'actual browser pointer lock succeeds');
    await page.mouse.wheel(0,-100);await sleep(400);const zoom=await dump();check(zoom.camera.dist<before.camera.dist&&zoom.camera.dist/before.camera.dist>.85,'100px wheel uses one smooth source zoom step');
    await page.mouse.wheel(0,100);await sleep(400);check(Math.abs((await dump()).camera.dist-before.camera.dist)<.01,'opposite wheel restores trial zoom');
    await page.keyboard.down('w');await sleep(2500);await page.keyboard.up('w');await sleep(400);
    const moved=await dump();check(Math.hypot(moved.vehicle.position[0]-before.vehicle.position[0],moved.vehicle.position[2]-before.vehicle.position[2])>2,'held keyboard throttle moves actual player');
    await page.mouse.move(test.width*.5,test.height*.5);await page.mouse.move(test.width*.5+4,test.height*.5-90,{steps:8});await page.mouse.move(test.width*.5+8,test.height*.5-145,{steps:8});await sleep(500);
    await page.mouse.down();await wait(s=>s.weapons.shots>0,'equipped weapons fire',15000);await page.mouse.up();check((await dump()).weapons.shots>0,'actual mouse fires equipped weapons');
    await page.keyboard.press('Escape');await wait(s=>!s.pointer.captured,'release');
   }else{
    await widget('拉近');await sleep(400);check((await dump()).camera.dist<before.camera.dist*.95,'touch zoom uses equivalent native notch');
   }
   await page.keyboard.press('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'return to hall');check(!state.loadingFlow.failed,'trial returns through shared transition');
   if(process.env.VOX_QA_BATTLE==='1'){
    const titles={elimination:'歼灭战',conquest:'站点争夺',escort:'推车'};
    for(const mode of (process.env.VOX_QA_MODES||'elimination').split(',')){
    if((await dump()).tab!=='battle')await widget('出战');await wait(s=>s.tab==='battle','mode picker');await widget(titles[mode]);await sleep(300);await widget('开始匹配');
    await wait(s=>s.loadingFlow?.match?.stage==='queue'&&s.loadingFlow.visible,'source matchmaking queue');await shot('queue');
    await page.keyboard.press('Escape');await wait(s=>!s.loadingFlow.active&&s.mode==='hangar','queue cancel');check(!state.battle,'queue cancellation preserves garage');
    await widget('开始匹配');await wait(s=>s.loadingFlow?.match?.stage==='roster','source team cards');
    await wait(s=>s.mode==='trial'&&s.battle&&!s.loadingFlow.active,'production crater '+mode,240000);await shot(mode+'-battle');
    report.memory.push({stage:mode+'-loaded',...state.performance});
    check(state.performance.arrayBytes<68*1024*1024,'terrain arrays stay within 64 MiB payload budget in '+mode);
    check(state.map==='crater'&&state.battle.mode===mode&&state.battle.units.length===(mode==='elimination'?6:8),'production '+mode+' loads crater and source roster');
    await wait(s=>s.intro?.active,'source cinematic starts');const introStart=structuredClone(await dump());await sleep(1600);const introLater=await dump();
    check(introLater.battle.state==='prep'&&introLater.battle.timeLeft===introStart.battle.timeLeft,mode+' timer stays paused during cinematic');await shot(mode+'-intro');
    await page.keyboard.press('Space');await wait(s=>!s.intro?.active,'skip cinematic');
    const initial=structuredClone(await dump());await tap(test.width*.5,test.height*.5);await wait(s=>s.pointer.captured,'battle capture');await sleep(10000);const live=await dump();
    check(live.battle.state==='live',mode+' countdown enters live battle');
    check(live.battle.units.some((u,i)=>!u.player&&Math.hypot(u.position[0]-initial.battle.units[i].position[0],u.position[2]-initial.battle.units[i].position[2])>3),mode+' bots navigate actual crater');
    if(mode==='conquest')check(live.battle.points.length===3,'three source capture points remain in live state');
    if(mode==='escort')check(live.battle.payload.length>300,'source payload route is installed in Web');
    await shot(mode+'-battle-live');if(!test.touch){await page.keyboard.press('Escape');await wait(s=>!s.pointer.captured,'battle release');await sleep(500);}await widget('退出对局');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'battle return',60000);check(!state.craterModelResident,mode+' return retires unused crater models');
    await sleep(500);await dump();report.memory.push({stage:mode+'-returned',...state.performance});
    check(state.performance.arrayBytes===0,mode+' return releases both terrain arrays');
    }
   }
   check(errors.length===0,'no unexpected runtime or probe errors');report.result='PASS';
  }catch(error){report.result='FAIL';report.failure=error.stack;report.lastState=state;await shot('failure-final').catch(e=>report.captureFailure=e.message);throw error;}
  finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:errors.length,httpFailures:httpFailures.length}));
 }}finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});

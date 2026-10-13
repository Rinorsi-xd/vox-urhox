const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const build=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json'),'utf8'));
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{hasTouch:true,isMobile:true}:{})});
  const cdp=test.touch?await page.context().newCDPSession(page):null;
  const report={build:build.source_directory,manifest:path.basename(build.manifest_path),viewport:test,checks:[],errors:[],truncatedProbes:0,httpFailures:[],samples:[]};
  const prefix='missiles-web-'+test.name;let state,sequence=0;
  fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',msg=>{const line=msg.text();fs.appendFileSync(path.join(out,prefix+'.log'),line+'\n');const i=line.indexOf('OUTGAME_STATE ');
   if(i>=0){const payload=line.slice(i+14);try{state=JSON.parse(payload);sequence++;if(state.missile)report.samples.push(state.missile);}catch(e){
    if(!payload.trimEnd().endsWith('}'))report.truncatedProbes++;else report.errors.push(e.message);
   }}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });
  page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Browser renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
  async function wait(pred,label,timeout=180000){const at=Date.now();while(!state||!pred(state)){
   if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));await sleep(80);
  }return state;}
  async function dump(){const before=sequence;await page.keyboard.press('F8');await wait(()=>sequence>before,'state probe',10000);return state;}
  async function shot(name){await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});}
  async function hold(on){if(!test.touch){if(on)await page.mouse.down();else await page.mouse.up();return;}
   const s=await dump(),r=s.touchRects.fire;assert.ok(r,'actual touch fire button');
   await cdp.send('Input.dispatchTouchEvent',{type:on?'touchStart':'touchEnd',touchPoints:on?[{x:(r[0]+r[2]/2)/s.width*test.width,y:(r[1]+r[3]/2)/s.height*test.height,id:3}]:[]});
  }
  try{
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
   await wait(s=>s.mode==='hangar'&&s.tab==='hangar','hall');
   await page.keyboard.press('F3');await wait(s=>s.blueprint==='量产机兵 · 重装'&&!s.vehicleLoading.busy,'source Mini Heavy');
   for(let cycle=0;cycle<2;cycle++){
    await page.keyboard.press('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'trial');await page.keyboard.press('F3');
    if(!test.touch){await page.mouse.click(test.width*.5,test.height*.5);await wait(s=>s.pointer.captured,'pointer lock');}
    await wait(s=>s.missile?.group==='missile'&&s.missile.lock>=1&&s.missile.phase==='ready','actual camera target lock',30000);
    check(state.missile.models>10,'cycle '+cycle+' mounts imported missile pod meshes');await shot('lock-'+cycle);
    const before=state.weapons.shots;await hold(true);
    await wait(s=>s.weapons.shots>before&&s.missile.visible>0,'actual input launches visible missiles',15000);await shot('volley-'+cycle);
    check(state.missile.projectiles>0,'cycle '+cycle+' source curved projectiles are active');await hold(false);
    check(report.samples.some(s=>s.energy<100),'cycle '+cycle+' launch consumes actual energy');
    await wait(s=>s.weapons.hits>0,'native target damage',20000);
    await wait(s=>s.missile.phase==='ready'&&s.missile.projectiles===0&&s.missile.visible===0,'reload and pooled cleanup',30000);
    for(const id of ['missile_scan','missile_lock','missile_open','missile_launch','missile_eject','missile_blast','missile_reload','missile_close'])check(state.weaponAudio.counts[id]>0,'cycle '+cycle+' actual Web source plays '+id);
    check(state.weaponAudio.voices<=10&&!state.weaponAudio.loops.missile_flight.playing,'cycle '+cycle+' audio loops expire and voices stay bounded');
    check(!state.pointer.fire,'cycle '+cycle+' release clears mouse/touch fire');await shot('reload-'+cycle);
    if(!test.touch){await page.keyboard.press('Escape');await wait(s=>!s.pointer.captured&&!s.weaponAudio.active,'pause');}
    await page.keyboard.press('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'return');check(!state.loadingFlow.failed,'cycle '+cycle+' returns through actual loading flow');
   }
   check(report.errors.length===0,'no unexpected runtime errors');report.result='PASS';
  }catch(error){report.result='FAIL';report.failure=error.stack;report.lastState=state;await shot('failure').catch(()=>{});throw error;}
  finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length,httpFailures:report.httpFailures.length}));
 }}finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});

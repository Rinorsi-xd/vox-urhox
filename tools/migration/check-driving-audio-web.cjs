const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true}];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(c.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{hasTouch:true,isMobile:true}:{})});
  const prefix='driving-audio-web-'+test.name;
  const report={build:prepared.source_directory,manifest:path.basename(prepared.manifest_path),viewport:test,checks:[],errors:[],httpFailures:[],samples:[]};
  let state,seq=0;fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),line+'\n');const i=line.indexOf('OUTGAME_STATE ');
   if(i>=0){try{state=JSON.parse(line.slice(i+14));seq++;}catch(e){if(line.trimEnd().endsWith('}'))report.errors.push(e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  async function wait(fn,label,timeout=150000){const at=Date.now();let nextDump=at+1000;while(!state||!fn(state)){
   if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
   if(Date.now()>nextDump){nextDump=Date.now()+1000;await page.keyboard.press('F8');}await sleep(80);
  }return state;}
  async function dump(){const old=seq;await page.keyboard.press('F8');await wait(()=>seq>old,'dump',10000);return state;}
  const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
  async function tap(x,y){if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
  async function shot(name){await dump();report.samples.push(structuredClone(state));await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});}
  const stopped=s=>!s.drivingAudio.active&&Object.values(s.drivingAudio.loops).every(l=>!l.playing&&l.gain===0);
  try{
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar','hall');
   await page.keyboard.press('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'trial');
   if(!test.touch)check(stopped(await dump()),'unlocked PC has no engine playback');
   await tap(test.width*.5,test.height*.5);await wait(s=>s.pointer.captured&&s.drivingAudio.active,'capture');
   await wait(s=>s.drivingAudio.loops.drive_idle?.playing,'wheel idle starts');
   check(state.drivingAudio.loops.drive_idle.frequency>30000,'Web loop frequency uses sample Hz');await shot('idle');
   const before=structuredClone(state);let cdp;
   if(test.touch){
    const r=state.touchRects.stick,[x,y,w,h]=r;
    const cx=(x+w/2)/state.width*test.width,cy=(y+h/2)/state.height*test.height,up=(y+h/2-60)/state.height*test.height;
    cdp=await page.context().newCDPSession(page);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:cx,y:cy,id:3}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:cx,y:up,id:3}]});
   }else await page.keyboard.down('w');
   await wait(s=>s.drivingAudio.loops.drive_load?.playing&&Math.abs(s.vehicle.speed)>2,'real throttle and load');await shot('load');
   if(test.touch)await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});else await page.keyboard.up('w');
   check(Math.hypot(state.vehicle.position[0]-before.vehicle.position[0],state.vehicle.position[2]-before.vehicle.position[2])>1,'actual keyboard or touch joystick moves the sounding wheel car');
   check(state.drivingAudio.loops.drive_load.gain>0&&state.drivingAudio.loops.drive_load.frequency>30000,'load sample reaches live Web playback');
   if(!test.touch){await page.keyboard.press('Escape');await wait(s=>stopped(s),'release stops driving');check(stopped(state),'pointer release stops every engine voice');}
   await page.keyboard.press('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'return');check(!state.drivingAudio,'return disposes session sample ownership');
   await page.keyboard.press('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'second trial');
   await tap(test.width*.5,test.height*.5);await wait(s=>s.drivingAudio.loops.drive_idle?.playing,'second engine');check(state.drivingAudio.counts.drive_idle===1,'re-entry creates one fresh idle source');
   await sleep(600);await page.keyboard.press('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'second return');
   check(report.errors.length===0,'no unexpected runtime errors');report.result='PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await page.screenshot({path:path.join(out,prefix+'-failure.png')}).catch(()=>{});throw e;}
  finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

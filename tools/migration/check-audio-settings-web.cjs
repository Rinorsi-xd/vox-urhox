const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4280),root=path.resolve(__dirname,'../..');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa);
 const out=path.join(root,'docs/migration/evidence/audio-settings-web-'+identity.servedManifest.replace('.json','')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});let failed=false;
 try{for(const test of [{name:'pc',width:1920,height:1080,touch:false},{name:'20-9',width:840,height:378,touch:true}]){
  const context=await browser.newContext({viewport:{width:test.width,height:test.height},hasTouch:test.touch,isMobile:test.touch,deviceScaleFactor:test.touch?3:1});
  const page=await context.newPage();let state,serial=0;const report={identity,test,checks:[],errors:[],probeErrors:[]};
  page.on('console',message=>{const text=message.text();fs.appendFileSync(path.join(out,test.name+'.log'),text+'\n');const at=text.indexOf('OUTGAME_STATE ');
   if(at>=0){try{state=JSON.parse(text.slice(at+14));serial++;}catch(error){report.probeErrors.push(String(error));}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))report.errors.push(text);
  });page.on('pageerror',error=>report.errors.push(String(error)));
  async function key(key){await page.keyboard.down(key);await sleep(100);await page.keyboard.up(key);await sleep(100);}
  async function wait(fn,label,ms=180000){const started=Date.now();while(!state||!fn(state)){
   if(Date.now()-started>ms)throw Error('Timeout '+label);await key('F8');await sleep(250);
  }return state;}
  async function dump(){const before=serial;await key('F8');await wait(()=>serial>before,'fresh snapshot',15000);return state;}
  async function tap(rect){const x=(rect[0]+rect[2]/2)*test.width/state.width,y=(rect[1]+rect[3]/2)*test.height/state.height;
   if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await sleep(250);await dump();}
  async function click(text,icon){await dump();const widget=state.widgets.find(w=>!w.disabled&&(icon?w.icon===icon:w.text===text));assert(widget,'actual control '+(text||icon));await tap(widget.rect);}
  function check(condition,label){assert(condition,label);report.checks.push(label);}
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'actionable home');assert(state.audioSettings,'audio probe snapshot is available');await click(null,'gear');await click('声音与音乐');
   await wait(s=>s.audioSettings?.open,'source settings');check(!!state.audioSettings.rects.voice,'three source controls rendered');
   const card=state.audioSettings.modal,reference=test.touch?[174.3,70.48,491.4,237.04]:[570,327.875,780,424.25];
   const physical=[card.x*test.width/state.width,card.y*test.height/state.height,card.w*test.width/state.width,card.h*test.height/state.height];
   check(physical.every((value,i)=>Math.abs(value-reference[i])<1.5),'source reference card position and dimensions match at this screen ratio');
   report.card={actual:physical,source:reference,compact:state.audioSettings.compact};
   await tap(state.audioSettings.rects.musicEnabled);check(!state.audioSettings.music.enabled,'real checkbox disables scene music');
   await tap(state.audioSettings.rects.musicEnabled);check(state.audioSettings.music.enabled,'real checkbox enables scene music');
   const voice=state.audioSettings.rects.voice;await tap(voice);await key('Home');await dump();check(state.audioSettings.levels.voice===0,'slider keyboard Home mutes voice');
   await key('End');await dump();check(state.audioSettings.levels.voice===1,'slider keyboard End restores full voice');
   await tap(state.audioSettings.rects.pause);check(state.audioSettings.music.paused&&state.audioSettings.nextDisabled,'music pause updates state and disables next');
   await page.screenshot({path:path.join(out,test.name+'-settings.png')});
   await tap(state.audioSettings.rects.done);check(!state.audioSettings.open,'done closes source modal');
   await click(null,'gear');await click('声音与音乐');check(state.audioSettings.levels.voice===1,'reopen retains exact audio preference');
   await tap(state.audioSettings.rects.pause);await tap(state.audioSettings.rects.done);
   await key('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow?.active,'trial');
   const trialParts=state.practice?.parts;
   await click('设置');check(!!state.pauseMenu&&!state.pointer.captured,'actual in-game settings entry releases pointer and opens shared menu');
   check(!!state.pauseMenu.rows.resume&&!!state.pauseMenu.rows.return,'shared menu exposes resume and explicit return');
   await tap(state.pauseMenu.rows.audio.rect);check(state.audioSettings.open&&!state.pointer.captured,'shared menu opens source audio settings');
   await page.screenshot({path:path.join(out,test.name+'-trial.png')});await tap(state.audioSettings.rects.done);
   check(!state.audioSettings.open&&!!state.pauseMenu&&!state.pointer.captured,'audio done returns to shared settings without recapturing input');
   await page.screenshot({path:path.join(out,test.name+'-trial-menu.png')});
   await tap(state.pauseMenu.rows.resume.rect);
   check(!state.pauseMenu&&state.mode==='trial'&&state.practice?.parts===trialParts,'resume preserves trial and player parts');
   if(!test.touch){
    check(state.pointer.captured,'explicit resume captures PC input');
    await key('Escape');await dump();check(!state.pointer.captured&&!state.pauseMenu&&state.mode==='trial','first Escape releases PC input while retaining trial');
    await key('Escape');await dump();check(!!state.pauseMenu&&state.mode==='trial','second Escape opens shared settings without returning home');
    await key('Escape');await dump();check(!state.pauseMenu&&!state.pointer.captured&&state.mode==='trial','Escape closes shared settings and retains released trial');
   }
  }catch(error){report.errors.push(error.stack||String(error));failed=true;try{await page.screenshot({path:path.join(out,test.name+'-failure.png'),timeout:10000});}catch{}}
  report.result=report.errors.length?'FAIL':'PASS';report.final=state;fs.writeFileSync(path.join(out,test.name+'.json'),JSON.stringify(report,null,2));console.log(test.name+': '+report.result+' '+report.checks.length+' checks');await context.close();
 }}finally{await browser.close();}console.log(out);if(failed)process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1;});

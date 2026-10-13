const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path));
const catalog=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Music/Catalog.json')));
const source=JSON.parse(fs.readFileSync(path.join(out,'source-music-box.json')));
const musicFiles=new Map();
for(const t of catalog.tracks){const file=manifest.files.find(f=>f.fs_path===t.file);assert.ok(file,'Catalog audio packaged: '+t.id);assert.ok(!file.flags?.includes('#blocking')&&!file.groups?.includes('boot')&&!file.groups?.includes('#blocking'),'Music is deferred: '+t.id);musicFiles.set(file.uuid+'-'+file.hash+file.ext,t.id);}
const cases=[{name:'pc',width:1920,height:1080,dpr:1},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'phone-16-9',width:800,height:450,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=d3d11']});
 let failed=false;
 try{
  for(const test of cases.filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name))){
   const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,...(test.touch?{hasTouch:true,isMobile:true}:{})});
   let state;const states=[],errors=[],requests=[],checks=[],probeIssues=[];const log=[];const logFile=path.join(out,'music-box-web-'+test.name+'.log');fs.writeFileSync(logFile,'');
   page.on('console',m=>{
    const text=m.text();log.push(text);fs.appendFileSync(logFile,text+'\n');const i=text.indexOf('OUTGAME_STATE ');
    if(i>=0){
     try{const next=JSON.parse(text.slice(i+14));state=next;states.push(next);}
     catch(e){probeIssues.push({message:e.message,bytes:Buffer.byteLength(text),tail:text.slice(-80)});}
    }
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))errors.push(text);
   });
   page.on('pageerror',e=>errors.push(e.message));page.on('requestfailed',r=>errors.push('NETWORK '+r.url()+' '+r.failure()?.errorText));
   page.on('request',r=>{const id=musicFiles.get(new URL(r.url()).pathname.split('/').pop());if(id)requests.push(id);});
   async function wait(fn,label,ms=120000){const start=Date.now();let lastProbe=start;while(!state||!fn(state)){
    if(Date.now()-start>ms)throw Error('Timeout '+label);
    if(Date.now()-lastProbe>1000){lastProbe=Date.now();await page.keyboard.down('F8');await sleep(70);await page.keyboard.up('F8');}
    await sleep(100);
   }return state;}
   async function dump(){const n=states.length;await page.keyboard.down('F8');await sleep(70);await page.keyboard.up('F8');await wait(()=>states.length>n,'probe',10000);return state;}
   function point(rect){const [x,y,w,h]=rect;return [(x+w/2)*test.width/state.width,(y+h/2)*test.height/state.height];}
   async function tapRect(rect){const [x,y]=point(rect);if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await sleep(120);await dump();}
   async function click(text,icon){await dump();const w=state.widgets.find(w=>(icon?w.icon===icon:w.text===text)&&!w.disabled);assert.ok(w,'Live control '+(text||icon));await tapRect(w.rect);}
   async function key(key){await page.keyboard.down(key);await sleep(100);await page.keyboard.up(key);await sleep(100);await dump();}
   const check=(condition,message)=>{assert.ok(condition,message);checks.push(message);};
   try{
    await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
    await wait(s=>s.tab==='hangar','home');await sleep(1200);await dump();
    check(requests.length===0,'No unopened music downloads at boot');
    await click('音乐盒');await wait(s=>s.music?.duration>0,'compressed MP3 playback');await dump();
    check(state.music.count===13,'Original approved 13 tracks');
    const l=state.music.layout;const expectedW=test.width<=1000?720:880;const expectedH=test.height<=450?test.height-40:620;
    check(Math.abs(l.w-expectedW)<.1&&Math.abs(l.h-expectedH)<.1,'Popup uses physical CSS viewport breakpoints');
    check(Math.abs(l.k-state.width/test.width)<.001,'UI scale preserves CSS popup size at requested DPR');
    check(state.physical[0]/state.dpr===test.width&&state.physical[1]/state.dpr===test.height,'Actual browser resolution matches landscape case');
    for(const [target,original] of Object.entries({header:'mb-header',deck:'mb-deck',library:'mb-library',art:'mb-art',heading:'mb-track-heading',
     filters:'mb-filters',listHead:'mb-list-head',list:'mb-track-list',libraryFooter:'mb-library-footer',transport:'mb-transport'})){
     const rect=source.states[test.name].find(e=>e.class===original).rect;
     check(l.rects[target].every((v,i)=>Math.abs(v-rect[i])<.1),'Original H5 DOM bounds: '+original);
    }
    await click('机库工作台');await wait(s=>s.music.track==='hangar-01-workshop-floor','specific original track');
    await sleep(2700);await dump();await click(null,'pause');await sleep(500);await dump();
    check(state.music.paused,'Pause control');
    const paused=state.music.position;await sleep(450);await dump();check(Math.abs(state.music.position-paused)<.06,'Actual audio position holds while paused');
    await page.screenshot({path:path.join(out,'music-box-web-'+test.name+'-main.png')});
    await click('训练营');check(state.music.count===1,'Training filter');
    await click('全部');check(state.music.count===13,'All filter');
    await tapRect(state.music.rects.search);await page.keyboard.type('VECTOR');await dump();check(state.music.count===2,'Original English search');
    await page.keyboard.press('Control+A');await page.keyboard.press('Backspace');await dump();check(state.music.count===13,'Clearing search restores list');
    await click(null,'shuffle');check(state.music.menu,'Original mode popup opens');
    await page.screenshot({path:path.join(out,'music-box-web-'+test.name+'-menu.png')});
    await key('Escape');check(state.music&&!state.music.menu,'Escape closes menu before music box');
    await click(null,'shuffle');await click('单曲循环');check(state.music.mode==='repeat','Repeat mode');
    await click(null,'volume');check(state.music.volume===0,'Mute');await click(null,'volumeOff');check(state.music.volume>0,'Restore volume');
    const before=state.music.track;await key('Escape');check(!state.music&&state.tab==='hangar','Escape returns home');
    await click('音乐盒');check(state.music.track===before,'Closing preserves selected song');await key('Escape');
    check(requests.length<=3,'Only visited music is downloaded');
   }catch(e){errors.push(e.stack||e.message);await page.screenshot({path:path.join(out,'music-box-web-'+test.name+'-failure.png')});}
   fs.writeFileSync(path.join(out,'music-box-web-'+test.name+'.log'),log.join('\n'));
   fs.writeFileSync(path.join(out,'music-box-web-'+test.name+'.json'),JSON.stringify({result:errors.length?'FAIL':'PASS',build:{directory:prepared.source_directory,manifest:path.basename(prepared.manifest_path)},test,checks,errors,probeIssues,requests,states},null,2));
   console.log(test.name+': '+checks.length+' checks; '+errors.length+' errors; '+requests.length+' music downloads');
   if(errors.length)failed=true;await page.close();
  }
 }finally{await browser.close();}
 if(failed)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});

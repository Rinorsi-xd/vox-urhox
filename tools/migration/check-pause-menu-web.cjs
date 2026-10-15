const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4286);
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa);
 const source=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/evidence/source-pause-menu-2026-10-15T06-50-10-574Z/result.json')));
 const out=path.join(root,'docs/migration/evidence/pause-menu-web-'+identity.servedManifest.replace('.json','')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});let failed=false;
 try{for(const test of [{name:'pc',width:1920,height:1080,touch:false},{name:'20-9',width:840,height:378,touch:true}].filter(t=>!process.env.VOX_QA_CASE||t.name===process.env.VOX_QA_CASE)){
  const context=await browser.newContext({viewport:{width:test.width,height:test.height},hasTouch:test.touch,isMobile:test.touch,deviceScaleFactor:test.touch?3:1});
  const page=await context.newPage();let state,revision=0;const report={identity,test,checks:[],errors:[],samples:[]};
  page.on('console',m=>{const t=m.text();fs.appendFileSync(path.join(out,test.name+'.log'),t+'\n');const i=t.indexOf('OUTGAME_STATE ');if(i>=0){try{state=JSON.parse(t.slice(i+14));revision++;}catch{}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t))report.errors.push(t);
  });page.on('pageerror',e=>report.errors.push(String(e)));
  async function key(k){await page.keyboard.down(k);await sleep(100);await page.keyboard.up(k);await sleep(100);}
  async function wait(fn,label,timeout=180000){const start=Date.now();while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-start>timeout)throw Error('Timeout '+label);await key('F8');await sleep(250);}return state;}
  async function dump(){const before=revision;await key('F8');await wait(()=>revision>before,'fresh snapshot',15000);return state;}
  async function tap(r){const x=(r[0]+r[2]/2)/state.width*test.width,y=(r[1]+r[3]/2)/state.height*test.height;if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await sleep(350);await dump();}
  async function open(){await dump();const gear=state.widgets.find(w=>w.icon==='gear'&&!w.disabled);assert(gear,'actual settings button');await tap(gear.rect);await wait(s=>s.pauseMenu,'pause menu');}
  function check(ok,label){assert(ok,label);report.checks.push(label);}
  async function compare(screen){
   await sleep(400);await dump();const menu=state.pauseMenu;assert(menu);const reference=source.cases.find(c=>c.viewport.width===test.width&&c.screen===screen);
   const r=menu.modal,actual=[r.x/state.width*test.width,r.y/state.height*test.height,r.w/state.width*test.width,r.h/state.height*test.height];
   check(actual.every((v,i)=>Math.abs(v-reference.metrics['#modal .card'][0].rect[i])<1.5),screen+' card matches frozen source position and size');
   check(!!menu.rows.modeIntro&&!!menu.rows.audio,screen+' source replay and audio rows exist');
   check(test.touch?!menu.rows.help&&!menu.rows.keys&&!!menu.rows.touch:!!menu.rows.help&&menu.rows.keys.disabled,screen+' platform rows match source');
   if(screen==='edit')check(menu.rows.save.subtitle===(test.touch?'存进车位':'存进车位（Ctrl+S）'),'source editor save caption');
   report.samples.push({screen,menu,actual,reference:reference.metrics['#modal .card'][0].rect});
   await page.screenshot({path:path.join(out,test.name+'-'+screen+'.png')});
  }
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'home');await open();await compare('home');
   await tap(state.pauseMenu.rows.modeIntro.rect);check(!state.pauseMenu,'real replay click closes menu');
   await key('e');await wait(s=>s.build&&!s.loadingFlow?.active,'editor');
   await key('Escape');await wait(s=>s.pauseMenu,'editor pause');await compare('edit');
   if(test.touch){
    const cdp=await context.newCDPSession(page),x=test.width*.5,start=test.height*.78,end=test.height*.27;
    const before=state.pauseMenu.rows.touch.rect[1];
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:1,x,y:start}]});
    for(let i=1;i<=12;i++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:1,x,y:start+(end-start)*i/12}]});await sleep(25);}
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await sleep(500);await dump();
    await page.screenshot({path:path.join(out,test.name+'-edit-scroll.png')});
    const row=state.pauseMenu.rows.touch.rect,modal=state.pauseMenu.modal;
    check(row[1]<before&&row[1]>=modal.y&&row[1]+row[3]<=modal.y+modal.h+1,'actual touch scroll exposes the entire last source row');
   }
   await key('Escape');await wait(s=>!s.pauseMenu,'close menu');check(state.build,'closing pause preserves editor and actual blueprint');
  }catch(error){report.errors.push(error.stack||String(error));failed=true;await page.screenshot({path:path.join(out,test.name+'-failure.png')}).catch(()=>{});}
  report.result=report.errors.length?'FAIL':'PASS';report.final=state;fs.writeFileSync(path.join(out,test.name+'.json'),JSON.stringify(report,null,2));console.log(test.name+': '+report.result+' '+report.checks.length+' checks');await context.close();
 }}finally{await browser.close();}console.log(out);if(failed)process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1;});

const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const build=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const base='http://127.0.0.1:'+(process.env.VOX_QA_PORT||'4204');
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'phone-16x9',width:800,height:450,dpr:2,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(c.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{isMobile:true,hasTouch:true}:{})});
  const prefix='mvp-web-'+test.name,errors=[],httpFailures=[],states=[],checks=[];let state,closed=false;
  const report={build:build.source_directory,manifest:path.basename(build.manifest_path),viewport:test,errors,httpFailures,checks,shots:[]};
  fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',msg=>{const text=msg.text();fs.appendFileSync(path.join(out,prefix+'.log'),text+'\n');const at=text.indexOf('OUTGAME_STATE ');
   if(at>=0){try{state=JSON.parse(text.slice(at+14));states.push(state);}catch(e){if(text.trimEnd().endsWith('}'))errors.push('PROBE '+e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))errors.push(text);
  });
  page.on('pageerror',e=>errors.push(e.message));page.on('crash',()=>{closed=true;errors.push('Browser crashed');});
  page.on('response',r=>{if(r.status()>=400)httpFailures.push({status:r.status(),url:r.url()});});
  const check=(ok,label)=>{assert.ok(ok,label);checks.push(label);};
  async function wait(fn,label,limit=240000){const start=Date.now();let lastProbe=start;while(!state||!fn(state)){if(closed||errors.length)throw Error(label+': '+errors.join('\n'));if(Date.now()-start>limit)throw Error('Timeout '+label+' '+JSON.stringify(state));if(Date.now()-lastProbe>1000){lastProbe=Date.now();await page.keyboard.press('F8');}await sleep(100);}return state;}
  async function dump(){const n=states.length;await page.keyboard.press('F8');return wait(()=>states.length>n,'fresh state',10000);}
  async function tap(x,y){if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
  async function widget(text){const s=await dump(),item=s.widgets.find(w=>w.text===text);check(item,'actual '+text+' widget');const [x,y,w,h]=item.rect;await tap((x+w/2)/s.width*test.width,(y+h/2)/s.height*test.height);}
  async function shot(name){const file=path.join(out,prefix+'-'+name+'.png');await page.screenshot({path:file,timeout:10000});const stats=await sharp(file).stats();check(stats.channels.slice(0,3).some(c=>c.stdev>20),'nonblank '+name);report.shots.push({name,file,stdev:stats.channels.slice(0,3).map(c=>c.stdev)});return file;}
  async function clock(at){const start=Date.now();while((await dump()).battle.mvp.t<at){if(Date.now()-start>120000)throw Error('MVP clock timeout '+at);await sleep(100);}return state;}
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.mode==='hangar'&&s.tab==='hangar','hall');await widget('出战');await widget('歼灭战');await widget('开始匹配');
   await wait(s=>s.mode==='trial'&&s.battle&&!s.loadingFlow.active,'actual crater battle');
   if(state.intro?.active)await page.keyboard.press('Space');await sleep(300);
   await page.keyboard.down('Tab');await sleep(250);await shot('board');await page.keyboard.up('Tab');
   await page.keyboard.press('F2');await dump();await wait(s=>s.battle?.mvp?.active,'production MVP scene');
   const start=structuredClone(await dump());check(start.battle.state==='over'&&!start.pointer.captured,'MVP releases gameplay pointer');
   await clock(1);const rise=await shot('rise');await clock(2.45);await shot('burst');await clock(7.2);await shot('title');
   const shown=structuredClone(await dump());report.shown=shown.battle.mvp;
   check(shown.battle.mvp.stage.banner&&shown.battle.mvp.stage.column,'real banner and spiral visible');
   check(shown.battle.mvp.stage.uploads===1&&shown.battle.mvp.stage.smokeUploads===1,'GPU celebration meshes upload once');
   check(shown.battle.mvp.stage.bannerName&&shown.battle.mvp.stage.bannerRenders===1,'awarded name renders once');
   check(!Object.values(shown.widgets).some(w=>w.text==='回机库'),'result controls blocked during showcase');
   await page.keyboard.down('w');await page.mouse.click(test.width*.75,test.height*.25,{button:'right'});await sleep(700);await page.keyboard.up('w');
   const frozen=await dump();check(frozen.battle.timeLeft===start.battle.timeLeft&&!frozen.pointer.captured,'showcase inputs cannot resume combat');
   await page.keyboard.press('Space');await dump();await wait(s=>s.battle.mvp.done,'continue fade',30000);await shot('result');
   await widget('再来一局');await dump();await wait(s=>s.battle.state==='prep'&&!s.battle.mvp,'actual replay');check(!state.pointer.captured,'replay respects released pointer');
   await page.keyboard.press('F2');await dump();await wait(s=>s.battle.mvp.active,'second cinematic');await page.keyboard.press('Enter');await dump();
   check(state.battle.mvp.jumped&&state.battle.mvp.t>=7.1&&!state.battle.mvp.done,'first skip reaches showcase');
   if(test.touch)await tap(test.width*.8,test.height*.7);else await page.keyboard.press('Escape');await dump();await wait(s=>s.battle.mvp.done,'second skip ends cinematic');
   await widget('回机库');await dump();await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'return to actual hall');await shot('returned');
   check(state.performance.arrayBytes===0,'return releases battle terrain arrays');check(errors.length===0,'no unexpected runtime shader or Lua errors');report.result='PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await shot('failure').catch(()=>{});throw e;}
  finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:checks.length,errors:errors.length,httpFailures:httpFailures.length}));
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

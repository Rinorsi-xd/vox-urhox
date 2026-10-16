// Public matchmaking and Escape only; the matching QA package supplies state.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4337),root=path.resolve(__dirname,'../..');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa);
 const out=path.join(root,'docs/migration/evidence/map-cancel-'+identity.servedManifest.replace('.json','')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log(out);
 const report={identity,checks:[],states:[],errors:[],startedAt:new Date().toISOString(),boundary:'Actual public queue/load/cancel/recover. No failure injection, cloud account or performance acceptance.'};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:{width:1600,height:900}});let state,revision=0,closed=false;
 const deadline=Date.now()+480000;
 page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,'console.log'),line+'\n');
  const at=line.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(line.slice(at+14));revision++;}catch{report.truncated=(report.truncated||0)+1;}}
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
 });page.on('pageerror',e=>report.errors.push(String(e)));page.on('crash',()=>{closed=true;report.errors.push('Browser renderer crashed');void browser.close();});
 async function wait(fn,label){let next=0;while(!state||!fn(state)){
  if(closed||report.errors.length)throw Error(label+': '+report.errors.at(-1));
  if(Date.now()>deadline)throw Error('Timeout '+label);
  if(Date.now()>next){next=Date.now()+350;await page.keyboard.press('F8');}await sleep(70);
 }}
 async function dump(){const before=revision;await page.keyboard.press('F8');await wait(()=>revision>before,'fresh state');}
 async function click(text){await dump();const button=state.widgets.find(w=>w.text===text&&!w.disabled);assert(button,'public control '+text);
  const r=button.rect;await page.mouse.click((r[0]+r[2]/2)/state.width*1600,(r[1]+r[3]/2)/state.height*900,{delay:80});await sleep(200);
 }
 const check=(ok,label)=>{report.checks.push({label,pass:!!ok});assert(ok,label);};
 async function shot(name){
  const png=await page.screenshot({path:path.join(out,name+'.png')});
  const stats=await sharp(png).stats();
  check(stats.channels.slice(0,3).some(c=>c.stdev>15),'rendered nonblank '+name);
 }
 try{
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow.active,'normal hall');
  const before={blueprint:state.blueprint,parts:state.parts};
  for(let attempt=0;attempt<2;attempt++){
   if(state.tab!=='battle')await click('出战');await wait(s=>s.tab==='battle','mode picker');await click('歼灭战');await click('开始匹配');
   await wait(s=>s.mode==='loading'&&s.performance?.mapTransition?.released&&s.loadingFlow?.active,'old hall released behind actual loading page');
   check(!state.sceneVisible,'old hall has no active viewport '+attempt);
   const frames=state.loadingFlow.pageFrames;
   await wait(s=>s.loadingFlow?.pageFrames>=frames+3,'loading page still presents after hall disposal');
   check(state.loadingFlow.pageFrames>=frames+3,'shared UI frame survives hall disposal '+attempt);
   report.states.push({stage:'released-'+attempt,state:structuredClone(state)});
   await shot('released-'+attempt);
   await page.keyboard.press('Escape');
   await wait(s=>s.mode==='hangar'&&s.tab&&!s.loadingFlow?.active&&s.sceneVisible,'cancel restores authored hall');await dump();
   check(state.blueprint===before.blueprint&&state.parts===before.parts,'cancel preserves actual vehicle '+attempt);
   check(!state.loadingFlow.failed,'recovery completed without failed overlay '+attempt);
   check(state.performance?.mapTransition?.state==='idle','transition ownership cleared '+attempt);
   report.states.push({stage:'recovered-'+attempt,state:structuredClone(state)});
   await shot('recovered-'+attempt);
  }
  check(report.errors.length===0,'no runtime errors');report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;report.lastState=state;await page.screenshot({path:path.join(out,'failure.png'),timeout:5000}).catch(()=>{});process.exitCode=1;}
 finally{report.finishedAt=new Date().toISOString();fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));await browser.close();}
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,errors:report.errors.length}));
})().catch(error=>{console.error(error);process.exitCode=1;});

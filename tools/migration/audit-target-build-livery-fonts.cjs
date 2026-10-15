const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base=process.env.VOX_QA_BASE||'http://127.0.0.1:4296',sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json()),out=path.resolve('docs/migration/evidence/target-build-livery-fonts-'+identity.servedManifest.replace('.json','')+'-'+Date.now());fs.mkdirSync(out,{recursive:true});
 const report={identity,pages:[],errors:[],boundary:'Actual target clicks/keyboard, no injected game state. Screenshots not blanket visual acceptance.'};
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=d3d11']});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});let state,serial=0;
  page.on('console',m=>{const text=m.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');const at=text.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(text.slice(at+14));serial++;}catch{}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))report.errors.push(text);});page.on('pageerror',e=>report.errors.push(e.message));
  async function key(k){await page.keyboard.down(k);await sleep(80);await page.keyboard.up(k);}
  async function wait(fn,label,timeout=160000){const started=Date.now();let last=started;while(!state||!fn(state)){if(Date.now()-started>timeout)throw Error('Timeout '+label);if(Date.now()-last>1000){last=Date.now();await key('F8');}await sleep(100);}}
  async function dump(){const before=serial;await key('F8');await wait(()=>serial>before,'fresh state',15000);}
  async function click(text){await dump();const w=state.widgets.find(w=>w.text===text&&!w.disabled);assert(w,'Live entry '+text);await page.mouse.click(w.rect[0]+w.rect[2]/2,w.rect[1]+w.rect[3]/2,{delay:70});await sleep(700);await dump();}
  async function capture(name){await sleep(1000);await dump();report.pages.push({name,state:structuredClone(state)});await page.screenshot({path:path.join(out,name+'.png')});}
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&s.sceneVisible&&!s.loadingFlow.active,'home');await sleep(1000);
  await click('涂装');await wait(s=>s.tab==='livery','livery');await capture('livery');
  await click('机库');await key('e');await wait(s=>s.build&&!s.loadingFlow.active,'build');await capture('build');report.result='CAPTURED';
 }catch(e){report.result='FAIL';report.failure=e.stack;}
 finally{await browser.close();fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({out,result:report.result,pages:report.pages.map(p=>p.name),errors:report.errors,failure:report.failure},null,2));}
 if(report.result==='FAIL')process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});

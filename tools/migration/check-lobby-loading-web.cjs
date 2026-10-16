const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base=process.env.VOX_QA_BASE||'http://127.0.0.1:4450';
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa);
 const out=path.resolve('docs/migration/evidence/lobby-loading-'+identity.servedManifest.replace('.json','')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log('Evidence: '+out);
 const report={identity,checks:[],errors:[],httpFailures:[],samples:[],boundary:'Real public UI actions; local fresh session. No authenticated account or actual mobile hardware.'};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:{width:1600,height:900}});let state,seq=0,lastProbe=0,debugReady=false;
 page.on('console',message=>{const text=message.text();if(text.includes('[Debug] 点击 Debug'))debugReady=true;fs.appendFileSync(path.join(out,'console.log'),text+'\n');const i=text.indexOf('OUTGAME_STATE ');
  if(i>=0){try{state=JSON.parse(text.slice(i+14));seq++;report.samples.push(state);}catch(error){if(text.trimEnd().endsWith('}'))report.errors.push(error.message);}}
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))report.errors.push(text);
 });
 page.on('pageerror',e=>report.errors.push(e.stack||e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
 const check=(value,label)=>{assert(value,label);report.checks.push(label);};
 async function wait(fn,label,limit=240000){const started=Date.now();while(!state||!fn(state)){
  if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-started>limit)throw Error('Timeout '+label+' '+JSON.stringify(state));
  if(Date.now()-lastProbe>500){lastProbe=Date.now();await page.keyboard.press('F8');}await sleep(70);
 }return state;}
 async function dump(){const before=seq;await page.keyboard.press('F8');return wait(()=>seq>before,'probe',15000);}
 async function click(text,kind){await dump();const button=(state.widgets||[]).find(w=>w.text===text&&(!kind||w.kind===kind)&&!w.disabled);assert(button,'public button '+text);
  const [x,y,w,h]=button.rect,canvas=await page.locator('canvas').boundingBox();await page.mouse.click(canvas.x+(x+w/2)/state.width*canvas.width,canvas.y+(y+h/2)/state.height*canvas.height);
 }
 try{
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1'+(process.env.VOX_QA_QUERY||''));
  await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'hall');
  if(process.env.VOX_QA_DEBUG==='1'){
   check(debugReady,'Actual local build initializes user Debug panel');
   const canvas=await page.locator('canvas').boundingBox();
   const x=canvas.x+(state.width-47)/state.width*canvas.width,y=canvas.y+86/state.height*canvas.height;
   await page.mouse.click(x,y);await sleep(350);await page.screenshot({path:path.join(out,'debug-open.png')});
   await page.mouse.click(x,y);await sleep(350);
  }
  const started=Date.now();await click('打捞行动');
  await wait(s=>s.loadingFlow?.map==='salvage-lobby'&&s.loadingFlow.visible&&s.loadingFlow.phase==='loading'&&s.loadingFlow.pageFrames>=2,'presented depot page after reveal');
  check(state.loadingFlow.active&&state.loadingFlow.steps.length===6,'Source six-row depot page is presented after reveal');
  await page.screenshot({path:path.join(out,'loading-pc.png')});
  for(const [name,width,height] of [['tablet',1024,768],['landscape-20-9',1440,648]]){
   await page.setViewportSize({width,height});await sleep(250);await dump();
   await page.screenshot({path:path.join(out,'loading-'+name+'.png')});
  }
  await page.setViewportSize({width:1600,height:900});
  await wait(s=>s.tab==='salvage'&&s.warehouse?.ready&&!s.loadingFlow?.active,'salvage lobby');
  report.switchMs=Date.now()-started;await dump();report.final=state;
  check(state.lobby==='salvage'&&state.warehouse.ready,'Actual separate salvage warehouse is ready');
  check(state.loadingFlow.steps.every(step=>step.state==='done'),'All actual preparation tasks completed');
  check(state.loadingFlow.pageFrames>=2,'Preparation retained presented page gates');
  await page.screenshot({path:path.join(out,'lobby-ready.png')});
  const departure=(state.widgets||[]).find(w=>w.text==='出发');
  check(departure&&!departure.disabled,'Fresh saved starter passes actual inventory validation');
  if(process.env.VOX_QA_DEPLOY==='1'){
   await click('出发');await wait(s=>s.mode==='trial'&&s.map==='salvage'&&!s.loadingFlow.active,'actual salvage deployment',300000);
   await dump();report.deployed=state;await page.screenshot({path:path.join(out,'deployed.png')});
   check(!!state.salvageRun,'Public departure reaches actual salvage runtime');
  }
  check(report.errors.length===0&&report.httpFailures.length===0,'No runtime or resource errors');report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;report.lastState=state;await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});}
 finally{await browser.close();fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2)+'\n');}
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,errors:report.errors.length,switchMs:report.switchMs,evidence:out}));
 if(report.result!=='PASS')process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1;});

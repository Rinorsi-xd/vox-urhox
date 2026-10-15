const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base=process.env.VOX_QA_BASE||'http://127.0.0.1:4294';
const output=process.env.VOX_QA_OUTPUT_DIR||path.join(root,'docs/migration/evidence','drive-readouts-web-'+Date.now());
fs.mkdirSync(output,{recursive:true});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=d3d11']});
 let failure=false;
 try{for(const test of [{name:'pc',width:1920,height:1080},{name:'20x9-touch',width:840,height:378,dpr:3,touch:true}]){
  const report={identity,test,checks:[],errors:[],httpFailures:[],samples:[]};let state,sequence=0;
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{isMobile:true,hasTouch:true}:{})});
  page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(output,test.name+'.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');
   if(at>=0){try{state=JSON.parse(line.slice(at+14));sequence++;}catch{}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  async function key(k){await page.keyboard.down(k);await sleep(80);await page.keyboard.up(k);}
  async function wait(fn,label,timeout=160000){const at=Date.now();let last=at;while(!state||!fn(state)){
   if(report.errors.length)throw Error(report.errors[0]);if(Date.now()-at>timeout)throw Error('Timeout '+label);
   if(Date.now()-last>1000){last=Date.now();await key('F8');}await sleep(100);
  }return state;}
  async function dump(){const last=sequence;await key('F8');await wait(()=>sequence>last,'state',10000);report.samples.push(structuredClone(state));return state;}
  const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
  async function shot(name){await dump();await page.screenshot({path:path.join(output,test.name+'-'+name+'.png')});}
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar'&&!s.loadingFlow.active,'home');await key('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'natural trial');
   if(test.touch)await page.touchscreen.tap(test.width/2,test.height/2);else await page.mouse.click(test.width/2,test.height/2);
   await wait(s=>s.pointer.captured,'driving input');await shot('summary');check(!state.reticle.legacyMeter,'legacy speed surface remains hidden');
   await key('i');await sleep(350);await shot('details');const before=state.camera.dist;
   await page.mouse.move(test.width/2,test.height*.75);await page.mouse.wheel(0,600);await sleep(300);await shot('details-wheel');
   check(Math.abs(state.camera.dist-before)<.0001,'detail wheel does not zoom the production camera');
   await key('i');await sleep(300);await shot('closed');
   if(!test.touch){await page.mouse.wheel(0,100);await sleep(250);await dump();check(Math.abs(state.camera.dist-before)>.01,'closing details restores actual camera wheel zoom');}
   await key('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'return home');check(!state.reticle,'return releases driving HUD');
   check(report.errors.length===0,'no runtime errors');report.result='PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;failure=true;await page.screenshot({path:path.join(output,test.name+'-failure.png')}).catch(()=>{});}
  fs.writeFileSync(path.join(output,test.name+'.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length,manifest:identity.servedManifest}));await page.close();
 }}finally{await browser.close();}
 console.log(output);if(failure)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});

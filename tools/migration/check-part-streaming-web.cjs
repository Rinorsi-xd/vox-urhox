const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path));
const catalog=JSON.parse(fs.readFileSync(path.join(root,'assets/Parts/Catalog.json')));
const dependencies=JSON.parse(fs.readFileSync(path.join(root,'assets/Parts/Dependencies.json')));
const files=manifest.files.filter(f=>/^Parts\/Models\/.+\.bin$/.test(f.fs_path));
assert.equal(files.length,579);
for(const f of files)assert.ok(!(f.groups||[]).some(g=>g==='boot'||g==='#blocking'),f.fs_path+' must be deferred');
const byUrl=new Map(manifest.files.map(f=>[f.uuid+'-'+f.hash+f.ext,f]));
const models=parts=>new Set(parts.flatMap(p=>assert(dependencies[p.type],p.type)||dependencies[p.type]).filter(p=>p.endsWith('.bin')));
const race=models(catalog.presets.buildRaceCar.parts),scorpion=models(catalog.presets.buildScorpion.parts),hawk=models(catalog.presets.buildHawk.parts);
const ghostType='light',ghostModels=new Set(dependencies[ghostType].filter(p=>p.endsWith('.bin')));
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const cases=[{name:'pc',width:1920,height:1080,dpr:1},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(c.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,hasTouch:!!test.touch,isMobile:!!test.touch});
  const context=page.context(),cdp=await context.newCDPSession(page);
  await cdp.send('Network.enable');await cdp.send('Network.setCacheDisabled',{cacheDisabled:true});
  let state,phase='boot',held=new Set(),releases=[];
  const states=[],requests=[],responses=[],errors=[],cancelled=[],httpErrors=[],checks=[],probeIssues=[];
  const requestPhases=new WeakMap(),cancelPhases=new Set();
  const log=path.join(out,'part-streaming-web-'+test.name+'.log');fs.writeFileSync(log,'');
  page.on('console',msg=>{const line=msg.text();fs.appendFileSync(log,line+'\n');const index=line.indexOf('OUTGAME_STATE ');if(index>=0){try{state=JSON.parse(line.slice(index+14));states.push(state);}catch(e){probeIssues.push({message:e.message,bytes:Buffer.byteLength(line),tail:line.slice(-100)});}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))errors.push(line);});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('request',request=>{requestPhases.set(request,phase);const file=byUrl.get(new URL(request.url()).pathname.split('/').pop());if(file)requests.push({path:file.fs_path,bytes:file.size,phase,time:Date.now()});});
  page.on('response',response=>{const file=byUrl.get(new URL(response.url()).pathname.split('/').pop());if(response.status()>=400)httpErrors.push({url:response.url(),status:response.status(),phase});if(file&&response.ok())responses.push({path:file.fs_path,phase});});
  page.on('requestfailed',request=>{const file=byUrl.get(new URL(request.url()).pathname.split('/').pop());const message=request.url()+' '+request.failure()?.errorText;
   if(cancelPhases.has(requestPhases.get(request))&&file?.fs_path.startsWith('Parts/')&&request.failure()?.errorText==='net::ERR_ABORTED')cancelled.push(message);else errors.push(message);
  });
  await page.route('**/game-dist/assets/*',async route=>{const file=byUrl.get(new URL(route.request().url()).pathname.split('/').pop());if(file&&held.has(file.fs_path))await new Promise(resolve=>releases.push(resolve));try{await route.continue();}catch(e){if(!cancelPhases.has(requestPhases.get(route.request())))errors.push(e.message);}});
  function release(){held=new Set();for(const done of releases)done();releases=[];}
  async function wait(predicate,label,timeout=180000){const start=Date.now();let lastProbe=start;while(!state||!predicate(state)){if(Date.now()-start>timeout)throw Error('Timeout '+label);if(Date.now()-lastProbe>1000){lastProbe=Date.now();await page.keyboard.press('F8',{delay:100});}await sleep(100);}return state;}
  async function dump(){const n=states.length;await page.keyboard.press('F8',{delay:100});return wait(()=>states.length>n,'probe',15000);}
  async function click(text,match){await dump();const widget=state.widgets.find(w=>w.text===text&&!w.disabled&&(!match||match(w)));assert.ok(widget,'Visible command '+text);const [x,y,w,h]=widget.rect,canvas=await page.locator('canvas').boundingBox();const px=canvas.x+(x+w/2)/state.width*canvas.width,py=canvas.y+(y+h/2)/state.height*canvas.height;assert.ok(px>=0&&py>=0&&px<test.width&&py<test.height,'Command fits '+text);if(test.touch)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);await sleep(150);await dump();}
  async function shot(name){await page.screenshot({path:path.join(out,'part-streaming-web-'+test.name+'-'+name+'.png')});}
  async function detail(){await dump();if(state.workshop.view==='feature')await click('查看详情');else{await sleep(900);await click('隼',w=>!!w.card);}}
  async function sample(label){await dump();await sleep(5000);await dump();return {label,...state.frames,performance:state.performance};}
  let report;const start=Date.now();
  try{
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar','home');await sleep(2000);await dump();
   const startup=requests.filter(r=>/^Parts\/Models\//.test(r.path));
   assert.ok(startup.length>0&&startup.length<files.length,'Only initial car models requested');
   assert.ok(startup.every(r=>race.has(r.path)),'No unrelated part model at boot');
   assert.equal(new Set(startup.map(r=>r.path)).size,race.size,'All initial car dependencies downloaded');
   assert.equal(state.carVisuals,state.parts,'Complete initial car');checks.push('Boot requests only the complete initial car');
   const boot={ms:Date.now()-start,models:race.size,modelBytes:startup.reduce((sum,r)=>sum+r.bytes,0),deferredModelBytes:files.reduce((sum,f)=>sum+f.size,0)};
   const original={name:state.blueprint,parts:state.parts,visuals:state.carVisuals,garage:state.garage};await shot('home');
   phase='home-cancel';held=scorpion;
   await click('创意工坊');await wait(s=>s.tab==='workshop'&&s.workshop?.selected==='scorpion','feature');await sleep(900);
   await click('放进新车位');await wait(s=>s.vehicleLoading.busy&&s.vehicleLoading.state==='loading','pending car');
   assert.equal(state.blueprint,original.name);assert.equal(state.carVisuals,original.visuals);assert.deepEqual(state.garage,original.garage);
   checks.push('Cold home replacement preserves old vehicle and slots');await shot('pending-home');
   cancelPhases.add(phase);await click('机库');await wait(s=>s.tab==='hangar'&&!s.vehicleLoading.busy,'cancel home');release();await sleep(1200);await dump();
   assert.equal(state.blueprint,original.name);assert.deepEqual(state.garage,original.garage);checks.push('Leaving cancels home replacement before storage mutation');
   phase='detail-cancel';held=hawk;
   await click('创意工坊');await wait(s=>s.tab==='workshop','workshop again');await click('隼',w=>!w.card);
   await wait(s=>s.workshop?.selected==='hawk'&&!s.workshop.pending,'hawk artwork');await sleep(1100);await click('查看详情');
   await wait(s=>s.workshop?.view==='detail'&&s.preview&&!s.preview.ready,'held detail');assert.equal(state.preview.cursor,1);checks.push('Detail waits before native model construction');await shot('pending-detail');
   cancelPhases.add(phase);await click('机库');release();await sleep(1200);await dump();assert.equal(state.tab,'hangar');assert.ok(!state.preview);assert.equal(state.carVisuals,original.visuals);checks.push('Late detail response cannot resurrect disposed preview');
   phase='detail-retry';await click('创意工坊');await wait(s=>s.tab==='workshop','workshop retry');await detail();
   await wait(s=>s.preview?.complete,'detail retry');assert.equal(state.preview.total,catalog.presets.buildHawk.parts.length);assert.ok([...hawk].every(p=>responses.some(r=>r.path===p)));checks.push('Detail retry assembles all selected source parts');await sleep(1500);await shot('detail');
   await click('机库');await wait(s=>s.tab==='hangar','home');
   phase='ghost-cancel';held=ghostModels;await click('改装');await wait(s=>s.build&&s.ghost?.ready,'builder');
   await click('',w=>w.part===ghostType);await wait(s=>s.ghost?.type===ghostType&&s.ghost.state==='loading','held ghost');assert.equal(state.ghost.ready,false);assert.equal(state.ghost.pool,0);assert.equal(state.parts,original.parts);checks.push('Cold selected part waits without placement');await shot('pending-ghost');
   cancelPhases.add(phase);await click('',w=>w.part==='cube');await wait(s=>s.ghost?.type==='cube'&&s.ghost.ready,'cancel ghost');release();await sleep(1200);await dump();assert.equal(state.ghost.type,'cube');assert.equal(state.parts,original.parts);checks.push('Hotbar switch rejects late ghost response');
   phase='ghost-retry';await click('',w=>w.part===ghostType);await wait(s=>s.ghost?.type===ghostType&&s.ghost.ready,'ghost retry');await page.mouse.move(test.width*.48,test.height*.55);await sleep(600);await dump();
   assert.ok([...ghostModels].every(p=>responses.some(r=>r.path===p)));checks.push('Ghost retry downloads the complete selected part');await shot('ghost');
   await click('机库');await wait(s=>!s.build&&s.tab==='hangar','builder return');
   const frameSamples=[await sample('home-after-downloads')];
   phase='pressure';const before=requests.filter(r=>/^Parts\/Models\//.test(r.path)).length;
   for(let i=0;i<4;i++){
    await click('创意工坊');await wait(s=>s.tab==='workshop','pressure workshop');await detail();await wait(s=>s.preview?.complete,'pressure preview');
    await click('机库');await wait(s=>s.tab==='hangar'&&!s.preview,'pressure home');await click('改装');await wait(s=>s.build&&s.ghost?.ready,'pressure build');await click('机库');await wait(s=>!s.build&&s.tab==='hangar','pressure builder close');
   }
   assert.equal(requests.filter(r=>/^Parts\/Models\//.test(r.path)).length,before,'Cached cycles do not redownload models');assert.equal(state.carVisuals,original.visuals);assert.deepEqual(state.garage,original.garage);checks.push('Four cached preview/build cycles preserve car and avoid redownload');
   frameSamples.push(await sample('home-after-pressure'));await shot('final');
   phase='home-retry';await click('创意工坊');await wait(s=>s.tab==='workshop','home retry feature');
   if(state.workshop.view==='browse')await click('',w=>w.icon==='back');
   await wait(s=>s.workshop?.view==='feature','original featured page');await click('蝎型战车',w=>!w.card);await wait(s=>s.workshop?.selected==='scorpion'&&!s.workshop.pending,'scorpion artwork');await sleep(900);
   await click('放进新车位');await wait(s=>s.tab==='hangar'&&s.blueprint===catalog.presets.buildScorpion.name&&!s.vehicleLoading.busy,'replacement retry');await sleep(800);await dump();
   const savedDraft=!original.garage.active&&original.parts>1;
   assert.equal(state.build,false);assert.equal(state.parts,catalog.presets.buildScorpion.parts.length);assert.equal(state.carVisuals,state.parts);assert.equal(state.garage.used,original.garage.used+1+(savedDraft?1:0));
   if(savedDraft)assert.equal(state.garage.slots.find(s=>s&&s.name===original.name)?.parts,original.parts,'Source keepCurrent saves the unslotted car');
   assert.equal(state.garage.slots[state.garage.active-1].name,catalog.presets.buildScorpion.name);checks.push('Retry preserves unslotted draft and adds one complete source vehicle');await shot('replaced');assert.equal(errors.length,0,errors.join('\n'));
   const gpu=await page.evaluate(()=>{const gl=document.querySelector('canvas').getContext('webgl2'),ext=gl?.getExtension('WEBGL_debug_renderer_info');return ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):'unknown';});
   report={result:'PASS',build:{directory:path.basename(prepared.source_directory),manifest:path.basename(prepared.manifest_path)},viewport:test,gpu,checks,boot,frameSamples,errors,probeIssues,cancelled,httpErrors,requests};
  }catch(e){release();report={result:'FAIL',build:prepared.source_directory,checks,failure:e.message,state,errors,probeIssues,cancelled,httpErrors,requests};await shot('failure');}
  fs.writeFileSync(path.join(out,'part-streaming-web-'+test.name+'.json'),JSON.stringify(report,null,2));
  release();await cdp.detach();await context.close();console.log(test.name+' '+report.result+' '+JSON.stringify({checks:checks.length,boot:report.boot,failure:report.failure}));if(report.result!=='PASS')throw Error(report.failure);
 }}finally{await browser.close();}
})().catch(e=>{console.error(e.stack);process.exitCode=1;});

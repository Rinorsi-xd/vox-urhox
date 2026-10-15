const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path));
const modelFiles=manifest.files.filter(f=>/^Crater\/mesh-\d+\.bin$/.test(f.fs_path));
assert.equal(modelFiles.length,300,'Every source map model remains packaged');
for(const f of modelFiles)assert.ok(!(f.groups||[]).some(g=>g==='boot'||g==='#blocking'),'Map model must be deferred: '+f.fs_path);
const modelByUrl=new Map(modelFiles.map(f=>[f.uuid+'-'+f.hash+f.ext,f]));
const modelPaths=new Set(modelFiles.map(f=>f.fs_path));
const allByUrl=new Map(manifest.files.map(f=>[f.uuid+'-'+f.hash+f.ext,f]));
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const cases=[{name:'pc',width:1920,height:1080,dpr:1},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{
  for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(c.name))){
   const evidenceName=test.name+(process.env.VOX_QA_WEAK==='1'?'-weak':'');
   const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,hasTouch:!!test.touch,isMobile:!!test.touch});
   const context=page.context();const cdp=await context.newCDPSession(page);
   await cdp.send('Network.enable');await cdp.send('Network.setCacheDisabled',{cacheDisabled:true});
   let state,phase='boot',hold=false,releases=[],cancelRequested=false;const requestPhases=new WeakMap();const states=[],errors=[],cancelled=[],requests=[],responses=[],checks=[];
   const log=path.join(out,'crater-streaming-web-'+evidenceName+'.log');fs.writeFileSync(log,'');
   page.on('console',msg=>{const line=msg.text();fs.appendFileSync(log,line+'\n');const index=line.indexOf('OUTGAME_STATE ');if(index>=0){try{state=JSON.parse(line.slice(index+14));states.push(state);}catch(e){errors.push(e.message);}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))errors.push(line);});
   page.on('pageerror',e=>errors.push(e.message));
   page.on('request',request=>{requestPhases.set(request,phase);const key=new URL(request.url()).pathname.split('/').pop();const file=allByUrl.get(key);if(file)requests.push({path:file.fs_path,bytes:file.size,phase,time:Date.now()});});
   page.on('response',response=>{const key=new URL(response.url()).pathname.split('/').pop();const file=allByUrl.get(key);if(file&&response.ok())responses.push({path:file.fs_path,phase});});
   page.on('requestfailed',request=>{const file=allByUrl.get(new URL(request.url()).pathname.split('/').pop()),message=request.url()+' '+request.failure()?.errorText;if(cancelRequested&&requestPhases.get(request)==='cancel'&&file?.fs_path.startsWith('Crater/')&&request.failure()?.errorText==='net::ERR_ABORTED')cancelled.push(message);else errors.push(message);});
   await page.route('**/game-dist/assets/*',async route=>{
    const file=modelByUrl.get(new URL(route.request().url()).pathname.split('/').pop());
    if(file&&hold)await new Promise(resolve=>releases.push(resolve));
    try{await route.continue();}catch(e){if(phase!=='cancel')errors.push('Route '+e.message);}
   });
   async function wait(predicate,label,timeout=180000){const start=Date.now();while(!state||!predicate(state)){if(state?.loading.state==='failed')throw Error('Production loader failed '+label+' '+JSON.stringify(state.loading));if(Date.now()-start>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));await sleep(100);}return state;}
   async function dump(){const count=states.length;await page.keyboard.press('F8',{delay:100});return wait(()=>states.length>count,'state',15000);}
   async function key(name){await page.keyboard.press(name,{delay:100});await sleep(150);await dump();}
   async function sample(label){await dump();await sleep(Number(process.env.VOX_QA_SAMPLE_MS||15000));await dump();assert.ok(state.frames?.count>100,label+' has sustained frame samples');return {...state.frames,label};}
   const started=Date.now();let report;
   try{
    await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
    await wait(s=>s.tab==='hangar','home');await sleep(2500);await dump();
    const boot={ms:Date.now()-started,requests:requests.length,bytes:requests.reduce((sum,r)=>sum+r.bytes,0)};
    assert.equal(requests.filter(r=>modelPaths.has(r.path)).length,0,'Unselected map models generate no startup requests');
    assert.equal(state.craterModelResident,false,'Unselected map has no native model');checks.push('No map models downloaded or loaded at boot');
    await page.screenshot({path:path.join(out,'crater-streaming-web-'+evidenceName+'-home.png')});
    const homeFrames=await sample('home');
    const network=process.env.VOX_QA_WEAK==='1'?{offline:false,latency:150,downloadThroughput:2*1024*1024,uploadThroughput:1024*1024}:null;
    if(network)await cdp.send('Network.emulateNetworkConditions',network);
    phase='cancel';hold=true;await key('F7');await wait(s=>s.loading.state==='loading'&&s.loading.phase==='download','map download');
    assert.equal(state.mapPreview,false,'Active hall survives pending model download');checks.push('Hall remains active while map downloads');
    cancelRequested=true;await key('Escape');assert.equal(state.loading.state,'idle','Cancellation clears loader');assert.equal(state.mapPreview,false,'Cancelled map never activates');checks.push('Cold map entry cancels without activation');
    hold=false;for(const release of releases)release();releases=[];await sleep(1000);
    phase='retry';const retryStarted=Date.now();await key('F7');await wait(s=>s.mapPreview&&s.previewMap==='crater','retry map');await sleep(3500);await dump();
    const mapMs=Date.now()-retryStarted;
    assert.equal(state.craterModelResident,true,'UMDL binary loads through native Model cache');
    const downloads=new Set(responses.filter(r=>/^Crater\/mesh-\d+\.bin$/.test(r.path)).map(r=>r.path));
    assert.equal(downloads.size,modelFiles.length,'All selected map models download before activation');checks.push('Retry downloads all 300 native models and activates map');
    await page.screenshot({path:path.join(out,'crater-streaming-web-'+evidenceName+'-map.png')});
    const mapFrames=await sample('map');
    phase='return';await key('Escape');await wait(s=>!s.mapPreview&&s.loading.state==='ready','return');await sleep(2500);await dump();
    assert.equal(state.craterModelResident,false,'Map models release on return');checks.push('Returning retires native map resources');
    phase='cached';const warmStarted=Date.now();await key('F7');await wait(s=>s.mapPreview,'cached map');const warmMs=Date.now()-warmStarted;await key('Escape');
    checks.push('Downloaded map can be entered again');assert.equal(errors.length,0,errors.join('\n'));
    const gpu=await page.evaluate(()=>{const gl=document.querySelector('canvas').getContext('webgl2'),ext=gl?.getExtension('WEBGL_debug_renderer_info');return ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):'unknown';});
    report={result:'PASS',build:prepared.source_directory,viewport:[test.width,test.height],gpu,network,checks,boot,mapMs,warmMs,frames:[homeFrames,mapFrames],downloadedModels:downloads.size,deferredBytes:modelFiles.reduce((s,f)=>s+f.size,0),errors,cancelled,requests};
   }catch(e){report={result:'FAIL',build:prepared.source_directory,checks,errors,cancelled,failure:e.message,state,requests};hold=false;for(const release of releases)release();await page.screenshot({path:path.join(out,'crater-streaming-web-'+evidenceName+'-failure.png')});}
   fs.writeFileSync(path.join(out,'crater-streaming-web-'+evidenceName+'.json'),JSON.stringify(report,null,2));
   await cdp.detach();await page.close();console.log(test.name+' '+report.result+' '+JSON.stringify({boot:report.boot,frames:report.frames,failure:report.failure}));if(report.result!=='PASS')throw Error(report.failure);
  }
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});

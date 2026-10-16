const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
function validate(result,mode){
 assert.equal(result.result,'PASS',result.message);assert.equal(result.mode,mode);assert.equal(result.rows.length,2);
 const [initial,warm]=result.rows;assert.equal(initial.label,'initial');assert.equal(warm.label,'warm');
 assert(initial.resources.every(r=>r.existsBefore===false),'New browser context must start without the two local files');
 assert(warm.synchronous===true,'Actual downloaded-resource synchronous gate fastpath');
 assert(warm.resources.every(r=>r.existsBefore===true));
 for(const row of result.rows){
  assert(row.downloadOK);assert(row.requestWall<=row.callbackEnterWall);assert(row.callbackExitWall<=row.nextUpdateWall);
  assert(row.nextUpdateFrame>row.callbackFrame);assert.equal(row.resources.length,2);
  if(mode==='prepare')for(const resource of row.resources){
   assert(resource.readyWall>=row.nextUpdateWall,'Readiness only observed in Update');
   if(resource.queueWall!==undefined){assert(resource.queueFrame>row.callbackFrame);assert(resource.queueReturnWall>=resource.queueWall);assert(resource.readyWall>=resource.queueWall);assert(resource.queued)}
  }
 }
 if(mode==='prepare'){assert(initial.resources.every(r=>r.residentBefore===false));assert(warm.resources.every(r=>r.residentBefore===true))}
 assert(result.frames.length>=30,'Frame intervals during actual download and preparation');
}
async function selfTest(){
 const {prepare,createServer}=require('./serve-sound-callback.cjs');
 const evidence={result:'RUNNING',startedAt:new Date().toISOString(),toolHashes:{},modes:[],boundary:'Actual HTTP server and frozen bytes plus actual Lua lifecycle on CPU fake native methods. No browser/GPU execution.'};
 for(const name of ['probe-sound-callback.lua','serve-sound-callback.cjs','check-sound-callback-web.cjs','check-sound-callback-fixture.py'])evidence.toolHashes[name]=sha(path.join(__dirname,name));
 for(const mode of ['download','prepare']){
  const fixture=prepare({mode});assert.equal(fixture.identity.resources.length,2);assert.equal(fixture.identity.preload.length,3);
  assert(!/require[^\n]*(HangarApp|VOX_HANGAR|OpeningHost)/.test(fixture.entry));
  const server=createServer(fixture);await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try{
   const base='http://127.0.0.1:'+server.address().port;
   assert.deepEqual(await fetch(base+'/identity.json').then(r=>r.json()),fixture.identity);
   const manifest=await fetch(base+'/game-dist/1.0.0/manifest-35b14da3.json').then(r=>r.json());assert.deepEqual(manifest.preload_groups,['qa']);
   assert.equal(await fetch(base+'/game-dist/assets/'+fixture.mainName).then(r=>r.text()),fixture.entry);
   for(const row of fixture.identity.resources){const body=Buffer.from(await fetch(base+'/game-dist/assets/'+row.payload).then(r=>r.arrayBuffer()));assert.equal(crypto.createHash('sha256').update(body).digest('hex'),row.sha256)}
   assert.equal((await fetch(base+'/game-dist/%2e%2e/%2e%2e/package.json')).status,404);
   evidence.modes.push({mode,identity:fixture.identity,http:'PASS'});
  }finally{await new Promise(r=>server.close(r))}
 }
 const python='C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe';
 evidence.actualLua=require('node:child_process').execFileSync(python,[path.join(__dirname,'check-sound-callback-fixture.py')],{encoding:'utf8',windowsHide:true}).trim();
 evidence.result='PASS';evidence.finishedAt=new Date().toISOString();
 const target=path.join(root,'docs/migration/evidence/sound-callback-cpu-selftest.json');fs.writeFileSync(target,JSON.stringify(evidence,null,2));
 console.log(evidence.actualLua);console.log(target);
 console.log('PASS: exact frozen bytes, isolated entry/preload HTTP overrides and actual Lua cold/warm gate/queue lifecycle. No GPU/browser started.');
}
async function run(){
 const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
 const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4420);
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa&&identity.soundCallbackProbe);
 assert.equal(identity.servedManifest,'manifest-35b14da3.json');assert.equal(identity.probeSha256,sha(path.join(__dirname,'probe-sound-callback.lua')));
 const folder=path.join(root,'docs/migration/evidence','sound-callback-'+identity.mode+'-'+new Date().toISOString().replaceAll(':','-').replaceAll('.','-'));
 fs.mkdirSync(folder,{recursive:true});const log=path.join(folder,'runtime.log');fs.writeFileSync(log,'');
 const report={result:'RUNNING',identity,errors:[],httpFailures:[],network:[],startedAt:new Date().toISOString(),shutdown:'PENDING',toolHashes:{}};
 for(const name of ['probe-sound-callback.lua','serve-sound-callback.cjs','check-sound-callback-web.cjs'])report.toolHashes[name]=sha(path.join(__dirname,name));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});let outcome;
 try{
  const context=await browser.newContext({viewport:{width:800,height:450}});const page=await context.newPage();const cdp=await context.newCDPSession(page);
  await cdp.send('Network.enable');await cdp.send('Network.setCacheDisabled',{cacheDisabled:true});
  for(const name of ['requestWillBeSent','responseReceived','loadingFinished','loadingFailed'])cdp.on('Network.'+name,data=>report.network.push({event:name,...data}));
  await page.addInitScript(()=>{
   window.__soundFrames=[];window.__soundTasks=[];window.__soundXHR=[];
   let previous=performance.now();function tick(at){window.__soundFrames.push({at,ms:at-previous});previous=at;if(window.__soundFrames.length<30000)requestAnimationFrame(tick)}requestAnimationFrame(tick);
   try{new PerformanceObserver(list=>{for(const row of list.getEntries())window.__soundTasks.push({at:row.startTime,ms:row.duration})}).observe({entryTypes:['longtask']})}catch{}
   const open=XMLHttpRequest.prototype.open,send=XMLHttpRequest.prototype.send;
   XMLHttpRequest.prototype.open=function(method,url,...rest){this.__soundURL=String(url);return open.call(this,method,url,...rest)};
   XMLHttpRequest.prototype.send=function(...args){
    const record={url:this.__soundURL,send:performance.now(),sendEpoch:Date.now()};window.__soundXHR.push(record);
    const onload=this.onload;
    if(typeof onload==='function')this.onload=function(...values){record.onloadEnter=performance.now();record.onloadEnterEpoch=Date.now();try{return onload.apply(this,values)}finally{record.onloadExit=performance.now();record.onloadExitEpoch=Date.now();record.status=this.status;record.byteLength=this.response?.byteLength}};
    return send.apply(this,args);
   };
  });
  page.on('console',message=>{const line=message.text();fs.appendFileSync(log,line+'\n');const at=line.indexOf('SOUND_CALLBACK_RESULT ');if(at>=0){try{outcome=JSON.parse(line.slice(at+22))}catch(e){report.errors.push(e.message)}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(/.test(line))report.errors.push(line)});
  page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({url:r.url(),status:r.status()})});
  await page.goto(base+'/sound-callback.html?-game_url='+base+'/game-dist/&-log=info');
  const deadline=Date.now()+150000;
  while(!outcome&&Date.now()<deadline){if(report.errors.length)throw Error(report.errors.join('\n'));await sleep(100)}
  assert(outcome,'150-second result timeout');report.runtime=outcome;validate(outcome,identity.mode);
  report.browser=await page.evaluate(()=>({timeOrigin:performance.timeOrigin,now:performance.now(),raf:window.__soundFrames,longTasks:window.__soundTasks,xhr:window.__soundXHR,
   resources:performance.getEntriesByType('resource').map(e=>({name:e.name,startTime:e.startTime,responseEnd:e.responseEnd,duration:e.duration,transferSize:e.transferSize,encodedBodySize:e.encodedBodySize}))}));
  report.soundXHR=report.browser.xhr.filter(row=>identity.resources.some(r=>row.url?.includes(r.payload)));
  assert.equal(report.soundXHR.length,2,'Exact two original resource requests; warm gate must not download again');
  for(const row of report.soundXHR){assert(row.onloadEnter!==undefined&&row.onloadExit>=row.onloadEnter,'Actual XHR onload entry/exit captured');row.onloadDurationMs=row.onloadExit-row.onloadEnter}
  const intervals=outcome.frames.filter(f=>f.phase!=='boot').map(f=>f.ms).sort((a,b)=>a-b);
  assert(intervals.length);report.frameIntervals={count:intervals.length,maxMs:intervals.at(-1),p95Ms:intervals[Math.floor(intervals.length*.95)]};
  report.responsiveness=report.frameIntervals.maxMs<=100?'PASS':'FAIL';
  report.result=report.errors.length||report.httpFailures.length?'FAIL':'PASS';
  report.boundary='Lifecycle PASS is separate from strict 100ms responsiveness. CDP transfer finish, JS onload duration, native Lua clock and observer-ready clocks retained separately. No root-cause/lock-owner, playback, complete opening, mobile or production speedup claim.';
 }catch(e){report.result='FAIL';report.failure=e.stack;process.exitCode=1}
 finally{await browser.close();report.shutdown='CLOSED';report.finishedAt=new Date().toISOString();fs.writeFileSync(path.join(folder,'result.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({result:report.result,responsiveness:report.responsiveness,frameIntervals:report.frameIntervals,soundXHR:report.soundXHR,failure:report.failure,folder},null,2))}
}
if(require.main===module)(process.argv.includes('--self-test')?selfTest():run()).catch(e=>{console.error(e);process.exitCode=1});
module.exports={validate};

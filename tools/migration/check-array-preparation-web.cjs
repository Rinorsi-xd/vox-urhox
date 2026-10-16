const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4418),sleep=ms=>new Promise(r=>setTimeout(r,ms));
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.arrayProbe&&identity.qa,'Isolated array experiment server required');
 assert.equal(identity.servedManifest,process.env.VOX_EXPECT_MANIFEST||'manifest-80e98fd5.json');
 assert.equal(identity.probeSha256,hash(path.join(__dirname,'probe-array-preparation.lua')),'Actual served experiment probe');
 const folder=path.join(root,'docs/migration/evidence','array-preparation-'+identity.mode+'-'+new Date().toISOString().replaceAll(':','-').replaceAll('.','-'));
 fs.mkdirSync(folder,{recursive:true});const log=path.join(folder,'runtime.log');fs.writeFileSync(log,'');
 const report={result:'RUNNING',identity,errors:[],httpFailures:[],toolHashes:{},startedAt:new Date().toISOString(),shutdown:'PENDING'};
 for(const file of ['probe-array-preparation.lua','serve-array-preparation.cjs','check-array-preparation-web.cjs'])report.toolHashes[file]=hash(path.join(__dirname,file));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});let outcome;
 try{
  const page=await browser.newPage({viewport:{width:1600,height:900}});
  await page.addInitScript(()=>{window.__arrayFrames=[];window.__arrayTasks=[];let last=performance.now();function frame(t){window.__arrayFrames.push({at:t,ms:t-last});last=t;requestAnimationFrame(frame)}requestAnimationFrame(frame);try{new PerformanceObserver(list=>{for(const e of list.getEntries())window.__arrayTasks.push({at:e.startTime,ms:e.duration})}).observe({entryTypes:['longtask']})}catch{}});
  page.on('console',m=>{const line=m.text();fs.appendFileSync(log,line+'\n');const at=line.indexOf('ARRAY_PROBE_RESULT ');if(at>=0){try{outcome=JSON.parse(line.slice(at+19))}catch(e){report.errors.push(e.message)}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(/.test(line))report.errors.push(line)});
  page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()})});
  await page.goto(base+'/array-probe.html?-game_url='+base+'/game-dist/&-log=info');
  const deadline=Date.now()+240000;
  while(!outcome&&Date.now()<deadline){if(report.errors.length)throw Error(report.errors.join('\n'));await sleep(100)}
  assert(outcome,'Runtime result timeout');report.runtime=outcome;
  report.browser=await page.evaluate(()=>({raf:window.__arrayFrames,longTasks:window.__arrayTasks}));
  assert.equal(outcome.result,'PASS',outcome.message);assert.equal(outcome.rows.length,2,'Two original arrays');
  for(const row of outcome.rows){assert.equal(row.layers,6);assert.equal(row.width,1024);assert.equal(row.height,1024);assert.equal(row.levels,11);assert.equal(row.memoryBytes,33554792);assert(row.referenceMatched);assert(row.readyMs>=row.queueMs)}
  assert.equal(outcome.rows[0].format,outcome.rows[1].format,'Array formats equal');
  assert.equal(outcome.cleanup.pendingBackground,0);assert(Object.values(outcome.cleanup.residual).every(v=>v===false),'No retained array cache owners');
  assert(outcome.frames.length>=6,'Actual EndFrame interval samples required');
  const intervals=outcome.frames.map(f=>f.ms).sort((a,b)=>a-b);
  report.frameIntervals={count:intervals.length,maxMs:intervals.at(-1),p95Ms:intervals[Math.floor(intervals.length*.95)],p99Ms:intervals[Math.floor(intervals.length*.99)]};
  report.responsiveness=report.frameIntervals.maxMs<=250?'PASS':'FAIL';
  report.result='PASS';report.boundary='Actual isolated target API completion, original texture identity and material reference binding. Responsiveness reported independently; no thread ownership, scene pixels, whole-game loading benefit, audio or mobile claim.';
 }catch(e){report.result='FAIL';report.failure=e.stack;process.exitCode=1}
 finally{await browser.close();report.shutdown='CLOSED';report.finishedAt=new Date().toISOString();fs.writeFileSync(path.join(folder,'result.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({result:report.result,responsiveness:report.responsiveness,frameIntervals:report.frameIntervals,failure:report.failure,folder},null,2))}
})().catch(e=>{console.error(e);process.exitCode=1});

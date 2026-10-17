'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out),'Preserve previous result');fs.mkdirSync(out,{recursive:true});
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.objectiveWebCpu?.isolated&&!identity.qa&&!identity.perfMonitor);
 const manifest=await fetch(base+'/game-dist/'+path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/')).then(r=>r.json());
 const main=manifest.files.find(r=>r.fs_path==='main.lua');assert.equal(sha(Buffer.from(await fetch(base+'/game-dist/assets/'+main.uuid+'-'+main.hash+main.ext).then(r=>r.arrayBuffer()))),identity.objectiveWebCpu.entrySha256);
 const report={status:'RUNNING',identity,startedAt:new Date().toISOString(),errors:[],httpErrors:[],snapshots:[]};
 const persist=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');persist();
 const transport=require('./g1-web-cpu-run.cjs').chunks();let browser;
 try{
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});const page=await browser.newPage({viewport:{width:960,height:540}});
  page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');if(m.type()==='error'||/ERROR:|Aborted\(|stack traceback|Shader compilation failed|Failed to create bgfx/i.test(line))report.errors.push(line);const p='OBJECTIVE_WEB_CPU_CHUNK ',at=line.indexOf(p);if(at>=0)try{transport.add(JSON.parse(line.slice(at+p.length)))}catch(e){report.errors.push(e.message)}});
  page.on('console',m=>{const line=m.text(),prefix='OBJECTIVE_WEB_CPU_SNAPSHOT ',at=line.indexOf(prefix);if(at<0)return;
   try{const snapshot=JSON.parse(line.slice(at+prefix.length));assert(['before','candidate'].includes(snapshot.label)&&['conquest','escort'].includes(snapshot.case));
    const file=snapshot.label+'-'+snapshot.case+'.png';
    page.screenshot({path:path.join(out,file),timeout:15000}).then(()=>{report.snapshots.push({...snapshot,file});return page.keyboard.press('F8')}).catch(e=>report.errors.push('Native screenshot: '+e.message));
   }catch(e){report.errors.push(e.message)}
  });
  page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('requestfailed',r=>report.httpErrors.push({url:r.url(),error:r.failure()}));page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({url:r.url(),status:r.status()})});
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login',{waitUntil:'domcontentloaded',timeout:30000});
  const deadline=Date.now()+240000;while(!transport.ready()){assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,'HTTP errors');assert(Date.now()<deadline,'Objective fixture timeout');await new Promise(r=>setTimeout(r,250))}
  const result=transport.result();assert.equal(result.status,'PASS',result.error);assert.deepEqual(result.configuration,identity.objectiveWebCpu.configuration);assert.deepEqual(result.identity,identity.objectiveWebCpu.sourceIdentity);
  const summary=[];
  if(result.configuration.nativeReadback){
   assert.equal(result.nativeComparison.status,'PASS');assert.equal(report.snapshots.length,4);assert.equal(result.nativeComparison.observations.length,4);assert(result.nativeComparison.comparisons.vertices>0&&result.nativeComparison.comparisons.batches>0);
   for(const kind of ['conquest','escort']){const [a,b]=result.nativeComparison.observations.filter(r=>r.case===kind);assert(a.commits>0&&a.vertices>0);for(const key of ['commits','vertices','batches','camera','viewport'])assert.deepEqual(a[key],b[key],key)}
  }else{
  assert.deepEqual(result.rounds.map(r=>r.label),['A1','B1','B2','A2']);
  for(const round of result.rounds){assert.deepEqual(round.cases.map(c=>c.name),['conquest','escort']);for(const c of round.cases){assert.equal(c.samplesMs.length,result.configuration.steps);assert.equal(c.totalMs,c.samplesMs.reduce((a,b)=>a+b,0));assert(c.dueSteps>0&&c.nonDueSteps>0&&c.culledSteps>0);assert.equal(c.dueSteps+c.nonDueSteps,result.configuration.steps)}}
  for(let i=0;i<2;i++){const rows=result.rounds.map(r=>r.cases[i]);for(const r of rows.slice(1))for(const key of ['dueSteps','nonDueSteps','culledSteps','age','nextUpdate','randomTail'])assert.deepEqual(r[key],rows[0][key],key+' sequence mismatch');const before=(rows[0].totalMs+rows[3].totalMs)/(2*result.configuration.steps),candidate=(rows[1].totalMs+rows[2].totalMs)/(2*result.configuration.steps);summary.push({name:rows[0].name,ABBA_totalMs:rows.map(c=>c.totalMs),beforeMsPerStep:before,candidateMsPerStep:candidate,changePercent:(candidate/before-1)*100})}
  }
  await new Promise(r=>setTimeout(r,500));assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0);assert.deepEqual(await fetch(base+'/identity.json').then(r=>r.json()),identity);
  report.result=result;report.summary=summary;report.status='PASS';
 }catch(e){report.status='FAIL';report.failure=e.stack;throw e}
 finally{if(browser)try{await Promise.race([browser.close(),new Promise((_,reject)=>setTimeout(()=>reject(Error('Close timeout')),5000))]);report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.closeError=e.message}report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({status:report.status,shutdown:report.shutdown,summary:report.summary,failure:report.failure,out}))}
 return report;
}
module.exports={run};
if(require.main===module)run(process.argv[2],path.resolve(process.argv[3])).catch(e=>{console.error(e.stack);process.exitCode=1});

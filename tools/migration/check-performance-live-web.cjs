// Real engine/UI smoke. No artificial busy loops or gameplay state mutation.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base=process.env.VOX_QA_BASE;
const pause=ms=>new Promise(r=>setTimeout(r,ms));
async function main(){
 assert.match(base||'',/^http:\/\/127\.0\.0\.1:\d+$/);
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.perfMonitor);
 const out=path.join(root,'docs/migration/evidence','performance-monitor-web-'+Date.now());fs.mkdirSync(out,{recursive:true});
 const result={result:'RUNNING',identity,checks:[],errors:[],records:[],out};let browser;
 const check=(ok,name)=>{assert.ok(ok,name);result.checks.push(name)};
 try{
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
  const page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,'console.log'),line+'\n');
   const at=line.indexOf('VOX_PERF ');if(at>=0){try{result.records.push(JSON.parse(line.slice(at+9)))}catch(e){result.errors.push(e.message)}}
   if(/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|ERROR:/.test(line))result.errors.push(line);
  });
  page.on('pageerror',e=>result.errors.push(e.message));
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  const deadline=Date.now()+240000;
  while(!result.records.some(r=>r.type==='sample'&&r.context?.mode==='hangar'&&!r.context.loading)){
   assert.ok(Date.now()<deadline,'Real boot and home timeout');assert.equal(result.errors.length,0,result.errors.join('\n'));await pause(500);
  }
  await pause(3000);await page.keyboard.press('F10');await pause(1500);
  check(result.records.some(r=>r.type==='marker'&&r.label==='user-mark'),'F10 real input writes marker');
  check(result.records.some(r=>r.type==='sample'&&r.frameSamples.length>0),'Real per-frame samples emitted');
  const records=result.records.filter(r=>r.type==='slow_frame');
  check(records.length>0,'Actual cold start produces long-frame evidence');
  check(records.every(r=>Array.isArray(r.stages)&&r.context&&Number.isFinite(r.scriptMs)&&r.wallMs>=r.scriptMs),'Long-frame timing and context internally consistent');
  await page.screenshot({path:path.join(out,'panel-desktop.png')});
  await page.keyboard.press('F6');await pause(400);await page.screenshot({path:path.join(out,'panel-hidden.png')});
  await page.keyboard.press('F6');await page.setViewportSize({width:1000,height:450});await pause(700);
  await page.screenshot({path:path.join(out,'panel-landscape.png')});
  await page.evaluate(()=>window.__voxPerfCollector.flush());await pause(300);
  result.status=await fetch(base+'/__vox_perf_status').then(r=>r.json());
  check(result.status.writtenRecords>0&&!result.status.writeFailures,'Collector actually persisted records');
  check(result.status.sessions.some(s=>s.session===result.records[0].session&&s.writtenRecords>0&&fs.existsSync(s.file)),'Game session exists on disk');
  result.collector=await page.evaluate(()=>window.__voxPerfCollector.status());
  check(result.collector.parseErrors===0&&result.collector.droppedRecords===0,'No truncated or dropped observer records');
  check(result.errors.length===0,'No runtime errors');result.result='PASS';
 }catch(e){result.result='FAIL';result.failure=e.stack;throw e}
 finally{await browser?.close();result.shutdown='CLOSED';fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({result:result.result,out,checks:result.checks.length,failure:result.failure}))}
}
main().catch(e=>{console.error(e);process.exitCode=1});

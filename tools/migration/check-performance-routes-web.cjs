// Actual public route and per-frame timings. No injected gameplay state or busy loop.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function main(){
 const base=process.env.VOX_QA_BASE;assert.match(base||'',/^http:\/\/127\.0\.0\.1:\d+$/);
 const route=process.env.VOX_PERF_ROUTE||'match';assert.ok(['match','story'].includes(route));
 assert.ok(route==='match'||!process.argv.includes('--require-baked-minimap'),'Baked minimap assertion only applies to competitive matches');
 const driveMs=Number(process.env.VOX_PERF_DRIVE_MS||4000);
 assert.ok(Number.isInteger(driveMs)&&driveMs>=4000&&driveMs<=120000,'Drive sample duration 4-120 seconds');
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa&&identity.perfMonitor);
 const out=path.resolve('docs/migration/evidence/performance-route-'+route+'-'+Date.now());fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',route,driveMs,identity,checks:[],errors:[],records:[],boundary:'Real public route with read-only F8 observer. Functional timing coverage only; not isolated desktop or device FPS acceptance.'};
 let browser,page,state,seq=0;
 const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label)};
 try{
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
  page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',m=>{
   const line=m.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   for(const [prefix,handle] of [['VOX_PERF ',r=>report.records.push(r)],['OUTGAME_STATE ',r=>{state=r;seq++}]]){
    const at=line.indexOf(prefix);if(at>=0){try{handle(JSON.parse(line.slice(at+prefix.length)))}catch(e){report.errors.push(prefix+e.message)}}
   }
   if(/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|ERROR:/.test(line))report.errors.push(line);
  });
  page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Renderer crash'));
  async function wait(fn,label,timeout=240000){
   const start=Date.now();let next=0;
   while(!state||!fn(state)){
    assert.equal(report.errors.length,0,report.errors.join('\n'));assert.ok(Date.now()-start<timeout,'Timeout '+label);
    if(Date.now()>next){next=Date.now()+500;await page.keyboard.press('F8')}await sleep(60);
   }return state;
  }
  async function click(text){
   const rows=s=>Array.isArray(s.widgets)?s.widgets:[];
   await wait(s=>rows(s).some(w=>w.text===text&&!w.disabled&&w.rect?.[2]>0),'button '+text);
   const w=rows(state).find(w=>w.text===text&&!w.disabled&&w.rect?.[2]>0),old=seq;
   await page.mouse.click((w.rect[0]+w.rect[2]/2)/state.width*1600,(w.rect[1]+w.rect[3]/2)/state.height*900);
   await wait(()=>seq>old,'button state '+text);
  }
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow?.active,'hall');await click('出战');
  if(route==='match'){
   await click('歼灭战');await click('开始匹配');
   await wait(s=>s.mode==='trial'&&s.battle&&!s.loadingFlow?.active,'match',300000);
   if(state.intro?.active){await page.keyboard.press('Space');await wait(s=>!s.intro?.active,'cinematic skip')}
  }else{
   await click('剧情模式');await wait(s=>s.tab==='story'&&s.story?.ready,'story selector');
   const level=require('../../assets/Story/Mission/Level1.json').level;
   await click(level.no+'  '+level.name);await click('开始任务');
   await wait(s=>s.mode==='trial'&&s.story?.id===level.id&&!s.loadingFlow?.active,'story',300000);
  }
  await page.mouse.click(800,450);await wait(s=>s.pointer?.captured,'actual pointer capture');
  if(route==='match')await wait(s=>s.battle?.state==='live','match live',30000);
  if(process.argv.includes('--require-baked-minimap')){
   const capture=state.performance?.lifecycle?.capture;
   check(capture?.baked&&capture.ready&&!capture.gate&&!capture.bakePending,'Actual baked minimap ready without runtime capture fallback');
   report.minimapCapture=capture;
  }
  await page.keyboard.down('w');await page.mouse.down();await sleep(driveMs);await page.mouse.up();await page.keyboard.up('w');
  await page.keyboard.press('F10');await sleep(1800);
  const samples=report.records.filter(r=>r.type==='sample'&&!r.context?.loading&&r.context?.map&&(route==='match'?r.context.matchState==='live':r.context.story==='s1'));
  check(samples.length>0,'Actual active '+route+' samples');
  const frames=samples.flatMap(s=>(Array.isArray(s.frameSamples)?s.frameSamples:[]).map(f=>({f,names:s.stageNames})));
  check(frames.some(({f,names})=>Array.isArray(names)&&Array.isArray(f.stageTimes)&&f.stageTimes.length>0),'Per-frame stage dictionaries reach real browser');
  const stages=new Set();let detailed=0;
  for(const {f,names} of frames){
   if(!Array.isArray(f.stageTimes))continue;detailed++;
   check(f.stageTimes.length%5===0,'Valid frame detail '+f.frame);
   for(let i=0;i<f.stageTimes.length;i+=5){assert.equal(typeof names[f.stageTimes[i]-1],'string');stages.add(names[f.stageTimes[i]-1])}
  }
  check(stages.has('vehicle.Step')&&stages.has('physics.Step')&&stages.has('weapons.Step'),'Real vehicle, physics and weapon scopes');
  report.coverage={detailedFrames:detailed,stages:[...stages]};
  await page.evaluate(()=>window.__voxPerfCollector.flush());await sleep(300);
  report.status=await fetch(base+'/__vox_perf_status').then(r=>r.json());
  report.collector=await page.evaluate(()=>window.__voxPerfCollector.status());
  check(report.status.writtenRecords>0&&report.status.writeFailures===0,'Actual durable write');
  check(report.collector.parseErrors===0&&report.collector.droppedRecords===0&&report.collector.oversizedRecords===0,'No dropped/truncated frame detail');
  check(report.errors.length===0,'No engine/runtime errors');
  await page.screenshot({path:path.join(out,'active.png'),timeout:15000});
  if(process.argv.includes('--return-hall')){
   const oldSeq=seq;await page.keyboard.press('Escape');await wait(()=>seq>oldSeq,'pause after pointer release');
   await click('返回车库');if(route==='match')await click('确定');
   await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'actual return hall',120000);
   await sleep(2200);
   const last=report.records.filter(r=>r.type==='sample').at(-1);
   check(last?.context?.mode==='hangar'&&last.context.units===0&&!last.context.sceneIsTrial,'Returned hall has no live battle units');
   report.returnContext=last.context;
   await page.screenshot({path:path.join(out,'returned.png'),timeout:15000});
   await page.evaluate(()=>window.__voxPerfCollector.flush());await sleep(300);
   report.status=await fetch(base+'/__vox_perf_status').then(r=>r.json());
   report.collector=await page.evaluate(()=>window.__voxPerfCollector.status());
   check(report.errors.length===0&&report.collector.parseErrors===0&&report.collector.droppedRecords===0&&report.status.writeFailures===0,'Return transition remains error-free and durable');
  }
  report.result='PASS';
 }catch(e){report.result='FAIL';report.failure=e.stack;throw e}
 finally{await browser?.close();report.shutdown='CLOSED';fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({result:report.result,route,out,coverage:report.coverage,checks:report.checks.length,failure:report.failure}))}
}
main().catch(e=>{console.error(e.message);process.exitCode=1});

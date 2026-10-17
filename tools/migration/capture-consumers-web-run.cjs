'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {stream}=require('./monitor-combat-run.cjs'),acceptance=require('./capture-consumers-web-acceptance.cjs');
const sleep=ms=>new Promise(r=>setTimeout(r,ms)),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
 const report={status:'RUNNING',errors:[],httpErrors:[],stages:[],startedAt:new Date().toISOString()},deadline=Date.now()+600000;
 let browser,page,state,sequence=0;const streams=new Map(),answered=new Set();
 const persist=()=>{report.lastState=state;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n')};
 const stage=name=>{report.stage=name;report.stages.push({name,time:new Date().toISOString()});persist();console.log(JSON.stringify({progress:name,out}))};
 const healthy=()=>{assert(Date.now()<deadline,'600s total deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors[0]))};
 try{
  const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.captureConsumersWeb?.isolated);assert.equal(identity.qa,false);report.identity=identity;
  const relative=path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/');
  const manifest=await fetch(base+'/game-dist/'+relative).then(r=>r.json());report.httpHashes={};
  for(const name of ['main.lua',...Object.keys(identity.captureConsumersWeb.sources),'audio/StoryComms.lua','audio/StoryRadio.lua','render/MissionView.lua']){
   const entry=manifest.files.find(x=>x.fs_path===name);assert(entry,name);
   const response=await fetch(base+'/game-dist/assets/'+entry.uuid+'-'+entry.hash+entry.ext);assert.equal(response.status,200);
   const actual=sha(Buffer.from(await response.arrayBuffer()));assert.equal(actual,identity.identity.scripts[name],name);report.httpHashes[name]=actual;
  }
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});
  page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',message=>{
   const text=message.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');
   if(message.type()==='error'||/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\bERROR:/.test(text))report.errors.push(text);
   const prefix='CAPTURE_CONSUMERS_CHUNK ',at=text.indexOf(prefix);
   if(at>=0)try{
    const chunk=JSON.parse(text.slice(at+prefix.length));let item=streams.get(chunk.kind);if(!item){item=stream();streams.set(chunk.kind,item)}item.add(chunk);
    if(item.ready()){const next=item.value();assert.equal(chunk.kind,'state-'+next.sequence);if(!state||next.sequence>state.sequence){state=next;state.widgets=Array.isArray(state.widgets)?state.widgets:[];state.calls=Array.isArray(state.calls)?state.calls:[];sequence++}}
   }catch(error){report.errors.push(error.stack)}
  });
  page.on('pageerror',error=>report.errors.push(error.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('response',response=>{if(response.status()>=400)report.httpErrors.push({url:response.url(),status:response.status()})});
  page.on('requestfailed',request=>report.httpErrors.push({url:request.url(),error:request.failure()?.errorText}));
  async function poll(){
   const old=sequence,until=Math.min(deadline,Date.now()+(state?8000:180000));let next=0;
   while(sequence===old){healthy();assert(Date.now()<until,'F7 observer response');if(Date.now()>=next){await page.keyboard.press('F7');next=Date.now()+(state?1500:700)}await sleep(50)}
   const choice=state.story?.choice;
   if(choice&&!answered.has(choice.id)){
    assert.equal(choice.id,'tag','Only authored S4 tag choice is expected');answered.add(choice.id);
    report.choiceInput={id:choice.id,index:2,ruleTime:state.story.time};await page.keyboard.press('2');
   }
   return state;
  }
  async function wait(test,label,ms=30000){stage(label);const until=Math.min(deadline,Date.now()+ms);while(!state||!test(state)){healthy();assert(Date.now()<until,'Stage deadline: '+label);await poll();if(!test(state))await sleep(150)}return state}
  async function click(text){
   await wait(s=>s.widgets.some(w=>w.text===text&&!w.disabled),'button '+text);
   const widget=state.widgets.find(w=>w.text===text&&!w.disabled),r=widget.rect;
   await page.mouse.click((r[0]+r[2]/2)/state.width*1600,(r[1]+r[3]/2)/state.height*900);await poll();
  }
  report.url=base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login';
  await page.goto(report.url,{waitUntil:'domcontentloaded',timeout:30000});await page.bringToFront();
  await wait(s=>s.mode==='hangar'&&!s.loading,'actual hall ready',180000);
  for(let i=0;i<5;i++){
   const skip=state.widgets.find(w=>/^(跳过引导|确定跳过？再点一次)$/.test(w.text)&&!w.disabled);
   if(skip){await click(skip.text);continue}break;
  }
  await click('出战');await click('剧情模式');await click('04  偷家');
  await wait(s=>{
   const h=s.holo;if(h?.failure||h?.gate?.state==='failed')throw Error('Actual StoryHolo download failure: '+JSON.stringify(h));
   return h?.level===4&&h.ready===true&&h.downloaded===true&&!h.disposed&&h.gate?.state==='ready'&&h.gate.activeGroup===false;
  },'actual selected S4 hologram download and model readiness',120000);
  report.holoBeforeStart=structuredClone(state.holo);await click('开始任务');
  await wait(s=>s.mode==='trial'&&s.story?.id==='s4'&&!s.loading,'actual S4 ready',180000);
  if(state.intro){await page.keyboard.press('Space');await wait(s=>!s.intro,'actual entry intro completes')}
  await page.locator('#canvas').click();await wait(s=>s.captured,'actual pointer captured');
  await wait(s=>s.story?.step==='A','actual first authored capture objective');report.sites=[];
  for(const [index,site]of ['A','B','C'].entries()){
   await wait(s=>s.story?.step===site,'actual '+site+' objective');
   stage('explicit QA actual Place '+site);await page.keyboard.press('F10');
   await wait(s=>s.story?.step===site&&s.story.cap?.phase==='cap','actual '+site+' guard encounter');
   await page.locator('#canvas').screenshot({path:path.join(out,site+'-encounter.png'),timeout:10000});
   stage('explicit QA guard core Destroy/Flush '+site);await page.keyboard.press('F9');
   await wait(s=>s.story?.step===site&&s.story.cap?.phase==='counter','actual '+site+' natural capture timer and counterattack',45000);
   report.sites[index]={site,captured:structuredClone(state)};
   await page.locator('#canvas').screenshot({path:path.join(out,site+'-captured.png'),timeout:10000});
   stage('explicit QA counter core Destroy/Flush '+site);await page.keyboard.press('F9');
   await wait(s=>s.story?.step===site&&s.story.cap?.phase==='scrub','actual '+site+' counter defeated');
   await page.keyboard.press('F10');stage('actual G interaction '+site);await page.keyboard.down('g');
   try{await wait(s=>s.consumer?.sites?.[site]?.scrubbed!==undefined,'actual '+site+' original scrub timer',15000)}finally{await page.keyboard.up('g')}
   await poll();report.sites[index].accepted=acceptance.check(state,site);report.sites[index].scrubbed=structuredClone(state);
   await page.locator('#canvas').screenshot({path:path.join(out,site+'-scrubbed.png'),timeout:10000});persist();
  }
  assert.equal(state.story.stats.sites,3);assert.equal(state.story.stats.graffiti,3);
  await wait(s=>s.story?.finished,'actual S4 result after original completion delay',45000);
  report.completionAccepted=acceptance.checkComplete(state);
  assert.equal(state.story.flags.tag,1,'Actual non-default tag choice reached the source flag');
  report.completed=state;report.status='PASS';report.boundary=identity.captureConsumersWeb.boundary;
 }catch(error){report.status='FAIL';report.failure=error.stack;if(page)try{await page.screenshot({path:path.join(out,'failure.png'),timeout:3000})}catch{}throw error}
 finally{
  if(page)try{await page.keyboard.up('g')}catch{}
  if(browser)try{await Promise.race([browser.close(),sleep(5000).then(()=>{throw Error('Close deadline')})]);report.shutdown='CLOSED'}catch(error){report.shutdown='UNCONFIRMED';report.closeError=error.message}
  report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({status:report.status,shutdown:report.shutdown,out,failure:report.failure}));
 }
 return report;
}
module.exports={run};
if(require.main===module){const [base,out]=process.argv.slice(2);assert(base&&out,'base URL and unused output directory required');run(base,path.resolve(out)).catch(error=>{console.error(error.stack);process.exitCode=1})}

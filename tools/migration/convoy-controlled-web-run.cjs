'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {stream}=require('./monitor-combat-run.cjs'),acceptance=require('./convoy-controlled-web-acceptance.cjs');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms)),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
 const report={status:'RUNNING',errors:[],httpErrors:[],stages:[],startedAt:new Date().toISOString()},deadline=Date.now()+480000;
 let browser,page,state,revision=0;const streams=new Map(),answered=new Set();
 const persist=()=>{report.lastState=state;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n')};
 const stage=name=>{report.stage=name;report.stages.push({name,time:new Date().toISOString()});persist();console.log(JSON.stringify({progress:name,out}))};
 const healthy=()=>{assert(Date.now()<deadline,'480s total deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors[0]))};
 try{
  const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.convoyControlledWeb?.isolated);assert.equal(identity.qa,false);report.identity=identity;
  const relative=path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/');
  const manifest=await fetch(base+'/game-dist/'+relative).then(r=>r.json());report.httpHashes={};
  for(const name of ['main.lua',...Object.keys(identity.convoyControlledWeb.sources)]){
   const entry=manifest.files.find(r=>r.fs_path===name);assert(entry,name);
   const response=await fetch(base+'/game-dist/assets/'+entry.uuid+'-'+entry.hash+entry.ext);assert.equal(response.status,200);
   const hash=sha(Buffer.from(await response.arrayBuffer()));assert.equal(hash,identity.identity.scripts[name],name);report.httpHashes[name]=hash;
  }
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});
  page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',message=>{
   const text=message.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');
   if(message.type()==='error'||/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\bERROR:/.test(text))report.errors.push(text);
   const prefix='CONVOY_CONTROLLED_CHUNK ',at=text.indexOf(prefix);
   if(at>=0)try{
    const chunk=JSON.parse(text.slice(at+prefix.length));let item=streams.get(chunk.kind);if(!item){item=stream();streams.set(chunk.kind,item)}item.add(chunk);
    if(item.ready()){
     const next=item.value();assert.equal(chunk.kind,'state-'+next.sequence);
     if(!state||next.sequence>state.sequence){state=next;for(const key of ['widgets','calls','checkpoints','preparations'])if(!Array.isArray(state[key]))state[key]=[];revision++}
    }
   }catch(error){report.errors.push(error.stack)}
  });
  page.on('pageerror',error=>report.errors.push(error.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('response',response=>{if(response.status()>=400)report.httpErrors.push({url:response.url(),status:response.status()})});
  page.on('requestfailed',request=>report.httpErrors.push({url:request.url(),error:request.failure()?.errorText}));
  async function poll(){
   const old=revision,until=Math.min(deadline,Date.now()+(state?8000:180000));let next=0;
   while(revision===old){healthy();assert(Date.now()<until,'F7 observer response');if(Date.now()>=next){await page.keyboard.press('F7');next=Date.now()+(state?1300:700)}await sleep(50)}
   const choice=state.story?.choice;
   if(choice&&!answered.has(choice.id)){
    assert(['rate','road'].includes(choice.id),'Known authored S2 choice');answered.add(choice.id);
    const index=choice.id==='rate'?2:3;(report.choices??=[]).push({id:choice.id,index,time:state.story.time});await page.keyboard.press(String(index));
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
  for(let i=0;i<5;i++){const skip=state.widgets.find(w=>/^(跳过引导|确定跳过？再点一次)$/.test(w.text)&&!w.disabled);if(skip)await click(skip.text);else break}
  await click('出战');await click('剧情模式');await click('02  物资车');
  await wait(s=>{
   const h=s.holo;if(h?.failure||h?.gate?.state==='failed')throw Error('Actual StoryHolo download failure '+JSON.stringify(h));
   return h?.level===2&&h.ready===true&&h.downloaded===true&&!h.disposed&&h.gate?.state==='ready'&&h.gate.activeGroup===false;
  },'actual S2 hologram and download ready',120000);
  report.holoBeforeStart=structuredClone(state.holo);await click('开始任务');
  await wait(s=>s.mode==='trial'&&s.story?.id==='s2'&&!s.loading,'actual public S2 ready',180000);
  if(state.intro){await page.keyboard.press('Space');await wait(s=>!s.intro,'actual entry intro completes')}
  await page.locator('#canvas').click();await wait(s=>s.captured,'actual pointer captured');
  await wait(s=>s.story?.step==='meet','actual first authored meet objective');
  stage('explicit QA Mission.Place at meet');await page.keyboard.press('F10');
  await wait(s=>s.story?.step==='convoy','actual meet consumed by normal Rules update');
  for(const cp of [1,2]){
   stage('explicit QA placement immediately before checkpoint '+cp);await page.keyboard.press('F10');
   await wait(s=>s.checkpoints.length===cp&&s.story?.truck.cp===cp,'actual checkpoint '+cp+' original Update and consumers');
   report['checkpoint'+cp]=structuredClone(state);
   await page.locator('#canvas').screenshot({path:path.join(out,'checkpoint-'+cp+'.png'),timeout:10000});
   if(cp===1){
    await page.keyboard.press('Escape');await wait(s=>s.unified&&!s.captured,'actual unified pause page');
    report.pauseBefore=structuredClone(state);await sleep(1200);await poll();report.pauseAfter=structuredClone(state);
    await page.locator('#canvas').screenshot({path:path.join(out,'paused.png'),timeout:10000});
    await click('继续');await wait(s=>s.captured&&!s.dialog,'actual Continue restores pointer and mission');
    report.resumed=structuredClone(state);report.pauseAccepted=acceptance.pause(report.pauseBefore,report.pauseAfter,report.resumed);
   }
  }
  report.checkpointsAccepted=acceptance.checkpoints(state);report.preparationsAccepted=acceptance.preparations(state);
  report.consumers=structuredClone(state);
  await page.keyboard.press('Escape');await wait(s=>s.unified&&!s.captured,'actual public return menu');await click('返回车库');
  await wait(s=>s.mode==='hangar'&&!s.loading&&s.terrainReleased,'actual public hall and terrain disposal',120000);
  report.returned=structuredClone(state);report.returnAccepted=acceptance.returned(state);
  await page.locator('#canvas').screenshot({path:path.join(out,'returned.png'),timeout:10000});
  healthy();report.status='PASS';report.boundary=identity.convoyControlledWeb.boundary;
 }catch(error){report.status='FAIL';report.failure=error.stack;if(page)try{await page.screenshot({path:path.join(out,'failure.png'),timeout:3000})}catch{}throw error}
 finally{
  if(browser)try{await Promise.race([browser.close(),sleep(5000).then(()=>{throw Error('Browser close deadline')})]);report.shutdown='CLOSED'}catch(error){report.shutdown='UNCONFIRMED';report.closeError=error.message}
  report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({status:report.status,shutdown:report.shutdown,out,failure:report.failure}));
 }
 return report;
}
module.exports={run};
if(require.main===module){const [base,out]=process.argv.slice(2);assert(base&&out,'base URL and unused output path required');run(base,path.resolve(out)).catch(error=>{console.error(error.stack);process.exitCode=1})}

'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {stream}=require('./monitor-combat-run.cjs'),acceptance=require('./boss-missile-web-acceptance.cjs');
const {awaitFirstState}=require('./ads-pixel-run.cjs');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms)),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
 const report={status:'RUNNING',errors:[],httpErrors:[],stages:[],screenshots:[],startedAt:new Date().toISOString()},deadline=Date.now()+420000;
 let browser,page,state,revision=0;const streams=new Map();
 const persist=()=>{report.lastState=state;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n')};
 const stage=name=>{report.stage=name;report.stages.push({name,time:new Date().toISOString()});persist();console.log(JSON.stringify({progress:name,out}))};
 const healthy=()=>{assert(Date.now()<deadline,'420s overall deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors[0]))};
 try{
  const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.bossMissileWeb?.isolated);assert.equal(identity.qa,false);report.identity=identity;
  const relative=path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/');
  const manifest=await fetch(base+'/game-dist/'+relative).then(r=>r.json());report.httpHashes={};
  for(const name of ['main.lua',...Object.keys(identity.bossMissileWeb.sources)]){
   const entry=manifest.files.find(row=>row.fs_path===name);assert(entry,name);
   const response=await fetch(base+'/game-dist/assets/'+entry.uuid+'-'+entry.hash+entry.ext);assert.equal(response.status,200);
   const hash=sha(Buffer.from(await response.arrayBuffer()));assert.equal(hash,identity.identity.scripts[name],name);report.httpHashes[name]=hash;
  }
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});
  page=await browser.newPage({viewport:{width:1600,height:900},deviceScaleFactor:1});
  page.on('console',message=>{
   const text=message.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');
   if(message.type()==='error'||/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\bERROR:/.test(text))report.errors.push(text);
   const prefix='BOSS_MISSILE_CHUNK ',at=text.indexOf(prefix);
   if(at>=0)try{
    const chunk=JSON.parse(text.slice(at+prefix.length));let item=streams.get(chunk.kind);if(!item){item=stream();streams.set(chunk.kind,item)}item.add(chunk);
    if(item.ready()){
     const next=item.value();assert.equal(chunk.kind,'state-'+next.sequence);
     if(!state||next.sequence>state.sequence){state=next;for(const key of ['widgets','cases','actions'])if(!Array.isArray(state[key]))state[key]=[];revision++}
    }
   }catch(error){report.errors.push(error.stack)}
  });
  page.on('pageerror',error=>report.errors.push(error.stack||error.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('response',response=>{if(response.status()>=400)report.httpErrors.push({url:response.url(),status:response.status()})});
  page.on('requestfailed',request=>report.httpErrors.push({url:request.url(),error:request.failure()?.errorText}));
  async function poll(){
   const old=revision,until=Math.min(deadline,Date.now()+8000);await page.keyboard.press('F7');
   while(revision===old){healthy();assert(Date.now()<until,'Actual F7 post-update state response');await sleep(50)}return state;
  }
  async function wait(test,label,ms=30000){stage(label);const until=Math.min(deadline,Date.now()+ms);while(!state||!test(state)){healthy();assert(Date.now()<until,'Stage deadline: '+label);await poll();if(!test(state))await sleep(150)}return state}
  async function shot(label){await poll();const file=label+'.png';await page.locator('#canvas').screenshot({path:path.join(out,file),timeout:15000});report.screenshots.push({label,file,state:structuredClone(state)});persist()}
  async function click(text){
   await wait(s=>s.widgets.some(w=>w.text===text&&!w.disabled),'actual button '+text);
   assert.equal(state.captured,false,'Release actual pointer before menu hit testing');
   const widget=state.widgets.find(w=>w.text===text&&!w.disabled),rect=widget.rect;
   await page.mouse.click((rect[0]+rect[2]/2)/state.width*1600,(rect[1]+rect[3]/2)/state.height*900);await poll();
  }
  report.url=base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login';
  await page.goto(report.url,{waitUntil:'domcontentloaded',timeout:30000});await page.bringToFront();
  await awaitFirstState(()=>state,()=>page.keyboard.press('F7'),healthy);
  await wait(s=>s.appReady&&s.mode==='hangar'&&!s.trial&&!s.loading,'actual hall ready',120000);
  stage('controlled actual EnterTrial story5 request');await page.keyboard.press('F4');
  await wait(s=>s.mode==='trial'&&s.story?.id==='s5'&&!s.loading,'actual EnginePit installed and warmed',180000);
  assert.equal(state.actions.length,1);assert.equal(state.actions[0].accepted,true);assert.equal(state.actions[0].map,'story5');
  if(state.intro){stage('actual entry intro skip input');await page.keyboard.press('Space');await wait(s=>!s.intro,'actual entry intro completes')}
  await wait(s=>s.story?.begun&&!s.dialog,'actual mission begun');
  await page.locator('#canvas').click();await wait(s=>s.captured,'actual driving pointer captured');await shot('engine-pit');
  stage('explicit Boss objective and three real projectile consumers');await page.keyboard.press('F10');
  await wait(s=>s.cases.length===3&&s.setup?.wrappersRestored,'actual atomic impact records',60000);
  report.impacts=structuredClone(state);report.impactAcceptance=acceptance.impacts(state);await shot('boss-impact-consumers');
  report.menuInputs=[];
  for(let attempt=0;attempt<3&&(!state.unified||state.captured);attempt++){
   await page.keyboard.press('Escape');await sleep(200);await poll();
   report.menuInputs.push({attempt,captured:state.captured,dialog:state.dialog,unified:state.unified});
  }
  await wait(s=>s.unified&&!s.captured,'actual unified pause menu and released pointer');await shot('paused');
  await click('返回车库');
  await wait(s=>s.mode==='hangar'&&!s.trial&&!s.loading&&!s.releaseWaiting&&s.terrainReleased,'actual public return and release',120000);
  report.returned=structuredClone(state);report.returnAcceptance=acceptance.returned(state);await shot('returned');
  healthy();report.status='PASS';report.boundary=identity.bossMissileWeb.boundary;
 }catch(error){report.status='FAIL';report.failure=error.stack;if(page)try{await page.screenshot({path:path.join(out,'failure.png'),timeout:3000})}catch{}throw error}
 finally{
  if(browser)try{await Promise.race([browser.close(),sleep(5000).then(()=>{throw Error('Browser close deadline')})]);report.shutdown='CLOSED'}catch(error){report.shutdown='UNCONFIRMED';report.status='FAIL';report.closeError=error.message}
  report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({status:report.status,shutdown:report.shutdown,out,failure:report.failure}));
 }
 return report;
}
module.exports={run};
if(require.main===module){const [base,out]=process.argv.slice(2);assert(base&&out,'base URL and unused output path required');run(base,path.resolve(out)).catch(error=>{console.error(error.stack);process.exitCode=1})}

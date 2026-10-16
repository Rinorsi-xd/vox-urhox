// Public story-three navigation and real input only; no QA gameplay shortcuts.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const {frameObjects,choiceEvidence}=require('./story-presentation-evidence.cjs');
const root=path.resolve(__dirname,'../..'),base=process.env.VOX_QA_BASE;
assert(base,'VOX_QA_BASE must identify an immutable QA server');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const allCases=[{name:'pc',width:1920,height:1080,dpr:1},{name:'20x9',width:840,height:378,dpr:3,touch:true}];
(async()=>{
 const response=await fetch(base+'/identity.json');assert(response.ok,'HTTP identity accessible');const identity=await response.json();assert(identity.qa,'QA identity required');
 const probeSha=crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'))).digest('hex');assert.equal(identity.probeSha256,probeSha,'Actual server uses frozen presentation observer');
 if(process.env.VOX_EXPECT_MANIFEST)assert.equal(identity.servedManifest,process.env.VOX_EXPECT_MANIFEST);
 const production={};for(const name of ['ui/MissionChoiceState.lua','ui/MissionChoice.lua','ui/MissionObjective.lua','ui/MissionHud.lua','story/Mission.lua','story/MissionRules.lua']){
  const sha=crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'scripts',name))).digest('hex');assert.equal(identity.identity.scripts[name],sha,'Frozen current payload '+name);production[name]=sha;
 }
 const output=process.env.VOX_QA_OUTPUT_DIR||path.join(root,'docs/migration/evidence','story-presentation-'+identity.servedManifest.replace('.json','')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(output,{recursive:true});console.log(output);let failures=0;
 for(const test of allCases.filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name))){
  const report={identity,production,viewport:test,result:'RUNNING',objectiveResult:'NOT_RUN',choiceResult:'NOT_RUN',checks:[],errors:[],httpFailures:[],probeErrors:[],samples:[],drive:[],
   boundary:'Public battle/story03/start controls and real input only. PC natural W/S drive to gate and authored dialogue choice; no teleport, fake progress, injected mission or direct Choose. 20:9 touch case checks initial objective only. Post-update ring reads existing presenter samples; screenshot review is separate. Not whole-story or phone-performance acceptance.'};
  let browser,page,inputSession,state,sequence=0;
  const check=(ok,label)=>{report.checks.push({label,pass:!!ok});assert(ok,label);};
  try{
   browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
   page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,...(test.touch?{hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36'}:{})});
   inputSession=await page.context().newCDPSession(page);
   page.on('console',message=>{const line=message.text();fs.appendFileSync(path.join(output,test.name+'.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');
    if(at>=0)try{state=JSON.parse(line.slice(at+14));sequence++;}catch(error){report.probeErrors.push({error:String(error),length:line.length,tail:line.slice(-120)});}
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(line))report.errors.push(line);
   });page.on('pageerror',error=>report.errors.push(String(error)));page.on('crash',()=>report.errors.push('Browser renderer crashed'));
   page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
   async function key(k){
    // This bundled Playwright key table stops at F12. Send the actual F13 key via CDP.
    if(k==='F13'){
     const event={key:'F13',code:'F13',windowsVirtualKeyCode:124,nativeVirtualKeyCode:124};
     await inputSession.send('Input.dispatchKeyEvent',{type:'rawKeyDown',...event});await sleep(40);
     await inputSession.send('Input.dispatchKeyEvent',{type:'keyUp',...event});return;
    }
    await page.keyboard.press(k,{delay:40});
   }
   async function wait(predicate,label,timeout=240000){const begin=Date.now();let next=0;while(!state||!predicate(state)){
    if(report.errors.length)throw Error(label+': '+report.errors.at(-1));if(Date.now()-begin>timeout)throw Error('Timeout '+label);
    if(Date.now()>=next){next=Date.now()+650;await key('F8');}await sleep(60);
   }return state;}
   async function dump(){const before=sequence,full=!!state?.story?.presentation;await key(full?'F13':'F8');return wait(()=>sequence>before&&(!full||state.story?.presentation?.historyMode==='full'),'fresh explicit presentation probe',15000);}
   async function tapRect(rect){const canvas=await page.locator('canvas').boundingBox();assert(canvas);const x=canvas.x+(rect[0]+rect[2]/2)/state.width*canvas.width,y=canvas.y+(rect[1]+rect[3]/2)/state.height*canvas.height;
    if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y,{delay:40});await sleep(100);}
   async function widget(text){const before=sequence;await key('F8');await wait(()=>sequence>before,'fresh public widget probe',15000);const w=state.widgets.find(w=>w.text===text&&w.rect[2]>0&&w.rect[3]>0&&!w.disabled);assert(w,'Public widget '+text);await tapRect(w.rect);}
   async function shot(name){if(state.story?.presentation)await dump();else{const before=sequence;await key('F8');await wait(()=>sequence>before,'fresh nontrial screenshot probe',15000);}report.samples.push({name,state:structuredClone(state)});const png=await page.screenshot({path:path.join(output,test.name+'-'+name+'.png')});check((await sharp(png).stats()).channels.slice(0,3).some(c=>c.stdev>15),'Nonblank actual '+name);}
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow?.active,'actionable hall');await widget('出战');await wait(s=>s.tab==='battle','battle page');await widget('剧情模式');
   await wait(s=>s.tab==='story'&&s.story?.ready,'story selector');await widget('03  围剿');await wait(s=>s.story?.level===3&&s.story.ready,'mission-three briefing');await shot('briefing');await widget('开始任务');
   await wait(s=>s.mode==='trial'&&s.story?.id==='s3'&&!s.loadingFlow?.active,'actual mission-three');
   await wait(s=>s.story.step==='gate'&&s.story.presentation?.objective?.title==='开到要塞门口','first natural objective');await shot('objective');
   const objective=state.story.presentation.objective;
   check(objective.index===1&&objective.total===4&&objective.hint==='停机坪往北，门口的坡道上','Actual authored objective title/hint/counter');
   check(objective.alpha>0&&objective.x>=-18&&objective.x<=0,'Actual objective entry sampled');
   report.objectiveAnimation=frameObjects(state.story.presentation).some(f=>f.objectiveAlpha>0&&f.objectiveAlpha<1)?'PARTIAL_ENTRY_OBSERVED':'ENTRY_NOT_CAPTURED';
   report.objectiveResult='PASS';
   if(!test.touch&&process.env.VOX_STORY_OBJECTIVE_ONLY!=='1'){
    const canvas=await page.locator('canvas').boundingBox();await page.mouse.click(canvas.x+canvas.width*.5,canvas.y+canvas.height*.5);await wait(s=>s.pointer.captured,'natural browser capture',30000);
    const target=[0,5,-200],distance=s=>Math.hypot(s.vehicle.center[0]-target[0],s.vehicle.center[2]-target[2]);
    let direction='w',lastDistance=distance(state);const started=Date.now();
    while(state.story.step==='gate'){
     if(Date.now()-started>90000)throw Error('Natural gate drive did not finish; choice remains OPEN');
     const d=distance(state);report.drive.push({at:Date.now(),key:direction,distance:d,vehicle:state.vehicle});
     await page.keyboard.down(direction);await sleep(d>22?450:160);await page.keyboard.up(direction);
     await page.keyboard.down('Space');await sleep(180);await dump();await page.keyboard.up('Space');
     if(state.story.step!=='gate')break;
     const next=distance(state);if(next>lastDistance+1)direction=direction==='w'?'s':'w';lastDistance=next;
    }
    await page.keyboard.down('Space');await sleep(300);await page.keyboard.up('Space');
    await wait(s=>s.story.choice?.id==='surrender'&&s.story.presentation?.choice?.choosing,'natural surrender dialogue after driving',120000);
    await wait(s=>s.story.presentation.choice.alpha>=.99,'choice enter completes',10000);await shot('choice-natural');
    check(state.story.step==='parley'&&state.story.choice.options.length===3,'Natural authored parley has three options');
    const before=Date.now();await key('2');await sleep(80);await dump();
    check(!state.story.choice&&state.story.flags.surrender===1,'Actual digit2 resolves logical reply once');
    await shot('choice-selected');
    await sleep(1000);await dump();await shot('choice-exited');
    // Screenshots yield to automatic compact probes; retain the frozen full-ring samples.
    const evidence=choiceEvidence(report.samples.filter(s=>s.name.startsWith('choice-')),'surrender',2);report.choiceEvidence=evidence;
    check(evidence.heldObserved,'Actual post-update frame keeps selected row before500ms hide timer');
    check(evidence.exitObserved&&evidence.orderedExit,'Actual post-update frame completes choice exit');
    check(evidence.timerWithinSource,'Actual confirmation timer never exceeds source500ms');
    report.choiceElapsedMs=Date.now()-before;report.choiceResult='PASS';
   }else report.choiceReason=test.touch?'20:9 objective only; natural touchscreen driving and choice remain OPEN':'Requested objective-only route; choice remains OPEN';
   if(state.pointer.captured){await key('Escape');await wait(s=>!s.pointer.captured,'normal story capture release',15000);}
   await key('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'normal return to hall');
   check(!state.story?.presentation,'Story presenter disposed on normal return');check(report.errors.length===0,'No runtime errors');
   report.gameHttpFailures=report.httpFailures.filter(f=>f.url.startsWith(base+'/game-dist/'));check(report.gameHttpFailures.length===0,'No failed actual game payload requests');report.result='PASS';
  }catch(error){failures++;report.result='FAIL';report.failure=String(error.stack||error);report.lastState=state;if(page)await page.screenshot({path:path.join(output,test.name+'-failure.png')}).catch(()=>{});}
  finally{if(page)await page.keyboard.up('w').catch(()=>{});if(page)await page.keyboard.up('s').catch(()=>{});if(page)await page.keyboard.up('Space').catch(()=>{});if(browser)await browser.close();fs.writeFileSync(path.join(output,test.name+'.json'),JSON.stringify(report,null,2));}
  console.log(JSON.stringify({case:test.name,result:report.result,objective:report.objectiveResult,choice:report.choiceResult,checks:report.checks.length,errors:report.errors.length}));
 }
 if(failures)process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1;});

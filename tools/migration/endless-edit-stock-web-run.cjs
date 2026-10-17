'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function checksum(text){let hash=2166136261;for(const b of Buffer.from(text,'utf8'))hash=Math.imul(hash^b,16777619)>>>0;return hash}
function transport(){let count,bytes,digest;const parts=new Map();return {add(p){assert(Number.isInteger(p.sequence)&&p.sequence>0);assert(Number.isInteger(p.count)&&p.count>0&&p.count<1000);assert(Number.isInteger(p.index)&&p.index>0&&p.index<=p.count);assert(Number.isInteger(p.bytes)&&p.bytes>0);assert(Number.isInteger(p.checksum)&&p.checksum>=0&&p.checksum<=0xffffffff,'Required observer checksum');assert.equal(typeof p.data,'string');if(count){assert.equal(count,p.count);assert.equal(bytes,p.bytes);assert.equal(digest,p.checksum)}count=p.count;bytes=p.bytes;digest=p.checksum;assert(!parts.has(p.index),'Duplicate chunk');parts.set(p.index,p.data)},ready(){return count&&parts.size===count},value(){assert(this.ready());const s=Array.from({length:count},(_,i)=>parts.get(i+1)).join('');assert.equal(Buffer.byteLength(s),bytes);assert.equal(checksum(s),digest,'Observer checksum mismatch');return JSON.parse(s)}}}
function stable(s){return {hotbar:s.hotbar,active:s.active,type:s.type,parts:s.parts,blueprint:s.blueprint,history:s.history,remaining:s.remaining,inventory:s.inventory}}
function sameSelection(a,b,label){assert.deepEqual(stable(b),stable(a),label);assert.equal(b.inventory,true,label+' keeps inventory open')}
function sameRun(a,b){assert.equal(a.wave,b.wave);assert.equal(a.lives,b.lives);assert.equal(a.worldTime,b.worldTime,'World clock paused during edit');assert.equal(a.runTime,b.runTime,'Run clock paused during edit')}
function normalizeObservation(s){for(const k of ['widgets','cards','supplies','candidates','slots','partRecords']){if(s[k]===undefined)continue;if(!Array.isArray(s[k])){assert.deepEqual(s[k],{},'Only Lua empty tables may normalize to arrays: '+k);s[k]=[]}}return s}
function startupGate(){let ready=false;return {observe(text){if(/(?:^|\s)ENDLESS_STOCK_OBSERVER_READY$/.test(text))ready=true},ready(){return ready}}}
function hallReady(s){return !!s&&s.mode==='hangar'&&s.tab==='hangar'&&s.loading===false&&Array.isArray(s.widgets)&&s.widgets.some(w=>w.text==='出战'&&!w.disabled&&w.rect?.[2]>0)}
async function heldHistoryShortcut(keyboard,key,observe,pause=sleep){
 assert.match(key,/^Control\+[zy]$/,'Only actual editor history shortcuts');
 const letter=key.slice(-1);await keyboard.down('Control');
 try{
  await pause(120);await keyboard.down(letter);await pause(80);
  await observe();
 }finally{
  try{await keyboard.up(letter)}finally{await keyboard.up('Control')}
 }
}
function releasedPointer(s){return !!s&&s.mode==='trial'&&s.pointer?.captured===false&&s.pointer?.pending===false&&s.endless?.state==='rest'}
function pauseMenuReady(s){return releasedPointer(s)&&s.overlayState?.owner==='app.trial.dialog'&&s.overlayState?.title==='暂停'&&s.overlayState?.open===true}
function exitHudReady(s){
 if(!releasedPointer(s)||!s.overlayState)return false;
 const o=s.overlayState,stack=Array.isArray(o.stack)?o.stack:o.stack&&Object.keys(o.stack).length===0?[]:null;
 if(o.present===false)return stack?.length===0;
 if(o.present!==true||o.stackAvailable!==true||!stack||stack.length===0)return false;
 return stack.every(item=>item.owner==='main.performancePanel'&&item.visible===true&&item.pointerEvents==='box-none');
}
async function releaseExitPointer(actions){
 await actions.escape();
 const paused=await actions.observe(pauseMenuReady,'actual Escape releases driving pointer and opens pause menu');
 assert(pauseMenuReady(paused),'Actual pointer release and pause menu required');actions.snap('actual pause menu after Escape',paused);
 await actions.backdrop(paused);
 const released=await actions.observe(exitHudReady,'actual pause backdrop close leaves HUD pointer released');
 assert(exitHudReady(released),'Actual released HUD without blocking dialog required');actions.snap('actual released HUD before finish',released);
 return released;
}
function selfTest(){
 const gate=startupGate();for(const text of ['Module.calledRun=true','BootstrapPipeline: executing LoadPreloadResources','ENDLESS_STOCK_OBSERVER_READYING'])gate.observe(text);assert.equal(gate.ready(),false);gate.observe('[13] INFO: ENDLESS_STOCK_OBSERVER_READY');assert.equal(gate.ready(),true);
 const hall={mode:'hangar',tab:'hangar',loading:false,widgets:[{text:'出战',disabled:false,rect:[0,0,200,60]}]};assert(hallReady(hall));for(const broken of [null,{mode:'hangar',loading:false,tab:false,widgets:{}},{...hall,loading:true},{...hall,widgets:[]},{...hall,tab:'story'}])assert.equal(hallReady(broken),false);
 const text=JSON.stringify({name:'激光炮',hotbar:[false,'laser1']}),packet={sequence:1,count:1,index:1,bytes:Buffer.byteLength(text),checksum:checksum(text),data:text},t=transport();t.add(packet);assert.deepEqual(t.value(),JSON.parse(text));
 assert.throws(()=>t.add(packet));
 const bad=transport();bad.add({...packet,bytes:packet.bytes+1});assert.throws(()=>bad.value());
 const corrupt=transport();corrupt.add({...packet,data:text.replace('laser1','laser2')});assert.throws(()=>corrupt.value());assert.throws(()=>transport().add({...packet,checksum:undefined}));
 const incomplete=transport(),partial='{\"widgets\":[{\"rect\":[0,0,';incomplete.add({...packet,data:partial,bytes:Buffer.byteLength(partial),checksum:checksum(partial)});assert.throws(()=>incomplete.value());
 const s={hotbar:['laser1'],active:1,type:'laser1',parts:3,blueprint:{parts:[1]},history:{undo:1,redo:0},remaining:{laser1:0},inventory:true,wave:1,lives:3,worldTime:10,runTime:10};sameSelection(s,structuredClone(s),'unchanged');sameRun(s,structuredClone(s));
 for(const mutate of [s=>s.hotbar.push('x'),s=>s.active++,s=>s.type='x',s=>s.parts++,s=>s.blueprint.parts.push(2),s=>s.history.undo++,s=>s.remaining.laser1++,s=>s.inventory=false]){const b=structuredClone(s);mutate(b);assert.throws(()=>sameSelection(s,b,'negative control'))}
 for(const k of ['wave','lives','worldTime','runTime']){const b=structuredClone(s);b[k]++;assert.throws(()=>sameRun(s,b))}
 assert.deepEqual(normalizeObservation({widgets:{},supplies:{}}),{widgets:[],supplies:[]});assert.throws(()=>normalizeObservation({widgets:{broken:true}}));
 console.log('PASS: actual PostUpdate startup readiness gate and visible loaded hall; UTF-8/checksum transport, corruption/duplicate/truncation/incomplete JSON rejection; 12 selection/pause negative controls; Lua empty table normalization');
}
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out),'Never overwrite evidence');fs.mkdirSync(out,{recursive:true});
 const report={status:'RUNNING',startedAt:new Date().toISOString(),checks:[],errors:[],httpErrors:[],states:[],entryBoundary:'Existing isolated --qa PageDown calls production SelectEndless; this is a controlled QA entry, not public menu navigation. Starter selection and retained editor use actual input; inventory and blueprint are never injected.'};const deadline=Date.now()+600000;
 let browser,page,state,sequence=0,cancelled,runtimeState,runtimeSequence=0;const packets=new Map(),startup=startupGate();let mouse={x:800,y:450};
 const sigint=()=>{cancelled='SIGINT'},sigterm=()=>{cancelled='SIGTERM'};process.once('SIGINT',sigint);process.once('SIGTERM',sigterm);
 const save=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
 const progress=label=>{report.stage=label;save();console.log(JSON.stringify({stage:label,out}))};
 const healthy=()=>{assert(!cancelled,'Requested '+cancelled+' cancellation');assert(Date.now()<deadline,'600s total deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors[0]))};
 try{
  const identity=await fetch(base+'/identity.json').then(r=>{assert(r.ok);return r.json()});assert.equal(identity.endlessStockObserver,true);assert.equal(identity.qa,true);report.identity=identity;
  report.toolHashes={};for(const name of ['endless-edit-stock-web-run.cjs','endless-edit-stock-web-observer.lua','endless-edit-stock-web-serve.cjs'])report.toolHashes[name]=hash(fs.readFileSync(path.join(__dirname,name)));
  assert.equal(identity.endlessStockObserverSha256,report.toolHashes['endless-edit-stock-web-observer.lua'],'Actual server uses the frozen revised observer');
  const relative=path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/');const manifest=await fetch(base+'/game-dist/'+relative).then(r=>r.json());
  report.sourceHashes={};for(const name of ['endless/Edit.lua','app/BuildSession.lua','ui/InventoryPanel.lua','construction/BuildEditor.lua','construction/GridRay.lua','construction/Placement.lua','controls/BuildInput.lua']){const e=manifest.files.find(f=>f.fs_path===name);assert(e);const b=Buffer.from(await fetch(base+'/game-dist/assets/'+e.uuid+'-'+e.hash+e.ext).then(r=>r.arrayBuffer()));assert.equal(hash(b),identity.identity.scripts[name]);report.sourceHashes[name]=hash(b)}
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',m=>{const text=m.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');startup.observe(text);if(m.type()==='error'||/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\bERROR:/.test(text))report.errors.push(text);const runtimeAt=text.indexOf('OUTGAME_STATE ');if(runtimeAt>=0)try{runtimeState=JSON.parse(text.slice(runtimeAt+14));runtimeSequence++}catch(e){report.ancillaryTelemetryParseErrors=report.ancillaryTelemetryParseErrors||[];report.ancillaryTelemetryParseErrors.push({runtimeSequence,bytes:Buffer.byteLength(text),message:e.message,tail:text.slice(-120)})}const at=text.indexOf('ENDLESS_STOCK_CHUNK ');if(at>=0)try{const v=JSON.parse(text.slice(at+20));let t=packets.get(v.sequence);if(!t){t=transport();packets.set(v.sequence,t)}t.add(v);if(t.ready()){state=normalizeObservation(t.value());sequence=v.sequence;packets.delete(v.sequence)}}catch(e){report.errors.push(e.stack)}});
  page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Renderer crashed'));page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({url:r.url(),status:r.status()})});page.on('requestfailed',r=>report.httpErrors.push({url:r.url(),error:r.failure()?.errorText}));
  async function poll(){const old=sequence,until=Date.now()+8000;while(sequence===old){healthy();assert(Date.now()<until,'F8 state deadline');await page.keyboard.press('F8');const t=Date.now()+800;while(sequence===old&&Date.now()<t){healthy();await sleep(30)}}return state}
  async function wait(predicate,label,ms=20000){progress(label);const until=Date.now()+ms;while(!state||!predicate(state)){healthy();assert(Date.now()<until,'Stage deadline '+label);await sleep(150);await poll()}return state}
  async function runtimeWait(predicate,label,ms=10000){progress(label);const before=runtimeSequence,until=Date.now()+ms;while(runtimeSequence===before||!predicate(runtimeState)){healthy();assert(Date.now()<until,'Runtime telemetry deadline '+label);await sleep(150);await poll()}return runtimeState}
  const center=r=>({x:(r[0]+r[2]/2)/state.width*1600,y:(r[1]+r[3]/2)/state.height*900});
  async function rect(r,options){const p=center(r);mouse=p;await page.mouse.click(p.x,p.y,options);await sleep(180);return poll()}
  async function click(text){await wait(s=>s.widgets.some(w=>w.text===text&&!w.disabled&&w.rect?.[2]>0),'button '+text);return rect(state.widgets.find(w=>w.text===text&&!w.disabled&&w.rect?.[2]>0).rect)}
  async function press(key){await page.keyboard.press(key);await sleep(180);return poll()}
  const snap=label=>{report.states.push({label,state:structuredClone(state)});save()};
  async function search(id){if(!state.inventory)await press('b');await wait(s=>s.inventory&&s.search,'inventory ready');await rect(state.search);await page.keyboard.press('Control+a');await page.keyboard.insertText(id);await sleep(250);await poll();await wait(s=>s.cards.some(c=>c.id==='laser1'),'laser card search');return state.cards.find(c=>c.id==='laser1')}
  async function closeInventory(){if(state.inventory)await rect(state.close);await wait(s=>!s.inventory,'inventory closed')}
  async function capture(){if(!state.camera.captured){mouse={x:800,y:450};await page.mouse.click(mouse.x,mouse.y);await sleep(250);await poll()}await wait(s=>s.camera.captured,'actual editor pointer capture')}
  async function historyShortcut(key,label){
   await capture();assert(!state.inventory,'Actual history input outside inventory');
   assert(state.inputFocus&&!state.inputFocus.textInput,'Actual history input has no text field focus');
   report.historyInputs=report.historyInputs||[];
   const activeElement=await page.evaluate(()=>{const e=document.activeElement;return e?{tag:e.tagName,id:e.id||'',type:e.type||'',contentEditable:e.isContentEditable}:null});
   const attemptsBefore=state.keyAudit?.attempts?.length||0;
   report.historyInputs.push({label,key,activeElement,before:structuredClone(state.inputFocus)});save();
   await heldHistoryShortcut(page.keyboard,key,async()=>{
    await wait(s=>(s.keyAudit?.attempts?.length||0)>attemptsBefore,label+' held key dispatch',5000);snap(label+' key dispatch');
    assert.equal(state.keyAudit?.attempts?.length,attemptsBefore+1,'Exactly one new actual history key dispatch');
    const attempt=state.keyAudit?.attempts?.at(-1);assert(attempt,'Actual BuildSession.Keys shortcut dispatch observed');
    assert(attempt.ctrl,'Actual engine Control key held during shortcut dispatch');
    assert(!attempt.focus.textInput&&!attempt.focus.inventory&&!attempt.focus.dialog,'Actual shortcut reaches editor without modal/text focus');
    assert(key.endsWith('z')?attempt.z:attempt.y,'Actual engine history key press observed');
   });
  }
  const angle=x=>Math.atan2(Math.sin(x),Math.cos(x));
  async function aim(target){await capture();for(let i=0;i<12;i++){const dx=-angle(target.yaw-state.camera.yaw)/.0022,dy=-(target.pitch-state.camera.pitch)/.0022;if(Math.abs(dx)<1.5&&Math.abs(dy)<1.5)return;const scale=Math.min(1,55/Math.max(Math.abs(dx),Math.abs(dy)));mouse={x:mouse.x+dx*scale,y:mouse.y+dy*scale};await page.mouse.move(mouse.x,mouse.y);await sleep(100);await poll()}throw Error('Actual pointer movement did not align camera')}
  const url=base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login';report.url=url;await page.goto(url,{waitUntil:'domcontentloaded',timeout:30000});await page.bringToFront();
  await page.waitForFunction(()=>globalThis.Module?.calledRun===true,{},{timeout:120000});
  progress('actual game observer bootstrap');const startupDeadline=Date.now()+120000;
  while(!startup.ready()){healthy();assert(Date.now()<startupDeadline,'Game PostUpdate observer startup deadline');await sleep(100)}
  report.observerReadyAt=new Date().toISOString();await wait(hallReady,'visible loaded hall ready',120000);
  for(let i=0;i<8;i++){await poll();const skip=state.widgets.find(w=>/^(跳过引导|确定跳过？再点一次)$/.test(w.text));if(skip){await click(skip.text);continue}if(state.tab==='hangar')break;await click('机库')}
  progress('controlled QA SelectEndless entry');await page.keyboard.press('PageDown',{delay:80});await sleep(180);await poll();await click('先锋 · 轮式激光');await wait(s=>s.mode==='trial'&&s.state&&!s.loading,'actual endless loaded',120000);snap('natural countdown');
  const clearDeadline=Date.now()+90000;while(state.state!=='rest'){healthy();assert(Date.now()<clearDeadline,'Natural wave spawn/clear deadline');if(state.enemies>0)await press('F2');else{await sleep(400);await poll()}}snap('natural wave rest after QA kills spawned enemies');assert.equal(state.wave,1);
  if(state.supplies.length){const choice=state.supplies.find(s=>s.kind==='repair'||s.type!=='laser1')||state.supplies[0];await click(choice.name);await wait(s=>s.supplies.length===0,'actual supply choice')}
  await press('F3');await press('g');await wait(s=>s.editing,'retained actual editor');if(state.mirror)await press('m');assert.equal(state.mirror,false);const entered=structuredClone(state);snap('editor entered');assert((state.remaining.laser1||0)>0,'Real starter spare laser required');assert((state.remaining.laser1||0)<=6,'Bounded installation workload');
  let card=await search('激光');assert(!card.disabled&&!card.unavailable);await rect(card.rect);await closeInventory();assert.equal(state.type,'laser1');const remainingStart=state.remaining.laser1;let lastInstalled;report.placementAttempts=[];
  async function selectType(kind){const slot=state.hotbar.indexOf(kind);assert(slot>=0,'Real hotbar contains '+kind);await press(String((slot+1)%10));assert.equal(state.type,kind,'Actual hotbar selected '+kind)}
  async function placeActual(candidate,kind,label){
   await aim(candidate);const pv=state.preview;
   report.placementAttempts.push({label,candidate,actualPreview:pv,hit:state.hit});save();
   if(!pv||pv.type!==kind||!pv.ok)return false;
   const before=state.parts,count=state.counts.laser1||0,remaining=state.remaining.laser1,ids=new Set(state.partRecords.map(p=>p.id));
   await page.mouse.click(mouse.x,mouse.y);await sleep(220);await poll();if(state.parts!==before+1)return false;
   const installed=state.partRecords.filter(p=>!ids.has(p.id));assert.equal(installed.length,1);assert.equal(installed[0].type,kind);
   assert.equal(state.counts.laser1||0,count+(kind==='laser1'?1:0));assert.equal(state.remaining.laser1,remaining-(kind==='laser1'?1:0));
   snap(label);return {yaw:state.camera.yaw,pitch:state.camera.pitch,id:installed[0].id};
  }
  for(let install=0;install<remainingStart;install++){
   progress('actual foundation then laser placement '+(install+1));await selectType('cube');
   const foundations=structuredClone(state.candidates).filter(c=>c.legal&&c.type==='cube'&&c.normal[1]===1&&c.cell[2]>=3).sort((a,b)=>a.cell[1]-b.cell[1]||a.ordinal-b.ordinal);
   let foundation;
   for(const candidate of foundations){foundation=await placeActual(candidate,'cube','actual unlimited foundation '+(install+1));if(foundation)break}
   assert(foundation,'No legal actual front structural foundation; never manufacture stock or commits');
   await selectType('laser1');
   const mounts=structuredClone(state.candidates).filter(c=>c.legal&&c.part===foundation.id&&c.normal[1]===1);let added=false;
   for(const candidate of mounts){lastInstalled=await placeActual(candidate,'laser1','actual limited laser '+(install+1));if(lastInstalled){added=true;break}}
   assert(added,'No legal actual laser mount on the placed foundation; never manufacture inventory or commits');
  }
  assert.equal(state.remaining.laser1,0);await press('Escape');card=await search('激光');assert(card.disabled&&card.unavailable);snap('actual installations exhaust laser stock');const exhausted=structuredClone(state);sameRun(entered,exhausted);
  for(const [label,act]of [['disabled click',()=>rect(card.rect)],['disabled double click',()=>rect(card.rect,{clickCount:2,delay:90})],['disabled drag',async()=>{const from=center(card.rect),to=center(state.slots[10-1]);mouse=from;await page.mouse.move(from.x,from.y);await page.mouse.down();await page.mouse.move(to.x,to.y,{steps:12});await page.mouse.up();mouse=to;await sleep(200);await poll()}]]){await act();sameSelection(exhausted,state,label);assert.equal(state.drag,false);snap(label)}
  await rect(state.search);for(let i=0;i<80&&state.focus!=='laser1';i++)await press('Tab');assert.equal(state.focus,'laser1','Actual Tab reaches disabled card');
  for(const key of ['Enter','Space','0']){await press(key);sameSelection(exhausted,state,'disabled keyboard '+key)}snap('disabled keyboard activation/assignment rejected');
  await closeInventory();const count=state.parts;await historyShortcut('Control+z','actual undo');assert.equal(state.parts,count-1);assert.equal(state.remaining.laser1,1);card=await search('激光');assert(!card.disabled&&!card.unavailable);snap('actual undo restores stock');await closeInventory();await historyShortcut('Control+y','actual redo');assert.equal(state.parts,count);assert.equal(state.remaining.laser1,0);snap('actual redo consumes stock');
  await aim(lastInstalled);
  if(state.hit?.partId!==lastInstalled.id){for(const candidate of structuredClone(state.candidates).filter(c=>c.part===lastInstalled.id)){await aim(candidate);if(state.hit?.partId===lastInstalled.id)break}}
  assert.equal(state.hit?.partId,lastInstalled.id,'Actual removal ray hits the exact installed laser');const hitType=state.partRecords.find(p=>p.id===state.hit.partId)?.type;assert.equal(hitType,'laser1');report.removalHitType=hitType;
  // Aim at the same face now occupied by the placed laser; verify the real hit
  // against the newly added IDs before the public right-button removal.
  const addedIds=state.partRecords.filter(p=>!entered.partRecords.some(q=>q.id===p.id)).map(p=>p.id);assert(addedIds.includes(state.hit.partId),'Removal targets an actual newly installed part');
  await page.mouse.click(mouse.x,mouse.y,{button:'right'});await sleep(220);await poll();assert.equal(state.parts,count-1);assert.equal(state.remaining.laser1,1);snap('actual removal returns stock');await press('Escape');await click('重置本次改装');assert.deepEqual(state.blueprint,entered.blueprint);snap('public reset restores original valid blueprint');
  await click('Enter · 出发');await wait(s=>!s.editing&&s.state==='rest','same wave resumed');assert.equal(state.wave,entered.wave);assert.equal(state.lives,entered.lives);const resumed=structuredClone(state);await sleep(800);await poll();assert(state.worldTime>resumed.worldTime&&state.runTime>resumed.runTime,'Clocks resume after edit');snap('resumed clocks');
  await page.locator('#canvas').screenshot({path:path.join(out,'resumed.png')});
  await releaseExitPointer({escape:()=>press('Escape'),observe:runtimeWait,
   backdrop:async()=>{mouse={x:12,y:450};await page.mouse.click(mouse.x,mouse.y);await sleep(220);await poll()},
   snap:(label,s)=>{report.exitInputs=report.exitInputs||[];report.exitInputs.push({label,runtimeSequence,pointer:structuredClone(s.pointer),overlayState:structuredClone(s.overlayState),endless:structuredClone(s.endless),mouse:structuredClone(s.mouse)});save()}});
  await click('结束本局');await wait(s=>s.state==='over'&&!s.editing,'actual public endless summary');snap('actual finished summary');
  await click('回主页');await wait(hallReady,'public return hall',90000);snap('returned hall');await page.locator('#canvas').screenshot({path:path.join(out,'returned.png')});
  report.checks=['Frozen source HTTP hashes match identity','Controlled QA SelectEndless entry, actual starter selection and natural wave countdown/spawn; QA F2 kills only spawned enemies','Actual supply and G editor entry','Actual mouse placement exhausts real spare lasers','Disabled click/double click/drag/Enter/Space/digit preserve selection and blueprint','Actual undo/redo/removal preserve inventory accounting','World/run clocks pause in editor and resume afterward','Reset and depart retain wave/lives','Actual Escape releases driving pointer, public backdrop closes pause without recapture','Actual public finish enters summary and return reaches visible loaded hall'];report.status='PASS';
 }catch(e){report.status='FAIL';report.failure=e.stack;if(page)try{await page.screenshot({path:path.join(out,'failure.png'),timeout:3000})}catch{}throw e}
 finally{if(browser)try{await Promise.race([browser.close(),sleep(5000).then(()=>{throw Error('Browser close timeout')})]);report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.closeError=e.message}process.removeListener('SIGINT',sigint);process.removeListener('SIGTERM',sigterm);report.finishedAt=new Date().toISOString();report.lastState=state;save();console.log(JSON.stringify({status:report.status,shutdown:report.shutdown,out,failure:report.failure}))}
 return report;
}
module.exports={transport,checksum,stable,sameSelection,sameRun,normalizeObservation,startupGate,hallReady,selfTest,heldHistoryShortcut,releasedPointer,pauseMenuReady,exitHudReady,releaseExitPointer,run};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else run(process.argv[2],path.resolve(process.argv[3])).catch(e=>{console.error(e.stack);process.exitCode=1})}

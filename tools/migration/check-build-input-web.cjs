// Public hall/build controls only. F8 is read-only QA observation.
// No gameplay evaluation, console commands, mode mutation or injected blueprint.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..');
const base=process.env.VOX_QA_BASE||'http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4454);
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const productionNames=['app/BuildSession.lua','controls/BuildInput.lua','controls/Wheel.lua','controls/BuildCamera.lua','controls/FreeFlight.lua','construction/BuildEditor.lua','construction/BuildStretch.lua','construction/EditHistory.lua'];
const normalizedIds=value=>Object.values(value||{}).sort((a,b)=>a-b);
function canonicalParts(state){
 assert(state.buildSelection?.active&&state.buildSelection.parts,'Actual selection mode exposes complete blueprint observation');
 return JSON.stringify(Object.values(state.buildSelection.parts).map(p=>({id:p.id,type:p.type,pos:p.pos,rot:p.rot,g:p.g,color:p.color??null,shellColor:p.shellColor??null})).sort((a,b)=>a.id-b.id));
}
(async()=>{
 const response=await fetch(base+'/identity.json');assert(response.ok,'Actual QA HTTP identity');
 const identity=await response.json();assert(identity.qa,'Read-only QA observer required');
 if(process.env.VOX_EXPECT_MANIFEST)assert.equal(identity.servedManifest,process.env.VOX_EXPECT_MANIFEST,'Pinned acceptance package');
 const production={};
 for(const name of productionNames){const hash=sha(fs.readFileSync(path.join(root,'scripts',name)));assert.equal(identity.identity.scripts[name],hash,'Current frozen module '+name);production[name]=hash;}
 const out=path.join(root,'docs/migration/evidence/build-input-web-'+identity.servedManifest.replace('.json','')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log(out);
 const report={identity,production,result:'RUNNING',checks:[],states:[],errors:[],httpFailures:[],probeErrors:[],
  open:[
   {id:'orbit-modifier-zoom',reason:'The public construction entry exposes first-person only. Actual orbit distance scaling remains OPEN; this run signs first-person modifier priority only.'},
   {id:'orbit-press-hit',reason:'Press/release target snapshots and Euclidean click travel belong to the orbit adapter. No public orbit switch exists; no hidden mode injection is allowed.'},
   {id:'real-mobile-input',reason:'Desktop Chromium run only; real phone, mobile event ordering and frame pacing are not exercised.'},
   {id:'visual-parity',reason:'Screenshots are retained for human review. Nonblank pixels do not establish full H5 visual parity.'}
  ],
  boundary:'Actual public hall edit button, pointer capture, real authored vehicle, placement, selection, stretch, keyboard cancellation/history, first-person right deselection and middle-pick. F8 read-only. No injected model, camera mode, editor call or gameplay state. Source baseline 2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455.'};
 let browser,page,state,sequence=0,crashed=false;
 const check=(value,label)=>{report.checks.push({label,pass:!!value});assert(value,label);};
 try{
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
  page=await browser.newPage({viewport:{width:1920,height:1080},deviceScaleFactor:1});
  page.on('console',message=>{
   const text=message.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');
   const at=text.indexOf('OUTGAME_STATE ');
   if(at>=0){try{
    state=JSON.parse(text.slice(at+14));if(state.buildSelection)state.buildSelection.ids=normalizedIds(state.buildSelection.ids);sequence++;
    for(const error of report.probeErrors)if(error.transportTruncated&&!error.recoveredBySequence)error.recoveredBySequence=sequence;
   }catch(error){report.probeErrors.push({error:String(error),length:text.length,afterSequence:sequence,
    transportTruncated:/Unexpected end of JSON input/.test(String(error))&&!text.trimEnd().endsWith('}'),rawLog:'runtime.log'});}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(text))report.errors.push(text);
  });
  page.on('pageerror',error=>report.errors.push(String(error)));
  page.on('crash',()=>{crashed=true;report.errors.push('Renderer crashed');});
  page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  async function key(name){await page.keyboard.press(name,{delay:80});await sleep(160);}
  async function wait(predicate,label,timeout=240000){
   const started=Date.now();let next=0;
   while(true){
    if(crashed||report.errors.length)throw Error(label+': '+JSON.stringify(report.errors.at(-1)));
    if(state&&predicate(state))return state;
    if(Date.now()-started>timeout)throw Error('Timeout '+label);
    if(Date.now()>=next){next=Date.now()+700;await key('F8');}await sleep(60);
   }
  }
  async function dump(){const before=sequence;await key('F8');await wait(()=>sequence>before,'fresh F8 observation',15000);return structuredClone(state);}
  async function point(x,y){const c=await page.locator('canvas').boundingBox();assert(c,'Actual game canvas');return {x:c.x+x/state.width*c.width,y:c.y+y/state.height*c.height};}
  async function clickRect(rect){assert(rect?.length===4,'Observed public edit rectangle');const p=await point(rect[0]+rect[2]/2,rect[1]+rect[3]/2);await page.mouse.click(p.x,p.y,{delay:70});await sleep(200);await dump();}
  async function click(button='left'){await page.mouse.down({button});await sleep(55);await page.mouse.up({button});await sleep(200);await dump();}
  async function screenshot(name){
   await dump();report.states.push({stage:name,state:structuredClone(state)});
   const png=await page.screenshot({path:path.join(out,name+'.png')});
   check((await sharp(png).stats()).channels.slice(0,3).some(c=>c.stdev>15),'Actual nonblank screenshot '+name);
  }
  async function wheel(pixels,modifier){
   if(modifier)await page.keyboard.down(modifier);
   try{await page.mouse.wheel(0,pixels);await sleep(180);}finally{if(modifier)await page.keyboard.up(modifier);}
   await sleep(100);return dump();
  }
  async function selectMode(){if(!state.buildSelection.active){await key('q');await dump();}check(state.buildSelection.active,'Actual Q selection mode');}
  async function buildMode(){if(state.buildSelection.active){await key('q');await dump();}check(!state.buildSelection.active,'Actual Q leaves selection mode');}
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.tab==='hangar'&&s.sceneVisible&&!s.loadingFlow?.active,'actionable hall');await dump();
  await clickRect(state.homeRects?.edit);
  await wait(s=>s.build&&s.buildInput&&s.buildSelection&&!s.loadingFlow?.active,'public construction entry');
  check(state.buildInput.mode==='fp','Public desktop construction uses source first-person camera');
  const center=await point(state.width/2,state.height/2);await page.mouse.move(center.x,center.y);await click();
  await wait(s=>s.buildInput.captured,'actual pointer capture',15000);await screenshot('entered');

  // Observe every original part and turn mirror off through its actual key,
  // so one placement creates a known single, independent structural seed.
  await selectMode();const original=canonicalParts(state),initialParts=state.parts;
  const originalIds=new Set(Object.values(state.buildSelection.parts).map(p=>p.id));
  if(state.buildSelection.mirror){await key('m');await dump();}
  check(state.buildSelection.mirror===false,'Actual M disables mirrored placement for deterministic seed');
  if(state.buildGroups.joinNew){await key('f');await dump();}
  check(!state.buildGroups.joinNew,'Actual F leaves new placement independent of existing groups');
  await buildMode();await key('1');await dump();
  let mx=center.x,my=center.y;
  const aimAttempts=[];
  for(let attempt=0;attempt<32&&!state.buildInput.preview?.ok;attempt++){
   mx+=attempt%2?-6:3;my+=attempt%3?3:-4;
   await page.mouse.move(mx,my,{steps:2});await sleep(100);await dump();
   aimAttempts.push({attempt,hit:state.buildSelection.hit,preview:state.buildInput.preview});
  }
  report.aimAttempts=aimAttempts;
  check(state.buildInput.tool==='build'&&state.buildInput.preview?.ok,'Actual ray offers a valid structural placement');
  const revision=state.buildSelection.revision;await click();
  await wait(s=>s.parts===initialParts+1&&s.buildSelection.revision===revision+1,'one real structural placement',20000);
  let committedRevision=state.buildSelection.revision;
  await selectMode();const placed=canonicalParts(state);
  const added=Object.values(state.buildSelection.parts).filter(p=>!originalIds.has(p.id));
  check(added.length===1,'Actual placement created exactly one new structural seed');
  const seed=added[0];report.seed=seed;
  const catalogBytes=fs.readFileSync(path.join(root,'assets/Parts/Catalog.json'));
  const cellSize=JSON.parse(catalogBytes).cell;
  assert(Number.isFinite(cellSize)&&cellSize>0,'Actual structural cell size');
  report.aimCellSize={size:cellSize,catalogSha256:sha(catalogBytes)};
  check(state.buildSelection.hit?.id===seed.id,'Current actual center ray hits the placed seed');
  await click();
  check(state.buildSelection.ids.length===1&&state.buildSelection.ids[0]===seed.id,'Actual pointer selects the independent placed seed');

  // Populate a real redo stack too. Otherwise Ctrl+Y could incorrectly call
  // Redo on an empty stack and appear to cancel safely by coincidence.
  await key('p');await key('Alt+2');await dump();
  check(state.buildInput.tool==='paint'&&state.buildInput.color!==seed.color,'Actual alternate paint color differs from the placed seed');
  await click();await wait(s=>s.buildSelection.revision===committedRevision+1,'actual reversible paint transaction',10000);
  await key('Control+z');await dump();
  check(state.buildSelection.revision===committedRevision+2&&state.parts===initialParts+1,'Actual paint undo populates redo history while retaining placement undo');
  await selectMode();check(canonicalParts(state)===placed,'Preparing actual redo stack restores unchanged placed blueprint');
  committedRevision=state.buildSelection.revision;

  async function aimSeed(){
   // Shift is also the actual free-flight descend key. Its wheel check can
   // move the camera; reacquire the selected face using public mouse input.
   const cell=Object.values(seed._cells)[0];
   const target=[-cell[0]*cellSize,(cell[1]+.5)*cellSize,cell[2]*cellSize];
   report.seedReacquisitions??=[];
   for(let attempt=0;attempt<16&&state.buildSelection.hit?.id!==seed.id;attempt++){
    const camera=state.camera,p=camera.position,f=camera.forward;
    const dx=target[0]-p[0],dy=target[1]-p[1],dz=target[2]-p[2];
    const yaw=Math.atan2(dx,-dz),currentYaw=Math.atan2(f[0],-f[2]);
    const angle=Math.atan2(Math.sin(yaw-currentYaw),Math.cos(yaw-currentYaw));
    const pitch=Math.atan2(dy,Math.hypot(dx,dz)),currentPitch=Math.asin(Math.max(-1,Math.min(1,f[1])));
    const moveX=Math.max(-60,Math.min(60,-angle/.0022)),moveY=Math.max(-60,Math.min(60,-(pitch-currentPitch)/.0022));
    mx+=moveX;my+=moveY;await page.mouse.move(mx,my,{steps:3});await sleep(150);await dump();
    report.seedReacquisitions.push({attempt,camera:structuredClone(state.camera),hit:state.buildSelection.hit,move:[moveX,moveY]});
   }
   check(state.buildSelection.hit?.id===seed.id,'Actual center ray reacquires the selected seed before stretch');
  }
  async function startStretch(){
   await aimSeed();
   await key('j');await dump();check(state.buildInput.tool==='stretch','Actual J enters source stretch tool');
   await click();await wait(s=>s.buildStretch?.phase==='selection','actual selected-face extrusion',15000);
   check(state.parts===initialParts+1&&state.buildSelection.revision===committedRevision,'Starting stretch creates no committed edit');
  }
  await startStretch();
  const firstHeight=state.buildStretch.h,slot=state.buildInput.slot;
  await wheel(-1);check(state.buildStretch.h===firstHeight+1,'One negative CSS pixel immediately increases stretch by one');
  await wheel(1);check(state.buildStretch.h===firstHeight,'One positive CSS pixel immediately decreases stretch by one');
  await wheel(-100);const height=state.buildStretch.h,dist=state.camera.desiredDist;
  for(const modifier of ['Shift','Control']){
   await wheel(100,modifier);
   check(state.buildStretch.h===height,'Actual '+modifier+' wheel takes priority over stretch');
   check(Math.abs(state.camera.desiredDist-dist)<1e-8,'First-person '+modifier+' wheel does not change orbit distance');
  }
  check(state.buildInput.slot===slot&&state.buildSelection.revision===committedRevision&&state.parts===initialParts+1,'Actual wheel does not change hotbar, blueprint or committed history');
  await screenshot('stretch-wheel');

  for(const chord of ['Control+z','Control+Shift+z','Control+y']){
   if(!state.buildStretch)await startStretch();
   await key(chord);await dump();
   check(!state.buildStretch&&state.parts===initialParts+1&&state.buildSelection.revision===committedRevision,chord+' cancels only the uncommitted preview');
   await selectMode();check(canonicalParts(state)===placed,chord+' preserves every actual part, finish and group');
   await screenshot('cancel-'+chord.toLowerCase().replaceAll('+','-'));
  }
  await key('Control+z');await dump();
  check(state.parts===initialParts&&state.buildSelection.revision===committedRevision+1,'First undo after preview cancellation still undoes the prior real placement');
  check(canonicalParts(state)===original,'Actual prior placement undo restores original blueprint');
  await key('Control+y');await dump();
  check(state.parts===initialParts+1&&state.buildSelection.revision===committedRevision+2,'Actual redo remains available after cancellation');
  check(canonicalParts(state)===placed,'Actual redo restores placed seed and all original groups');

  // First-person right deselection is publicly reachable. The orbit-specific
  // press/release adapter remains explicitly OPEN in report.open above.
  await key('Control+a');await dump();
  check(state.buildSelection.ids.length===state.parts,'Actual Ctrl+A selects the whole authored vehicle');
  const selectedCount=state.buildSelection.ids.length;let selectRevision=state.buildSelection.revision;
  await click('right');
  check(state.buildSelection.ids.length<selectedCount&&state.buildSelection.ids.length>0,'Actual first-person right click removes current target from selection');
  check(state.parts===initialParts+1&&state.buildSelection.revision===selectRevision&&canonicalParts(state)===placed,'Actual right deselection cannot delete blueprint parts');
  await screenshot('right-deselect');

  // Form groups through the actual F shortcut, test a multi-part group if the
  // placed seed is face-connected to authored structure, then undo that edit.
  await key('Control+a');await dump();await key('f');await dump();
  check(state.buildSelection.revision===selectRevision+1&&state.parts===initialParts+1,'Actual F groups the selected authored structure as one transaction');
  const grouped=canonicalParts(state),hitId=state.buildSelection.hit?.id;
  const member=Object.values(state.buildGroups.parts||{}).find(p=>p.id===hitId);
  const groupIds=member?Object.values(state.buildGroups.parts).filter(p=>p.g===member.g).map(p=>p.id):[];
  if(groupIds.length>1){
   const before=new Set(state.buildSelection.ids);await click('right');
   check(groupIds.every(id=>before.has(id)&&!state.buildSelection.ids.includes(id)),'Actual first-person right click deselects every member of the target group');
   check(state.parts===initialParts+1&&state.buildSelection.revision===selectRevision+1&&canonicalParts(state)===grouped,'Actual grouped deselection does not delete or edit parts');
   await screenshot('right-group-deselect');
  }else{
   report.open.push({id:'public-group-deselection',reason:'The actual center target did not form a multi-part group with nearby authored structure. Single-part deselection passed; group propagation remains OPEN.',hitId,groupIds});
  }
  await key('Control+z');await dump();selectRevision+=2;
  check(state.buildSelection.revision===selectRevision&&canonicalParts(state)===placed,'Actual undo restores all original groups after the group-input check');

  const targetId=state.buildSelection.hit?.id;
  const target=Object.values(state.buildSelection.parts).find(p=>p.id===targetId);check(!!target,'Actual middle-pick target is observed');
  await key('p');await dump();check(state.buildInput.tool==='paint','Actual P enters paint mode');
  await click('middle');
  check(state.buildInput.tool==='build'&&!state.buildSelection.active,'Actual first-person middle pick exits paint/selection');
  check(state.buildInput.preview?.type===target.type,'Actual middle pick chooses target part type');
  check(state.parts===initialParts+1&&state.buildSelection.revision===selectRevision,'Actual middle pick does not edit blueprint');
  await screenshot('middle-pick');

  // Remove the test seed with real undo; do not persist a modified test car.
  await selectMode();await key('Control+z');await dump();
  check(state.parts===initialParts&&canonicalParts(state)===original,'Final actual undo restores the original authored blueprint');
  await key('Escape');await dump();
  if(state.buildInput?.captured){await key('Escape');await dump();}
  check(!state.buildStretch,'No transient stretch remains after actual Escape');
  await screenshot('finished');
  const after=await fetch(base+'/identity.json').then(r=>r.json());
  check(JSON.stringify(after)===JSON.stringify(identity),'HTTP served identity remained unchanged throughout the run');
  check(report.errors.length===0,'No game runtime errors');
  check(!report.probeErrors.some(e=>!e.transportTruncated||!e.recoveredBySequence),'No malformed or unrecovered read-only observations');
  check(!report.httpFailures.some(f=>f.url.startsWith(base+'/game-dist/')),'No failed game resource requests');
  report.result='PASS_WITH_OPEN';
 }catch(error){
  report.result='FAIL';report.failure=error.stack;report.lastState=state;
  if(page)await page.screenshot({path:path.join(out,'failure.png'),timeout:5000}).catch(()=>{});
  process.exitCode=1;
 }finally{
  if(page)await page.close().catch(()=>{});
  if(browser)await browser.close().catch(()=>{});
  report.gameResourceHttpFailures=report.httpFailures.filter(f=>f.url.startsWith(base+'/game-dist/'));
  report.optionalHttpFailures=report.httpFailures.filter(f=>!f.url.startsWith(base+'/game-dist/'));
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({out,result:report.result,checks:report.checks.length,open:report.open.length}));
 }
})().catch(error=>{console.error(error);process.exitCode=1;});

// Public construction controls and real mouse/touch/keyboard input only.
// F8 observes the QA probe; this tool never invokes a gameplay method.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..');
const base=process.env.VOX_QA_BASE||'http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4359);
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const actions={move:'移动',copy:'复制',join:'连块 / 拆开',stretch:'拉伸',paint:'涂当前色',delete:'删除',clear:'取消'};
const cases=[{name:'pc',width:1920,height:1080,dpr:1},{name:'20x9',width:840,height:378,dpr:3,touch:true}];
const keysOnly=process.env.VOX_SELECTION_KEYS_ONLY==='1',skipKeys=process.env.VOX_SELECTION_SKIP_KEYS==='1';

(async()=>{
 assert(!(keysOnly&&skipKeys),'Keyboard-only and skip-keyboard modes are mutually exclusive');
 const response=await fetch(base+'/identity.json');assert(response.ok,'QA HTTP identity is accessible');
 const identity=await response.json();assert(identity.qa,'Read-only QA observer required');
 if(process.env.VOX_EXPECT_MANIFEST)assert.equal(identity.servedManifest,process.env.VOX_EXPECT_MANIFEST,'Pinned final package');
 const production={};
 for(const name of ['ui/SourceSelectionBar.lua','app/BuildSession.lua','construction/BuildEditor.lua','controls/BuildInput.lua','ui/TouchBuildControls.lua','audio/UiSound.lua','ui/ActionButton.lua','ui/GarageHud.lua']){
  const sha=crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'scripts',name))).digest('hex');
  assert.equal(identity.identity.scripts[name],sha,'Package contains current frozen '+name);production[name]=sha;
 }
 const out=path.join(root,'docs/migration/evidence/selection-actions-'+identity.servedManifest.replace('.json','')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log(out);
 const report={identity,production,keysOnly,skipKeys,cases:[],result:'RUNNING',boundary:'Public hall/build UI; requested keyboard-only mode signs only focused Enter, focused Space release, unfocused Enter build and actual pointer audio. Skip-keyboard mode does not sign keyboard behavior. Full mode uses PC Ctrl+A and actual landscape touchscreen tools/selection/projected vehicle taps; actual palette and selection buttons, undo/redo and clipboard shortcuts. F8 is read-only observation. No injected models, selection state, editor calls or SelectionAction calls. Desktop/emulated 840x378 DPR3 only, not real-phone performance or full visual parity.'};
 for(const test of cases.filter(t=>(!keysOnly||t.name==='pc')&&(!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name)))){
  const item={case:test.name,viewport:test,result:'RUNNING',keyboardResult:'NOT_RUN',selectionResult:'NOT_RUN',checks:[],errors:[],httpFailures:[],probeErrors:[],states:[],selectionAttempts:[]};report.cases.push(item);
  let browser,page,cdp,state,sequence=0,crashed=false;
  const check=(ok,label)=>{item.checks.push({label,pass:!!ok});assert(ok,label);};
  try{
   browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
   page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,...(test.touch?{hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36'}:{})});
   page.on('console',message=>{
    const text=message.text();fs.appendFileSync(path.join(out,test.name+'.log'),text+'\n');
    const at=text.indexOf('OUTGAME_STATE ');
    if(at>=0){try{state=JSON.parse(text.slice(at+14));if(state.buildSelection)state.buildSelection.ids=Object.values(state.buildSelection.ids||{});sequence++;}catch(error){item.probeErrors.push({error:String(error),length:text.length,tail:text.slice(-120)});}}
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(text))item.errors.push(text);
   });
   page.on('pageerror',error=>item.errors.push(String(error)));
   page.on('crash',()=>{crashed=true;item.errors.push('Renderer crashed');});
   page.on('response',r=>{if(r.status()>=400)item.httpFailures.push({status:r.status(),url:r.url()});});
   async function key(name){await page.keyboard.press(name,{delay:90});await sleep(100);}
   async function wait(predicate,label,timeout=240000){
    const started=Date.now();let next=0;
    while(true){
     if(crashed||item.errors.length)throw Error(label+': '+JSON.stringify(item.errors.at(-1)));
     if(state?.loadingFlow?.active&&state.loadingFlow.match)throw Error('Unexpected match loading triggered during '+label);
     if(state&&predicate(state))return state;
     if(Date.now()-started>timeout)throw Error('Timeout '+label);
     if(Date.now()>=next){next=Date.now()+800;await key('F8');}await sleep(80);
    }
   }
   async function dump(){const before=sequence;await key('F8');await wait(()=>sequence>before,'fresh complete F8 observation',15000);return structuredClone(state);}
   async function point(x,y){const canvas=await page.locator('canvas').boundingBox();assert(canvas,'Actual game canvas');return {x:canvas.x+x/state.width*canvas.width,y:canvas.y+y/state.height*canvas.height};}
   async function tapRect(rect){assert(rect?.length===4,'Observed public rectangle');const p=await point(rect[0]+rect[2]/2,rect[1]+rect[3]/2);if(test.touch)await page.touchscreen.tap(p.x,p.y);else await page.mouse.click(p.x,p.y,{delay:70});await sleep(250);return dump();}
   async function text(label,kind){await dump();const w=state.widgets.find(w=>w.text===label&&(!kind||w.kind===kind)&&!w.disabled);assert(w,'Public control '+label);return tapRect(w.rect);}
   async function mobile(id){await dump();const rect=state.touchControls?.rects?.[id];assert(rect,'Actual touch control '+id);return tapRect(rect);}
   async function capture(name){
    await dump();item.states.push({stage:name,state:structuredClone(state)});
    const png=await page.screenshot({path:path.join(out,test.name+'-'+name+'.png')});
    check((await sharp(png).stats()).channels.slice(0,3).some(c=>c.stdev>15),'Nonblank actual '+name);
   }
   const sound=s=>s.audioSettings?.uiSound||s.uiSound;
   const paintCount=()=>sound(state)?.counts?.paint||0;
   const actionWidget=id=>(state.widgets||[]).find(w=>w.action===id&&w.text===actions[id]&&!w.disabled);
   async function scrollBar(direction){
    const rect=state.buildSelection.bar.rect;const a=await point(rect[0]+(direction>0?rect[2]-28:28),rect[1]+rect[3]/2);
    const b=await point(rect[0]+(direction>0?28:rect[2]-28),rect[1]+rect[3]/2);
    if(test.touch){
     cdp=cdp||await page.context().newCDPSession(page);
     await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:81,...a}]});
     for(let step=1;step<=8;step++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:81,x:a.x+(b.x-a.x)*step/8,y:a.y}]});await sleep(30);}
     await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    }else{await page.mouse.move((a.x+b.x)/2,a.y);await page.mouse.wheel(direction*420,0);}
    await sleep(450);await dump();
   }
   async function revealAction(id){
    for(let attempt=0;attempt<8;attempt++){
     await dump();const w=actionWidget(id);assert(w,'Actual source selection entry '+id);
     const b=state.buildSelection.bar.rect,r=w.rect,cx=r[0]+r[2]/2;
     if(cx>=b[0]+8&&cx<=b[0]+b[2]-8&&r[1]>=b[1]-1&&r[1]+r[3]<=b[1]+b[3]+1)return w;
     await scrollBar(cx>b[0]+b[2]/2?1:-1);
    }
    throw Error('Could not reveal source selection action '+id+' with real horizontal scroll');
   }
   async function action(id){const w=await revealAction(id);return tapRect(w.rect);}
   async function barCheck(label){
    await sleep(250);await dump();const s=state.buildSelection,b=s.bar;check(b?.shown,label+' selection strip visible');
    check(b.count===s.ids.length&&b.count>0,label+' actual selected count');
    const [x,y,w,h]=b.rect;
    check(x>=-1&&x+w<=state.width+1&&y>=0&&y+h<=state.height,label+' strip bounds fit actual viewport');
    check(Math.abs(y-(state.height-b.layout.bottom-h))<=1.5,label+' source bottom offset');
    check(b.layout.bottom===(state.width>state.height&&state.height<=600?108:128),label+' source landscape placement');
    for(const [id,title]of Object.entries(actions))check(actionWidget(id)?.text===title,label+' original entry '+id);
   }

   async function runCase(){
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar'&&s.sceneVisible&&!s.loadingFlow?.active,'actionable hall');
   await dump();
   await wait(s=>sound(s)?.ready>=7&&sound(s)?.voices===10,'original seven UI cues and ten-source pool');
   check(sound(state).voices===10,'Actual original ten-voice UI sound pool');
   if(!test.touch&&!skipKeys){
    const pressCount=()=>sound(state)?.counts?.press||0;
    const battle=state.widgets.find(w=>w.text==='出战'&&!w.disabled);assert(battle,'Actual pointer sound control');
    const r=battle.rect,p=await point(r[0]+r[2]/2,r[1]+r[3]/2),silent=pressCount();
    await page.mouse.move(p.x,p.y);await sleep(200);await dump();check(pressCount()===silent,'Actual hover does not play press audio');
    for(const button of ['right','middle']){
     await page.mouse.click(p.x,p.y,{button,delay:90});await sleep(200);await dump();
     check(state.tab==='hangar'&&!state.loadingFlow?.active,button+' click does not navigate');
     check(pressCount()===silent,button+' click does not play press audio');
    }
    async function focusWithoutClick(){
     await dump();const button=state.widgets.find(w=>w.text==='出战'&&!w.disabled);assert(button,'Actual hall battle button');
     const r=button.rect,a=await point(r[0]+r[2]/2,r[1]+r[3]/2),b=await point(state.width*.5,state.height*.22);
     const beforePress=pressCount();
     await page.mouse.move(a.x,a.y);await page.mouse.down();await sleep(140);
     await page.mouse.move(b.x,b.y,{steps:8});await page.mouse.up();await sleep(220);await dump();
     check(state.tab==='hangar'&&!state.build,'Pointer down -> outside release does not navigate');
     check(state.widgets.some(w=>w.text==='出战'&&w.focused),'Cancelled pointer activation retains actual button focus');
     check(pressCount()===beforePress+1,'Actual primary pointerdown plays exactly one press cue');
    }
    await focusWithoutClick();await key('Enter');
    await wait(s=>s.tab==='battle'&&!s.loadingFlow?.active,'focused Enter enters battle selection');await dump();
    check(!state.build&&state.mode==='hangar'&&!state.loadingFlow?.active,'Focused Enter opens mode page without starting a match or construction');
    await capture('keyboard-enter');await key('Escape');await wait(s=>s.tab==='hangar','Escape returns focused Enter route');
    await focusWithoutClick();await page.keyboard.down('Space');await sleep(250);await dump();
    check(state.tab==='hangar'&&!state.build,'Focused Space down only presses the button');
    await page.keyboard.up('Space');await wait(s=>s.tab==='battle'&&!s.loadingFlow?.active,'focused Space release activates battle selection');await dump();
    check(!state.build&&state.mode==='hangar','Focused Space up opens mode page only');
    await capture('keyboard-space');await key('Escape');await wait(s=>s.tab==='hangar','Escape returns Space route');await dump();
    const blank=[.20,.28,.36,.44,.52,.60].flatMap(y=>[.38,.46,.54,.62].map(x=>({x:x*state.width,y:y*state.height}))).find(p=>!state.widgets.some(w=>{const r=w.rect;return p.x>=r[0]&&p.x<=r[0]+r[2]&&p.y>=r[1]&&p.y<=r[1]+r[3];}));
    assert(blank,'Observed empty hall surface');const empty=await point(blank.x,blank.y);await page.mouse.click(empty.x,empty.y,{delay:70});await sleep(200);await dump();
    check(!state.widgets.some(w=>w.focused),'Clicking actual blank surface clears widget focus');
    await key('Enter');
   }else{
    assert(state.homeRects?.edit,'Public hall construction control');await tapRect(state.homeRects.edit);
   }
   await wait(s=>s.build&&s.buildSelection?.bar&&!s.loadingFlow?.active,'public construction and new strip observer');
   if(!test.touch&&!skipKeys){item.keyboardResult='PASS';await capture('keyboard-unfocused-enter-build');}
   if(keysOnly)return;
   check(!state.buildSelection.bar.shown,'No empty selection strip on entry');
   const initialParts=state.parts,initialRevision=state.buildSelection.revision;
   if(test.touch){
    await mobile('me-tools');await text('选择','row');
    check(state.buildSelection.active,'Actual mobile tools -> selection');
    const candidates=(state.buildTargets||[]).filter(p=>p.x>.32&&p.x<.78&&p.y>.17&&p.y<.66).sort((a,b)=>b.y-a.y);
    check(candidates.length>0,'Observed projected targets on existing authored vehicle');
    for(const target of candidates){
     const p=await point(target.x*state.width,target.y*state.height);
     await page.touchscreen.tap(p.x,p.y);await sleep(250);await dump();
     item.selectionAttempts.push({target,selected:state.buildSelection.ids,hit:state.buildSelection.hit});
     if(state.buildSelection.ids.length>0)break;
    }
    check(state.buildSelection.ids.length>0,'Actual finger selects existing vehicle part through projection');
   }else{
    await text('选择','tool');await key('Control+a');await dump();
    check(state.buildSelection.active&&state.buildSelection.ids.length===state.parts,'Actual PC Ctrl+A selects authored vehicle');
   }
   check(state.parts===initialParts&&state.buildSelection.revision===initialRevision,'Selection input does not edit authored vehicle');
   await barCheck('Initial');await capture('selected');

   if(test.touch)await mobile('me-paint');
   await dump();const swatches=state.widgets.filter(w=>w.kind===(test.touch?'swatch':'dock-swatch')&&!w.auto&&Number.isInteger(w.hex));
   const swatch=swatches.find(w=>w.hex===0x14c4c4)||swatches.find(w=>w.hex!==state.buildInput.color);
   check(!!swatch,'Actual colored palette entry observed');
   const chosen=swatch.hex;await tapRect(swatch.rect);
   check(!state.buildInput.autoColor&&state.buildInput.color===chosen,'Actual palette sets current brush');
   if(test.touch)await mobile('me-paint');
   await barCheck('After palette');check(state.buildSelection.bar.brush===chosen,'Selection paint icon uses actual chosen color');
   const before=await dump(),revision=before.buildSelection.revision,cue=paintCount();
   await action('paint');await wait(s=>s.buildSelection.revision===revision+1,'actual selected paint edit',10000);
   await dump();check(state.buildSelection.revision===revision+1&&state.parts===initialParts,'One actual selection paint transaction preserves vehicle part count');
   check(paintCount()===cue+1,'Successful selection paint plays exactly one actual paint cue');
   const painted=await dump();await capture('painted');
   await sleep(180);await action('paint');await sleep(300);await dump();
   check(state.buildSelection.revision===revision+1&&paintCount()===cue+1,'Repeated identical selection paint creates no edit and no paint cue');
   if(test.touch)await mobile('me-undo');else{await key('Control+z');await dump();}
   check(state.buildSelection.revision===revision+2&&state.parts===initialParts,'Actual undo reverses selection paint in one command');
   check(paintCount()===cue+1,'Undo does not replay paint cue');
   if(test.touch)await mobile('me-redo');else{await key('Control+y');await dump();}
   check(state.buildSelection.revision===revision+3&&state.parts===initialParts,'Actual redo restores selection paint in one command');
   check(paintCount()===cue+1,'Redo does not replay paint cue');
   if(before.buildSelection.parts&&painted.buildSelection.parts){
    const colors=s=>JSON.stringify(s.buildSelection.parts.map(p=>({id:p.id,color:p.color,shellColor:p.shellColor})));
    // The probe may omit shellColor on mixed materials, so transaction/cue
    // assertions above remain mandatory even when the color trace is partial.
    item.colorTrace={before:colors(before),painted:colors(painted),redone:colors(state)};
    check(colors(state)===colors(painted),'Redo restores observed part finish fields');
   }
   await capture('redo');
   const selected=state.buildSelection.ids.length;
   await action('copy');check(state.buildSelection.clipboard===selected,'Public copy entry fills actual clipboard');
   await key('Control+v');await dump();
   if(test.touch)item.mobilePasteBoundary='Ctrl+V is an actual emulated hardware-keyboard shortcut after touchscreen copy; the mobile UI has no dedicated paste button. This does not sign off a complete touchscreen-only paste workflow.';
   check(state.buildSelection.pasting&&!state.buildSelection.bar.shown,'Actual paste shortcut hides selection strip');
   check(state.buildSelection.revision===revision+3&&state.parts===initialParts,'Starting paste leaves model and edit history intact');
   await capture('paste-hidden');await key('Escape');await dump();
   check(!state.buildSelection.pasting&&state.parts===initialParts,'Escape cancels actual unplaced paste');
   await barCheck('After paste cancel');await action('clear');
   check(state.buildSelection.ids.length===0&&!state.buildSelection.bar.shown,'Public cancel entry clears selection and hides strip');
   check(state.buildSelection.revision===revision+3&&paintCount()===cue+1,'Copy/paste cancellation and clear do not add edits or paint audio');
   await capture('cleared');item.selectionResult='PASS';
   if(test.touch&&process.env.VOX_SELECTION_TOUCH_ERASE==='1'){
    await mobile('me-tools');await text('建造','row');
    await mobile('me-more');await text('准星','segment');await mobile('me-more');
    await wait(s=>s.touchControls?.prefs?.build==='aim'&&s.buildSelection.hit&&!s.buildSelection.active,'actual aim construction target',10000);
    const count=state.parts,rev=state.buildSelection.revision;
    const eraseRect=state.touchControls.rects.erase;assert(eraseRect,'Actual aim erase control');
    const erase=await point(eraseRect[0]+eraseRect[2]/2,eraseRect[1]+eraseRect[3]/2);
    cdp=cdp||await page.context().newCDPSession(page);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:82,...erase}]});
    await sleep(90);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    await wait(s=>s.parts<count&&s.buildSelection.revision===rev+1,'actual first-person aim erase edit',10000);
    const erased=state.parts;await capture('touch-aim-erased');
    await sleep(500);await dump();
    check(state.parts===erased&&state.buildSelection.revision===rev+1,'Released aim erase does not keep deleting');
    await mobile('me-undo');check(state.parts===count&&state.buildSelection.revision===rev+2,'Touch undo restores actual erased part transaction');
    await capture('touch-aim-undo');item.touchEraseResult='PASS';
   }
   }
   await runCase();
   check(item.errors.length===0,'No runtime errors');
   check(item.httpFailures.filter(f=>f.url.startsWith(base+'/game-dist/')).length===0,'No failed actual game-dist resource HTTP responses');
   item.result='PASS';
  }catch(error){
   item.result='FAIL';item.failure=error.stack;item.lastState=state;
   if(page)await page.screenshot({path:path.join(out,test.name+'-failure.png'),timeout:5000}).catch(()=>{});
   process.exitCode=1;
  }finally{
   if(cdp){await cdp.send('Input.dispatchTouchEvent',{type:'touchCancel',touchPoints:[]}).catch(()=>{});await cdp.detach().catch(()=>{});}
   if(page)await page.close().catch(()=>{});
   if(browser)await browser.close().catch(()=>{});
   item.gameResourceHttpFailures=item.httpFailures.filter(f=>f.url.startsWith(base+'/game-dist/'));
   item.optionalEngineProbeFailures=item.httpFailures.filter(f=>!f.url.startsWith(base+'/game-dist/')&&f.url.includes('assets@windows.7z'));
   item.httpBoundary='All >=400 responses remain in httpFailures. Only actual '+base+'/game-dist/ resource failures are a game-resource assertion; optional engine assets@windows.7z probing is listed separately without deleting original records.';
   fs.writeFileSync(path.join(out,test.name+'.json'),JSON.stringify(item,null,2));
   console.log(JSON.stringify({case:test.name,result:item.result,checks:item.checks.length,errors:item.errors.length}));
  }
 }
 report.result=report.cases.length>0&&report.cases.every(c=>c.result==='PASS')?'PASS':'FAIL';
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
 if(report.result!=='PASS')process.exitCode=1;
 console.log(JSON.stringify({out,result:report.result,cases:report.cases.length}));
})().catch(error=>{console.error(error);process.exitCode=1;});

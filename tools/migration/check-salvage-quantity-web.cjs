// Public input only. F8 observes the isolated preview; it does not create stock.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');

async function run(){
 const base=process.env.VOX_QA_BASE;
 assert.ok(/^http:\/\/127\.0\.0\.1:\d+$/.test(base||''),'Set VOX_QA_BASE to the root-owned QA server');
 const identity=await fetch(base+'/identity.json').then(r=>{assert.ok(r.ok);return r.json();});
 assert.equal(identity.qa,true,'Only an explicit QA preview is allowed');
 assert.ok(!identity.storyRoute&&!identity.loadProfile&&!identity.combatProfile&&!identity.renderExperiment,'Use the ordinary QA observer without experiment injection');
 const currentProbe=sha(fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua')));
 assert.equal(identity.probeSha256,currentProbe,'Restart QA server after the read-only quantity observer changed');
 const out=path.join(root,'docs/migration/evidence','salvage-quantity-web-'+path.basename(identity.manifest_path,'.json')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',shutdown:'PENDING',identity,startedAt:new Date().toISOString(),checks:[],errors:[],httpErrors:[],probeErrors:[],holdSamples:[],resources:[],screenshots:[],
  boundary:'Fresh nonpersistent browser context; public mouse/keyboard/wheel only. F8 is read-only. Any transaction requires CloudStorage state=session and is confined to anonymous testFill stock. No real-account, earned-stock, cloud persistence, source visual approval or performance claim.'};
 let state,seq=0,browser,context,page,mouseHeld=false;
 const persist=()=>{report.lastState=state;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));};
 const check=(condition,label)=>{assert.ok(condition,label);report.checks.push(label);persist();};
 persist();
 try{
  const manifest=JSON.parse(fs.readFileSync(identity.manifest_path,'utf8'));
  async function asset(relative,local){
   const match=manifest.files.find(f=>f.fs_path.replace(/\\/g,'/').replace(/^(scripts|assets)\//,'')===relative);
   assert.ok(match,'Frozen asset is present: '+relative);
   const url=base+'/game-dist/assets/'+match.uuid+'-'+match.hash+match.ext;
   const response=await fetch(url);assert.ok(response.ok,'HTTP resource '+url);
   const bytes=Buffer.from(await response.arrayBuffer()),hash=sha(bytes);
   if(local)assert.equal(hash,sha(fs.readFileSync(path.join(root,local))),'Candidate matches reviewed quantity file '+local);
   report.resources.push({relative,url,bytes:bytes.length,sha256:hash});persist();return bytes;
  }
  for(const relative of ['ui/SalvageQuantity.lua','ui/SalvagePage.lua','ui/SalvagePaint.lua'])await asset(relative,'scripts/'+relative);
  const data=JSON.parse((await asset('UI/Outgame.json')).toString('utf8'));
  const rules=JSON.parse((await asset('UI/SalvageRules.json')).toString('utf8'));
  report.fixture={testFill:rules.testFill,cells:rules.cells,sellRate:rules.sellRate};
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
  context=await browser.newContext({viewport:{width:1600,height:900}});page=await context.newPage();
  page.on('console',m=>{
   const message=m.text();fs.appendFileSync(path.join(out,'console.log'),message+'\n');
   const index=message.indexOf('OUTGAME_STATE ');
   if(index>=0){try{state=JSON.parse(message.slice(index+14));seq++;}catch(e){report.probeErrors.push(e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(message))report.errors.push(message);
  });
  page.on('pageerror',error=>report.errors.push(error.stack||error.message));
  page.on('crash',()=>report.errors.push('Browser page crashed'));
  page.on('response',response=>{if(response.status()>=400)report.httpErrors.push({status:response.status(),url:response.url()});});
  async function wait(predicate,label,timeout=30000){
   const start=Date.now();let lastProbe=0;
   while(!state||!predicate(state)){
    assert.equal(report.errors.length,0,report.errors.join('\n'));
    assert.ok(!state?.loadingFlow?.failed,'Actual loading failed: '+state?.loadingFlow?.error);
    assert.ok(Date.now()-start<timeout,'Timed out: '+label);
    if(Date.now()-lastProbe>600){lastProbe=Date.now();await page.keyboard.press('F8');}
    await delay(75);
   }
   return state;
  }
  async function dump(){const before=seq;await page.keyboard.press('F8');return wait(()=>seq>before,'fresh F8 state',15000);}
  const widgets=()=>state?.widgets||[];
  async function point(rect){
   assert.ok(rect&&rect[2]>0&&rect[3]>0,'Visible control geometry');
   const canvas=await page.locator('canvas').boundingBox();assert.ok(canvas);
   return {x:canvas.x+(rect[0]+rect[2]/2)*canvas.width/state.width,y:canvas.y+(rect[1]+rect[3]/2)*canvas.height/state.height};
  }
  async function at(rect,action){const p=await point(rect);await action(p);}
  async function click(text,kind){
   await wait(()=>widgets().some(w=>w.text===text&&(!kind||w.kind===kind)&&!w.disabled&&(!w.entrance||w.entrance.opacity>.9)),'visible '+text);
   const button=widgets().filter(w=>w.text===text&&(!kind||w.kind===kind)&&!w.disabled).at(-1);
   await at(button.rect,p=>page.mouse.click(p.x,p.y));await delay(300);await dump();
  }
  async function shot(name){
   const file=name+'.png';await page.screenshot({path:path.join(out,file)});
   report.screenshots.push({file,width:state.width,height:state.height});persist();
  }
  function anonymous(){check(state.storage?.web===true&&state.storage.state==='session'&&state.storage.pending===0,'Anonymous Web session; no cloud account transaction');}
  function inventory(){return structuredClone(state.salvageInventory);}
  function unchanged(before,label){
   assert.deepEqual(state.salvageInventory.items,before.items,label+' stock');
   assert.equal(state.salvageInventory.credits,before.credits,label+' wallet');
   assert.deepEqual(state.salvageInventory.installed,before.installed,label+' installed vehicle');
   check(state.mode==='hangar'&&state.lobby==='salvage'&&!state.salvageRun&&!state.loadingFlow?.active,label+' does not purchase, sell or deploy');
  }
  async function input(text,expected){
   await dump();const row=state.salvageQuantity;assert.ok(row,'Quantity observer is present');
   await at(row.fieldRect,p=>page.mouse.click(p.x,p.y));await page.keyboard.press('Control+A');await page.keyboard.type(text);
   await dump();check(state.salvageQuantity.value===text&&state.salvageQuantity.focused,'Actual text field accepts '+JSON.stringify(text));
   const before=inventory();await page.keyboard.press('Enter');await delay(250);await dump();
   check(state.salvage.qty===expected&&state.salvageQuantity.value===String(expected)&&!state.salvageQuantity.focused,'Enter commits and clamps '+JSON.stringify(text));
   unchanged(before,'Enter in quantity');
  }
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'initial hall',240000);await shot('01-hall');
  await click('打捞行动');await wait(s=>s.lobby==='salvage'&&s.tab==='salvage'&&!s.vehicleLoading?.busy&&!s.loadingFlow?.active,'salvage hall',240000);
  anonymous();report.inventoryBefore=inventory();
  await click('商人','tab');await click('出售','segment');await click('材料','subtab');
  const item=rules.itemOrder.map(id=>data.items[id]).find(it=>it.cat==='material'&&(state.salvage.loose[it.id]||0)>100&&widgets().some(w=>w.text===it.name));
  assert.ok(item,'An actual visible material has >100 loose items for non-destructive hold tests');report.item={id:item.id,name:item.name,price:item.price};
  await click(item.name);await wait(s=>s.salvage.selected===item.id&&s.salvageQuantity,'selected quantity');await shot('02-market');
  await input('7',7);await input('0',1);await input('999999',state.salvageQuantity.maximum);await input('7',7);
  const beforeSteps=inventory();
  await at(state.salvageQuantity.minusRect,p=>page.mouse.click(p.x,p.y));await delay(150);await dump();
  check(state.salvage.qty===6,'Minus click subtracts exactly once');
  await at(state.salvageQuantity.maxRect,p=>page.mouse.click(p.x,p.y));await delay(150);await dump();
  check(state.salvage.qty===state.salvageQuantity.maximum,'Maximum click uses actual loose-stock ceiling');unchanged(beforeSteps,'Stepper buttons');await input('7',7);
  const beforeWheel=inventory();
  await at(state.salvageQuantity.fieldRect,async p=>{await page.mouse.move(p.x,p.y);await page.mouse.wheel(0,-120);});
  await delay(200);await dump();check(state.salvage.qty===8,'Wheel up over numeric field adds exactly one');
  await at(state.salvageQuantity.fieldRect,async p=>{await page.mouse.move(p.x,p.y);await page.mouse.wheel(0,120);});
  await delay(200);await dump();check(state.salvage.qty===7,'Wheel down over numeric field removes exactly one');
  const outside=widgets().find(w=>w.text==='出售'&&w.kind==='segment');
  await at(outside.rect,async p=>{await page.mouse.move(p.x,p.y);await page.mouse.wheel(0,-120);});
  await delay(200);await dump();check(state.salvage.qty===7,'Wheel outside numeric field leaves quantity unchanged');unchanged(beforeWheel,'Quantity wheel');await shot('03-input-wheel');
  await input('1',1);const beforeHold=inventory();
  await at(state.salvageQuantity.plusRect,async p=>{await page.mouse.move(p.x,p.y);await page.mouse.down();mouseHeld=true;});
  const holdStart=Date.now();
  await dump();report.holdSamples.push({elapsed:Date.now()-holdStart,quantity:state.salvage.qty,hold:structuredClone(state.salvageQuantity.hold)});
  check(state.salvageQuantity.hold?.direction===1,'Pointer down starts the actual plus repeat owner');
  await wait(s=>{report.holdSamples.push({elapsed:Date.now()-holdStart,quantity:s.salvage.qty,hold:structuredClone(s.salvageQuantity.hold)});return s.salvageQuantity.hold?.ticks>=14;},'hold repeat accelerates',15000);
  const sample=state.salvageQuantity;check(sample.qty===2+Math.min(sample.hold.ticks,12)+Math.max(0,sample.hold.ticks-12)*5,'Actual repeat ticks use +1 then +5 after tick 12');
  await page.mouse.up();mouseHeld=false;await delay(180);await dump();const released=state.salvage.qty;
  check(!state.salvageQuantity.hold,'Pointer up releases the repeat owner');await delay(800);await dump();check(state.salvage.qty===released,'Quantity stops changing after release');unchanged(beforeHold,'Held stepper');await shot('04-hold-released');
  await input('1',1);
  await at(state.salvageQuantity.plusRect,async p=>{await page.mouse.move(p.x,p.y);await page.mouse.down();mouseHeld=true;});
  await page.mouse.move(10,10);await page.mouse.up();mouseHeld=false;await delay(180);await dump();const outsideReleased=state.salvage.qty;
  await delay(700);await dump();check(!state.salvageQuantity.hold&&state.salvage.qty===outsideReleased,'Release outside button stops the captured pointer repeat');
  await click('购买','segment');await click('材料','subtab');await click(item.name);await input('2',2);unchanged(report.inventoryBefore,'All market controls');
  await click('整备','tab');await click('仓库','handle');await click('材料','category');await click(item.name);
  await wait(s=>s.salvageQuantity&&widgets().some(w=>w.text==='卖给后勤处'),'actual loadout inspection');
  check(state.salvage.market==='buy','Inspection opens while last market mode is buy');await input('2',2);await shot('05-inspect');
  for(const viewport of [{width:2000,height:900},{width:1280,height:720}]){
   await page.setViewportSize(viewport);await delay(600);await dump();
   const visible=[state.salvageQuantity.fieldRect,widgets().find(w=>w.text==='卖给后勤处')?.rect];
   check(visible.every(r=>r&&r[0]>=0&&r[1]>=0&&r[0]+r[2]<=state.width+1&&r[1]+r[3]<=state.height+1),'Inspection controls fit '+viewport.width+'x'+viewport.height+' landscape');
   await shot('06-inspect-'+viewport.width+'x'+viewport.height);
  }
  await page.setViewportSize({width:1600,height:900});await delay(400);await dump();await input('2',2);
  anonymous();const beforeSale=inventory();report.inventoryBeforeSale=beforeSale;
  await click('卖给后勤处');await wait(s=>s.salvageInventory.items[item.id]===beforeSale.items[item.id]-2,'actual inspection sale');
  const afterSale=inventory(),unit=Math.max(1,Math.floor(item.price*rules.sellRate));
  for(const id of new Set([...Object.keys(beforeSale.items),...Object.keys(afterSale.items)]))assert.equal(afterSale.items[id]||0,(beforeSale.items[id]||0)-(id===item.id?2:0),'Exact isolated stock delta '+id);
  check(afterSale.credits===beforeSale.credits+2*unit,'Inspection sells selected quantity at original buyback price even after buy mode');
  assert.deepEqual(afterSale.installed,beforeSale.installed);check(state.salvage.qty===1,'Successful inspection trade resets quantity to one');
  report.inventoryAfterSale=afterSale;report.cleanup='Two fixture materials sold only inside a new anonymous context. Context is destroyed at shutdown; no real account was used. No buyback attempted because testFill:999 can exceed the 120-cell purchase limit.';
  await shot('07-inspect-sold');
  check(report.errors.length===0&&report.probeErrors.length===0&&report.httpErrors.length===0,'No runtime, observer or HTTP errors on this UI route');
  report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;await page?.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});}
 finally{
  if(mouseHeld)await page?.mouse.up().catch(()=>{});
  try{await context?.close();await browser?.close();report.shutdown='CLOSED';}
  catch(error){report.shutdown='FAILED';report.shutdownError=error.stack;report.result='FAIL';}
  report.finishedAt=new Date().toISOString();persist();
 }
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,out,shutdown:report.shutdown}));
 if(report.result!=='PASS')throw Error(report.failure||report.shutdownError);
}
if(require.main===module)run().catch(error=>{console.error(error);process.exitCode=1;});

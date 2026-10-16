// Public inputs only; F8 exposes read-only state from the matching QA package.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {execFileSync}=require('node:child_process');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base=process.env.VOX_QA_BASE||'http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4335);
const waitMs=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Workshop.json')));
const oracle=JSON.parse(execFileSync(process.execPath,[path.join(__dirname,'workshop-shop-oracle.cjs')],{encoding:'utf8'}));
const ids=['rat','roach','miniAssault','miniScout','miniHeavy'];
const number=value=>Number(value).toLocaleString('en-US');
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa,'requires matching read-only QA build');
 const out=path.join(root,'docs/migration/evidence/workshop-shop-web-'+path.basename(identity.manifest_path,'.json')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log('Evidence: '+out);
 const report={identity,source:oracle.baseline,viewport:{width:1600,height:900},checks:[],pages:[],errors:[],instrumentationErrors:[],
  boundary:'Real hall/salvage/workshop/card/detail/purchase/cancel inputs, original source prices, existing wallet/stock only. No state injection, QA action keys, cloud-account or phone-performance acceptance.',startedAt:new Date().toISOString()};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:report.viewport});let state,sequence=0,parseFailures=0,instrumentationFailure;
 const deadline=Date.now()+480000;
 page.on('console',message=>{
  const line=message.text();fs.appendFileSync(path.join(out,'console.log'),line+'\n');
  const marker='OUTGAME_SHOP_STATE ',at=line.indexOf(marker);
  if(at>=0){
   const payload=line.slice(at+marker.length);
   try{state=JSON.parse(payload);sequence++;parseFailures=0;}
   catch(error){
    parseFailures++;
    report.instrumentationErrors.push({message:error.message,length:payload.length,consecutive:parseFailures,tail:payload.slice(-160)});
    if(parseFailures>=3)instrumentationFailure='Three consecutive incomplete read-only shop samples';
   }
  }
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
 });page.on('pageerror',error=>report.errors.push(error.message));
 const widgets=()=>Array.isArray(state?.widgets)?state.widgets:[];
 function check(label,value){report.checks.push({label,pass:!!value});assert.ok(value,label);}
 async function wait(predicate,label,limit=120000){
  const start=Date.now();let next=0;
  while(!state||!predicate(state)){
   if(instrumentationFailure)throw Error('Instrumentation error while '+label+': '+instrumentationFailure);
   if(report.errors.length)throw Error('Runtime error while '+label+': '+report.errors.at(-1));
   if(state?.loadingFlow?.failed)throw Error('Resource loading failed: '+state.loadingFlow.error);
   if(Date.now()>deadline||Date.now()-start>limit)throw Error('Timeout '+label);
   if(Date.now()>=next){next=Date.now()+800;await page.keyboard.press('F8');}
   await waitMs(100);
  }
 }
 async function dump(){const before=sequence;await page.keyboard.press('F8');await wait(()=>sequence>before,'fresh F8',15000);}
 async function click(label,predicate){
  await dump();const button=widgets().filter(w=>!w.disabled&&(predicate?predicate(w):w.text===label)).at(-1);
  assert.ok(button,'visible enabled public button '+label);const rect=button.rect;
  const canvas=await page.locator('canvas').boundingBox();assert.ok(canvas,'actual game canvas');
  const x=rect[0]+rect[2]/2,y=rect[1]+rect[3]/2;
  assert.ok(x>=0&&x<=state.width&&y>=0&&y<=state.height,'button inside viewport '+label);
  await page.mouse.click(canvas.x+x/state.width*canvas.width,canvas.y+y/state.height*canvas.height,{delay:80});await waitMs(250);
 }
 async function shot(name){await page.screenshot({path:path.join(out,name+'.png')});}
 const wallet=()=>state.salvageInventory?.credits;
 const usage=()=>state.garage?.used;
 function summary(){return (state.purchase?.rows||[]).map(row=>row.text||'').join('\n');}
 async function browse(){
  if(state.workshop?.view==='detail'){
   await page.keyboard.press('Escape');await wait(s=>s.workshop?.view==='browse','detail returns to original browse');
  }
  if(state.workshop?.view==='feature'){
   await click('查看全部');await wait(s=>s.workshop?.view==='browse','actual browse view');
  }
 }
 async function detail(id){
  await browse();const prefab=data.prefabs.find(p=>p.id===id);assert.ok(prefab,'known source prefab '+id);
  await click(prefab.name,w=>w.prefab===id||w.text===prefab.name);
  await wait(s=>s.workshop?.view==='detail'&&s.workshop.selected===id&&s.preview?.complete,'assembled actual detail '+id);
  await dump();const action=widgets().find(w=>w.kind==='go'&&w.shop);
  check('actual detail price '+id,action?.shop?.cost===oracle.prices[id]);
  check('actual detail wallet '+id,action?.shop?.wallet===wallet());
  return action;
 }
 async function purchaseDialog(id){
  await click('购买整车',w=>w.kind==='go');await wait(s=>s.dialog&&s.purchase,'actual source purchase dialog '+id);
  await dump();const price=oracle.prices[id];
  check('source full price in visible purchase summary '+id,summary().includes('整车 ◆ '+number(price)));
  const full=widgets().find(w=>w.kind==='primary'&&w.text==='购买整车');
  check('purchase affordability uses actual wallet '+id,!!full&&!!full.disabled===(price>wallet()));
 }
 try{
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.tab==='hangar'&&s.sceneVisible&&!s.loadingFlow?.active,'actionable normal hall');
  await click('打捞行动');await wait(s=>s.tab==='salvage'&&!s.vehicleLoading?.busy&&!s.loadingFlow?.active,'ordinary salvage lobby');
  check('real wallet available',Number.isFinite(wallet()));report.initial={wallet:wallet(),used:usage()};
  await click('创意工坊');await wait(s=>s.workshop&&widgets().some(w=>w.text==='查看全部'),'actual nested workshop');
  for(const id of ids){
   await detail(id);const before={wallet:wallet(),used:usage(),items:JSON.stringify(state.salvageInventory.items)};
   await purchaseDialog(id);await shot('dialog-'+id);report.pages.push({id,price:oracle.prices[id],wallet:wallet(),state:structuredClone(state)});
   await click('取消');await wait(s=>!s.dialog,'public cancel '+id);await dump();
   check('cancel preserves exact balance/stock/garage '+id,wallet()===before.wallet&&usage()===before.used&&JSON.stringify(state.salvageInventory.items)===before.items);
  }
  const affordable=ids.filter(id=>oracle.prices[id]>0&&oracle.prices[id]<=wallet()).sort((a,b)=>oracle.prices[a]-oracle.prices[b])[0];
  let selected=affordable,cost;
  if(selected){
   await detail(selected);await purchaseDialog(selected);cost=oracle.prices[selected];
  }else{
   for(const id of ids.slice().sort((a,b)=>oracle.prices[a]-oracle.prices[b])){
    await detail(id);await purchaseDialog(id);
    const alternate=widgets().find(w=>!w.disabled&&w.text.startsWith('用仓库里的零件拼'));
    if(alternate){selected=id;const match=alternate.text.match(/补 ([\d,]+)/);cost=match?Number(match[1].replaceAll(',','')):0;break;}
    await click('取消');await wait(s=>!s.dialog,'cancel unaffordable '+id);
   }
  }
  assert.ok(selected,'No actual affordable positive-price car or stock alternative; purchase acceptance remains blocked, no wallet injection');
  const before={wallet:wallet(),used:usage()};
  await click(affordable?'购买整车':'用仓库里的零件拼',w=>affordable?w.text==='购买整车':w.text.startsWith('用仓库里的零件拼'));
  await wait(s=>!s.dialog&&!s.vehicleLoading?.busy&&s.tab==='salvage'&&s.salvage?.tab==='garage'&&s.garage?.used===before.used+1,'real purchase returns to isolated garage');
  await dump();check('exact actual purchase debit',wallet()===before.wallet-cost);
  check('exact one new garage vehicle',usage()===before.used+1);
  report.purchase={id:selected,route:affordable?'full':'stock',cost,before,after:{wallet:wallet(),used:usage()},state:structuredClone(state)};
  await shot('purchased-garage');check('no runtime errors',report.errors.length===0);report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;report.lastState=state;await shot('failure').catch(()=>{});process.exitCode=1;}
 finally{report.finishedAt=new Date().toISOString();fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));await page.close();await browser.close();}
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,errors:report.errors.length,purchase:report.purchase&&{id:report.purchase.id,cost:report.purchase.cost}}));
})().catch(error=>{console.error(error);process.exitCode=1;});

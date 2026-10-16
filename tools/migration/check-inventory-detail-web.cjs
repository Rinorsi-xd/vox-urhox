const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base=process.env.VOX_QA_BASE||'http://127.0.0.1:4332';
const sourceURL=process.env.VOX_SOURCE_URL||'http://localhost:5173/three/';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const sourceRoot=baseline.source;
const out=path.join(root,'docs/migration/evidence/inventory-detail-web-'+new Date().toISOString().replace(/[:.]/g,'-'));
fs.mkdirSync(out,{recursive:true});
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const cases=[{name:'pc',width:1920,height:1080,dpr:1},{name:'20x9',width:840,height:378,dpr:3,touch:true,android:true},
 {name:'20x9-desktopua',width:840,height:378,dpr:3,touch:true,diagnostic:true}];
const mobileUA='Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36';
function context(test){return {viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,...(test.touch?{hasTouch:true,isMobile:true}:{}),...(test.android?{userAgent:mobileUA}:{})};}
const parts=[{id:'tianyuanDrill',name:'天元钻头'},{id:'fuyuanDrill',name:'夫元钻头'},{id:'laser1',name:'激光枪 T1'}];
const report={baseline:{branch:baseline.branch,commit:baseline.commit},checks:[],pages:[],bottoms:[],devices:[],errors:[],
 boundary:'Real source/target public build/inventory inputs and screenshots. Read-only target QA probe. Touch emulation is not real-phone acceptance; capture alone is not visual acceptance.'};
function check(name,value){report.checks.push({name,pass:!!value});assert(value,name)}
async function source(browser,test){
 const page=await browser.newPage(context(test));
 page.on('pageerror',e=>report.errors.push({side:'source',case:test.name,error:e.message}));
 try{
  await page.goto(sourceURL);await page.locator('.home-tabs [data-tab="hangar"]').waitFor({state:'visible',timeout:120000});
  report.devices.push({side:'source',case:test.name,stage:'hall',state:await page.evaluate(()=>({
   width:innerWidth,height:innerHeight,dpr:devicePixelRatio,screen:{width:screen.width,height:screen.height},
   coarse:matchMedia('(pointer: coarse)').matches,maxTouchPoints:navigator.maxTouchPoints,
   compact:document.documentElement.hasAttribute('data-ui-compact'),userAgent:navigator.userAgent,
  }))});
  await page.locator('.home-tabs [data-tab="hangar"]').click();await page.keyboard.press('e');
  await page.locator('#editbar').waitFor({state:'visible',timeout:45000});await page.keyboard.press('b');
  await page.locator('#inventory .inv-search').waitFor({state:'visible',timeout:30000});
  for(const part of (test.diagnostic?parts.slice(0,1):parts)){
   await page.locator('#inventory .inv-search').fill(part.name);
   const card=page.locator('#inventory .inv-part[data-type="'+part.id+'"]');await card.waitFor({state:'visible'});
   await card.focus();await sleep(500);const more=page.locator('#inventory .inv-more');
   if(!await more.evaluate(el=>el.open))await more.locator('summary').click();
   await page.evaluate(()=>document.fonts.ready);await sleep(500);
   const state=await page.evaluate(()=>{
    const inv=document.querySelector('#inventory'),detail=inv.querySelector('.inv-detail');
    const rect=el=>{const r=el.getBoundingClientRect();return [r.x,r.y,r.width,r.height]};
    const texts=[...detail.querySelectorAll('h3,p,.inv-tag,.inv-stats li > span,.inv-stats li > b,.inv-value,summary')].map(el=>{
     const c=getComputedStyle(el);return {tag:el.tagName,text:el.textContent.trim(),font:c.fontFamily,weight:c.fontWeight,size:c.fontSize,
      spacing:c.letterSpacing,lineHeight:c.lineHeight,rect:rect(el)};
    });
    return {title:detail.querySelector('h3').textContent,rows:[...detail.querySelectorAll('.inv-more .inv-stats li')].map(el=>[el.querySelector('span').textContent,el.querySelector('b').textContent]),
     detailRect:rect(detail),cardRect:rect(inv.querySelector('.inv-card')),scrollTop:detail.scrollTop,scrollHeight:detail.scrollHeight,texts};
   });
   check(test.name+' source title '+part.id,state.title===part.name);
   report.pages.push({side:'source',case:test.name,part:part.id,state});
   await page.screenshot({path:path.join(out,'source-'+test.name+'-'+part.id+'.png')});
   await page.locator('#inventory .inv-detail').evaluate(el=>{el.scrollTop=el.scrollHeight});await sleep(100);
   report.bottoms.push({side:'source',case:test.name,part:part.id,state:await page.evaluate(()=>{
    const inv=document.querySelector('#inventory'),detail=inv.querySelector('.inv-detail');
    const rect=el=>{const r=el.getBoundingClientRect();return [r.x,r.y,r.width,r.height]};
    return {scrollTop:detail.scrollTop,scrollHeight:detail.scrollHeight,detailRect:rect(detail),cardRect:rect(inv.querySelector('.inv-card')),
     texts:[...detail.querySelectorAll('h3,p,.inv-tag,.inv-stats li > span,.inv-stats li > b,.inv-value,summary')].map(el=>({text:el.textContent.trim(),rect:rect(el)}))};
   })});
   await page.screenshot({path:path.join(out,'source-'+test.name+'-'+part.id+'-bottom.png')});
  }
 }finally{await page.close();}
}
async function target(browser,test){
 const page=await browser.newPage(context(test));
 let state,revision=0;
 page.on('console',msg=>{const line=msg.text();fs.appendFileSync(path.join(out,'target-'+test.name+'.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');
  if(at>=0){try{state=JSON.parse(line.slice(at+14));revision++;}catch{}}
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push({side:'target',case:test.name,error:line});
 });page.on('pageerror',e=>report.errors.push({side:'target',case:test.name,error:e.message}));
 async function key(name){await page.keyboard.press(name,{delay:80})}
 async function wait(fn,label,timeout=240000){const started=Date.now();let next=0;while(!state||!fn(state)){
  if(report.errors.some(e=>e.side==='target'&&e.case===test.name))throw Error('Target runtime error');
  if(state?.loadingFlow?.failed)throw Error(state.loadingFlow.error);
  if(Date.now()-started>timeout)throw Error('Timeout '+label);
  if(Date.now()>next){next=Date.now()+1000;await key('F8');}await sleep(100);
 }}
 async function dump(){const before=revision;await key('F8');await wait(()=>revision>before,'fresh state',15000);}
 function point(r){return {x:(r[0]+r[2]/2)/state.width*test.width,y:(r[1]+r[3]/2)/state.height*test.height}}
 async function tap(r){const p=point(r);if(test.touch)await page.touchscreen.tap(p.x,p.y);else await page.mouse.click(p.x,p.y,{delay:80})}
 async function scroll(r,amount){const p=point(r);if(!test.touch){await page.mouse.move(p.x,p.y);await page.mouse.wheel(0,amount);return;}
  const cdp=await page.context().newCDPSession(page),span=Math.min(r[3]/state.height*test.height*.65,120),start=p.y+span/2;
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:p.x,y:start,id:1}]});
  for(let i=1;i<=12;i++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:p.x,y:start-span*i/12,id:1}]});await sleep(25);}
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();
 }
 try{
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.tab==='hangar'&&s.sceneVisible&&!s.loadingFlow?.active,'actionable hall');await sleep(800);
  await dump();report.devices.push({side:'target',case:test.name,stage:'hall',state:{device:state.device,width:state.width,height:state.height,physical:state.physical,dpr:state.dpr,touch:state.touch}});
  if(test.diagnostic)await page.screenshot({path:path.join(out,'target-'+test.name+'-hall.png')});
  await key('e');await wait(s=>s.build&&!s.loadingFlow?.active,'builder');
  report.devices.push({side:'target',case:test.name,stage:'build',state:{device:state.device,width:state.width,height:state.height,physical:state.physical,dpr:state.dpr,touch:state.touch}});
  if(test.diagnostic)await page.screenshot({path:path.join(out,'target-'+test.name+'-build.png')});
  await key('b');await wait(s=>s.inventory,'inventory');
  for(const part of (test.diagnostic?parts.slice(0,1):parts)){
   await dump();await tap(state.inventoryState.searchRect);await key('Control+a');await page.keyboard.insertText(part.name);
   await wait(s=>s.inventoryState?.query===part.name&&s.widgets.some(w=>w.inventoryMotion&&w.part===part.id),'search '+part.id);
   await dump();const card=state.widgets.find(w=>w.inventoryMotion&&w.part===part.id);await tap(card.rect);await wait(s=>s.inventoryState.shown===part.id,'detail '+part.id);
   await sleep(600);await dump();let detail=state.inventoryState.detail;
   if(!detail.expanded){
    let r=detail.moreRect;
    for(let i=0;i<10&&(r[1]<detail.scrollRect[1]||r[1]+r[3]>detail.scrollRect[1]+detail.scrollRect[3]);i++){
     await scroll(detail.scrollRect,220);await sleep(250);await dump();detail=state.inventoryState.detail;r=detail.moreRect;
    }
    check(test.name+' more button reachable '+part.id,r[1]>=detail.scrollRect[1]-1&&r[1]+r[3]<=detail.scrollRect[1]+detail.scrollRect[3]+1);
    await tap(r);await wait(s=>s.inventoryState.detail.expanded,'expanded '+part.id);
   }
   await sleep(400);await dump();detail=state.inventoryState.detail;
   const expected=report.pages.find(p=>p.side==='source'&&p.case===test.name&&p.part===part.id).state;
   check(test.name+' source detail rows '+part.id,JSON.stringify(detail.rows.slice(3).map(r=>[r[1],r[2]]))===JSON.stringify(expected.rows));
   report.pages.push({side:'target',case:test.name,part:part.id,state:structuredClone(state)});
   await page.screenshot({path:path.join(out,'target-'+test.name+'-'+part.id+'.png')});
   for(let i=0;i<8;i++)await scroll(detail.scrollRect,420);await sleep(250);await dump();
   report.bottoms.push({side:'target',case:test.name,part:part.id,state:structuredClone(state)});
   await page.screenshot({path:path.join(out,'target-'+test.name+'-'+part.id+'-bottom.png')});
  }
  await key('Escape');await wait(s=>!s.inventory,'close inventory');check(test.name+' inventory backdrop released',!state.backdrop);
 }finally{await page.close();}
}
(async()=>{
 for(const file of ['shared/ui/inventory.js','shared/css/new-ui-inventory.css','shared/ui/homeScale.js','shared/css/new-ui-responsive.css']){
  const live=fs.readFileSync(path.join(sourceRoot,file),'utf8'),frozen=fs.readFileSync(path.join(baseline.snapshot.replaceAll('\\\\','/'),file),'utf8');
  const sha=text=>crypto.createHash('sha256').update(text).digest('hex');
  check('frozen source hash '+file,sha(frozen)===baseline.files[file].sha256);
  check('live source matches baseline content '+file,live.replace(/\r\n/g,'\n')===frozen.replace(/\r\n/g,'\n'));
  (report.sourceHashes??=[]).push({file,live:sha(live),frozen:sha(frozen)});
 }
 report.identity=await fetch(base+'/identity.json').then(r=>r.json());check('QA server',report.identity.qa);
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||c.name===process.env.VOX_QA_CASE)){await source(browser,test);await target(browser,test);}
  check('No runtime errors',report.errors.length===0);report.result='FUNCTIONAL_PASS_VISUAL_REVIEW_REQUIRED';
 }catch(e){report.result='FAIL';report.failure=e.stack;}
 finally{await browser.close();fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({out,result:report.result,checks:report.checks.length,pages:report.pages.length,errors:report.errors,failure:report.failure},null,2));}
 if(report.result==='FAIL')process.exitCode=1;
})().catch(e=>{report.result='FAIL';report.failure=e.stack;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.error(e);process.exitCode=1});

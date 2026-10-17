'use strict';
// Read-only observer; all state changes use public editor/inventory input.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const preparePath=path.resolve(root,process.env.VOX_PREPARE_FILE||'.tmp/outgame-prepare-cached.json');
const base=process.env.VOX_QA_BASE||'http://127.0.0.1:4581';
const baseline='b276064942ae09c0227ec28d4cfda1d5ff006455';
const cases=[{name:'pc',width:1600,height:900,dpr:1,padding:18},{name:'20x9',width:840,height:378,dpr:3,padding:8,touch:true}];
const modules=['ui/InventoryPanel.lua','ui/InventoryDetailScroll.lua','ui/InventoryDetail.lua'];
async function touchScroll(page,state,rect,amount,delay=sleep){
 const canvas=await page.locator('canvas').boundingBox();assert(canvas);
 const viewport=page.viewportSize(),scale=canvas.height/state.height;
 const top=Math.max(0,canvas.y+rect[1]*scale),bottom=Math.min(viewport.height,canvas.y+(rect[1]+rect[3])*scale);
 const x=canvas.x+(rect[0]+rect[2]/2)/state.width*canvas.width;
 const spanLimit=(bottom-top)*.68;assert(spanLimit>20&&x>0&&x<viewport.width,'Touch scroll stays inside actual viewport');
 const cdp=await page.context().newCDPSession(page);let active=false,remaining=Math.abs(amount)*scale;
 try{
  for(let swipe=0;remaining>.1&&swipe<8;swipe++){
   const span=Math.min(spanLimit,remaining),direction=amount>0?-1:1;
   const start=(top+bottom)/2-direction*span/2,end=start+direction*span;
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y:start,id:1}]});active=true;
   for(let step=1;step<=20;step++){
    const progress=1-Math.pow(1-step/20,3);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:start+(end-start)*progress,id:1}]});await delay(20);
   }
   // End a deliberate drag at rest so subsequent part switching does not race inertia.
   for(let pause=0;pause<3;pause++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:end,id:1}]});await delay(35)}
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});active=false;remaining-=span;await delay(80);
  }
 }finally{
  if(active)await cdp.send('Input.dispatchTouchEvent',{type:'touchCancel',touchPoints:[]}).catch(()=>{});
  await cdp.detach();
 }
}
function offline(){
 const prepared=JSON.parse(fs.readFileSync(preparePath,'utf8').replace(/^\uFEFF/,''));
 assert(prepared.ok);assert.equal(prepared.identity.sourceCommit,baseline);
 for(const file of modules){const expected=prepared.identity.scripts[file];assert(expected);
  assert.equal(sha(fs.readFileSync(path.join(root,'scripts',file))),expected,'Production identity '+file);
  assert.equal(sha(fs.readFileSync(path.join(prepared.source_directory,'scripts',file))),expected,'Frozen identity '+file);
 }
 return prepared;
}
async function main(){
 const prepared=offline(),identity=await fetch(base+'/identity.json').then(response=>{assert.equal(response.status,200);return response.json()});
 assert(identity.qa);assert.deepEqual(identity.identity,prepared.identity);assert.equal(identity.source_directory,prepared.source_directory);
 const out=path.join(root,'docs/migration/evidence/inventory-detail-retention-web-'+Date.now());fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',identity,out,cases:[],boundary:'Public editor/inventory input, read-only existing QA state and screenshots. Actual PC and emulated Android landscape only; no full G2, visual identity or phone performance acceptance.'};
 let browser,server,page,lastPage;
 try{
  server=await chromium.launchServer({headless:true,channel:'chrome',args:['--use-angle=d3d11']});browser=await chromium.connect(server.wsEndpoint());
  for(const test of cases.filter(test=>!process.env.VOX_QA_CASE||test.name===process.env.VOX_QA_CASE)){
   const item={viewport:test,result:'RUNNING',checks:[],errors:[],httpErrors:[],samples:[]};report.cases.push(item);let state,sequence=0;
   page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,...(test.touch?{hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36'}:{})});lastPage=page;
   page.on('console',message=>{const text=message.text();fs.appendFileSync(path.join(out,test.name+'.log'),text+'\n');const at=text.indexOf('OUTGAME_STATE ');
    if(at>=0)try{state=JSON.parse(text.slice(at+14));sequence++}catch(error){if(text.trimEnd().endsWith('}'))item.errors.push('Malformed complete state '+error.message)}
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(text))item.errors.push(text);
   });
   page.on('pageerror',error=>item.errors.push(error.message));page.on('requestfailed',request=>item.httpErrors.push({url:request.url(),error:request.failure()?.errorText}));
   page.on('response',response=>{if(response.status()>=400)item.httpErrors.push({status:response.status(),url:response.url()})});
   const check=(value,label)=>{assert(value,label);item.checks.push(label)};
   async function key(value){await page.keyboard.press(value,{delay:70});await sleep(150)}
   async function wait(predicate,label,timeout=180000){const started=Date.now();let next=0;while(!state||!predicate(state)){
    assert.equal(item.errors.length,0,item.errors.join('\n'));if(Date.now()-started>timeout)throw Error('Timeout '+label);
    if(Date.now()>next){next=Date.now()+900;await key('F8')}await sleep(90);
   }}
   async function dump(){const old=sequence;await key('F8');await wait(()=>sequence>old,'fresh observer',15000)}
   async function center(rect){const canvas=await page.locator('canvas').boundingBox();assert(canvas);return {x:canvas.x+(rect[0]+rect[2]/2)/state.width*canvas.width,y:canvas.y+(rect[1]+rect[3]/2)/state.height*canvas.height}}
   async function tap(rect){const point=await center(rect);if(test.touch)await page.touchscreen.tap(point.x,point.y);else await page.mouse.click(point.x,point.y);await sleep(300);await dump()}
   async function wheel(amount){
    if(test.touch)await touchScroll(page,state,state.inventoryState.detail.scrollRect,amount);
    else{const point=await center(state.inventoryState.detail.scrollRect);await page.mouse.move(point.x,point.y);await page.mouse.wheel(0,amount)}
    await sleep(500);await dump();
    if(test.touch){
     // Repeated stationary CDP moves can be coalesced; observe natural inertia
     // ending before recording the scroll retained by a subsequent part switch.
     let previous=offset(),stable=0;
     for(let attempt=0;attempt<24&&stable<3;attempt++){
      await sleep(150);await dump();const current=offset();
      stable=Math.abs(current-previous)<=.01?stable+1:0;previous=current;
     }
     assert(stable>=3,'Touch detail scrolling settles before part-switch measurement');
    }
   }
   function offset(){const detail=state.inventoryState.detail;return detail.scrollRect[1]+test.padding-detail.rect[1]}
   async function shot(name){await dump();item.samples.push({name,offset:offset(),state:structuredClone(state)});await page.screenshot({path:path.join(out,test.name+'-'+name+'.png'),timeout:15000})}
   async function pick(id,name){await tap(state.inventoryState.searchRect);await key('Control+a');await page.keyboard.insertText(name);
    await wait(value=>value.inventoryState?.query===name&&value.widgets.some(widget=>widget.inventoryMotion&&widget.part===id),'search '+id);await dump();
    const card=state.widgets.find(widget=>widget.inventoryMotion&&widget.part===id);await tap(card.rect);await wait(value=>value.inventoryState.shown===id,'detail '+id);await sleep(400);await dump();
   }
   try{
    await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-vox-debug=1');
    await wait(value=>value.tab==='hangar'&&!value.loadingFlow?.active,'hall');await key('e');await wait(value=>value.build&&!value.loadingFlow?.active,'editor');await key('b');await wait(value=>value.inventory,'inventory');await dump();
    await pick('tianyuanDrill','天元钻头');
    for(let i=0;i<10;i++){const detail=state.inventoryState.detail,r=detail.moreRect;
     if(r&&r[1]>=detail.scrollRect[1]&&r[1]+r[3]<=detail.scrollRect[1]+detail.scrollRect[3]){await tap(r);break}
     await wheel(130);
    }
    await wait(value=>value.inventoryState.detail.expanded,'expanded details');
    await wheel(-10000);await wheel(90);const before=offset();check(before>20,'User scrolls expanded detail away from top');await shot('before-switch');
    await pick('fuyuanDrill','夫元钻头');const after=offset();check(Math.abs(after-before)<=1,'Switch preserves valid actual detail scroll');
    check(state.inventoryState.detail.expanded,'Expanded state persists across switch');await shot('after-switch');
    await wheel(10000);await pick('cube','轻方块');await sleep(350);await dump();
    const detail=state.inventoryState.detail,max=Math.max(0,test.padding+detail.height+(test.touch?12:16)-detail.scrollRect[3]);
    check(offset()>=-.5&&offset()<=max+1,'Shorter part clamps scroll to real layout range');await shot('shorter-part');
    await key('Escape');await wait(value=>!value.inventory,'close inventory');check(!state.backdrop,'Inventory backdrop released');
    assert.equal(item.errors.length,0);assert.equal(item.httpErrors.length,0);item.result='PASS';
   }catch(error){item.result='FAIL';item.failure=error.stack;item.lastState=state;await page.screenshot({path:path.join(out,test.name+'-failure.png'),timeout:10000}).catch(()=>{});throw error}
   finally{await page.close({runBeforeUnload:false});page=null;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2))}
  }
  offline();report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;process.exitCode=1}
 finally{report.shutdown=await require('./run-auto-gc-aba.cjs').closeOwnedBrowser(page||lastPage,browser,server);fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({result:report.result,out,shutdown:report.shutdown,failure:report.failure}))}
}
module.exports={offline,touchScroll};
if(require.main===module){if(process.argv.includes('--self-test')){offline();console.log('PASS current/frozen module identities; no browser launched')}else main().catch(error=>{console.error(error.stack);process.exitCode=1})}

'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {protocol}=require('./check-aim-engine-web.cjs');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const expected={'ui/InventoryPanel.lua':'4e6f796d40c0b32121a1e46d244249988380902809cffd913df60a9780cec6fe','ui/InventoryKeys.lua':'f9bde8322b5e32d4b01c5943aba6752f441ddf2b87914c01621209d33e0500f4'};
function unchanged(a,b){assert.deepEqual(b.content,a.content);assert.deepEqual(b.selection.hotbar,a.selection.hotbar);assert.equal(b.inventory,true);assert.equal(b.dialog,false)}
function selected(a,b,target){unchanged(a,b);assert.notEqual(a.selection.active,target);assert.equal(b.selection.active,target)}
function selfTest(){
 const a={inventory:true,dialog:false,content:{blueprint:'test',undo:1},selection:{active:7,hotbar:['laser1',false]}};
 const b=structuredClone(a);b.selection.active=10;selected(a,b,10);
 for(const mutate of [s=>s.selection.active=7,s=>s.selection.hotbar[1]='laser1',s=>s.content.undo++,s=>s.dialog=true,s=>s.inventory=false]){
  const c=structuredClone(b);mutate(c);assert.throws(()=>selected(a,c,10));
 }
 console.log('PASS: slot selection requires active change, no assignment/content mutation or modal');
}
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',errors:[],httpErrors:[],checks:[],states:[],truncatedStateMessages:0,truncatedStateSamples:[],boundary:'Public salvage/editor/inventory mouse/keyboard inputs using naturally zero-stock parts; no stock/blueprint injection or purchase confirmation. Read-only QA snapshots; desktop only, no FPS/full G2/G5 acceptance.'};
 let browser,page,state,seq=0,ready=false;const reader=protocol(report);
 const save=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
 const healthy=()=>{assert.equal(report.errors.length,0,report.errors.join('\n'));assert.equal(report.httpErrors.length,0,JSON.stringify(report.httpErrors))};
 try{
  const identity=await fetch(base+'/identity.json').then(r=>{assert(r.ok);return r.json()});report.identity=identity;
  assert(identity.qa&&identity.inventoryDigitObserver);assert.equal(identity.inventoryDigitObserverSha256,sha(fs.readFileSync(path.join(__dirname,'inventory-digit-stock-observer.lua'))));
  for(const [file,digest]of Object.entries(expected)){assert.equal(identity.identity.scripts[file],digest);assert.equal(sha(fs.readFileSync(path.resolve('scripts',file))),digest)}
  const manifest=await fetch(base+'/game-dist/'+path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/')).then(r=>r.json());
  for(const [file,digest]of Object.entries(expected)){const e=manifest.files.find(f=>f.fs_path===file);assert(e);assert.equal(sha(Buffer.from(await fetch(base+'/game-dist/assets/'+e.uuid+'-'+e.hash+e.ext).then(r=>r.arrayBuffer()))),digest)}
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',msg=>{const text=msg.text();fs.appendFileSync(path.join(out,'runtime.log'),text+'\n');if(text.endsWith('INVENTORY_DIGIT_OBSERVER_READY'))ready=true;reader.feed(text);const at=text.indexOf('INVENTORY_DIGIT_STATE ');if(at>=0)try{state=JSON.parse(text.slice(at+22));seq++}catch(e){report.errors.push(e.stack)}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))report.errors.push(text)});
  page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Renderer crash'));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({url:r.url(),status:r.status()})});page.on('requestfailed',r=>report.httpErrors.push({url:r.url(),error:r.failure()?.errorText}));
  async function dump(){const before=seq,until=Date.now()+12000;while(seq===before){healthy();assert(Date.now()<until,'Fresh snapshot');await page.keyboard.press('F8',{delay:70});await sleep(300)}return state}
  async function wait(fn,label,limit=180000){report.stage=label;save();const until=Date.now()+limit;while(!fn()){healthy();assert(Date.now()<until,'Timeout '+label);await dump()}return state}
  async function key(k){await page.keyboard.press(k,{delay:70});await sleep(200);await dump()}
  async function point(r){const canvas=await page.locator('canvas').boundingBox();assert(canvas);return {x:canvas.x+(r[0]+r[2]/2)/state.width*canvas.width,y:canvas.y+(r[1]+r[3]/2)/state.height*canvas.height}}
  async function rect(r){const p=await point(r);await page.mouse.click(p.x,p.y);await sleep(250);await dump()}
  async function button(text){await wait(()=>reader.state?.widgets?.some(w=>w.text===text&&!w.disabled),'public button '+text);await rect(reader.state.widgets.filter(w=>w.text===text&&!w.disabled).at(-1).rect)}
  async function snap(label){report.states.push({label,state:structuredClone(state)});await page.screenshot({path:path.join(out,label+'.png')});save()}
  report.url=base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login';await page.goto(report.url,{waitUntil:'domcontentloaded'});await page.bringToFront();
  const bootstrapDeadline=Date.now()+180000;while(!ready){healthy();assert(Date.now()<bootstrapDeadline,'Actual game observer bootstrap');await sleep(200)}
  await wait(()=>reader.state?.mode==='hangar'&&reader.state?.tab==='hangar'&&!reader.state.loadingFlow?.active,'loaded hall');
  await button('打捞行动');await wait(()=>reader.state?.tab==='salvage'&&!reader.state.loadingFlow?.active&&!reader.state.vehicleLoading?.busy,'salvage loaded');
  await key('e');await wait(()=>state?.build,'actual editor');await key('b');await wait(()=>state?.inventory&&state?.missing,'actual inventory with naturally missing weapon');
  const missing=structuredClone(state.missing);report.missing=missing;
  await rect(state.search);await key('Control+a');await page.keyboard.insertText(missing.name);await sleep(250);await dump();
  await wait(()=>state?.cards?.some(c=>c.id===missing.id&&c.unavailable&&!c.disabled),'buyable zero-stock card');
  await key('Tab');assert(!state.focus.search,'Search typing focus released via actual Tab');
  let card=state.cards.find(c=>c.id===missing.id);let p=await point(card.rect);await page.mouse.move(p.x,p.y);await sleep(200);await dump();assert.equal(state.hover,missing.id);
  let before=structuredClone(state),target=state.selection.active===10?9:10;await key(String(target%10));selected(before,state,target);await snap('hover-digit-selects-slot');report.checks.push('Actual hovered zero-stock digit changes slot without purchase or assignment');
  await rect(state.search);for(let i=0;i<80&&state.focus.part!==missing.id;i++)await key('Tab');assert.equal(state.focus.part,missing.id);assert(!state.focus.disabled,'Buyable zero-stock part stays in actual Tab order');
  before=structuredClone(state);target=state.selection.active===10?9:10;await key(String(target%10));selected(before,state,target);await snap('focus-digit-selects-slot');report.checks.push('Actual focused buyable zero-stock digit changes slot without assignment');
  card=state.cards.find(c=>c.id===missing.id);before=structuredClone(state);await rect(card.rect);await wait(()=>state.dialog,'original purchase dialog');assert.deepEqual(state.content,before.content);assert.deepEqual(state.selection.hotbar,before.selection.hotbar);await snap('click-still-opens-purchase');report.checks.push('Clicking buyable missing part still opens purchase without consuming stock');
  healthy();report.result='PASS';
 }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;if(page)await page.screenshot({path:path.join(out,'failure.png'),timeout:5000}).catch(()=>{});process.exitCode=1}
 finally{if(browser)try{await browser.close();report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.closeError=e.message}save();console.log(JSON.stringify({result:report.result,out,shutdown:report.shutdown,failure:report.failure}))}
}
module.exports={selected,unchanged,selfTest,run};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else run(process.argv[2],path.resolve(process.argv[3])).catch(e=>{console.error(e);process.exitCode=1})}

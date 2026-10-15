const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4267);
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa);
 const out=path.resolve('docs/migration/evidence/warehouse-'+path.basename(identity.manifest_path,'.json')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log('Evidence: '+out);
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const viewport of [{width:1600,height:900},{width:1440,height:648}]){
  const name=viewport.width===1600?'pc':'landscape-20-9',prefix='salvage-buy-web-'+name,page=await browser.newPage({viewport});
  const report={identity,viewport,checks:[],errors:[],boundary:'Real pointer actions and production vehicleSwitch/BuyAll. No authenticated cloud SDK or actual phone performance evidence.',startedAt:new Date().toISOString()};let state,seq=0;
  fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',m=>{const t=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),t+'\n');const at=t.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(t.slice(at+14));seq++;}catch(e){report.errors.push(e.message);}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t))report.errors.push(t);});
  page.on('pageerror',e=>report.errors.push(e.message));
  async function wait(fn,label,limit=180000){const start=Date.now();let probe=0;while(!state||!fn(state)){if(Date.now()-start>limit)throw Error('Timeout '+label);if(Date.now()-probe>750){probe=Date.now();await page.keyboard.press('F8');}await delay(100);}return state;}
  async function dump(){const before=seq;await page.keyboard.press('F8');await wait(()=>seq>before,'fresh state',15000);}
  const widgets=()=>Array.isArray(state?.widgets)?state.widgets:[];
  async function click(text,match){await dump();const all=widgets().filter(w=>!w.disabled&&(match?match(w):w.text===text));assert.ok(all.length,'Actual button '+text);const b=all.at(-1),r=b.rect,c=await page.locator('canvas').boundingBox();await page.mouse.click(c.x+(r[0]+r[2]/2)*c.width/state.width,c.y+(r[1]+r[3]/2)*c.height/state.height);await delay(400);}
  function check(value,label){assert.ok(value,label);report.checks.push(label);}
  async function shot(suffix){await page.screenshot({path:path.join(out,prefix+'-'+suffix+'.png')});}
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'actionable hall');
   await click('打捞行动');await wait(s=>s.tab==='salvage'&&!s.vehicleLoading?.busy&&!s.loadingFlow?.active,'actual salvage switch');await delay(1000);await shot('lobby');
   check(state.garage.used>=1,'Actual isolated salvage garage starter exists');const before=state.garage.used;
   await click('创意工坊');await wait(()=>widgets().some(w=>w.text==='放进新车位'),'actual salvage workshop');await delay(1200);
   await click('放进新车位');await wait(s=>s.dialog&&widgets().some(w=>w.text==='购买整车'),'source car purchase opens');await delay(700);await shot('purchase');
   check(widgets().some(w=>w.text.startsWith('用仓库里的零件拼')),'Source buy existing loose parts alternative is available');
   await click('取消');await wait(s=>!s.dialog,'actual cancel');check(state.garage.used===before,'Cancel does not create free car');
   await click('放进新车位');await wait(s=>s.dialog,'reopened source purchase');await delay(500);await click('use loose stock',w=>w.text.startsWith('用仓库里的零件拼'));
   await wait(s=>!s.dialog&&!s.vehicleLoading?.busy&&s.garage.used===before+1&&widgets().some(w=>w.text==='拆掉这辆车'),'actual purchased car placed in visible salvage garage');await delay(1000);await shot('placed');
   await dump();report.placedState=state;
   check(state.warehouse?.cameraSafety===true,'Real warehouse entry owns its camera obstruction bounds');
   check(state.tab==='salvage'&&state.garage.used===before+1,'Purchase returns to isolated salvage garage with exactly one new car');
   check(report.errors.length===0,'No Lua/browser/resource errors');report.result='PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await shot('failure').catch(()=>{});}
  finally{report.finishedAt=new Date().toISOString();fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({name,result:report.result,checks:report.checks.length,errors:report.errors.length}));if(report.result!=='PASS')throw Error(report.failure);
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

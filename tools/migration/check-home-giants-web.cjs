// Public workshop and existing garage cards in a fresh anonymous Web context.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base=process.env.VOX_QA_BASE;
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
async function run(){
 assert.match(base||'',/^http:\/\/127\.0\.0\.1:\d+$/);
 const identity=await fetch(base+'/identity.json').then(r=>{assert.ok(r.ok);return r.json();});
 assert.equal(identity.qa,true);assert.equal(identity.probeSha256,sha(fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'))));
 const catalog=JSON.parse(fs.readFileSync(path.join(root,'assets/Parts/Catalog.json')));
 const workshop=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Workshop.json')));
 const targets=[['fox','buildFox'],['megaMech','buildMegaMech']].map(([id,preset])=>({id,...catalog.presets[preset],label:workshop.prefabs.find(p=>p.id===id).name}));
 const out=path.join(root,'docs/migration/evidence/home-giants-web-'+identity.servedManifest.replace('.json','')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',shutdown:'PENDING',identity,checks:[],errors:[],httpErrors:[],observerErrors:[],switches:[],screenshots:[],startedAt:new Date().toISOString(),
  boundary:'Fresh anonymous session, real workshop installation and saved garage card input. F8 only observes. Assembly milliseconds measure the production coroutine slice, not full rendered frame or GPU. No authenticated account or Snapdragon performance acceptance.'};
 let browser,page,state,seq=0,phase='boot';
 const persist=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({...report,lastState:state},null,2));
 const check=(value,label)=>{assert.ok(value,label);report.checks.push(label);persist();};
 try{
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
  page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');
   if(at>=0){try{state=JSON.parse(line.slice(at+14));seq++;if(state.vehicleLoading)report.switches.findLast(s=>s.phase===phase)?.samples.push({wall:Date.now(),loading:state.vehicleLoading,blueprint:state.blueprint,frames:state.frames});}catch(e){report.observerErrors.push(e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });
  page.on('pageerror',e=>report.errors.push(e.stack||e.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({status:r.status(),url:r.url()});});
  async function wait(fn,label,timeout=180000){const start=Date.now();let next=0;while(!state||!fn(state)){
   assert.equal(report.errors.length,0,report.errors.join('\n'));assert.ok(!state?.loadingFlow?.failed,state?.loadingFlow?.error);
   assert.ok(Date.now()-start<timeout,'Timeout '+label);
   if(Date.now()>next){next=Date.now()+450;await page.keyboard.press('F8');}await sleep(70);
  }return state;}
  async function dump(){const before=seq;await page.keyboard.press('F8');return wait(()=>seq>before,'fresh observer',15000);}
  const widgets=()=>Array.isArray(state?.widgets)?state.widgets:[];
  async function tap(rect){const c=await page.locator('canvas').boundingBox();assert.ok(c&&rect&&rect[2]>0&&rect[3]>0);const x=c.x+(rect[0]+rect[2]/2)*c.width/state.width,y=c.y+(rect[1]+rect[3]/2)*c.height/state.height;
   assert.ok(x>=0&&x<c.x+c.width&&y>=0&&y<c.y+c.height,'Control lies inside canvas');await page.mouse.click(x,y);await sleep(100);}
  async function click(text,predicate){await dump();const w=widgets().find(w=>w.text===text&&!w.disabled&&(!predicate||predicate(w)));assert.ok(w,'Visible command '+text);await tap(w.rect);}
  async function shot(name){await page.screenshot({path:path.join(out,name+'.png')});report.screenshots.push(name+'.png');persist();}
  async function completed(name,parts,label){await wait(s=>s.tab==='hangar'&&s.blueprint===name&&!s.vehicleLoading?.busy&&!s.vehicleLoading?.lift,label,240000);await dump();
   check(state.parts===parts&&state.carVisuals===parts,label+' contains all source parts and visuals');
   check(state.hangar?.scan===false,label+' has no active scan stripe');
   const rec=report.switches.findLast(s=>s.phase===phase);rec.elapsedMs=Date.now()-rec.startedAt;rec.final=structuredClone(state.vehicleLoading);persist();}
  async function slot(name,parts,label){await dump();const existing=state.garage.slots.filter(Boolean),index=existing.findIndex(s=>s.name===name);assert.ok(index>=0,'Saved vehicle exists '+name);
   phase=label;report.switches.push({phase,startedAt:Date.now(),samples:[]});await tap(state.garage.cards[index]);await completed(name,parts,label);}
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active,'actionable home',240000);await dump();
  check(state.storage?.state==='session'&&state.storage.web,'Isolated anonymous Web garage');
  const original={name:state.blueprint,parts:state.parts};report.original=original;
  for(const target of targets){
   await click('创意工坊');await wait(s=>s.tab==='workshop'&&s.workshop?.view==='feature','workshop feature');
   await click(target.label,w=>!w.card);await wait(s=>s.workshop?.selected===target.id&&!s.workshop.pending,'selected '+target.id);await sleep(350);
   phase='cold-'+target.id;report.switches.push({phase,startedAt:Date.now(),samples:[]});
   await click('放进新车位');await completed(target.name,target.parts.length,phase);await shot(phase);
   check(state.garage.slots.some(s=>s&&s.name===original.name),'Original unslotted vehicle retained in a garage slot');
   await slot(original.name,original.parts,'small-after-'+target.id);
   await slot(target.name,target.parts.length,'warm-'+target.id);await shot('warm-'+target.id);
   await slot(original.name,original.parts,'return-after-'+target.id);
  }
  check(report.errors.length===0&&report.httpErrors.length===0&&report.observerErrors.length===0,'No runtime, HTTP or observer errors');
  report.result='PASS';await shot('returned-small');
 }catch(e){report.result='FAIL';report.failure=e.stack;await page?.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});}
 finally{await browser?.close();report.shutdown='CLOSED';report.finishedAt=new Date().toISOString();persist();}
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,out,switches:report.switches.map(s=>({phase:s.phase,elapsedMs:s.elapsedMs,final:s.final}))}));
 if(report.result!=='PASS')throw Error(report.failure);
}
run().catch(e=>{console.error(e);process.exitCode=1;});

// Public opening entry; pointer/keyboard only, read-only F8 runtime snapshots.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),port=Number(process.env.VOX_QA_PORT||4312),base='http://127.0.0.1:'+port;
const out=path.join(root,'docs/migration/evidence/intro-dialog-web-'+new Date().toISOString().replace(/[:.]/g,'-'));
const sleep=ms=>new Promise(r=>setTimeout(r,ms));fs.mkdirSync(out,{recursive:true});
(async()=>{const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa);const report={identity,checks:[],errors:[],captures:[],result:'RUNNING'};
 const browser=await chromium.launch({channel:'chrome',headless:true,args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:{width:1920,height:1080},deviceScaleFactor:1});let state,revision=0;
 page.on('console',m=>{const t=m.text();fs.appendFileSync(path.join(out,'runtime.log'),t+'\n');const p=t.indexOf('OUTGAME_STATE ');if(p>=0){state=JSON.parse(t.slice(p+14));revision++;}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t))report.errors.push(t);});
 page.on('pageerror',e=>report.errors.push(e.message));
 async function dump(){const prev=revision;await page.keyboard.press('F8');const deadline=Date.now()+15000;while(revision===prev){if(Date.now()>deadline)throw Error('F8 response timeout');await sleep(30);}return state;}
 async function wait(fn,label,timeout=240000){const deadline=Date.now()+timeout;while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()>deadline)throw Error('Timeout '+label);await page.keyboard.press('F8');await sleep(state?120:1000);}return state;}
 async function captureLine(id){await wait(s=>s.line===id,id);await page.screenshot({path:path.join(out,id+'-partial-pc.png')});report.captures.push({id,phase:'partial',viewport:[1920,1080],state:structuredClone(state)});await page.keyboard.press('Space');
  for(const v of [{name:'pc',width:1920,height:1080},{name:'20-9',width:840,height:378},{name:'extra-wide',width:1605,height:388}]){await page.setViewportSize({width:v.width,height:v.height});await sleep(180);await dump();assert.equal(state.line,id,'line still active during resize');await page.screenshot({path:path.join(out,id+'-full-'+v.name+'.png')});report.captures.push({id,phase:'full',viewport:[v.width,v.height],state:structuredClone(state)});report.checks.push(id+' rendered after real resize '+v.name);}
  await page.setViewportSize({width:1920,height:1080});
 }
 try{await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active&&!s.loading?.busy,'hall');const entry=state.widgets.find(w=>w.text==='开场动画'&&!w.disabled);assert.ok(entry);const[x,y,w,h]=entry.rect;await page.mouse.click(x+w/2,y+h/2);await wait(s=>s.mode==='opening'&&s.ready,'opening ready');await page.mouse.click(960,700);await wait(s=>s.stage==='ad','ad');await page.keyboard.press('Escape');await wait(s=>s.shot==='comms','comms');
  await wait(s=>s.line==='v01','v01');await page.keyboard.press('Space');await sleep(100);await page.keyboard.press('Space');await wait(s=>s.line==='v02','v02');await page.keyboard.press('Space');await sleep(100);await page.keyboard.press('Space');await captureLine('v03');
  await page.keyboard.press('Space');await wait(s=>s.line==='v04','v04');await page.keyboard.press('Space');await sleep(100);await page.keyboard.press('Space');await wait(s=>s.page?.choosing,'choices');await page.keyboard.press('3');await wait(s=>s.line==='v07','v07');await page.keyboard.press('Space');await sleep(100);await page.keyboard.press('Space');await captureLine('v08');assert.equal(report.errors.length,0);report.result='PASS';
 }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});}
 finally{await browser.close();fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({out,result:report.result,checks:report.checks.length,errors:report.errors.length}));}if(report.result!=='PASS')process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});

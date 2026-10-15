const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:'+(process.env.VOX_G0_PORT||4219),root=path.resolve(__dirname,'../..');
const restoreOnly=process.argv.includes('--restore-only');
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa);
 const out=path.join(root,'docs/migration/evidence/full-parity',identity.identity.sourceCommit.slice(0,12),'G0',identity.servedManifest.replace('.json',''),'resize-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});const logs=[],errors=[],report={identity,restoreOnly,checks:[],limitation:'Real same-origin iframe dimensions; not native Windows minimize or background cold-start acceptance.'};
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=d3d11']});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});let state,seq=0;
  page.on('console',m=>{const text=m.text();logs.push(text);if(/ERROR:|Execute Lua|Aborted\(|Attachment has zero size/.test(text))errors.push(text);const i=text.indexOf('OUTGAME_STATE ');if(i>=0){try{state=JSON.parse(text.slice(i+14));seq++;}catch{}}});
  page.on('pageerror',e=>errors.push(e.message));
  const wait=async(predicate,label,failOnErrors=false,timeout=240000)=>{const start=Date.now();while(!predicate()){if(failOnErrors)assert(!errors.length,errors.slice(-2).join('\n'));if(Date.now()-start>timeout)throw Error('Timeout '+label);await page.waitForTimeout(200);}};
  await page.goto(base+'/resize-host.html'+(restoreOnly?'?restore=1':''));
  const frame=page.frames().find(f=>f.url().includes('/outgame.html'));assert(frame);
  const initial=await frame.evaluate(()=>({w:innerWidth,h:innerHeight}));assert.equal(initial.w,restoreOnly?1920:0);assert.equal(initial.h,restoreOnly?1080:0);report.initialWindow=initial;
  await wait(()=>state?.mode==='hangar'&&state.widgets?.length,'startup',true);report.checks.push('actual iframe starts at '+initial.w+' x '+initial.h+' and reaches hall without errors');
  const dump=async()=>{const old=seq;await frame.locator('canvas').press('F8');await wait(()=>seq>old,'fresh state',false,15000);};
  for(const size of [[1920,1080],[0,0],[1,1],[840,378],[1920,1080]]){
   const errorStart=errors.length;
   await page.locator('iframe').evaluate((el,[w,h])=>{el.style.width=w+'px';el.style.height=h+'px';},size);
   await page.waitForTimeout(1200);
   // A hidden zero-area frame cannot receive input; recover dimensions first.
   if(size[0]>1&&size[1]>1)await dump();
   const actual=await frame.evaluate(()=>({w:innerWidth,h:innerHeight}));assert.equal(actual.w,size[0]);assert.equal(actual.h,size[1]);
   if(size[0]>1&&size[1]>1){assert(state.widgets.some(w=>w.text==='改装'));report.checks.push('HUD widget retained at '+size.join(' x '));}
   (report.steps??=[]).push({size,actual,errors:errors.slice(errorStart)});
   await page.screenshot({path:path.join(out,'size-'+size.join('x')+'.png')});
  }
  await page.screenshot({path:path.join(out,'restored-hall.png')});
  const button=state.widgets.find(w=>w.text==='改装'),[x,y,w,h]=button.rect;
  await frame.locator('canvas').click({position:{x:(x+w/2)/state.width*1920,y:(y+h/2)/state.height*1080}});
  await dump();await wait(()=>state?.build,'restored construction button');report.checks.push('actual construction button works after restoration');
  await page.screenshot({path:path.join(out,'restored-build.png')});
  assert(!errors.length,errors.slice(-3).join('\n'));report.result='PASS';
 }catch(error){report.result='FAIL';report.error=error.message;process.exitCode=1;}
 finally{await browser.close();report.errors=errors;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));fs.writeFileSync(path.join(out,'console.log'),logs.join('\n'));console.log(JSON.stringify({out,result:report.result,checks:report.checks,error:report.error,errors}));}
})().catch(error=>{console.error(error);process.exitCode=1;});

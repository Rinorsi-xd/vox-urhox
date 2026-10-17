const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const {protocol}=require('./check-aim-engine-web.cjs');
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4520);
async function run(){
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa&&identity.qaSalvageStock);
 const out=path.resolve('docs/migration/evidence/salvage-stock-'+Date.now());fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',identity,runs:[],errors:[],httpErrors:[],truncatedStateMessages:0,truncatedStateSamples:[],boundary:'Actual Web URL controls debug flag. Explicit QA suffix detaches and empties only session inventory and suppresses instance Save; real mouse/Enter departure inputs. No earned economy, natural match, FPS or mobile claim.'};
 let browser;
 try{
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});
  for(const debug of [false,true]){
   const context=await browser.newContext({viewport:{width:1600,height:900},deviceScaleFactor:1});
   const page=await context.newPage(),reader=protocol(report),row={debug,checks:[],snapshots:[]};report.runs.push(row);
   let stock,stockSeq=0;
   const label=debug?'debug':'ordinary',log=path.join(out,label+'.log');
   page.on('console',msg=>{const text=msg.text();fs.appendFileSync(log,text+'\n');reader.feed(text);const at=text.indexOf('QA_SALVAGE_STOCK ');if(at>=0){try{stock=JSON.parse(text.slice(at+17));stockSeq++;row.snapshots.push(stock);}catch(e){report.errors.push(e.message);}}if(/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|ERROR:|memory access out of bounds|out of memory|\bOOM\b/i.test(text))report.errors.push(text);});
   page.on('crash',()=>report.errors.push('Browser page crashed'));
   page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({status:r.status(),url:r.url()});});
   const fresh=async()=>{const before=reader.sequence;await page.keyboard.press('F8');const end=Date.now()+2500;while(reader.sequence===before&&Date.now()<end)await delay(60);return reader.state;};
   const wait=async(fn,name,ms=240000)=>{const end=Date.now()+ms;while(!reader.state||!fn(reader.state)){assert.equal(report.errors.length,0,report.errors.join('\n'));assert.ok(Date.now()<end,'Timeout '+name);await fresh();await delay(100);}return reader.state;};
   const check=(ok,name)=>{assert.ok(ok,name);row.checks.push(name);};
   const click=async(text,allowDisabled=false)=>{let b;await wait(s=>(b=s.widgets?.filter(w=>w.text===text&&(allowDisabled||!w.disabled)&&(!w.entrance||w.entrance.opacity>.9)).at(-1)),'visible button '+text,25000);const s=reader.state,c=await page.locator('canvas').boundingBox(),r=b.rect;await page.mouse.click(c.x+(r[0]+r[2]/2)*c.width/s.width,c.y+(r[1]+r[3]/2)*c.height/s.height);await delay(400);};
   const key=async(code)=>{const cdp=await context.newCDPSession(page);try{const ev={key:'F'+(code-111),code:'F'+(code-111),windowsVirtualKeyCode:code,nativeVirtualKeyCode:code};await cdp.send('Input.dispatchKeyEvent',{type:'rawKeyDown',...ev});await delay(50);await cdp.send('Input.dispatchKeyEvent',{type:'keyUp',...ev});}finally{await cdp.detach();}};
   const sample=async(code,phase)=>{const before=stockSeq;await key(code);const end=Date.now()+10000;while(stockSeq===before&&Date.now()<end)await delay(70);assert.ok(stockSeq>before,'QA stock response '+phase);assert.equal(stock.phase,phase);return structuredClone(stock);};
   try{
    row.url=base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-vox-debug='+(debug?'1':'0');
    await page.goto(row.url);await page.bringToFront();await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'hall');
    await click('打捞行动');await wait(s=>s.tab==='salvage'&&!s.loadingFlow?.active&&!s.vehicleLoading?.busy,'salvage');
    const prepared=await sample(127,'prepared');row.prepared=prepared;row.actualUrl=page.url();
    check(prepared.debug===debug,'Actual URL produced expected debugEnabled');
    check(prepared.used>0&&prepared.missingKinds>0&&Object.keys(prepared.stock.items).length===0,'Real installed vehicle exceeds detached empty inventory');
    check(prepared.deploymentMissingKinds===(debug?0:prepared.missingKinds),'Only debug departure ignores real shortage');
    await fresh();const button=reader.state.widgets.filter(w=>w.text==='出发').at(-1);
    check(Boolean(button)&&Boolean(button.disabled)===!debug,'Actual departure button enabled only for debug shortage');
    await page.screenshot({path:path.join(out,label+'-shortage.png')});
    await click('出发',true);
    if(debug){await wait(s=>s.salvageRun&&!s.loadingFlow?.active,'actual debug raid loaded',240000);row.entered=structuredClone({mode:reader.state.mode,salvageRun:reader.state.salvageRun,loadingFlow:reader.state.loadingFlow});check(Boolean(reader.state.salvageRun),'Real mouse departure reached loaded salvage map');}
    else{await page.keyboard.press('Enter');await delay(1200);await fresh();check(reader.state.mode==='hangar'&&!reader.state.loadingFlow?.active&&!reader.state.salvageRun,'Disabled click and real Enter remain blocked without debug');}
    const observed=await sample(128,'observed');row.observed=observed;
    check(observed.stock.credits===prepared.stock.credits&&Object.keys(observed.stock.items).length===0&&!observed.saveStockChanged,'Departure did not grant inventory or change credits');
    assert.deepEqual(observed.saved,prepared.saved,'Actual saved inventory unchanged');row.checks.push('Actual saved inventory unchanged');
    await page.screenshot({path:path.join(out,label+'-result.png')});
    const restored=await sample(129,'restored');row.restored=restored;assert.deepEqual(restored.stock,prepared.saved,'Restored original stash matches real saved baseline');row.checks.push('Detached fixture restored original stash');row.result='PASS';
   }catch(error){await page.screenshot({path:path.join(out,label+'-failure.png'),timeout:10000}).catch(()=>{});throw error;}
   finally{await context.close();row.browser='CLOSED';}
  }
  const after=await fetch(base+'/identity.json').then(r=>r.json());assert.deepEqual(after,identity,'QA identity stable');assert.equal(report.errors.length,0);assert.equal(report.httpErrors.length,0);report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;process.exitCode=1;}
 finally{if(browser)await browser.close();report.browser='CLOSED';fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({result:report.result,out,failure:report.failure,runs:report.runs.map(r=>({debug:r.debug,result:r.result,checks:r.checks}))}));}
}
if(require.main===module)run().catch(e=>{console.error(e);process.exitCode=1;});

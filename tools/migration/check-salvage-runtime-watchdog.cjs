const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {isRuntimeFatal,recordRuntimeFatal,createRuntimeWatchdog,guardPage,closeRuntime}=require('./salvage-runtime-watchdog.cjs');
const never=()=>new Promise(()=>{}),delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function run(){
 const checks=[];const check=(ok,name)=>{assert.ok(ok,name);checks.push(name);};
 for(const text of ['Aborted(OOM)','RuntimeError: Aborted(OOM). Build with -sASSERTIONS for more info.','Browser page crashed'])check(isRuntimeFatal(text),'Actual fatal recognized: '+text);
 for(const text of ['BLOOM compiled successfully','ERROR: ordinary shader message','OUTGAME_STATE {"mode":"trial"}','operation returned normally'])check(!isRuntimeFatal(text),'Negative control does not invent runtime fatal: '+text);

 const healthy=createRuntimeWatchdog();
 for(let i=0;i<1000;i++)assert.equal(await healthy.operation('healthy',()=>i),i);
 check(healthy.pendingOperations===0&&!healthy.fatal,'Successful operations remove all fatal subscriptions');
 await assert.rejects(healthy.operation('ordinary failure',()=>{throw Error('ordinary expected rejection');}),/ordinary expected/);
 check(!healthy.fatal&&healthy.pendingOperations===0,'Ordinary operation error neither invents fatal nor retains listener');

 let delivered=0;const concurrent=createRuntimeWatchdog({onFatal:()=>delivered++});
 const a=assert.rejects(concurrent.operation('move',never),/Aborted\(OOM\)/);
 const b=assert.rejects(concurrent.operation('screenshot',never),/Aborted\(OOM\)/);
 concurrent.fail('console','Aborted(OOM)');concurrent.fail('pageerror','RuntimeError duplicate');
 await Promise.all([a,b]);
 check(delivered===1&&concurrent.pendingOperations===0,'One runtime fatal interrupts all current operations exactly once');
 let retried=false;await assert.rejects(concurrent.operation('after fatal',()=>{retried=true;}),/Aborted\(OOM\)/);
 check(!retried,'Fatal refuses new browser operations instead of waiting on failed renderer');

 const report={result:'RUNNING',shutdown:'PENDING',combatLoot:{result:'RUNNING'}};const snapshots=[];
 const watchdog=createRuntimeWatchdog({onFatal:event=>recordRuntimeFatal(report,event,()=>snapshots.push(structuredClone(report)))});
 let mouseUpCalled=false,browserClosed=false,pageClosed=false;
 const raw={mouse:{move:never,up:()=>{mouseUpCalled=true;return never();}},close:async()=>{pageClosed=true;}};
 const page=guardPage(raw,watchdog),started=Date.now();
 const route=(async()=>{
  try{try{await page.mouse.move(100,200);}finally{await page.mouse.up();}}
  catch(error){report.result='FAIL';report.failure=error.message;}
  finally{report.shutdownDetails=await closeRuntime(raw,{close:async()=>{browserClosed=true;}},{pageTimeoutMs:50,browserTimeoutMs:50});report.shutdown=report.shutdownDetails.status;snapshots.push(structuredClone(report));}
 })();
 await delay(5);watchdog.fail('console','Aborted(OOM)');await route;
 check(Date.now()-started<500,'OOM interrupts stuck move plus nested mouse-up finally without renderer response');
 check(!mouseUpCalled&&pageClosed&&browserClosed,'Fatal skips renderer input cleanup but executes bounded page/browser close');
 check(report.result==='FAIL'&&report.combatLoot.result==='FAIL'&&report.shutdown==='CLOSED','Interrupted route records actual FAIL/CLOSED including combat consumer state');
 check(snapshots[0].result==='FAIL'&&snapshots[0].shutdown==='PENDING','Fatal failure is persisted immediately before cleanup');

 const slowPage=await closeRuntime({close:never},{close:async()=>{}},{pageTimeoutMs:10,browserTimeoutMs:30});
 check(slowPage.status==='CLOSED'&&slowPage.page.status==='CLOSE_TIMEOUT'&&slowPage.browser.status==='CLOSED','Acknowledged browser close records earlier page timeout without claiming page response');
 const closeStarted=Date.now(),stalled=await closeRuntime({close:never},{close:never},{pageTimeoutMs:10,browserTimeoutMs:15});
 check(stalled.status==='CLOSE_TIMEOUT'&&stalled.page.status==='CLOSE_TIMEOUT'&&Date.now()-closeStarted<500,'No browser acknowledgement produces bounded honest CLOSE_TIMEOUT');
 let closedAfterPageFailure=false;
 const rejected=await closeRuntime({close:async()=>{throw Error('page disconnected');}},{close:async()=>{closedAfterPageFailure=true;throw Error('browser disconnected');}},{pageTimeoutMs:10,browserTimeoutMs:10});
 check(closedAfterPageFailure&&rejected.status==='FAILED'&&rejected.page.status==='FAILED','Page close error still attempts browser close and preserves failed status');

 const timeout=createRuntimeWatchdog({operationTimeoutMs:10});
 await assert.rejects(timeout.operation('unresponsive keyboard',never),error=>error.code==='BROWSER_OPERATION_TIMEOUT');
 check(timeout.fatal.source==='operation:unresponsive keyboard'&&timeout.pendingOperations===0,'Unresponsive operation has finite timeout even with no fatal console event');

 const called=[];const fake={};
 for(const method of ['bringToFront','goto','screenshot'])fake[method]=async function(...args){assert.equal(this,fake);called.push(method);return args;};
 for(const [group,methods]of [['mouse',['click','move','down','up']],['keyboard',['press','down','up']]]){fake[group]={};for(const method of methods)fake[group][method]=async function(){assert.equal(this,fake[group]);called.push(group+'.'+method);};}
 fake.locator=()=>({boundingBox:async()=>({x:1,y:2,width:3,height:4})});
 const guarded=guardPage(fake,healthy);
 for(const method of ['bringToFront','goto','screenshot'])await guarded[method]('argument');
 for(const group of ['mouse','keyboard'])for(const method of Object.keys(guarded[group]))await guarded[group][method]();
 assert.deepEqual(await guarded.locator('canvas').boundingBox(),{x:1,y:2,width:3,height:4});
 check(called.length===10&&healthy.pendingOperations===0,'All runner browser actions preserve receiver, arguments and normal results');

 const evidence='docs/migration/evidence/salvage-natural-manifest-8d107d95-2026-10-16T15-36-48-056Z/salvage-natural-web.log';
 if(fs.existsSync(evidence)){
  const fatal=fs.readFileSync(evidence,'utf8').split(/\r?\n/)[3923];
  check(fatal==='Aborted(OOM)'&&isRuntimeFatal(fatal),'Original failing raw log3924 triggers exact fatal detector');
 }
 const originalReport='docs/migration/evidence/salvage-natural-manifest-8d107d95-2026-10-16T15-36-48-056Z/salvage-natural-web.json';
 if(fs.existsSync(originalReport)){
  const original=JSON.parse(fs.readFileSync(originalReport,'utf8'));
  check(original.result==='RUNNING'&&original.shutdown==='PENDING','Historical interrupted runner result is preserved, not relabeled PASS or CLOSED');
 }
 const result={result:'PASS',checks:checks.length,cases:checks,hardware:'No browser, Web runtime or Native runtime launched. Stalled browser promises are fake controlled negative cases.',generatedAt:new Date().toISOString()};
 const out=path.resolve('docs/migration/evidence/salvage-runtime-watchdog-offline.json');fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({result:result.result,checks:result.checks,evidence:out}));
}
if(require.main===module)run().catch(error=>{console.error(error);process.exitCode=1;});
module.exports={run};

const fatalPattern=/\bAborted\([^)]*\)|\bRuntimeError\b|\bBrowser page crashed\b/;

function isRuntimeFatal(message){return fatalPattern.test(String(message));}
function recordRuntimeFatal(report,event,persist){
 if(report.fatalRuntime)return;
 report.fatalRuntime=event;report.result='FAIL';report.failure=event.message;
 if(report.combatLoot){report.combatLoot.result='FAIL';report.combatLoot.failure=event.message;}
 persist();
}
function createRuntimeWatchdog({onFatal=()=>{},operationTimeoutMs=20000}={}){
 let fatal=null;const listeners=new Set();
 function fail(source,message){
  if(fatal)return fatal;
  fatal={source,message:String(message),detectedAt:new Date().toISOString()};
  for(const reject of listeners)reject(Object.assign(new Error(fatal.message),{code:'RUNTIME_FATAL'}));
  onFatal(fatal);return fatal;
 }
 function throwIfFatal(){if(fatal)throw Object.assign(new Error(fatal.message),{code:'RUNTIME_FATAL'});}
 async function operation(label,work,timeoutMs=operationTimeoutMs){
  throwIfFatal();let timer,interrupt;
  try{
   return await Promise.race([
    Promise.resolve().then(work),
    new Promise((_,reject)=>{interrupt=reject;listeners.add(reject);}),
    new Promise((_,reject)=>{timer=setTimeout(()=>reject(Object.assign(new Error('Timed out browser operation '+label),{code:'BROWSER_OPERATION_TIMEOUT'})),timeoutMs);}),
   ]);
  }catch(error){if(error.code==='BROWSER_OPERATION_TIMEOUT'||isRuntimeFatal(error.stack||error.message))fail('operation:'+label,error.stack||error.message);throw error;}
  finally{clearTimeout(timer);listeners.delete(interrupt);}
 }
 return {fail,throwIfFatal,operation,get fatal(){return fatal;},get pendingOperations(){return listeners.size;}};
}

// Restrict interception to this runner's awaited browser operations. Events and
// browser setup retain the original Playwright objects and synchronous behavior.
function guardPage(page,watchdog){
 const guarded={};
 for(const method of ['bringToFront','goto','screenshot'])
  guarded[method]=(...args)=>watchdog.operation('page.'+method,()=>page[method](...args),method==='goto'?60000:20000);
 for(const [group,methods]of [['mouse',['click','move','down','up']],['keyboard',['press','down','up']]]){
  guarded[group]={};
  for(const method of methods)guarded[group][method]=(...args)=>watchdog.operation(group+'.'+method,()=>page[group][method](...args));
 }
 guarded.locator=(...args)=>({boundingBox:()=>watchdog.operation('locator.boundingBox',()=>page.locator(...args).boundingBox())});
 return guarded;
}

async function bounded(work,timeoutMs){
 let timer;
 try{return await Promise.race([
  Promise.resolve().then(work).then(()=>({status:'CLOSED'}),error=>({status:'FAILED',error:error.stack||String(error)})),
  new Promise(resolve=>{timer=setTimeout(()=>resolve({status:'CLOSE_TIMEOUT'}),timeoutMs);}),
 ]);}
 finally{clearTimeout(timer);}
}
async function closeRuntime(page,browser,{pageTimeoutMs=2000,browserTimeoutMs=5000}={}){
 const pageClose=await bounded(()=>page.close(),pageTimeoutMs);
 const browserClose=await bounded(()=>browser.close(),browserTimeoutMs);
 // Browser/context close can complete even when the renderer never acknowledged
 // page close. Its successful completion is the final shutdown boundary.
 return {status:browserClose.status,page:pageClose,browser:browserClose,finishedAt:new Date().toISOString()};
}
module.exports={isRuntimeFatal,recordRuntimeFatal,createRuntimeWatchdog,guardPage,closeRuntime};

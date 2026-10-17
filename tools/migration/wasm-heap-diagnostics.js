(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 else root.VoxWasmHeapDiagnostics=api;
})(typeof globalThis==='object'?globalThis:this,function(){
 'use strict';
 const PREFIX='VOX_HEAP_SAMPLE ';
 function createProbe(host,options={}){
  if(options.enabled!==true)return {enabled:false,sample:()=>null,start:()=>false,dispose:()=>{},snapshot:()=>[]};
  const intervalMs=options.intervalMs??2000,maxSamples=options.maxSamples??120;
  if(!Number.isInteger(intervalMs)||intervalMs<1000||intervalMs>5000)throw Error('Heap interval must be 1000..5000 ms');
  if(!Number.isInteger(maxSamples)||maxSamples<1||maxSamples>1000)throw Error('Heap ring must contain 1..1000 samples');
  const mod=host.Module,callbacks=host.ASM_CONSTS;
  if(!mod||typeof mod.__heapInfo!=='function'||!callbacks)throw Error('Actual Runtime heapInfo/ASM_CONSTS unavailable');
  const candidates=Object.entries(callbacks).filter(([,fn])=>typeof fn==='function'&&fn.length===3&&
   ['WASM Heap (dlmalloc)','In-use:','Free:','Arena:'].every(label=>Function.prototype.toString.call(fn).includes(label)));
  if(candidates.length!==1)throw Error('Expected one labelled three-argument dlmalloc callback; found '+candidates.length);
  const [key,originalCallback]=candidates[0],rows=[];
  const now=()=>host.performance?.now?.()??Date.now();
  const emit=options.emit||((row)=>host.console.log(PREFIX+JSON.stringify(row)));
  let timer=null,disposed=false,sampling=false,latest=null;
  function capacity(){
   const values=[host.HEAPU8?.byteLength,host.wasmMemory?.buffer?.byteLength,mod.HEAPU8?.byteLength].filter(v=>Number.isInteger(v)&&v>0);
   if(!values.length||values.some(v=>v!==values[0]))throw Error('Actual WASM capacity unavailable or inconsistent');
   return values[0];
  }
  function publish(row){rows.push(row);if(rows.length>maxSamples)rows.shift();emit(row);return row;}
  function sample(tag='interval'){
   if(disposed||sampling)return null;
   const begun=now();sampling=true;
   let wrapper=null,row={kind:'sample',tag,at:new Date().toISOString(),wallMs:begun,units:'bytes',status:'UNAVAILABLE'};
   try{
    const capacityBytes=capacity();
    if(callbacks[key]!==originalCallback)throw Error('Heap callback changed by another owner');
    let calls=0,raw=null;
    wrapper=function(...args){calls++;raw=args;return originalCallback.apply(this,args);};
    callbacks[key]=wrapper;
    mod.__heapInfo();
    if(calls!==1||raw.length!==3||!raw.every(v=>Number.isSafeInteger(v)&&v>=0&&v<=capacityBytes))throw Error('Runtime returned invalid raw allocator statistics');
    const [inUseBytes,freeBytes,arenaBytes]=raw;
    if(inUseBytes>arenaBytes||freeBytes>arenaBytes)throw Error('Allocator statistics exceed reported arena');
    const memory=host.performance?.memory;
    row={...row,status:'OK',capacityBytes,inUseBytes,freeBytes,arenaBytes,
     callbackKey:key,source:'Module.__heapInfo / labelled dlmalloc callback',
     jsHeap:memory?{usedBytes:memory.usedJSHeapSize,totalBytes:memory.totalJSHeapSize,limitBytes:memory.jsHeapSizeLimit}:null};
    latest=row;
   }catch(error){row.reason=String(error?.message||error);}
   finally{
    if(wrapper&&callbacks[key]===wrapper)callbacks[key]=originalCallback;
    sampling=false;row.durationMs=now()-begun;
   }
   return publish(row);
  }
  const originalAbort=mod.onAbort;
  const abortWrapper=function(...args){
   // Do not re-enter dlmalloc while its failing allocation may hold a lock.
   try{publish({kind:'abort',at:new Date().toISOString(),reason:String(args[0]),lastSuccessfulSample:latest});}
   finally{if(typeof originalAbort==='function')return originalAbort.apply(this,args);}
  };
  mod.onAbort=abortWrapper;
  return {enabled:true,sample,snapshot:()=>rows.slice(),start(){if(disposed||timer!==null)return false;timer=host.setInterval(()=>sample(),intervalMs);return true;},dispose(){
   disposed=true;if(timer!==null){host.clearInterval(timer);timer=null;}
   if(mod.onAbort===abortWrapper)mod.onAbort=originalAbort;
  }};
 }
 return {createProbe,PREFIX};
});

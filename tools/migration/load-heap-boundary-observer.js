(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 else root.VoxLoadHeapBoundaryObserver=api;
})(typeof globalThis==='object'?globalThis:this,function(){
 'use strict';
 const MARKER='VOX_LOAD_HEAP_BOUNDARY ',PREFIX='VOX_LOAD_HEAP_DIAGNOSTIC ';
 function install(host,options={}){
  if(host.__voxLoadHeapBoundaryObserver)throw Error('Duplicate load heap observer');
  const original=host.console.log,now=()=>host.performance.now();
  const emit=options.emit||(row=>original.call(host.console,PREFIX+JSON.stringify(row)));
  const expected=['hall-stable','old-hall-cleaned','resources-ready','physics-prepared','activation-closed','returned-cleanup'];
  const seen=new Set(),sampledFrames=new Map();
  let pending=[],queued=false,disposed=false,probe=null,calls=0,consoleDepth=0,raf=null,rafFrame=0,lastCapacity=null,lastCapacityAt=-Infinity,context=null,lastError=null;
  function publish(row){emit({...row,wallMs:now(),rafFrame,diagnostic:true,excludeFromFps:true});}
  function report(error){lastError=String(error?.message||error);publish({kind:'observer-error',reason:lastError});}
  function flushUnsafe(){
   queued=false;if(disposed||!pending.length)return;
   if(consoleDepth!==0)throw Error('Allocator must never be called within Runtime console callback');
   const boundaries=pending;pending=[];
   const old=boundaries.filter(row=>sampledFrames.has(row.frame));
   const fresh=boundaries.filter(row=>!sampledFrames.has(row.frame));
   for(const row of old)publish({kind:'late-same-frame-boundary',marker:row,priorSample:sampledFrames.get(row.frame),delayMs:now()-row.receivedWallMs,boundary:'No new allocator call. Earlier sample predates this boundary; it is not a phase result.'});
   if(!fresh.length)return;
   if(calls>=6)throw Error('Load allocator query limit exceeded');
   const id=++calls,tags=fresh.map(row=>row.tag),frames=[...new Set(fresh.map(row=>row.frame))];
   for(const frame of frames)sampledFrames.set(frame,id);
   publish({kind:'sample-start',id,tags,engineFrames:frames,boundaries:fresh,delaysMs:fresh.map(row=>now()-row.receivedWallMs),coalesced:tags.length>1,
    boundary:'queueMicrotask after originating WASM call returns. Non-atomic boundary drift; coalesced tags share one value and cannot be attributed independently.'});
   if(!probe)probe=host.VoxWasmHeapDiagnostics.createProbe(host,{enabled:true,maxSamples:6,intervalMs:5000,emit:row=>publish({kind:'allocator-result',...(context||{id:null,tags:[],engineFrames:[],boundary:'Asynchronous allocator event outside a boundary query; not attributed to a loading phase.'}),allocator:row})});
   context={id,tags,engineFrames:frames};
   const begun=now(),sample=probe.sample('load-'+id+':'+tags.join('+'));context=null;
   publish({kind:'sample-end',id,tags,engineFrames:frames,durationMs:now()-begun,status:sample?.status});
   host.requestAnimationFrame(()=>{if(!disposed)publish({kind:'sample-following-frame',id,tags,engineFrames:frames});});
  }
  function flush(){try{flushUnsafe();}catch(error){report(error);}finally{context=null;}}
  function wrapped(...args){
   consoleDepth++;
   try{
    original.apply(this,args);
    const text=typeof args[0]==='string'?args[0]:'',at=text.indexOf(MARKER);
    if(!disposed&&at>=0){
     const boundary=JSON.parse(text.slice(at+MARKER.length));
     if(!expected.includes(boundary.tag)||!Number.isInteger(boundary.frame)||boundary.frame<0)throw Error('Invalid explicit loading boundary');
     if(!seen.has(boundary.tag)){
      if(seen.size>=6)throw Error('Load boundary count exceeds six');
      seen.add(boundary.tag);pending.push({...boundary,receivedWallMs:now()});
      if(!queued){queued=true;host.queueMicrotask(flush);}
     }
    }
   }catch(error){report(error);}finally{consoleDepth--;}
  }
  function capacity(){
   if(disposed)return;rafFrame++;
   const bytes=host.HEAPU8?.byteLength||host.Module?.HEAPU8?.byteLength||0,at=now();
   if(bytes>0&&(bytes!==lastCapacity||at-lastCapacityAt>=1000)){lastCapacity=bytes;lastCapacityAt=at;publish({kind:'capacity',capacityBytes:bytes});}
   raf=host.requestAnimationFrame(capacity);
  }
  host.console.log=wrapped;raf=host.requestAnimationFrame(capacity);
  const observer={snapshot:()=>({allocatorCalls:calls,tags:[...seen],pending:pending.length,zeroReentrancy:consoleDepth===0,error:lastError}),dispose(){
   if(disposed)return;disposed=true;pending=[];host.cancelAnimationFrame(raf);probe?.dispose();if(host.console.log===wrapped)host.console.log=original;
  }};
  host.__voxLoadHeapBoundaryObserver=observer;return observer;
 }
 return {install,MARKER,PREFIX};
});

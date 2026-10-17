(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 else root.VoxSparseHeapObserver=api;
})(typeof globalThis==='object'?globalThis:this,function(){
 'use strict';
 const PREFIX='VOX_SPARSE_HEAP ';
 function create(host,options={}){
  const now=()=>host.performance.now(),emit=options.emit||(row=>host.console.log(PREFIX+JSON.stringify(row)));
  const probe=host.VoxWasmHeapDiagnostics.createProbe(host,{enabled:true,maxSamples:4,intervalMs:5000});
  const timers=[],sampled=new Set();
  let disposed=false,frame=0,raf=null,lastEmit=-Infinity,lastCapacity=null,loadedAt=null,sampleSerial=0;
  function publish(row){emit({...row,wallMs:now(),frame});}
  function capacity(){return host.HEAPU8?.byteLength||host.Module?.HEAPU8?.byteLength||0;}
  function observe(){
   if(disposed)return;
   frame++;
   const bytes=capacity(),at=now();
   if(bytes!==lastCapacity||at-lastEmit>=1000){
    publish({kind:'capacity',capacityBytes:bytes,raidWallMs:loadedAt===null?null:at-loadedAt});
    lastCapacity=bytes;lastEmit=at;
   }
   raf=host.requestAnimationFrame(observe);
  }
  function sample(tag){
   if(disposed||sampled.has(tag))return null;
   if(!['loaded','raid80','raid140','returned'].includes(tag)||sampled.size>=4)throw Error('Sparse allocator sample limit/tag violated');
   sampled.add(tag);const serial=++sampleSerial,startFrame=frame,begun=now();
   publish({kind:'sample-start',tag,serial,excludeFromFps:true,exclusion:'Current and following observed animation frame; this diagnostic run is not a performance baseline.'});
   const result=probe.sample(tag);
   publish({kind:'sample-end',tag,serial,startFrame,endFrame:frame,durationMs:now()-begun,excludeFromFps:true,status:result?.status});
   host.requestAnimationFrame(()=>{if(!disposed)publish({kind:'sample-frame-boundary',tag,serial,startFrame,endFrame:frame,excludeFromFps:true});});
   return result;
  }
  function cancelMilestones(){for(const id of timers)host.clearTimeout(id);timers.length=0;}
  raf=host.requestAnimationFrame(observe);
  return {
   loaded(){
    if(loadedAt!==null)throw Error('Sparse loaded marker already armed');
    loadedAt=now();const first=sample('loaded');
    timers.push(host.setTimeout(()=>sample('raid80'),80000),host.setTimeout(()=>sample('raid140'),140000));
    return first;
   },
   returned(){cancelMilestones();return sample('returned');},
   dispose(){if(disposed)return;disposed=true;cancelMilestones();host.cancelAnimationFrame(raf);probe.dispose();},
   snapshot(){return {allocatorCalls:sampled.size,tags:[...sampled],lastCapacityBytes:lastCapacity,frame,loadedAt};},
  };
 }
 return {create,PREFIX};
});

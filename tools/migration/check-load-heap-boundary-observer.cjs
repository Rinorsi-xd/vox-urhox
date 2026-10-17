'use strict';
const assert=require('node:assert/strict');
const {install,MARKER}=require('./load-heap-boundary-observer.js');
let time=0,next=1,allocator=0,starts=0,disposes=0,depth=0,allocatorEmitter;
const rafs=new Map(),microtasks=[],rows=[],logs=[];
const original=function(...args){assert.equal(this,host.console);logs.push(args);};
const host={
 console:{log:original},performance:{now:()=>time},HEAPU8:{byteLength:536870912},
 queueMicrotask(fn){microtasks.push(fn);},
 requestAnimationFrame(fn){const id=next++;rafs.set(id,fn);return id;},cancelAnimationFrame(id){rafs.delete(id);},
 VoxWasmHeapDiagnostics:{createProbe(_host,opts){allocatorEmitter=opts.emit;return {
  sample(tag){assert.equal(depth,0,'Allocator is outside originating WASM stack');allocator++;time+=45;opts.emit({kind:'sample',tag,status:'OK'});return {status:'OK'};},
  start(){starts++;},dispose(){disposes++;},
 };}},
};
function marker(tag,frame){depth++;try{host.console.log(MARKER+JSON.stringify({tag,frame}));}finally{depth--;}}
function flush(){assert.equal(depth,0);while(microtasks.length)microtasks.shift()();}
function frame(ms=16){time+=ms;const work=[...rafs.values()];rafs.clear();for(const fn of work)fn();}
const observer=install(host,{emit:row=>rows.push(row)});
assert.throws(()=>install(host),/Duplicate/);
for(let i=0;i<100;i++)frame();
assert.equal(allocator,0);assert.equal(starts,0);
host.console.log('ordinary');assert.deepEqual(logs.at(-1),['ordinary']);
marker('hall-stable',10);assert.equal(allocator,0);assert.equal(microtasks.length,1);
time+=3;flush();assert.equal(allocator,1);
assert.deepEqual(rows.find(row=>row.kind==='sample-start').delaysMs,[3]);
frame();
marker('old-hall-cleaned',20);marker('resources-ready',20);assert.equal(allocator,1);assert.equal(microtasks.length,1);
flush();assert.equal(allocator,2);
const coalesced=rows.filter(row=>row.kind==='sample-start').at(-1);
assert.equal(coalesced.coalesced,true);assert.deepEqual(coalesced.tags,['old-hall-cleaned','resources-ready']);assert.deepEqual(coalesced.engineFrames,[20]);
marker('physics-prepared',20);flush();assert.equal(allocator,2);
const late=rows.find(row=>row.kind==='late-same-frame-boundary');assert.equal(late.priorSample,2);assert.match(late.boundary,/predates/);
marker('activation-closed',30);marker('activation-closed',30);flush();assert.equal(allocator,3);
marker('returned-cleanup',40);flush();assert.equal(allocator,4);
assert.equal(observer.snapshot().tags.length,6);assert.equal(observer.snapshot().pending,0);assert.equal(observer.snapshot().zeroReentrancy,true);
allocatorEmitter({kind:'abort',reason:'fake outside-query event'});
const abort=rows.at(-1);assert.equal(abort.kind,'allocator-result');assert.equal(abort.id,null);assert.deepEqual(abort.tags,[]);
assert.equal(starts,0);assert.ok(rows.every(row=>row.excludeFromFps&&row.diagnostic));
assert.ok(rows.filter(row=>row.kind==='sample-end').every(row=>row.durationMs===45));
assert.ok(rows.filter(row=>row.kind==='capacity').length<=3);
assert.doesNotThrow(()=>host.console.log(MARKER+'not JSON'),'Malformed QA marker never throws into WASM');assert.match(observer.snapshot().error,/JSON/);
assert.doesNotThrow(()=>marker('unexpected',50));assert.match(observer.snapshot().error,/Invalid/);
observer.dispose();observer.dispose();flush();frame();assert.equal(host.console.log,original);assert.equal(disposes,1);assert.equal(rafs.size,0);assert.equal(allocator,4);
console.log(JSON.stringify({result:'PASS',allocatorCalls:allocator,periodicStarts:starts,explicitTags:observer.snapshot().tags.length,coalescedQueries:1,lateSameFrameQueries:0,source:'Offline fake host only; no hardware, heap values, FPS or performance acceptance.'}));

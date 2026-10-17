const assert=require('node:assert/strict');
const {create}=require('./sparse-heap-observer.js');
let time=0,next=1,allocator=0,starts=0,disposes=0;
const rafs=new Map(),timers=new Map(),rows=[],tags=[];
const host={
 performance:{now:()=>time},HEAPU8:{byteLength:536870912},
 requestAnimationFrame(fn){const id=next++;rafs.set(id,fn);return id;},cancelAnimationFrame(id){rafs.delete(id);},
 setTimeout(fn,ms){const id=next++;timers.set(id,{fn,at:time+ms});return id;},clearTimeout(id){timers.delete(id);},
 VoxWasmHeapDiagnostics:{createProbe(){return {sample(tag){allocator++;tags.push(tag);time+=45;return {status:'OK'};},start(){starts++;},dispose(){disposes++;}};}},
};
function frame(ms=16){time+=ms;const work=[...rafs.values()];rafs.clear();for(const fn of work)fn();}
function advance(ms){time+=ms;for(const [id,timer]of [...timers])if(timer.at<=time){timers.delete(id);timer.fn();}}
const probe=create(host,{emit:row=>rows.push(row)});
for(let i=0;i<100;i++)frame();
assert.equal(allocator,0,'Capacity monitoring never calls allocator');
assert.equal(starts,0,'Periodic allocator start is never invoked');
assert.ok(rows.filter(row=>row.kind==='capacity').length<=3,'Stable scalar capacity emits at most once per second');
host.HEAPU8.byteLength*=2;frame();
assert.equal(rows.at(-1).capacityBytes,1073741824,'Capacity growth is observed without allocator access');
probe.loaded();assert.equal(allocator,1);assert.throws(()=>probe.loaded(),/already armed/);
frame();advance(80000);frame();advance(60000);frame();
assert.deepEqual(tags,['loaded','raid80','raid140']);
probe.returned();probe.returned();
assert.deepEqual(tags,['loaded','raid80','raid140','returned']);
assert.equal(starts,0);assert.equal(probe.snapshot().allocatorCalls,4);
assert.equal(rows.filter(row=>row.kind==='sample-start').length,4);
assert.ok(rows.filter(row=>row.kind==='sample-end').every(row=>row.excludeFromFps&&row.durationMs===45));
assert.ok(rows.filter(row=>row.kind==='sample-frame-boundary').every(row=>row.excludeFromFps));
probe.dispose();probe.dispose();advance(200000);frame();
assert.equal(allocator,4);assert.equal(disposes,1);assert.equal(timers.size,0);assert.equal(rafs.size,0);
console.log(JSON.stringify({result:'PASS',allocatorCalls:allocator,periodicStarts:starts,capacityRows:rows.filter(row=>row.kind==='capacity').length,sampleMarkers:rows.filter(row=>row.kind!=='capacity').length,boundary:'Offline fake clock/heap only; no hardware or game performance claims.'}));

const assert=require('node:assert/strict');
const {createProbe}=require('./wasm-heap-diagnostics.js');
const checks=[];function check(ok,label){assert.ok(ok,label);checks.push(label);}
const untouched=new Proxy({}, {get(){throw Error('Disabled probe accessed host');}});
const disabled=createProbe(untouched);check(!disabled.enabled&&disabled.sample()===null&&!disabled.start(),'Default OFF accesses no Runtime API');disabled.dispose();
function fixture(){
 const logs=[],emitted=[],timers=new Map();let invokes=0,aborts=0,receiver=null;
 const callback=function(a,b,c){receiver=this;logs.push(['=== WASM Heap (dlmalloc) ===','In-use:',(a/1048576).toFixed(1),'Free:',b,'Arena:',c]);};
 const host={HEAPU8:{byteLength:4096},wasmMemory:{buffer:{byteLength:4096}},ASM_CONSTS:{123:callback},console:{log:v=>logs.push(v)},performance:{now:()=>10,memory:{usedJSHeapSize:3,totalJSHeapSize:4,jsHeapSizeLimit:5}},
  setInterval(fn,ms){timers.set(1,{fn,ms});return 1;},clearInterval(id){timers.delete(id);}};
 host.Module={__heapInfo(){invokes++;host.ASM_CONSTS[123](1234,1022,3072);},onAbort(){aborts++;return this;}};
 return {host,logs,emitted,timers,callback,get invokes(){return invokes;},get aborts(){return aborts;},get receiver(){return receiver;}};
}
let f=fixture(),originalAbort=f.host.Module.onAbort,p=createProbe(f.host,{enabled:true,emit:r=>f.emitted.push(r),maxSamples:2});
const row=p.sample('manual');
check(row.inUseBytes===1234&&row.freeBytes===1022&&row.arenaBytes===3072&&row.capacityBytes===4096,'Exact raw bytes survive native rounded display; capacity differs from used');
check(row.jsHeap.usedBytes===3&&row.units==='bytes','JS memory is separately labelled');
check(f.logs.length===1&&f.receiver===f.host.ASM_CONSTS&&f.host.ASM_CONSTS[123]===f.callback,'Original log and receiver forwarded; callback restored');
check(p.start()&&!p.start()&&f.timers.get(1).ms===2000,'One low-frequency timer only');
p.sample();p.sample();check(p.snapshot().length===2,'Browser history is bounded');
const beforeAbort=f.invokes;check(f.host.Module.onAbort('OOM')===f.host.Module&&f.aborts===1&&f.invokes===beforeAbort,'Abort forwards original hook without querying allocator');
check(f.emitted.at(-1).kind==='abort'&&f.emitted.at(-1).lastSuccessfulSample.inUseBytes===1234,'Abort records previous successful raw sample');
p.dispose();check(!f.timers.size&&f.host.Module.onAbort===originalAbort&&p.sample()===null,'Dispose restores hook and timer; no subsequent sampling');
f=fixture();p=createProbe(f.host,{enabled:true,emit:r=>f.emitted.push(r)});f.host.Module.__heapInfo=()=>{throw Error('Expected allocator failure');};
check(p.sample().status==='UNAVAILABLE'&&f.host.ASM_CONSTS[123]===f.callback,'Allocator exception restores callback and fails closed');p.dispose();
for(const values of [[1,2,5000],[-1,2,3000],[1.5,2,3000],[3500,1,3000]]){
 f=fixture();f.host.Module.__heapInfo=()=>f.host.ASM_CONSTS[123](...values);p=createProbe(f.host,{enabled:true,emit:()=>{}});check(p.sample().status==='UNAVAILABLE','Invalid allocator values rejected '+values);p.dispose();
}
f=fixture();f.host.Module.__heapInfo=()=>{};p=createProbe(f.host,{enabled:true,emit:()=>{}});check(p.sample().status==='UNAVAILABLE','No actual callback is not a fabricated sample');p.dispose();
f=fixture();delete f.host.HEAPU8;delete f.host.wasmMemory;p=createProbe(f.host,{enabled:true,emit:()=>{}});check(p.sample().status==='UNAVAILABLE'&&f.invokes===0,'Missing capacity prevents allocator call');p.dispose();
f=fixture();f.host.ASM_CONSTS.other=f.callback;assert.throws(()=>createProbe(f.host,{enabled:true}),/found 2/);check(true,'Ambiguous callback rejected');
assert.throws(()=>createProbe({},{enabled:true}),/unavailable/);check(true,'Missing shipped API rejected');
for(const intervalMs of [0,999,5001,1.5])assert.throws(()=>createProbe({}, {enabled:true,intervalMs}),/interval/);check(true,'High frequency and invalid intervals rejected');
f=fixture();p=createProbe(f.host,{enabled:true,emit:()=>{}});const owned=()=>{};f.host.Module.onAbort=owned;p.dispose();check(f.host.Module.onAbort===owned,'Dispose preserves later owner of abort hook');
f=fixture();p=createProbe(f.host,{enabled:true,emit:()=>{throw Error('Expected writer error');}});check(f.host.Module.onAbort('OOM')===f.host.Module&&f.aborts===1,'Writer failure cannot suppress original abort hook');p.dispose();
f=fixture();p=createProbe(f.host,{enabled:true,emit:()=>{}});f.host.Module.__heapInfo=()=>{f.host.ASM_CONSTS[123]=owned;};check(p.sample().status==='UNAVAILABLE'&&f.host.ASM_CONSTS[123]===owned,'Sampler preserves later callback ownership even on missing result');p.dispose();
console.log(JSON.stringify({result:'PASS',checks:checks.length,labels:checks},null,2));

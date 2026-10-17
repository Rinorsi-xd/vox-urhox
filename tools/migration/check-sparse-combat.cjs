'use strict';
const assert=require('node:assert/strict'),vm=require('node:vm');
const {installBridge,intervals,attribute}=require('./sparse-combat-cpu.cjs');
const {buildRunner,runnerSource}=require('./sparse-combat-run.cjs');
buildRunner();
const source=runnerSource();
const hall=source.match(/await wait\(s=>s\.mode==='hangar'[^\n]+assert\.equal\(state\.monitorEnabled,false\);/);
assert(hall,'The actual inherited hall-bootstrap gate explicitly requires false');
const gate=hall[0].slice(hall[0].indexOf('assert.equal'));
vm.runInNewContext(gate,{assert,state:{monitorEnabled:false}});
for(const monitorEnabled of [true,undefined,null,0])assert.throws(()=>vm.runInNewContext(gate,{assert,state:{monitorEnabled}}));
assert(!/monitorEnabled\s*,\s*true|monitorEnabled\s*:\s*true|monitorEnabled\s*&&/.test(source));
const good={overflow:false,firstStack:'Error\n at wasm-function[1040] (wasm://wasm/id:0x123)',rows:[[1,'begin',8,100,100],[1,'begin',1,101,101],[1,'end',1,111,111],[1,'end',8,112,112]]};
assert.equal(intervals(good).length,2);
const clone=v=>structuredClone(v);
for(const mutate of [b=>b.overflow=true,b=>b.firstStack='at async browserLogger',b=>b.rows[2][2]=2,b=>b.rows.pop(),b=>b.rows[2][4]+=30,b=>b.rows[1][0]=3,b=>b.rows[2][1]='error']){
 const bad=clone(good);mutate(bad);assert.throws(()=>intervals(bad));
}
const profile={startTime:1104000,nodes:[{id:1,callFrame:{functionName:'wasm-function[9978]'},children:[2]},{id:2,callFrame:{functionName:'wasm-function[767]'}}],samples:[2,2,2],timeDeltas:[1000,2000,2000]};
const anchors=[{lowerMs:999.5,upperMs:1000.5},{lowerMs:999.8,upperMs:1000.2}];
const a=attribute(profile,good,anchors);assert.equal(a.owner9978StatisticalUs[1],5000);assert.equal(a.assigned9978Us,5000);
assert.throws(()=>attribute(profile,good,[anchors[0],{lowerMs:1002,upperMs:1003}]));
assert.throws(()=>attribute(profile,good,[{lowerMs:900,upperMs:1100},anchors[1]]));
assert.throws(()=>attribute({...profile,nodes:[{id:1,callFrame:{functionName:'unknown'},children:[2]},{id:2,callFrame:{functionName:'malloc'}}]},good,anchors));
assert.throws(()=>attribute({...profile,startTime:0},good,anchors));
const logged=[],context={console:{log(...args){logged.push(args)}},performance:{now:()=>123},Error};context.globalThis=context;
vm.runInNewContext('('+installBridge.toString()+')()',context);context.console.log('prefix VOX_SPARSE_SYNC 1 begin 2 99');
assert.equal(context.__voxSparseSync.rows.length,1);assert.equal(logged.length,1);assert.equal(context.__voxSparseSync.rows[0][4],123);
console.log('PASS: isolated runner transform; sync bridge forwarding; nested 9978 sample attribution; 10 marker/clock/missing-symbol negative controls. Offline only.');

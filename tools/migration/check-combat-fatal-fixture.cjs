// Execute the real browser-tool fatal/checkpoint path with an in-memory page.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(path.join(__dirname,'check-combat-performance-web.cjs'),'utf8');
const listeners={},files=new Map();let closes=0,evaluations=0,shots=0,done=false;
const frames={frames:[{at:10,ms:16,phase:'pre-oom'}],gl:{'pre-oom:compileShader':{calls:1}},slowGL:[]};
const page={
 on(name,fn){listeners[name]=fn},addInitScript:async()=>{},
 context:()=>({newCDPSession:async()=>({send:async name=>name==='Profiler.stop'?{profile:{nodes:[]}}:{}})}),
 keyboard:{press:async()=>{listeners.console({text:()=> 'OUTGAME_STATE '+JSON.stringify({mode:'hangar',tab:'hangar',widgets:[]})})}},
 evaluate:async(fn,arg)=>{if(arg!==undefined)return;evaluations++;return structuredClone(frames)},
 goto:async()=>{listeners.console({text:()=> 'Aborted(OOM)'});throw Error('Owned browser was closed')},
 screenshot:async()=>{shots++},
};
const browser={newPage:async()=>page,on:()=>{},close:async()=>{closes++}};
const mockfs={mkdirSync:()=>{},appendFileSync:(name,value)=>files.set(name,(files.get(name)||'')+value),writeFileSync:(name,value)=>files.set(name,value)};
const instrumented=source.replace(" try{\n  await begin('boot')"," await end('offline-last-checkpoint');\n try{\n  await begin('boot')");
assert.notEqual(instrumented,source,'Test injects one completed real checkpoint');
const sandbox={__dirname,process:{env:{},exitCode:0},fetch:async()=>({json:async()=>({qa:true})}),console:{log:()=>{done=true},error:()=>{}},setTimeout,clearTimeout,structuredClone,
 require(name){if(name==='node:fs')return mockfs;if(name.includes('playwright'))return {chromium:{launch:async()=>browser}};if(name==='./combat-result-flow.cjs')return require('./combat-result-flow.cjs');return require(name)}};
vm.runInNewContext(instrumented,sandbox,{filename:'actual-check-combat-performance-web.cjs'});
(async()=>{
 const until=Date.now()+2000;while(!done&&Date.now()<until)await new Promise(resolve=>setImmediate(resolve));
 assert(done,'Fatal path returns instead of hanging');assert.equal(closes,1,'Only owned browser closes once');assert.equal(shots,0,'No screenshot attempted on failed renderer');assert.equal(evaluations,1,'No final evaluate attempted after fatal');
 const reports=[...files].filter(([name])=>name.endsWith('report.json'));assert.equal(reports.length,1);
 const report=JSON.parse(reports[0][1]);assert.equal(report.result,'FAIL');assert(report.fatal.reason.includes('OOM'));assert.equal(report.stages.length,1);assert.equal(report.frames.length,1);assert.equal(report.frames[0].ms,16);assert(report.measurements.truncated);assert.equal(report.measurements.checkpoint.name,'offline-last-checkpoint');assert(report.finishedAt);
 console.log(JSON.stringify({result:'PASS',checks:13,boundary:'Actual tool fatal/checkpoint code with in-memory browser/fs; no GPU/browser launch or production acceptance.'}));
})().catch(error=>{console.error(error);process.exitCode=1});

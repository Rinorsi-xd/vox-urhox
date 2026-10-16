const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const tool=path.join(__dirname,'check-story-natural-web.cjs'),source=fs.readFileSync(tool,'utf8');
const captureSource=source.slice(source.indexOf('function captureBattleObjects('),source.indexOf('function recordBattleObjects('));
const recordSource=source.slice(source.indexOf('function recordBattleObjects('),source.indexOf('async function main('));
const sampleSource=source.slice(source.indexOf('async function sampleBattleObjects('),source.indexOf(' async function shot(')).trim();
const capture=eval('('+captureSource+')'),captureBattleObjects=capture,recordBattleObjects=eval('('+recordSource+')');let checks=0;
const check=(ok,label)=>{assert(ok,label);checks++;};
const createState=()=>({mode:'trial',story:{id:'s4',index:3,step:'fight',phase:'hold',time:12},performance:{battleObjects:{at:100,frame:7,elapsedMs:3,scene:{sampled:true,supported:true,nodes:40,components:60},world:{projectiles:{total:8}}}}});
function validate(api){
 const request={stage:'entered',storyId:'s4',afterSequence:10},observed=createState();
 assert.equal(api(request,observed,10),null);
 observed.mode='hangar';assert.equal(api(request,observed,11),null);observed.mode='trial';
 observed.story.id='s3';assert.equal(api(request,observed,11),null);observed.story.id='s4';
 observed.performance.battleObjects.scene.sampled=false;assert.equal(api(request,observed,11),null);observed.performance.battleObjects.scene.sampled=true;
 const captured=api(request,observed,11);assert.equal(captured.objects.scene.nodes,40);
 observed.performance.battleObjects.scene.nodes=999;assert.equal(captured.objects.scene.nodes,40);
 request.snapshot=captured;assert.equal(api(request,createState(),12),null);
 return 7;
}
checks+=validate(capture);
async function runCase(kind){
 let stateValue=createState(),state=stateValue,seq=10,objectRequest,persisted=0;const calls=[],report={errors:[],objectSamples:[]};
 if(kind==='hangar')state.mode='hangar';if(kind==='no-story')delete state.story;if(kind==='runtime-error')report.errors.push('Existing runtime failure');
 const sleep=async()=>{};const persist=()=>persisted++;
 const objectInput={send:async(method,event)=>{
  calls.push({method,...event});
  if(event.type==='rawKeyDown'&&kind!=='timeout'){
   stateValue=state=stateValue;
   if(kind==='unsupported')stateValue.performance.battleObjects.scene={sampled:true,supported:false,error:'API unavailable'};
   seq++;recordBattleObjects(objectRequest,stateValue,seq,report,persist);
   assert.equal(report.objectSamples.length,1,'Actual console observer persists before keyup');assert.equal(persisted,1);
   // A compact automatic dump and mutations arrive before keyup and screenshot.
   stateValue.performance.battleObjects.world.projectiles.total=999;
   state={mode:'trial',story:{id:'s4'},performance:{}};seq++;
  }
 }};
 const setTimeout=kind==='timeout'?(fn,ms)=>{assert.equal(ms,15000);queueMicrotask(fn);return 1;}:global.setTimeout;
 const clearTimeout=kind==='timeout'?()=>{}:global.clearTimeout;
 const sample=eval('('+sampleSource+')');let error;
 try{await sample('stage-3');}catch(value){error=String(value);}
 return {calls,report,persisted,error,objectRequest};
}
(async()=>{
 const actual=await runCase('success');
 check(!actual.error&&actual.report.objectSamples.length===1,'Actual request records exactly one sample');
 const sample=actual.report.objectSamples[0];
 check(sample.result==='PASS'&&sample.objects.world.projectiles.total===8,'Compact dump and source-object mutation cannot replace frozen actual counters');
 check(actual.calls.length===2&&actual.calls.every(c=>c.method==='Input.dispatchKeyEvent'&&c.key==='F14'&&c.code==='F14'&&c.windowsVirtualKeyCode===125&&c.nativeVirtualKeyCode===125),'Actual F14 uses explicit Chrome key125 delivery');
 check(actual.calls[0].type==='rawKeyDown'&&actual.calls[1].type==='keyUp','Actual keydown and keyup are paired');
 check(actual.objectRequest===null&&actual.persisted===2,'Actual observation persists on receipt and final key delivery, then clears once');
 for(const kind of ['hangar','no-story']){const r=await runCase(kind);check(!r.error&&!r.calls.length&&!r.report.objectSamples.length,'Skip non-story screenshot: '+kind);}
 const timeout=await runCase('timeout');
 check(/15 seconds/.test(timeout.error)&&timeout.report.objectSamples[0].result==='FAIL'&&timeout.report.objectSamples[0].observed===null&&timeout.objectRequest===null,'15-second deadline records explicit failure without invented sample');
 const unsupported=await runCase('unsupported');
 check(/API unavailable/.test(unsupported.error)&&unsupported.report.objectSamples[0].objects.scene.supported===false,'Unsupported engine API preserves failed actual observation');
 const failed=await runCase('runtime-error');check(/Existing runtime failure/.test(failed.error)&&!failed.calls.length,'Existing runtime error aborts before input');
 const rejectedMutations=[];
 for(const [label,before,after]of [
  ['stale sequence','sequence<=request.afterSequence||',''],
  ['wrong mode',"observed.mode!=='trial'||",''],
  ['wrong story','observed.story?.id!==request.storyId','false'],
  ['compact sample accepted','!objects?.scene?.sampled','!objects'],
  ['overwrite existing snapshot','request.snapshot||',''],
 ]){assert(captureSource.includes(before));const mutant=eval('('+captureSource.replace(before,after)+')');assert.throws(()=>validate(mutant),label);checks++;rejectedMutations.push(label);}
 check(source.includes('async function shot(name){persist();await sampleBattleObjects(name);'),'Only screenshot path requests explicit scene traversal');
 const report={result:'PASS',checks,rejectedMutations,toolSha256:crypto.createHash('sha256').update(source).digest('hex'),
  inputs:Object.fromEntries(['check-story-natural-web.cjs','check-story-natural-object-samples.cjs'].map(name=>['tools/migration/'+name,crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,name))).digest('hex')])),
  boundary:'CPU execution of actual capture/request functions with CDP and console-delivery adapters, including compact-overwrite race, missing observation, runtime error and unsupported API. No GPU/browser rerun, native scene count, mission completion or performance acceptance.'};
 fs.writeFileSync(path.join(__dirname,'../../docs/migration/evidence/story-natural-object-samples-offline.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});

// Keep call wall times, sampled CPU stacks and raw browser frames separate.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const directory=path.resolve(process.argv[2]||'');
if(!process.argv[2])throw Error('Pass a completed G0 profile directory');
const read=name=>JSON.parse(fs.readFileSync(path.join(directory,name),'utf8'));
const profile=read('summary.json'),gl=read('webgl.json'),identity=read('identity.json');
function waitStacks(file){
 const cpu=read(file),nodes=new Map(cpu.nodes.map(n=>[n.id,n])),parents=new Map(),totals=new Map();
 for(const node of cpu.nodes)for(const child of node.children||[])parents.set(child,node.id);
 for(let i=0;i<(cpu.samples||[]).length;i++)totals.set(cpu.samples[i],(totals.get(cpu.samples[i])||0)+cpu.timeDeltas[i]);
 return [...totals].filter(([id])=>nodes.get(id).callFrame.functionName==='_emscripten_get_now')
  .sort((a,b)=>b[1]-a[1]).slice(0,8).map(([id,us])=>{
   const frames=[];for(let current=id;current&&frames.length<20;current=parents.get(current))frames.push(nodes.get(current).callFrame.functionName);
   return {sampledSelfMs:us/1000,frames};
  });
}
const result={sourceCommit:identity.identity.sourceCommit,manifest:identity.servedManifest,
 qa:{loadProfile:identity.loadProfile===true,renderExperiment:identity.renderExperiment===true,warmExperiment:identity.warmExperiment===true,warmIntroExperiment:identity.warmIntroExperiment===true,probeSha256:identity.probeSha256||null},
 viewport:{width:1920,height:1080,dpr:1},instrumented:true,
 bootMs:profile.bootMs,craterMs:profile.craterMs,
 longestFrames:profile.frames.toSorted((a,b)=>b.ms-a.ms).slice(0,10),methods:gl.methods,
 longestTasks:gl.longTasks.toSorted((a,b)=>b.ms-a.ms).slice(0,10).map(task=>({...task,
  recordedSlowCallsMs:gl.slow.filter(call=>call.at>=task.at&&call.at+call.ms<=task.at+task.ms+2)
   .reduce((out,call)=>(out[call.method]=(out[call.method]||0)+call.ms,out),{})})),
 phaseTasks:Object.fromEntries(['boot','crater'].map(phase=>[phase,gl.longTasks.filter(t=>t.phase===phase).toSorted((a,b)=>b.ms-a.ms).slice(0,10)])),
 slowestCalls:gl.slow.toSorted((a,b)=>b.ms-a.ms).slice(0,20).map(call=>({...call,
  shaderHashes:(gl.programs[call.program]||[call.shader]).filter(Boolean).map(id=>{
   const shader=gl.shaders.find(s=>s.id===id);return {id,sha256:shader&&crypto.createHash('sha256').update(shader.source).digest('hex')};
  })})),
 bootWaitStacks:waitStacks('boot.cpuprofile'),craterWaitStacks:waitStacks('crater.cpuprofile'),
 limitations:[gl.limitation,'Slow-call overlap only includes calls >=20ms; it is not the complete GL time of a task.',
  'WASM function indexes are tied to this fixed runtime. No native symbols means no proven mutex owner.',
  'Single instrumented Windows Chrome sample; shader/OS caches may be warm. No target-phone or controlled before/after acceptance.']};
fs.writeFileSync(path.join(directory,'attribution.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify({manifest:result.manifest,bootMs:result.bootMs,craterMs:result.craterMs,
 longestFrameMs:result.longestFrames[0]?.ms,longestTask:result.longestTasks[0],slowestCall:result.slowestCalls[0]}));

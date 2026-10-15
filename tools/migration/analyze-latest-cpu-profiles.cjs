// Offline sampling attribution. Never interprets stripped WASM indexes as symbols.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const current=path.resolve(root,process.argv[2]||'docs/migration/verification/2026-10-15');
const reference=path.resolve(root,process.argv[3]||'docs/migration/evidence/combat-performance-2026-10-15T13-56-49-208Z');
const output=process.argv[4]&&path.resolve(root,process.argv[4]);
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const round=n=>Math.round(n*1000)/1000;
const ranking=map=>[...map].sort((a,b)=>b[1]-a[1]).map(([name,us])=>({name,sampledMs:round(us/1000)}));
const add=(map,key,n)=>map.set(key,(map.get(key)||0)+n);
const statusName=n=>/^(?:_emscripten_glGet(?:Program|Shader)iv|getProgramParameter|getShaderParameter)$/.test(n);
function summarize(file){
 const raw=fs.readFileSync(file),p=JSON.parse(raw),nodes=new Map(p.nodes.map(n=>[n.id,n])),parents=new Map();
 for(const n of p.nodes)for(const id of n.children||[])parents.set(id,n.id);
 if(p.samples.length!==p.timeDeltas.length)throw Error('Mismatched samples/deltas: '+file);
 const self=new Map(),inclusive=new Map(),classes=new Map(),timerStacks=new Map(),statusStacks=new Map();
 let total=0,maxDelta=0;
 const stack=id=>{const out=[];for(let n=id;n!==undefined;n=parents.get(n))out.push(nodes.get(n).callFrame.functionName||'(anonymous)');return out;};
 for(let i=0;i<p.samples.length;i++){
  const us=p.timeDeltas[i],names=stack(p.samples[i]),leaf=names[0];total+=us;maxDelta=Math.max(maxDelta,us);
  add(self,leaf,us);for(const name of new Set(names))add(inclusive,name,us);
  let group;
  if(leaf==='(idle)')group='idle';else if(leaf==='(garbage collector)')group='js-gc';
  else if(names.some(statusName))group='shader-status-subtree';
  else if(leaf==='_emscripten_get_now'||leaf==='now')group='clock-read-self';
  else if(names.includes('xhr.onload'))group='xhr-callback-subtree-other';
  else if(leaf.startsWith('wasm-function['))group='wasm-self-other';
  else group='js-or-browser-self-other';
  add(classes,group,us);
  if(leaf==='_emscripten_get_now'||leaf==='now')add(timerStacks,names.slice(0,24).join(' > '),us);
  if(names.some(statusName))add(statusStacks,names.slice(0,18).join(' > '),us);
 }
 const result={file:path.relative(root,file).replaceAll('\\','/'),sha256:sha(raw),durationMs:round((p.endTime-p.startTime)/1000),sampledMs:round(total/1000),sampleCount:p.samples.length,maxSampleDeltaMs:round(maxDelta/1000),
  classes:ranking(classes).map(s=>({...s,percent:round(s.sampledMs/(total/1000)*100)})),topSelf:ranking(self).slice(0,30),
  topNamedJsSelf:ranking(new Map([...self].filter(([n])=>!n.startsWith('wasm-function[')))).slice(0,25),
  clockReadStacks:ranking(timerStacks).slice(0,12),shaderStatusStacks:ranking(statusStacks).slice(0,8),
  selectedInclusive:['wasm-function[9978]','wasm-function[3264]','wasm-function[14591]','wasm-function[15564]','wasm-function[10071]','_emscripten_get_now','xhr.onload'].map(name=>({name,sampledMs:round((inclusive.get(name)||0)/1000)}))};
 if(sha(fs.readFileSync(file))!==result.sha256)throw Error('Input changed during analysis: '+file);
 return result;
}
function frames(values){const a=values.map(x=>x.ms).sort((a,b)=>a-b),q=p=>a[Math.floor((a.length-1)*p)];return{count:a.length,p50Ms:round(q(.5)),p95Ms:round(q(.95)),maxMs:round(a.at(-1)),above100:a.filter(x=>x>100).length};}
function suite(directory){
 const reportFile=path.join(directory,fs.existsSync(path.join(directory,'combat-web-report.json'))?'combat-web-report.json':'report.json');
 const raw=fs.readFileSync(reportFile),r=JSON.parse(raw),phases=[...new Set(r.frames.map(f=>f.phase))];
 return{directory:path.relative(root,directory).replaceAll('\\','/'),manifest:r.identity.servedManifest,reportSha256:sha(raw),
  framePhases:Object.fromEntries(phases.map(p=>[p,frames(r.frames.filter(f=>f.phase===p))])),
  stages:r.stages.map(s=>({name:s.name,at:s.at,performance:s.state.performance})),
  glInstrumentation:{methods:Object.keys(r.gl||{}).length,slowCalls:r.slowGL.length},
  profiles:fs.readdirSync(directory).filter(f=>f.endsWith('.cpuprofile')).sort().map(f=>summarize(path.join(directory,f)))};
}
const result={generatedAt:new Date().toISOString(),current:suite(current),reference:suite(reference),
 limitations:[
  'CPU samples are weighted by recorded timeDeltas; they are not GPU timestamps or exact per-call timings.',
  'Clock-read samples identify an observed stack, not a proven lock owner, mutex or function name.',
  'Stripped WASM function indexes remain unnamed; identical index/offset comparisons require the same engine binary.',
  'Shader-status-subtree and XHR categories include descendants; class groups are mutually exclusive, inclusive rankings overlap.',
  'These reports contain zero direct GL instrumentation records; native program status call parameters and GPU work cannot be recovered.',
  'Builds differ and AI/game positions may differ; phase comparisons are descriptive, not a controlled optimization A/B or phone acceptance.'
 ]};
if(output){fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');}
console.log(JSON.stringify({output,currentManifest:result.current.manifest,referenceManifest:result.reference.manifest,
 current:result.current.profiles.map(p=>({file:path.basename(p.file),durationMs:p.durationMs,classes:p.classes,topSelf:p.topSelf.slice(0,4)})),
 reference:result.reference.profiles.map(p=>({file:path.basename(p.file),durationMs:p.durationMs,classes:p.classes}))},null,2));

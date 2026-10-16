// Historical log attribution only; no renderer coverage changes or GPU claims.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const input=path.resolve(root,process.argv[2]||'docs/migration/evidence/intro-dialog-web-2026-10-15T11-22-36-417Z/runtime.log');
const contents=fs.readFileSync(input,'utf8');
const phases=[],seenCompile=new Set(),seenLoaded=new Set();let current=null;
function timestamp(line){
 const m=line.match(/^\[(\d{4}-\d\d-\d\d) (\d\d)_(\d\d)_(\d\d)_(\d{3})\]\[(\d+)\]/);
 return m?{ms:Date.parse(`${m[1]}T${m[2]}:${m[3]}:${m[4]}.${m[5]}Z`),frame:Number(m[6]),text:`${m[2]}:${m[3]}:${m[4]}.${m[5]}`}:null;
}
for(const line of contents.split(/\r?\n/)){
 const at=timestamp(line);if(!at)continue;
 const phase=line.match(/\[IntroWarmup\] ([\w-]+) visible=(\d+) skipped=(\d+) reused=(\d+)/);
 const end=line.match(/\[IntroWarmup\] restored frames=(\d+) batches=(\d+)/);
 if(phase||end){
  if(current){current.end=at.text;current.elapsedMs=at.ms-current.startMs;current.frames=at.frame-current.startFrame;current.tailAfterLastCompileMs=current.lastCompileMs===null?current.elapsedMs:at.ms-current.lastCompileMs;}
  current=phase?{phase:phase[1],start:at.text,startMs:at.ms,startFrame:at.frame,visible:Number(phase[2]),skipped:Number(phase[3]),reused:Number(phase[4]),compiled:[],recompiled:[],loaded:[],reloaded:[],lastCompileMs:null}:null;
  if(current)phases.push(current);
 }
 const compile=line.match(/Succeed to compile shader \[([^\]]+)\],defines \[([^\]]*)\]/);
 if(compile){const key=compile[1]+'|'+compile[2];if(current){current.compiled.push({shader:path.basename(compile[1]),defines:compile[2],at:at.text});if(seenCompile.has(key))current.recompiled.push(key);current.lastCompileMs=at.ms;}seenCompile.add(key);}
 const loaded=line.match(/INFO: Loaded (vertex|pixel) shader (.+)$/);
 if(loaded){const key=loaded[1]+'|'+loaded[2];if(current){current.loaded.push(key);if(seenLoaded.has(key))current.reloaded.push(key);}seenLoaded.add(key);}
}
for(const phase of phases){phase.compileCount=phase.compiled.length;phase.loadCount=phase.loaded.length;delete phase.lastCompileMs;delete phase.startMs;delete phase.startFrame;}
const report={result:'MEASURED_HISTORICAL',input:path.relative(root,input).replaceAll('\\','/'),sha256:crypto.createHash('sha256').update(contents).digest('hex'),phases,
 boundary:'Log phase-to-phase wall time and exact compiler/load line identities only. Logged compile completion spacing includes renderer/driver work and cannot isolate compiler CPU time. Absence of new compile lines does not prove a pose is redundant: linking, instancing, shadows, draw submission and camera/animation coverage may differ. No production or GPU changes.'};
const out=path.join(root,'docs/migration/evidence/intro-warmup-historical-attribution.json');fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({result:report.result,phases:phases.map(({phase,elapsedMs,frames,compileCount,loadCount,recompiled,reloaded,tailAfterLastCompileMs})=>({phase,elapsedMs,frames,compileCount,loadCount,recompiled:recompiled.length,reloaded:reloaded.length,tailAfterLastCompileMs})),evidence:out},null,2));

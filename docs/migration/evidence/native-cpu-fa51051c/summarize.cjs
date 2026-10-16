const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=__dirname,files=process.argv.slice(2);
const stats=values=>{const sorted=values.toSorted((a,b)=>a-b),n=sorted.length;return {count:n,total:values.reduce((a,b)=>a+b,0),mean:values.reduce((a,b)=>a+b,0)/n,p50:sorted[Math.ceil(n*.5)-1],p95:sorted[Math.ceil(n*.95)-1],p99:sorted[Math.ceil(n*.99)-1],max:sorted.at(-1)};};
const result={runs:{},boundary:'Per fixed step synchronous Native graphicsheadless. Inclusive rows overlap; self excludes instrumented descendants only. Timers/wrappers perturb timings. os.clock not verified thread CPU. Allocation no-GC pass measures Lua KB net including profiler/report objects. No full-frame FPS or GPU/phone inference.'};
for(const file of files){
 const raw=fs.readFileSync(path.join(root,file)),data=JSON.parse(raw),frames=data.frames.filter(f=>f.phase==='combat'),alloc=data.frames.filter(f=>f.phase==='allocation-no-gc');
 const labels=[...new Set(frames.flatMap(f=>Object.keys(f.methods)))],methods={};
 for(const label of labels){const rows=frames.map(f=>f.methods[label]),active=rows.filter(Boolean),calls=active.reduce((s,r)=>s+r.calls,0);
  methods[label]={calls,wallMs:stats(rows.map(r=>r?.wallMs||0)),selfWallMs:stats(rows.map(r=>r?.selfWallMs||0)),clockMs:stats(rows.map(r=>r?.clockMs||0)),selfClockMs:stats(rows.map(r=>r?.selfClockMs||0)),activeWallMs:stats(active.map(r=>r.wallMs)),callsPerStep:calls/frames.length};
 }
 const state=f=>f.state;
 const run={result:data.result,mode:data.mode||'fine',file,sha256:crypto.createHash('sha256').update(raw).digest('hex'),warmupSteps:data.warmupSteps,measuredSteps:frames.length,simSeconds:frames.length/60,
  totalWallMs:stats(frames.map(f=>f.totalWallMs)),totalClockMs:stats(frames.map(f=>f.totalClockMs)),luaNetKiB:stats(frames.map(f=>f.luaNetKiB)),allocationNoGC:stats(alloc.map(f=>f.luaNetKiB)),
  metadata:{initial:data.initial,first:state(frames[0]),last:state(frames.at(-1)),aliveRange:[Math.min(...frames.map(f=>f.state.alive)),Math.max(...frames.map(f=>f.state.alive))],minParts:Math.min(...frames.map(f=>f.state.parts)),maxParts:Math.max(...frames.map(f=>f.state.parts)),peakProjectiles:Math.max(...frames.map(f=>f.state.projectiles)),peakParticles:Math.max(...frames.map(f=>f.state.particles))},
  methods,stages:data.stages,skipped:data.skipped,
  allocationMethods:Object.fromEntries([...new Set(alloc.flatMap(f=>Object.keys(f.methods)))].map(label=>[label,{inclusiveKiB:stats(alloc.map(f=>f.methods[label]?.allocationKiB||0)),selfKiB:stats(alloc.map(f=>f.methods[label]?.selfAllocationKiB||0))}])),
  topInclusive:labels.toSorted((a,b)=>methods[b].wallMs.total-methods[a].wallMs.total).slice(0,20),
  topExclusive:labels.toSorted((a,b)=>methods[b].selfWallMs.total-methods[a].selfWallMs.total).slice(0,20),
  longestSteps:frames.toSorted((a,b)=>b.totalWallMs-a.totalWallMs).slice(0,8).map(f=>({step:f.step,totalWallMs:f.totalWallMs,luaNetKiB:f.luaNetKiB,state:f.state,top:Object.entries(f.methods).toSorted((a,b)=>b[1].wallMs-a[1].wallMs).slice(0,8)})),
 };
 result.runs[file]=run;
 process.stdout.write(JSON.stringify({file,totalWallMs:run.totalWallMs,allocationNoGC:run.allocationNoGC,alive:run.metadata.aliveRange,shots:run.metadata.last.shots,damage:run.metadata.last.damage,top:run.topExclusive.slice(0,12).map(label=>({label,wall:methods[label].wallMs,selfWall:methods[label].selfWallMs,calls:methods[label].calls}))})+'\n');
}
fs.writeFileSync(path.join(root,'summary.json'),JSON.stringify(result,null,2)+'\n');

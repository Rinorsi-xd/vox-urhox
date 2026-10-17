'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const directory=process.argv[2]||'docs/migration/evidence/monitor-combat-4a3a-1017-a';
const load=name=>JSON.parse(fs.readFileSync(path.join(directory,name),'utf8'));
const hash=name=>crypto.createHash('sha256').update(fs.readFileSync(path.join(directory,name))).digest('hex');
const report=load('report.json'),capture=load('capture.json'),analysis=load('analysis.json');
assert.equal(report.status,'PASS');assert.equal(report.shutdown,'CLOSED');assert.equal(report.errors.length,0);assert.equal(report.httpErrors.length,0);
const n=capture.frameIds.length;assert.equal(capture.rows.length,n*9);
for(const key of ['wallMs','parts','shots','hits','damage','kills'])assert.equal(capture[key].length,n);
for(let i=1;i<n;i++)assert.equal(capture.frameIds[i],capture.frameIds[i-1]+1);
const full=Array.from({length:n-2},(_,i)=>i+1),times=full.map(i=>capture.wallMs[i+1]);
const sum=xs=>xs.reduce((a,b)=>a+b,0),quantile=(xs,p)=>xs.slice().sort((a,b)=>a-b)[Math.ceil(xs.length*p)-1];
const frameResult={fullFrames:full.length,partialExcluded:2,firstEngineFrame:capture.frameIds[1],lastEngineFrame:capture.frameIds[n-2],totalWallMs:sum(times),meanWallMs:sum(times)/times.length,fps:1000*times.length/sum(times),p50Ms:quantile(times,.5),p95Ms:quantile(times,.95),p99Ms:quantile(times,.99),maxMs:Math.max(...times),over80:times.filter(x=>x>80).length};
assert.equal(frameResult.fullFrames,analysis.fullFrames);assert.equal(frameResult.meanWallMs,analysis.meanWallMs);assert.equal(frameResult.p95Ms,analysis.p95WallMs);assert.equal(frameResult.over80,analysis.over80);
const delta=Object.fromEntries(['shots','hits','damage','kills'].map(k=>[k,capture.after.world[k]-capture.before.world[k]]));
assert.deepEqual(delta,analysis.delta);
const work={delta,playerDamage:capture.after.playerDamage-capture.before.playerDamage,partsBefore:sum(capture.before.roster.map(u=>u.parts)),minimumParts:Math.min(...capture.parts),vehicles:capture.before.roster.length,aiDrivers:capture.before.roster.filter(u=>u.driver).length};
assert.equal(work.partsBefore,analysis.partsBefore);assert.equal(work.minimumParts,analysis.minParts);
const production=fs.readFileSync(path.join(directory,'production-perf.jsonl'),'utf8').trim().split(/\r?\n/).map(JSON.parse);
const names=[],frames=new Map();let duplicateCompactFrames=0;
for(const record of production){
 if(record.stageNames)record.stageNames.forEach((name,i)=>{if(names[i])assert.equal(names[i],name);names[i]=name;});
 for(const sample of record.frameSamples||[]){
  const value=JSON.stringify(sample);if(frames.has(sample.frame)){assert.equal(frames.get(sample.frame).encoded,value);duplicateCompactFrames++;}
  else frames.set(sample.frame,{sample,encoded:value});
 }
}
// Finalize emits the previous pending monitor frame during the next real Update.
const offsets=new Map();let prefixPairs=0;
for(const line of fs.readFileSync(path.join(directory,'runtime.log'),'utf8').split(/\r?\n/)){
 const at=line.indexOf('VOX_PERF '),prefix=line.match(/^\[[^\]]+\]\[(\d+)\]/);if(at<0||!prefix)continue;
 const record=JSON.parse(line.slice(at+9));if(record.frame===undefined)continue;
 const offset=Number(prefix[1])-record.frame;offsets.set(offset,(offsets.get(offset)||0)+1);prefixPairs++;
}
assert.equal(offsets.size,1);const emissionOffset=[...offsets.keys()][0],engineOffset=emissionOffset-1;
const selected=full.map(i=>{const engineFrame=capture.frameIds[i],item=frames.get(engineFrame-engineOffset);assert(item,'Actual corresponding monitor frame missing');const f=item.sample;assert(Math.abs(capture.wallMs[i+1]-f.frameMs)<=1,'Integer clock alignment');return {engineFrame,...f};});
const stageNames=['main.Update','trial.Tick','combat.BeforeStep','vehicle.Step','legs.Step','legHitboxes.Update','weapons.Step','ai.Step','combatView.Update','playerView.Update','weaponView.Update','vehicleView.UpdateIdle','effects.Update','hud.Update','main.PostUpdate','UI.Render'];
const stages=stageNames.map(name=>{
 const id=names.indexOf(name)+1;if(!id)return {name,present:false};
 const rows=selected.map(f=>{for(let i=0;i<f.stageTimes.length;i+=5)if(f.stageTimes[i]===id)return f.stageTimes.slice(i+1,i+5);return null;});
 const present=rows.filter(Boolean),ms=rows.map(r=>r?r[0]:0),self=rows.map(r=>r?r[1]:0);
 return {name,present:true,framesWithCalls:present.length,denominatorFrames:selected.length,totalInclusiveMs:sum(ms),meanInclusiveMsPerFrame:sum(ms)/selected.length,p95InclusiveMs:quantile(ms,.95),maxInclusiveMs:Math.max(...ms),totalSelfMs:sum(self),meanSelfMsPerFrame:sum(self)/selected.length,totalCalls:sum(present.map(r=>r[2])),maxCallMs:Math.max(...present.map(r=>r[3]))};
});
const result={auditStatus:'PASS',runStatus:report.status,shutdown:report.shutdown,runtimeErrors:report.errors.length,httpErrors:report.httpErrors.length,parseWarnings:report.perfParseWarnings,hashes:Object.fromEntries(['report.json','capture.json','analysis.json','production-perf.jsonl','runtime.log'].map(name=>[name,hash(name)])),frames:frameResult,work,alignment:{prefixPairs,allEmissionOffsets:[...offsets],engineFrameEqualsMonitorFramePlus:engineOffset,matchedFrames:selected.length,exactDurationMatches:selected.filter((f,i)=>f.frameMs===times[i]).length,maxDurationDifferenceMs:Math.max(...selected.map((f,i)=>Math.abs(f.frameMs-times[i]))),duplicateCompactFrames},stages,scope:'Actual Web controlled setup, eight vehicles and seven AI, production monitoring enabled, three coarse diagnostic wrappers. Inclusive durations overlap; self times exclude only instrumented children. No CPU/GPU split, no matched before/after workload, no causal FPS gain or sustained TapTap Snapdragon 845 acceptance.'};
const output=path.join(directory,'independent-current-audit.json');assert(!fs.existsSync(output),'Never overwrite audit evidence');fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));

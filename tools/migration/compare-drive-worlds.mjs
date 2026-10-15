import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const source=JSON.parse(fs.readFileSync('.tmp/source-drive-worlds.json'));
const target=JSON.parse(fs.readFileSync('.tmp/native-drive-worlds.json'));
assert.equal(source.sourceCommit,target.sourceCommit);assert.equal(source.dt,target.dt);
const distance=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
const angle=x=>Math.atan2(Math.sin(x),Math.cos(x));
function metrics(run){
 const groups=Object.groupBy(run.samples,s=>s.phase),end=name=>groups[name].at(-1);
 const brake=groups.brake,firstStop=brake.findIndex(s=>s.speed<=0);
 const beforeBrake=end('coast'),stop=firstStop<0?null:brake[firstStop];
 let yaw=0,previous=end('turn-runup').yaw;
 for(const sample of groups.turn){yaw+=angle(sample.yaw-previous);previous=sample.yaw;}
 return {mass:run.mass,comX:run.com[0],comY:run.com[1],comZ:run.com[2],
  settleY:end('settle').p[1],accelerationEndSpeed:end('accelerate').speed,
  accelerationDistance:distance(end('settle').p,end('accelerate').p),
  coastEndSpeed:beforeBrake.speed,coastDistance:distance(end('accelerate').p,beforeBrake.p),
  brakeStopTime:stop?stop.frame*source.dt:null,brakeStopDistance:stop?distance(beforeBrake.p,stop.p):null,
  turnAngle:yaw,turnEndSpeed:end('turn').speed,
  turnDisplacement:distance(end('turn-runup').p,end('turn').p)};
}
const cases=source.cases.map((s,i)=>{
 const t=target.cases[i];assert.equal(s.name,t.name);assert.equal(s.runs.length,t.runs.length);
 const sm=s.runs.map(metrics),tm=t.runs.map(metrics),measurements={};
 for(const key of Object.keys(sm[0])){
  const a=sm.map(v=>v[key]),b=tm.map(v=>v[key]);
  const mean=values=>values.reduce((n,x)=>n+x,0)/values.length;
  if(a.includes(null)||b.includes(null)){measurements[key]={source:a,target:b,unavailable:true};continue;}
  measurements[key]={sourceMean:mean(a),sourceRange:[Math.min(...a),Math.max(...a)],
   targetMean:mean(b),targetRange:[Math.min(...b),Math.max(...b)],delta:mean(b)-mean(a)};
 }
 let sumSpeed=0,maxSpeed=0,sumPosition=0,maxPosition=0,count=0;
 for(let r=0;r<s.runs.length;r++){
  assert.equal(s.runs[r].samples.length,t.runs[r].samples.length);
  for(let j=0;j<s.runs[r].samples.length;j++){
   const a=s.runs[r].samples[j],b=t.runs[r].samples[j];assert.equal(a.phase,b.phase);assert.equal(a.frame,b.frame);
   const speed=Math.abs(a.speed-b.speed),position=distance(a.p,b.p);
   sumSpeed+=speed*speed;maxSpeed=Math.max(maxSpeed,speed);sumPosition+=position*position;maxPosition=Math.max(maxPosition,position);count++;
  }
 }
 return {name:s.name,measurements,trajectory:{samples:count,speedRMSE:Math.sqrt(sumSpeed/count),speedMaxDelta:maxSpeed,positionRMSE:Math.sqrt(sumPosition/count),positionMaxDelta:maxPosition}};
});
const stamp=new Date().toISOString().replaceAll(':','-').replaceAll('.','-');
const dir=path.resolve('docs/migration/evidence/drive-worlds-'+stamp);fs.mkdirSync(dir,{recursive:true});
for(const [name,value] of [['source',source],['target',target]])fs.writeFileSync(path.join(dir,name+'.json'),JSON.stringify(value));
const result={status:'MEASURED_NOT_ACCEPTED',sourceCommit:source.sourceCommit,sourceEngine:source.engine,targetEngine:target.engine,
 description:'Actual worlds, original blueprints, identical commands and floor; no handfeel threshold invented. Three source repetitions establish observed variation.',cases};
fs.writeFileSync(path.join(dir,'comparison.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify({evidence:dir,...result},null,2));

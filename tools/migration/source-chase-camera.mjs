import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const provenance={};
for(const name of ['shared/drive/chaseCam.js','shared/drive/speedFov.js','shared/drive/combatSpeed.js','shared/core/math.js','shared/combat/tuning.js']){
 const hash=createHash('sha256').update(fs.readFileSync(path.join(baseline.snapshot,name))).digest('hex');
 if(hash!==baseline.files[name]?.sha256)throw Error('Frozen input drift: '+name);
 provenance[name]=hash;
}
const {ChaseCam}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/drive/chaseCam.js')));
const {SpeedFov}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/drive/speedFov.js')));
const cases=[];
for(const radius of [2,8,12,27,42])for(const ground of [-40,0,50])for(const flight of [false,true])for(const obstacle of [null,.5,4,30]){
 let ray=null;
 const cam=new ChaseCam({onPose:()=>{},castRay:(origin,dir,span)=>{ray={origin:[...origin],dir,span};return obstacle;}});
 cam.minY=ground<0?-Infinity:.35;cam.flight=flight;const pos=[4,ground,8];cam.reset(pos,.7,radius);
 const resetPitch=cam.pitch;const samples=[];
 for(let i=0;i<12;i++){
  const dt=[1/60,1/120,1/30,.2][i%4],mouse=[(i%3-1)*45,(i%4-2)*80],delta=[100,-100,5000,-5000,0,50][i%6];
  cam.zoomBy(delta);cam.sens=i%3===0?.23:1;
  const eye=i===7?[8,ground+3,20]:null;cam.eye=eye;
  const car={pos:[pos[0]+i*.3,pos[1]+Math.sin(i)*2,pos[2]+i],yaw:.7,speed:8,firing:false};
  cam.update(dt,{controlling:true,consumeMouse:()=>mouse},car);
  samples.push({dt,mouse,delta,sens:cam.sens,car,eye,expected:{yaw:cam.yaw,pitch:cam.pitch,zoom:cam.zoom,
   target:cam.target.toArray(),position:cam.position.toArray(),forward:cam.forward,curDist:cam.curDist,ray:eye?null:ray}});
 }
 cases.push({radius,ground,flight,obstacle,pos,resetPitch,samples});
}
const fov=[];
for(const scenario of [{topSpeed:32,thrusterSpeed:40},{topSpeed:0,thrusterSpeed:0},{topSpeed:32,legMode:true,legSpeedLimit:12},
 {topSpeed:15,mechMode:true},{topSpeed:28,thrusterSpeed:12}]){
 const state=new SpeedFov();const samples=[];let current=48;
 for(let i=0;i<90;i++){
  const dt=[1/60,1/120,1/30,.1][i%4],lv={x:i<30?35:i<60?9:0,y:200,z:i<60?12:0};
  const vehicle={spec:{motion:scenario},legMode:scenario.legMode,mechMode:scenario.mechMode,
   telemetry:{legSpeedLimit:scenario.legSpeedLimit},body:{linvel:()=>lv}};
  const options={scope:i>=20&&i<40?12:null,rush:i>=40&&i<50?1:0,charge:i<10?.7:0,punch:i===70?4:0};
  const previous=current;current=state.step(vehicle,dt,48,current,options);
  samples.push({dt,lv,options,previous,expected:{current,speed:state.speed,peak:state.peak,scopeT:state.scopeT}});
 }
 fov.push({scenario,samples});
}
const output=path.join(root,'.tmp/source-chase-camera.json');
fs.writeFileSync(output,JSON.stringify({sourceCommit:baseline.commit,provenance,cases,fov}));
console.log(JSON.stringify({output,cameraSamples:cases.reduce((n,c)=>n+c.samples.length,0),fovSamples:fov.reduce((n,c)=>n+c.samples.length,0)}));

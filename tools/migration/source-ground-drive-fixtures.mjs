import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=baseline.snapshot;
const dependencies=['shared/drive/contactControl.js','shared/drive/suspension.js','shared/drive/thrusterControl.js','shared/parts/thrusterMount.js','shared/core/math.js',
 'shared/drive/chassisStability.js','shared/drive/terrain.js','shared/combat/tuning.js'];
const provenance={};
for(const name of dependencies){
 const sha256=createHash('sha256').update(fs.readFileSync(path.join(source,name))).digest('hex');
 if(sha256!==baseline.files[name]?.sha256)throw Error('Frozen source changed: '+name);
 provenance[name]=sha256;
}
const {stepContacts}=await import(pathToFileURL(path.join(source,'shared/drive/contactControl.js')));
const {stepStability,wantsStability}=await import(pathToFileURL(path.join(source,'shared/drive/chassisStability.js')));
const cases=[];
const commands=[{throttle:0,steer:0},{throttle:1,steer:1},{throttle:-1,steer:-1},{throttle:-.2,steer:.4},{throttle:1,steer:1,handbrake:true}];
const scenarios=[{}, {tracked:true}, {contacts:[true,false,true,false]}, {contacts:[false,false,false,false]},
 {noSteer:true}, {hoverMode:true,lift:true}, {legMode:true,wings:true}];
for(const scenario of scenarios)for(const speed of [-8,0,4,28])for(const command of commands){
 const contacts=scenario.contacts||[true,true,true,true],loads=[1300,700,1700,1100],lengths=[.03,.22,.3,.28];
 const frame={up:[0,1,0],fwd:[0,0,1],vel:[2,.1,speed],speed,q:{x:0,y:0,z:0,w:1}};
 const vehicle={mass:500,spec:{motion:{topSpeed:32,accelFactor:.7},thrusters:scenario.lift?[{dir:[0,1,0]}]:[],wings:scenario.wings?[{}]:[]},
  capabilities:{wheelShare:.8},tracked:!!scenario.tracked,hoverMode:!!scenario.hoverMode,legMode:!!scenario.legMode,
  com:[.1,.2,0],cgH:.7,supRear:1.4,supFront:1.5,halfTrack:1,inertiaY:900,rMin:3,nRear:2,
  steer:.1,aLong:0,aLat:0,vPrev:speed-.15};
 vehicle.wheels=[[-1,1],[1,1],[-1,-1],[1,-1]].map(([x,z],index)=>({index,partId:index+10,
  center:[x,0,z],steer:!scenario.noSteer&&index<2,rear:index>=2,rearFade:index>=2,
  steerAngle:.6,track:!!scenario.tracked,share:.25,rest:.3}));
 vehicle.steerWheels=vehicle.wheels.filter(w=>w.steer);vehicle.trackWheels=vehicle.wheels.filter(w=>w.track);
 const initial=structuredClone({...vehicle,contacts,loads,lengths,frame});delete initial.steerWheels;delete initial.trackWheels;
 let applied=[],actuators=vehicle.wheels.map(()=>({engine:0,brake:0,steering:0,side:1}));
 vehicle.body={angvel:()=>({x:.2,y:.3,z:-.1}),addForce:force=>applied.push({force}),
  addTorque:torque=>applied.push({torque}),addForceAtPoint:(force,point)=>applied.push({force,point})};
 vehicle.vc={wheelIsInContact:i=>contacts[i],wheelSuspensionForce:i=>loads[i],wheelSuspensionLength:i=>lengths[i],
  wheelHardPoint:i=>({x:vehicle.wheels[i].center[0],y:.2,z:vehicle.wheels[i].center[2]}),wheelContactNormal:()=>({x:0,y:1,z:0}),
  setWheelEngineForce:(i,v)=>actuators[i].engine=v,setWheelBrake:(i,v)=>actuators[i].brake=v,
  setWheelSteering:(i,v)=>actuators[i].steering=v,setWheelSideFrictionStiffness:(i,v)=>actuators[i].side=v,
  wheelEngineForce:i=>actuators[i].engine,wheelBrake:i=>actuators[i].brake};
 const samples=[];
 for(const dt of [1/60,1/120,1/30]){
  applied=[];const telemetry=stepContacts(vehicle,command,dt,frame);
  samples.push({dt,telemetry,actuators:structuredClone(actuators),applied,steer:vehicle.steer,aLong:vehicle.aLong,aLat:vehicle.aLat,
   contacts:vehicle.contactStates.map(w=>({...w,index:w.index+1}))});
 }
 cases.push({initial,command,samples});
}
const stability=[];
for(const roll of [0,.3,1.2,Math.PI])for(const contact of [0,2,4])for(const gap of [null,-.1,.5,1.4,6])for(const airT of [0,.46]){
 const q={x:0,y:0,z:Math.sin(roll/2),w:Math.cos(roll/2)},frame={q,up:[-Math.sin(roll),Math.cos(roll),0],vel:[2,6,4]};
 const normal={x:0,y:Math.cos(.2),z:Math.sin(.2)};
 const initial={mass:500,cgH:.7,halfTrack:1,com:[.1,.2,.3],airT,wheels:[{},{},{},{}],spec:{thrusters:[]},p:{x:2,y:3,z:4},av:{x:5,y:.5,z:2},frame};
 const applied=[];let angular,ray;
 const v={...initial,body:{translation:()=>initial.p,angvel:()=>initial.av,addForce:force=>applied.push(force),setAngvel:value=>angular=value},
  R:{Ray:class{constructor(origin,direction){this.origin=origin;this.direction=direction;}},QueryFilterFlags:{EXCLUDE_SENSORS:1}},
  world:{castRayAndGetNormal:r=>{ray=r;return gap===null?null:{timeOfImpact:gap+initial.cgH,normal};}}};
 const wanted=wantsStability(v);stepStability(v,1/60,frame,contact);
 stability.push({initial,contact,gap,normal,wanted,result:{applied,angular:angular||null,state:v.stability,ray}});
}
const output=process.argv[2]||path.join(root,'.tmp/source-ground-drive-fixtures.json');
fs.writeFileSync(output,JSON.stringify({sourceCommit:baseline.commit,provenance,cases,stability}));
console.log(JSON.stringify({output,cases:cases.length,samples:cases.length*3,stability:stability.length,sourceCommit:baseline.commit}));

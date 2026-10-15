import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=baseline.snapshot;
const load=p=>import(pathToFileURL(path.join(source,p)));
const {hoverForce}=await load('shared/drive/hoverControl.js');
const {stepHoverMotion}=await load('shared/drive/hoverMotion.js');
const {stepThrusters}=await load('shared/drive/thrusterControl.js');
const {PARTS}=await load('shared/parts/defs.js');
const {hoverInfo,HOVER_HEIGHT_SCALE}=await load('shared/parts/hoverMount.js');
const {Blueprint,partSockets}=await load('shared/build/blueprint.js');
const {IDENTITY}=await load('shared/core/rotations.js');
const {buildVehicleSpec}=await load('shared/drive/vehicleSpec.js');
const hoverSpecs=[];
for(let tier=1;tier<=5;tier++)for(let rot=0;rot<24;rot++){
 const type='hover'+tier,bp=new Blueprint(),pos=[0,12,0];
 bp.add({type,pos,rot});
 const socket=partSockets(type,pos,rot).find(s=>!bp.overlaps('core',s.cell.map((v,i)=>v+s.dir[i]),IDENTITY));
 if(!socket)throw Error('No external mounting socket: '+type+'/'+rot);
 bp.add({type:'core',pos:socket.cell.map((v,i)=>v+socket.dir[i]),rot:IDENTITY});
 const result=buildVehicleSpec(bp);
 if(!result.ok||result.hovers.length!==1)throw Error('Disconnected hover fixture: '+type+'/'+rot);
 const pick=(v,keys)=>Object.fromEntries(keys.map(k=>[k,v[k]]));
 const h=result.hovers[0],hull=result.hulls.find(b=>b.partId===h.partId);
 hoverSpecs.push({type,rot,data:bp.toJSON(),hover:pick(h,['partId','type','mount','pos','dir','load','height','radius','speed','works','emits']),
  hull:pick(hull,['partId','center','half','quat','mass'])});
}
const forces=[];
for(let tier=1;tier<=5;tier++)for(const ratio of [.2,1,1.5,2.05])for(const speed of [-4,0,3])for(const load of [.3,1,2.2])for(const scale of [.6,1,1.35]){
 const h=PARTS['hover'+tier],height=hoverInfo(h.id).height*HOVER_HEIGHT_SCALE,args={h:{height,load:h.load},d:ratio*height,speed,share:h.load*load,scale};
 forces.push({...args,result:hoverForce(args.h,args.d,speed,args.share,scale)});
}
const thrusters=[[-1,0,-1.5],[1,0,-1.5],[-1,0,1.5],[1,0,1.5]].map((pos,i)=>({partId:i+1,type:'thruster3',pos,dir:[0,1,0],thrust:1900,speedLimit:96/3.6}));
for(const [pos,dir] of [[[0,0,-2],[1,0,0]],[[0,0,2],[1,0,0]],[[0,0,-2],[-1,0,0]],[[0,0,2],[-1,0,0]],[[0,0,-2],[0,0,1]],[[0,0,2],[0,0,-1]]])thrusters.push({partId:thrusters.length+1,pos,dir,thrust:900,speedLimit:72/3.6});
const spec={ok:true,boxes:[{center:[0,0,0],half:[1,.25,2],mass:500}],hulls:[],wheels:[],hovers:[],legs:[],thrusters,bounds:{min:[-1,-.25,-2],max:[1,.25,2],radius:2.3},motion:{mass:500,load:0,L:1,topSpeed:0,thrusterSpeed:96/3.6,thrusters:thrusters.length,thrustScale:1,accelFactor:.3}};
const commands=[{}, {climb:1},{},{throttle:1},{steer:1},{strafe:1},{strafe:-1},{throttle:-1},{climb:-1},{cutLift:true}];
const cases=[];
for(const tilt of [0,.15])for(const support of [0,1800,6000])for(const altitude of [3,175,205]){
 const state={p:{x:2,y:altitude,z:4},q:{x:Math.sin(tilt/2),y:0,z:0,w:Math.cos(tilt/2)},lv:{x:2,y:-.3,z:4},av:{x:.1,y:.2,z:-.1}};
 const v={spec,com:[.15,.05,-.2],mass:500,inertiaY:830,flightTarget:null,liftTilt:0,landingTime:0,R:{Ray:class{},QueryFilterFlags:{EXCLUDE_SENSORS:'mock-exclude-sensors'}},world:{castRay:()=>null}};
 let applied=[];v.body={translation:()=>state.p,rotation:()=>state.q,linvel:()=>state.lv,angvel:()=>state.av,
 addForce:f=>applied.push({force:f}),addForceAtPoint:(f,p)=>applied.push({force:f,point:p})};
 const samples=[];
 for(const command of commands){
  applied=[];const telemetry=stepThrusters(v,command,1/60,0,support);
  samples.push({command,telemetry,outputs:Object.fromEntries(v.thrusterOutputs),directions:Object.fromEntries(v.thrusterDirections),applied,flightTarget:v.flightTarget,liftTilt:v.liftTilt});
 }
 cases.push({state,support,com:v.com,inertiaY:v.inertiaY,samples});
}
const files=['shared/drive/hoverControl.js','shared/drive/hoverMotion.js','shared/drive/thrusterControl.js','shared/drive/vehicleSpec.js','shared/parts/hoverMount.js','shared/parts/hoverData.js','shared/parts/defs.js','shared/build/blueprint.js'];
const provenance=Object.fromEntries(files.map(p=>[p,createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex')]));
for(const [name,sha256] of Object.entries(provenance))if(sha256!==baseline.files[name]?.sha256)throw Error('Frozen source changed: '+name);
const hoverMotion=[];
for(const ground of [0,.3,1])for(const hoverMode of [false,true])for(const vel of [[0,0,0],[4,.5,8],[-6,0,-12],[24,0,24]])for(const command of [{},{throttle:1},{throttle:1,strafe:1,steer:.5},{throttle:-.2,strafe:-.8,steer:-1}]){
 const initial={mass:500,inertiaY:830,hoverMode,spec:{hovers:[{works:true,load:600,partId:10},{works:false,load:900,partId:11}],motion:{topSpeed:32,accelFactor:.7}},
  capabilities:{totalLoad:600},frame:{fwd:[0,0,1],vel},ground,av:{x:.3,y:.4,z:-.2}};
 const applied=[];const v={...initial,hoverStates:new Map([[10,{G:ground}]]),body:{angvel:()=>initial.av,
  addForce:force=>applied.push({force}),addTorque:torque=>applied.push({torque})}};
 hoverMotion.push({initial,command,result:{telemetry:stepHoverMotion(v,command,initial.frame),applied}});
}
fs.writeFileSync(path.join(root,'tools/migration/source-air-drive-fixtures.json'),JSON.stringify({sourceCommit:baseline.commit,provenance,forces,spec,cases,hoverMotion,hoverSpecs}));
console.log(`Frozen air drive: ${forces.length} hover forces, ${cases.length*commands.length} actuator samples, ${hoverMotion.length} motion cases; existing native test blueprints unchanged`);

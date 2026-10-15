import fs from 'node:fs';import path from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));const source=path.resolve(baseline.snapshot);
const {MechLegController}=await import(pathToFileURL(path.join(source,'shared/drive/mechControl.js')));
const {MechHitboxes}=await import(pathToFileURL(path.join(source,'shared/drive/mechHitboxes.js')));
const ik=await import(pathToFileURL(path.join(source,'shared/parts/mechIK.js')));const {MECH_GLB}=await import(pathToFileURL(path.join(source,'shared/parts/mechData.js')));
const {PARTS}=await import(pathToFileURL(path.join(source,'shared/parts/defs.js')));const {CELL}=await import(pathToFileURL(path.join(source,'shared/config.js')));const {ROTATIONS,applyRot}=await import(pathToFileURL(path.join(source,'shared/core/rotations.js')));
const poses=[],timings=[];const body={rotation:()=>({x:0,y:0,z:0,w:1}),translation:()=>({x:0,y:10,z:0}),linvel:()=>({x:0,y:0,z:0}),angvel:()=>({x:0,y:0,z:0})};
for(const type of ['mech3','mech4','mech5']){
 const d=MECH_GLB[type];for(const target of [d.joints.toe,[0,d.joints.toe[1]*.85,2],[1,d.joints.toe[1],-3]])for(const pitch of [0,-.18,.22])for(const yaw of [0,.3,-.3]){
  const toe=.1;poses.push({type,target,pitch,toe,yaw,pose:ik.solveMechIK(type,target,pitch,toe,yaw),sink:ik.mechSinkCapacity(type),extend:ik.mechExtendCapacity(type)});
 }
 const c=Object.create(MechLegController.prototype);Object.assign(c,{standAvg:8.5,sinkCap:ik.mechSinkCapacity(type),extCap:ik.mechExtendCapacity(type),boosting:false,slopeF:0,list:[{},{}]});
 for(const speed of [0,3,15,30])for(const spin of [0,1,3])for(const slope of [0,.1,.35,.7])for(const lat of [0,.5,1]){c.slopeF=slope;timings.push({type,speed,spin,ratio:speed/30,slope,lat,out:c._timing(speed,spin,speed/30,lat)});}
}
const provenance={};for(const p of ['shared/drive/mechControl.js','shared/drive/mechHitboxes.js','shared/parts/mechIK.js','shared/parts/mechData.js']){
 const sha=createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex');if(baseline.files[p]?.sha256!==sha)throw Error('Source hash mismatch '+p);provenance[p]=sha;
}
const dynamics=[];const rot=ROTATIONS.findIndex((_,i)=>applyRot(i,[0,1,0])[1]<-.99&&applyRot(i,[0,0,1])[2]>.99);
for(const type of ['mech3','mech4','mech5'])for(const slope of [0,.3]){
 const d=MECH_GLB[type],def=PARTS[type];const legs=[-1,1].map((side,i)=>({partId:i+1,type,rot,works:true,origin:[side*2,0,0],pos:[side*2,0,0],mount:[side*2,.5*CELL,0],standHeight:d.standHeight*CELL,load:def.load,speed:def.speed/3.6,jumpHeight:def.jumpHeight,jet:def.jet}));
 const spec={mechLegs:legs,wheels:[],hovers:[],legs:[],thrusters:[],boxes:[],hulls:[],motion:{topSpeed:def.speed/3.6}};const mass=def.load*1.2;let vel={x:0,y:0,z:0},position={x:0,y:d.standHeight*CELL,z:0},spin={x:0,y:0,z:0},forces=[];
 const b={rotation:()=>({x:0,y:0,z:0,w:1}),translation:()=>position,linvel:()=>vel,angvel:()=>spin,velocityAtPoint:()=>vel};
 for(const method of ['addForce','addTorque','addForceAtPoint','applyTorqueImpulse'])b[method]=(...args)=>forces.push({method,args:args.filter(a=>typeof a==='object')});
 b.applyImpulse=(j)=>{forces.push({method:'applyImpulse',args:[j]});vel={x:vel.x+j.x/mass,y:vel.y+j.y/mass,z:vel.z+j.z/mass};};b.setAngvel=a=>{spin=a;forces.push({method:'setAngvel',args:[a]});};
 const world={castRayAndGetNormal:(ray,distance)=>{const denominator=ray.dir.y-slope*ray.dir.z;if(Math.abs(denominator)<1e-9)return null;const t=(slope*ray.origin.z-ray.origin.y)/denominator;if(t<0||t>distance)return null;const k=Math.sqrt(1+slope*slope);return {timeOfImpact:t,normal:{x:0,y:1/k,z:-slope/k}};}};
 class Ray{constructor(origin,dir){this.origin=origin;this.dir=dir;}}
 const c=new MechLegController({spec,mass,com:[0,0,0],inertiaY:mass*4,body:b,R:{Ray,QueryFilterFlags:{EXCLUDE_SENSORS:1}},world,capabilities:{totalLoad:2*def.load,mechShare:1},legMode:true});const frames=[];
 for(let frame=0;frame<240;frame++){
  const cmd={throttle:frame<20?0:1,steer:frame>=70&&frame<95?.4:0,strafe:frame>=150&&frame<180?.6:0,boost:frame>=100&&frame<150,jump:frame>=185&&frame<215};const speed=frame<20?0:frame<185?Math.min(def.speed/3.6,(frame-20)*.35):12;position={x:0,y:d.standHeight*CELL+slope*(frame/60*speed)+(frame>=190&&frame<225?d.standHeight*CELL*1.7:0),z:frame/60*speed};vel={x:0,y:frame>=190&&frame<210?3:0,z:speed};spin={x:0,y:cmd.steer,z:0};forces=[];
  const out=c.step(cmd,1/60);frames.push({cmd,position,velocity:{x:0,y:frame>=190&&frame<210?3:0,z:speed},spin:{x:0,y:cmd.steer,z:0},out,forces,phase:c.phase,jetFuel:c.jetFuel,boostFuel:c.boostFuel,states:c.list.map(s=>({target:s.target,lift:s.lift,foot:s.foot,pitch:s.pitch,toe:s.toe,yaw:s.yaw,grounded:s.grounded}))});
 }
 dynamics.push({type,slope,spec,mass,frames});
}
const hitboxes=[];
for(const row of poses){
 const leg={partId:101,type:row.type,rot,origin:[2,4,6]};const colliders=[];
 const world={createCollider:desc=>{const c={half:desc.half,setTranslationWrtParent:p=>c.center=[p.x,p.y,p.z],setRotationWrtParent:q=>c.quat=q};colliders.push(c);return c;}};
 const R={ColliderDesc:{cuboid:(...half)=>({half,setSensor(){return this;},setDensity(){return this;}})}};
 new MechHitboxes({spec:{mechLegs:[leg]},world,R,body:{},mechStates:new Map([[101,{}]]),mechControl:{pose:()=>row.pose}},c=>c.partId=101);
 hitboxes.push({leg,pose:row.pose,items:colliders});
}
fs.writeFileSync(path.join(root,'tools/migration/source-mech-control.json'),JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},provenance,poses,timings,dynamics,hitboxes}));console.log(JSON.stringify({poses:poses.length,timings:timings.length,dynamics:dynamics.length,hitboxes:hitboxes.length}));

import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';

const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=path.resolve(root,baseline.snapshot),provenance={};
for(const [name,entry] of Object.entries(baseline.files)){
 if(!/^shared\/(drive|build|parts|combat|core)\/.*\.js$/.test(name))continue;
 const hash=createHash('sha256').update(fs.readFileSync(path.join(source,name))).digest('hex');
 if(hash!==entry.sha256)throw Error('Frozen source changed: '+name);
 provenance[name]=hash;
}
const load=name=>import(pathToFileURL(path.join(source,name)));
const [{loadRapier},{Vehicle},{buildVehicleSpec},{Blueprint},prefabs,{SUPPORT_GROUPS}]=await Promise.all([
 load('shared/drive/physics.js'),load('shared/drive/vehicle.js'),load('shared/drive/vehicleSpec.js'),
 load('shared/build/blueprint.js'),load('shared/build/prefab.js'),load('shared/drive/terrain.js')]);
const R=await loadRapier(),dt=1/60,groundHalf=Number(process.env.VOX_DRIVE_GROUND_HALF||500);
const phases=[{name:'settle',frames:300,cmd:{throttle:0,steer:0}},
 {name:'accelerate',frames:360,cmd:{throttle:1,steer:0}},
 {name:'coast',frames:180,cmd:{throttle:0,steer:0}},
 {name:'brake',frames:120,cmd:{throttle:-1,steer:0}},
 {name:'turn-settle',reset:true,frames:300,cmd:{throttle:0,steer:0}},
 {name:'turn-runup',frames:180,cmd:{throttle:1,steer:0}},
 {name:'turn',frames:180,cmd:{throttle:1,steer:1}}];
const cases=[];
for(const [name,build] of [['raceCar',prefabs.buildRaceCar],['tianyuan',prefabs.buildDrillTank],['fuyuan',prefabs.buildFuyuanTank]]){
 const bp=new Blueprint();build(bp);const blueprint=bp.toJSON(),spec=buildVehicleSpec(bp),runs=[];
 for(let repeat=0;repeat<3;repeat++){
  const world=new R.World({x:0,y:-9.81,z:0});world.timestep=dt;
  // Ground top y=0; retain the chosen size in both reports for solver comparisons.
  world.createCollider(R.ColliderDesc.cuboid(groundHalf,1,groundHalf).setTranslation(0,-1,0).setFriction(.9).setRestitution(0).setCollisionGroups(SUPPORT_GROUPS));
  const v=new Vehicle(R,world,spec);v.place([0,0,0],0);const samples=[];
  for(const phase of phases){
   if(phase.reset)v.place([0,0,0],0);
   for(let frame=1;frame<=phase.frames;frame++){
    v.step(phase.cmd,dt);world.step();v.postStep();
    if(frame%6===0){const p=v.body.translation(),lv=v.body.linvel();samples.push({phase:phase.name,frame,p:[p.x,p.y,p.z],lv:[lv.x,lv.y,lv.z],yaw:v.yaw,speed:v.speed,contact:v.telemetry.contact,
     suspension:v.wheels.map((w,i)=>({length:v.vc.wheelSuspensionLength(i),force:v.vc.wheelSuspensionForce(i),contact:v.vc.wheelIsInContact(i)}))});}
   }
  }
  runs.push({mass:v.body.mass(),com:Object.values(v.body.localCom()),samples});v.dispose();world.free();
 }
 cases.push({name,blueprint,runs});
}
const report={sourceCommit:baseline.commit,sourceContentSha256:baseline.contentSha256,provenance,engine:'Rapier '+R.version(),dt,ground:{half:[groundHalf,1,groundHalf],center:[0,-1,0],friction:.9,restitution:0},phases,cases};
const output=path.resolve(process.argv[2]||'.tmp/source-drive-worlds.json');fs.writeFileSync(output,JSON.stringify(report));
console.log(JSON.stringify({output,cases:cases.length,repeats:3,samples:cases.reduce((n,c)=>n+c.runs.reduce((m,r)=>m+r.samples.length,0),0),engine:report.engine}));

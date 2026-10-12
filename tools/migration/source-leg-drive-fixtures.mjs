// Read-only source imports; all generated acceptance files stay in this project.
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const source='D:/Rino_Project/Vox',root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const load=p=>import(pathToFileURL(path.join(source,p)));
const {legCar}=await load('shared/drive/legFixture.js');
const {Blueprint}=await load('shared/build/blueprint.js');
const {legPlacement}=await load('shared/parts/legMount.js');
const {buildVehicleSpec}=await load('shared/drive/vehicleSpec.js');
const {Vehicle}=await load('shared/drive/vehicle.js');
const {loadRapier}=await load('shared/drive/physics.js');
const {TrackSim}=await load('shared/drive/trackSim.js');
const {buildTrackLayout}=await load('shared/drive/track.js');
const {LegHitboxes}=await load('shared/drive/legHitboxes.js');
const wave=new Blueprint();wave.name='十足 T5';
for(let z=-6;z<6;z++)wave.add({type:z===0?'core':'cube',pos:[0,4,z],color:0xe7e5df});
for(const side of [-1,1])for(let z=-5;z<5;z+=2)wave.add({type:'leg5',pos:[side,4,z],...legPlacement([side,0,0]),color:0xffc21a});
const blueprints={LegT3:legCar(3),LegT5:legCar(5),LegWaveT5:wave};
for(const [name,bp] of Object.entries(blueprints))fs.writeFileSync(path.join(root,`assets/Blueprints/${name}.json`),JSON.stringify(bp.toJSON()));
const R=await loadRapier(),cases=[],hitboxes=[],clone=x=>JSON.parse(JSON.stringify(x));
function sensorFixture(v,c,name,scenario){
 const items=[],mock={spec:v.spec,legStates:c.states,body:{},R:{ColliderDesc:{cuboid:(...half)=>({half,setSensor(){return this;},setDensity(){return this;}})}},
  world:{createCollider(desc){const item={half:desc.half};items.push(item);return {setTranslationWrtParent(p){item.center=p;},setRotationWrtParent(q){item.quat=q;}};}}};
 let index=0;new LegHitboxes(mock,(_,id)=>{items[index++].partId=id;});
 hitboxes.push(clone({name,scenario,spec:v.spec,states:c.list.map(s=>({id:s.leg.partId,target:s.target,bladeAngle:s.bladeAngle})),items}));
}
const scenarios={flat:{p:[0,0,-100],time:5,cmd:t=>({throttle:t>1?1:0})},
 wall:{p:[-66,0,-32],time:8,cmd:t=>({throttle:t>1?1:0})},
 jumpWall:{p:[-66,0,-32],time:8,cmd:t=>({throttle:t>1?1:0,jump:t>1.9&&t<2})},
 hill:{p:[-100,0,-41],time:9,cmd:t=>({throttle:t>1?1:0})},
 spin:{p:[0,0,-100],time:4,cmd:t=>({steer:t>1?1:0})},
 stop:{p:[0,0,-100],time:6,cmd:t=>({throttle:t>1&&t<3?1:0})}};
for(const [name,bp] of Object.entries(blueprints))for(const [scenario,sc] of Object.entries(scenarios)){
 if(name==='LegWaveT5'&&!['flat','spin'].includes(scenario))continue;
 const sim=new TrackSim(R,buildTrackLayout()),v=new Vehicle(R,sim.world,buildVehicleSpec(bp));v.place(sc.p,0);sim.world.step();
 const c=v.legControl,samples=[];let rays=[],forces=[],velocities=[],afterImpulse=null;
 const velocity=v.body.velocityAtPoint.bind(v.body);v.body.velocityAtPoint=p=>{const result=velocity(p);velocities.push(clone({p,result}));return result;};
 const cast=c.cast.bind(c);c.cast=(p,d,length)=>{const hit=cast(p,d,length);rays.push(clone({p,d,length,hit}));return hit;};
 for(const method of ['addForce','addForceAtPoint','addTorque','applyImpulse']){
  const original=v.body[method].bind(v.body);v.body[method]=(...args)=>{forces.push(clone({method,args:args.slice(0,method==='addForceAtPoint'?2:1)}));const result=original(...args);if(method==='applyImpulse')afterImpulse={lv:v.body.linvel(),av:v.body.angvel()};return result;};
 }
 const step=c.step.bind(c);c.step=(command,dt,support)=>{
  rays=[];forces=[];velocities=[];afterImpulse=null;
  const b=v.body,state={p:b.translation(),q:b.rotation(),lv:b.linvel(),av:b.angvel(),com:b.worldCom()};
  const telemetry=step(command,dt,support);
  if(samples.length%60===0)sensorFixture(v,c,name,scenario);
  samples.push(clone({command,support,state,rays,forces,velocities,afterImpulse,telemetry,phase:c.phase,cadence:c.cadence,
   states:c.list.map(s=>({id:s.leg.partId,foot:s.foot,previous:s.previous,target:s.target,bladeAngle:s.bladeAngle,grounded:s.grounded,mode:s.mode,force:s.force}))}));
  return telemetry;
 };
 for(let i=0;i<sc.time*60;i++){v.step({throttle:0,steer:0,...sc.cmd(i/60)},1/60);sim.step(1/60);}
 cases.push({name,scenario,spec:v.spec,mass:v.mass,com:v.com,inertiaY:v.inertiaY,capabilities:v.capabilities,legMode:v.legMode,samples});
 v.dispose();sim.world.free();
}
const files=['shared/drive/legControl.js','shared/drive/legGait.js','shared/drive/legHitboxes.js','shared/parts/legIK.js','shared/drive/legFixture.js'];
const provenance=Object.fromEntries(files.map(p=>[p,createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex')]));
fs.writeFileSync(path.join(root,'tools/migration/source-leg-drive-fixtures.json'),JSON.stringify({provenance,cases,hitboxes}));
console.log(`Leg drive: ${cases.length} source trajectories, ${cases.reduce((s,c)=>s+c.samples.length,0)} fixed steps; three source blueprints`);

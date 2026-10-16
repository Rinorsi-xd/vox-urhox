import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
const root=(process.argv[2]||'D:/Rino_Project/Vox').replace(/[/\\]$/,'')+'/';
const load=p=>import(pathToFileURL(root+p));
const {loadRapier}=await load('shared/drive/physics.js');
const {Vehicle}=await load('shared/drive/vehicle.js');
const {Blueprint}=await load('shared/build/blueprint.js');
const {buildVehicleSpec}=await load('shared/drive/vehicleSpec.js');
const prefabs={...await load('shared/build/planePrefab.js'),...await load('shared/build/prefab.js')};
const R=await loadRapier();
const native=JSON.parse(fs.readFileSync(process.argv[3]||'.tmp/flight-parity-20261016/native-result.json'));
const plain=v=>JSON.parse(JSON.stringify(v,(_,x)=>ArrayBuffer.isView(x)?Array.from(x):x));
const snap=v=>plain({p:v.body.translation(),q:v.body.rotation(),lv:v.body.linvel(),av:v.body.angvel(),wing:v.wingState,telemetry:v.telemetry});
const result={rows:[],scope:'Actual H5 Rapier Vehicle in empty world; same initial state and commands as Native. No rendering or contacts.'};
for(const row of native.rows){
 const world=new R.World({x:0,y:-9.81,z:0});world.timestep=1/60;
 const builder='build'+row.id[0].toUpperCase()+row.id.slice(1);
 const spec=buildVehicleSpec(prefabs[builder](new Blueprint()));
 const v=new Vehicle(R,world,spec);world.step();
 const out={id:row.id,spec:plain(spec),mass:v.body.mass(),com:plain(v.body.localCom()),impulse:[],segments:[]};
 for(const entry of row.impulse){
  v.place([0,80,0],entry.yaw);const e={yaw:entry.yaw,rotation:plain(v.body.rotation()),axes:[]};
  for(let axis=0;axis<3;axis++){
   v.body.setAngvel({x:0,y:0,z:0},true);const j={x:axis===0?1:0,y:axis===1?1:0,z:axis===2?1:0};
   v.body.applyTorqueImpulse(j,true);e.axes.push({sourceTorqueImpulse:j,sourceAngularVelocity:plain(v.body.angvel())});
  }out.impulse.push(e);
 }
 world.gravity={x:0,y:0,z:0};v.place([0,80,0],0);v.body.setTranslation(row.freeDamping.initial.p,true);v.body.setAngvel({x:1,y:0,z:0},true);
 out.freeDamping={initial:snap(v),samples:[]};
 for(let s=1;s<=120;s++){world.step();if([1,30,60,120].includes(s))out.freeDamping.samples.push({step:s,state:snap(v)});}
 world.gravity={x:0,y:-9.81,z:0};
 for(const entry of row.segments){
  v.place([0,80,0],0);v.wingState=null;v.body.setTranslation(entry.initial.p,true);v.body.setLinvel(entry.initial.lv,true);
  const e={name:entry.name,command:entry.command,initial:snap(v),samples:[]};
  for(let s=1;s<=120;s++){v.step(entry.commands?.[s-1]||entry.command,1/60);world.step();if(entry.samples.some(x=>x.step===s))e.samples.push({step:s,state:snap(v)});}
  out.segments.push(e);
 }result.rows.push(out);v.dispose();world.free();
}
fs.writeFileSync(process.argv[4]||'.tmp/flight-parity-20261016/source-result.json',JSON.stringify(result,null,2));
for(let i=0;i<result.rows.length;i++){
 const a=native.rows[i],b=result.rows[i];
 const brief=x=>({name:x.name,p:x.samples.at(-1).state.p,q:x.samples.at(-1).state.q,av:x.samples.at(-1).state.av});
 console.log(JSON.stringify({id:a.id,nativeCom:a.nativeComSource,sourceCom:b.com,nativeImpulse:a.impulse[0].axes.map(x=>x.sourceAngularVelocity),sourceImpulse:b.impulse[0].axes.map(x=>x.sourceAngularVelocity),nativeDamping:a.freeDamping.samples.map(x=>x.state.av),sourceDamping:b.freeDamping.samples.map(x=>x.state.av),nativeSegments:a.segments.map(brief),sourceSegments:b.segments.map(brief)}));
}

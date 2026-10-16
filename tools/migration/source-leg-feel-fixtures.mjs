// Execute the frozen source controller; writes only its temporary fixture.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const source=path.join(root,'.tmp/outgame-source-2026-10-15T12-35-57-243Z');
const load=p=>import(pathToFileURL(path.join(source,p)));
const {LegController}=await load('shared/drive/legControl.js');
const V=await load('shared/drive/legMath.js');
const raw=JSON.parse(fs.readFileSync(path.join(root,'tools/migration/source-leg-drive-fixtures.json'),'utf8'));
const base=raw.cases[0],copy=x=>structuredClone(x),cases=[],snapshots=[];
function create(spec,mass,capabilities,state){
 const forces=[],rays=[];
 const body={rotation:()=>state.q,translation:()=>state.p,linvel:()=>state.lv,angvel:()=>state.av,worldCom:()=>state.com,
  velocityAtPoint:p=>V.vec(V.add(V.arr(state.lv),V.cross(V.arr(state.av),V.sub(V.arr(p),V.arr(state.com)))))};
 for(const name of ['addForce','addForceAtPoint','addTorque','applyImpulse'])body[name]=(...args)=>forces.push({method:name,args:copy(args.slice(0,name==='addForceAtPoint'?2:1))});
 const vehicle={spec:copy(spec),mass,capabilities:copy(capabilities),com:copy(base.com),inertiaY:base.inertiaY,legMode:true,body};
 const ctrl=new LegController(vehicle);
 ctrl.cast=(p,d,distance)=>{
  const t=Math.abs(d[1])>1e-9?-p[1]/d[1]:Infinity;
  const hit=t>1e-7&&t<=distance?{distance:t,point:V.add(p,V.mul(d,t)),normal:[0,1,0],collider:1}:null;
  rays.push({p:copy(p),d:copy(d),length:distance,hit:copy(hit)});return hit;
 };
 return {ctrl,vehicle,forces,rays};
}
const commands=[{throttle:1},{throttle:-1},{strafe:1},{throttle:.5,strafe:.5},{throttle:0,strafe:0}];
const jets=[[],[{dir:[0,0,1]}],[{dir:[0,1,0]}],[{dir:[1,.7,0]}],[{dir:[1,.699999,0]}],[{dir:[0,-.7,1]}]];
for(const total of [undefined,0,base.capabilities.totalLoad,base.capabilities.totalLoad*3])for(const [ji,thrusters]of jets.entries())for(const [ci,command]of commands.entries())for(const speed of [0,30]){
 const spec=copy(base.spec);spec.thrusters=thrusters;
 const caps=copy(base.capabilities);if(total===undefined)delete caps.totalLoad;else caps.totalLoad=total;
 const state={q:{x:0,y:0,z:0,w:1},p:{x:0,y:0,z:-20},lv:{x:ci===2?speed:0,y:0,z:ci===1?-speed:speed},av:{x:0,y:.1,z:0},com:{x:base.com[0],y:base.com[1],z:-20+base.com[2]}};
 const actual=create(spec,base.mass,caps,state),frames=[];
 for(let frame=0;frame<3;frame++){
  actual.forces.length=0;actual.rays.length=0;
  const telemetry=actual.ctrl.step(command,1/60,0);
  frames.push(copy({telemetry,forces:actual.forces,rays:actual.rays,driveJets:actual.vehicle.driveJets??null,offGround:actual.ctrl.offGround,wallMemo:actual.ctrl.wallMemo,states:actual.ctrl.list.map(s=>({id:s.leg.partId,foot:s.foot,target:s.target,mode:s.mode,bladeAngle:s.bladeAngle}))}));
 }
 cases.push({name:`load-${total??'missing'}/jets-${ji}/cmd-${ci}/speed-${speed}`,spec,mass:base.mass,capabilities:caps,com:base.com,inertiaY:base.inertiaY,legMode:true,state,command,frames});
}
for(const memo of [null,{normal:[0,0,-1],ttl:.42}]){
 const a=create(base.spec,base.mass,base.capabilities,base.samples[0].state);
 a.ctrl.offGround=.12;a.ctrl.wallMemo=memo;const saved=a.ctrl.snapshot();
 const b=create(base.spec,base.mass,base.capabilities,base.samples[0].state);
 b.ctrl.offGround=.03;b.ctrl.wallMemo={normal:[1,0,0],ttl:.8};b.ctrl.restore(saved);
 snapshots.push(copy({saved,restored:{offGround:b.ctrl.offGround,wallMemo:b.ctrl.wallMemo}}));
}
const files=['shared/drive/legControl.js','shared/drive/legGait.js','shared/parts/legIK.js','shared/drive/legMath.js'];
const hashes=Object.fromEntries(files.map(p=>[p,createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex')]));
const output={sourceCommit:'b276064942ae09c0227ec28d4cfda1d5ff006455',source,hashes,cases,snapshots};
fs.writeFileSync(path.join(root,'.tmp/source-leg-feel-fixtures.json'),JSON.stringify(output));
console.log(JSON.stringify({cases:cases.length,frames:cases.reduce((n,c)=>n+c.frames.length,0),snapshots:snapshots.length,hashes}));

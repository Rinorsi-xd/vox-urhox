import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
assert.equal(baseline.commit,'b276064942ae09c0227ec28d4cfda1d5ff006455');
const files=['three/src/build/vehicleView.js','three/src/drive/carVisual.js','shared/build/rotor.js','shared/core/rotations.js','shared/parts/defs.js'];
const sourceHashes={};
for(const file of files){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,file));
 const hash=createHash('sha256').update(bytes).digest('hex');
 assert.equal(hash,baseline.files[file]?.sha256,'Frozen source '+file);sourceHashes[file]=hash;
}
const load=p=>import(pathToFileURL(path.join(baseline.snapshot,p)));
const THREE=await load('three/vendor/three/build/three.module.js');
const R=await load('shared/build/rotor.js');
const {ROTATIONS}=await load('shared/core/rotations.js');
const {PARTS}=await load('shared/parts/defs.js');
const viewCode=fs.readFileSync(path.join(baseline.snapshot,files[0]),'utf8');
const driveCode=fs.readFileSync(path.join(baseline.snapshot,files[1]),'utf8');
const method=(code,start,end)=>{const a=code.indexOf(start),b=code.indexOf(end,a);assert(a>=0&&b>a);return code.slice(a,b)};
const addPart=method(viewCode,'\taddPart( part, fx = null ) {','\n\t// 连接块的光壳');
const rotors=method(driveCode,'\t_rotors( a ) {','\n\t// 轮子（');
const context=vm.createContext({THREE,PARTS,ROTATIONS,rotorAimOffset:R.rotorAimOffset,
 buildVehiclePart:()=>{const root=new THREE.Group(),head=new THREE.Group();root.add(head);root.userData.head=head;return root},
 partArrowGeometry:()=>null,partMeshes:()=>[],isRigged:()=>false,
 toQuat:q=>new THREE.Quaternion(q.x,q.y,q.z,q.w),NO_SHADOW_SLOTS:new Set()});
vm.runInContext(`const _m=new THREE.Matrix4(),_m2=new THREE.Matrix4(),_qa=new THREE.Quaternion(),_p=new THREE.Vector3(),_s=new THREE.Vector3(1,1,1),ONE=_s;
 ${method(viewCode,'export function partMatrix(','\n// 用于缩略图').replace('export ','')}
 class Source {${addPart}\n${rotors}};globalThis.Source=Source;`,context);
const points=[[0,0,0],[1,0,0],[0,1,0],[0,0,1],[.3,.2,-.8]];
const snapshot=head=>points.map(p=>new THREE.Vector3(...p).applyMatrix4(head.matrix).toArray());
const cases=[];
for(const type of ['rotor','rotorSpin','rotorStep'])for(const x of [-4,0,4])for(let rot=0;rot<24;rot++){
 const part={id:17,type,pos:[x,3,1],rot,color:0x32aacc};
 const view=new context.Source();Object.assign(view,{root:new THREE.Group(),liveParts:new Map(),livery:{partsChanged(){}},objects:new Map(),rigs:new Map()});
 view.addPart(part);const head=view.objects.get(17).userData.head;
 const initial=snapshot(head),frame=R.rotorFrame(part);
 const rotor={partId:17,sign:frame.sign,prev:0,angle:0,parent:-1,pivot:frame.pivot.map(v=>v*.5),axis:frame.spin};
 view.subs=[{r:rotor,disc:head,pivot:new THREE.Vector3(...frame.pivot),axis:new THREE.Vector3(...frame.spin),view:{root:new THREE.Group()}}];
 view.vehicle={rotors:[rotor]};
 const frames=[];
 for(const [prev,angle,alpha] of [[0,.8,0],[0,.8,.5],[0,.8,1],[.8,-1.2,.37],[-1.2,Math.PI,1],[Math.PI,6.2,.25]]){
  rotor.prev=prev;rotor.angle=angle;view._rotors(alpha);frames.push({prev,angle,alpha,points:snapshot(head)});
 }
 cases.push({part,initial,frames});
}
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},sourceHashes,points,cases}));

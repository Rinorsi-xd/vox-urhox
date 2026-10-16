import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import path from 'node:path';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const relative='three/src/battle/storyBoss.js',bytes=fs.readFileSync(path.join(baseline.snapshot,relative));
const sha256=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha256!==baseline.files[relative].sha256)throw Error('Frozen boss source drift');
const THREE=await import(pathToFileURL(path.join(baseline.snapshot,'three/vendor/three/build/three.module.js')).href);
let random=0;
const math=Object.create(Math);math.random=()=>random;
const document={createElement:()=>({getContext:()=>({createRadialGradient:()=>({addColorStop(){}}),fillRect(){}})})};
const context=vm.createContext({THREE,Math:math,document,radio(){}});
vm.runInContext(bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.BOSS_KIND=BOSS_KIND;globalThis.podMesh=podMesh;globalThis.bomberMesh=bomberMesh;',context);
function run(test){
 const group=new THREE.Group(),from=[10,12,-20],boss={unit:{pos:[0,0,0]},group,update(){},cockpit:()=>from,openDir:()=>0,look(){},talk(){},snap(){},cine(){}};
 const flow={stage:'ending',t:6,open:0};
 const m={boss,bossFlow:flow,drive:{},fx:{explode(){}},hud:{talking:false},ground:()=>0,view:{addTruck:()=>({})}};
 const frames=[];
 for(const op of test.ops){
  random=op.random;m.hud.talking=op.talking;
  context.BOSS_KIND.update(m,{lines:{}},op.dt);
  const pod=flow.pod;const visible=!!pod&&group.children.includes(pod.mesh);
  const frame={pod:pod?{t:pod.t,from:pod.from}:null,truck:!!flow.truck,visible};
  if(visible){
   pod.mesh.updateMatrixWorld(true);
   frame.position=pod.mesh.position.toArray();frame.quaternion=pod.mesh.quaternion.toArray();
   frame.flamePosition=pod.mesh.userData.flame.getWorldPosition(new THREE.Vector3()).toArray();
   frame.flameSize=pod.mesh.userData.flame.getWorldScale(new THREE.Vector3()).x;
  }
  frames.push(frame);
 }
 return frames;
}
const cases=[];
for(const sample of [0,.25,.5,.999999]){
 const ops=[{dt:0,random:sample,talking:false}];
 for(let i=0;i<480;i++)ops.push({dt:1/60,random:sample,talking:true});
 ops.push({dt:1/60,random:sample,talking:false});
 const test={name:`full-flight-${sample}`,ops};cases.push({test,expected:run(test)});
}
const test={name:'variable-timestep-and-flame',ops:[{dt:0,random:0,talking:false},
 ...[.001,.016,.033,.1,.5,1,2,3].map((dt,i)=>({dt,random:i/8,talking:true})),{dt:.016,random:.9,talking:false}]};
cases.push({test,expected:run(test)});
const controls=[];
for(const rig of ['bomber','pod'])for(const scale of [.5,1,2])for(const childScale of [1,.75,1.25]){
 const mesh=rig==='bomber'?context.bomberMesh():context.podMesh();mesh.position.set(12,-2,34);mesh.rotation.set(.3,-.8,.5);mesh.scale.multiplyScalar(scale);
 const flames=mesh.children.filter(n=>n.isSprite);for(const f of flames)f.scale.multiplyScalar(childScale);mesh.updateMatrixWorld(true);
 controls.push({test:{rig,scale,childScale},expected:flames.map(f=>({position:f.getWorldPosition(new THREE.Vector3()).toArray(),size:f.getWorldScale(new THREE.Vector3()).x}))});
}
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,path:relative,sha256},cases,controls}));

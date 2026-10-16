import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';

const root=process.cwd();
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const source=baseline.snapshot;
const files=['three/src/parts/wingFx.js','three/src/drive/carVisual.js','shared/parts/wingData.js','shared/core/rotations.js'];
const hashes={};
for(const file of files){
  const sha=createHash('sha256').update(fs.readFileSync(path.join(source,file))).digest('hex');
  if(sha!==baseline.files[file]?.sha256)throw Error('Frozen source drift: '+file);
  hashes[file]=sha;
}
const THREE=await import(pathToFileURL(path.join(source,'three/vendor/three/build/three.module.js')));
const {WING_GLB}=await import(pathToFileURL(path.join(source,'shared/parts/wingData.js')));
const {applyRot}=await import(pathToFileURL(path.join(source,'shared/core/rotations.js')));
const randomMath=Object.create(Math);randomMath.random=()=>.37;
const context=vm.createContext({THREE,Math:randomMath});
for(const [file,name] of [['three/src/parts/wingFx.js','WingRig'],['three/src/drive/carVisual.js','CarVisual']]){
  const code=fs.readFileSync(path.join(source,file),'utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'');
  vm.runInContext(code+`\nglobalThis.${name}=${name};`,context,{filename:file});
}
// This check covers articulation only. GPU trail construction/drawing stays in native/Web acceptance.
context.WingRig.prototype._makeTrail=()=>null;
const scenarios=[];
for(const [type,info] of Object.entries(WING_GLB))for(let rot=0;rot<24;rot++){
  const segs=JSON.parse(fs.readFileSync(`assets/Parts/Rigs/${type}.json`)).segments;
  if(JSON.stringify(info)!==JSON.stringify(segs.info))throw Error('Production wing metadata drift '+type);
  const nodes=new Map(),rootNode=new THREE.Group();
  for(const p of segs.parts){
    const g=new THREE.Group();g.position.fromArray(p.origin);nodes.set(p.name,{g,p,axis:new THREE.Vector3(...p.hinge).normalize()});
  }
  const glow={mat:{emissiveIntensity:2.8},base:2.8};
  const rig=new context.WingRig(rootNode,info,nodes,[glow]);
  const wing={partId:17,kind:info.kind,n:applyRot(rot,[1,0,0])};
  const object={userData:{wingRig:rig}};
  const car={vehicle:{spec:{wings:[wing]}},turretObjs:[],view:{update(){}},subs:[],
    _objects:function*(){yield[17,object];},_wheels(){},_tracks(){},_rotors(){},_turrets(){},_hullWear(){}};
  const frames=[];
  for(const phase of [null,'parked','taxi','takeoff','climb','cruise','boost','landing'])for(let step=0;step<8;step++){
    const dt=[1/60,1/120,1/30,.075][step%4];
    const surfaces=new Map(segs.parts.map((p,i)=>['17:'+p.name,Math.sin(i+step*.7)*.6]));surfaces.set('17:vanes',step%2?.75:-.75);
    const state=phase?{phase,airspeed:step*9,stallSpeed:15,brake:step<2?0:step<5?.7:1,throttle:1,airTime:0,controls:[.4,0,-.7],surfaces}:null;
    car.vehicle.wingState=state;
    context.CarVisual.prototype.update.call(car,0,1);
    rig.update(0,dt);
    frames.push({dt,state:state?{...state,surfaces:Object.fromEntries(surfaces)}:null,lifting:rig.state?.lifting??null,
      nodes:Object.fromEntries([...nodes].map(([name,n])=>[name,n.g.quaternion.toArray()])),
      glow:glow.mat.emissiveIntensity});
  }
  scenarios.push({type,rot,wing,segs,seed:rig.seed,frames});
}
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},sourceHashes:hashes,scenarios}));

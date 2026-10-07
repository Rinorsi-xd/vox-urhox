// Executes original Three.js ThrusterRig, without a DOM, GPU or source writes.
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {registerHooks} from 'node:module';
import {createHash} from 'node:crypto';
const source='D:/Rino_Project/Vox',root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const url=p=>pathToFileURL(path.join(source,p)).href;
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?url('three/vendor/three/build/three.module.js'):specifier,context);}});
const T=await import(url('three/vendor/three/build/three.module.js'));
const {ThrusterRig}=await import(url('three/src/parts/thrusterFx.js'));
const {THRUSTER_GLB}=await import(url('shared/parts/thrusterData.js'));
const cases=[];
for(const [type,info] of Object.entries(THRUSTER_GLB)){
 const root=new T.Group(),gimbal=new T.Group(),housing=new T.Group();root.add(gimbal);gimbal.add(housing);
 const glow={emissiveIntensity:0,dispose(){}};const rig=new ThrusterRig(root,info,[],[glow],gimbal,housing);
 const steps=[];let time=0;
 for(const [target,frames] of [[0,3],[1,35],[.25,12],[0,30],[.8,10],[0,40]])for(let i=0;i<frames;i++){
  const dt=[1/60,1/30,.01][i%3];time+=dt;rig.setOutput(target);rig.update(time,dt);
  steps.push({target,dt,time,power:rig.power,emission:glow.emissiveIntensity,jets:rig.jets.map(j=>({length:j.mat.uniforms.uLength.value,radius:j.mat.uniforms.uRadius.value,power:j.mat.uniforms.uPower.value}))});
 }
 cases.push({type,info,seed:rig.seed,steps});rig.dispose();
}
const provenance=['three/src/parts/thrusterFx.js','three/src/parts/hoverFx.js','shared/parts/thrusterData.js'].map(p=>({path:p,sha256:createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex')}));
fs.writeFileSync(path.join(root,'tools/migration/source-equipment-fixtures.json'),JSON.stringify({provenance,cases}));
console.log(`${cases.length} original rigs, ${cases.reduce((n,c)=>n+c.steps.length,0)} source updates`);

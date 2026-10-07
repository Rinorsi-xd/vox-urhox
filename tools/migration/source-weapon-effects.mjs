// Execute original Three WeaponRig effects; no renderer needed for CPU geometry.
import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const source='D:/Rino_Project/Vox',root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const url=p=>pathToFileURL(path.join(source,p)).href;
registerHooks({resolve(s,c,n){return n(s==='three'?url('three/vendor/three/build/three.module.js'):s.startsWith('@shared/')?url('shared/'+s.slice(8)):s,c);}});
const T=await import(url('three/vendor/three/build/three.module.js'));
globalThis.window={innerHeight:720};
globalThis.document={createElement(){return {width:64,height:64,getContext(){return {createRadialGradient(){return {addColorStop(){}}},fillRect(){}}}}}};
const {WeaponRig}=await import(url('three/src/parts/weaponRig.js'));
Math.random=()=>.5;
const cases=[];
for(const type of ['laser4','laser5','mg4','mg5','sniper4','sniper5']){
 const data=JSON.parse(fs.readFileSync(path.join(root,`assets/Parts/Rigs/${type}.json`)));
 const obj=new T.Group(),head=new T.Group();obj.add(head);const parts={};
 for(const p of data.segments.parts||[]){const grp=new T.Group();head.add(grp);(parts[p.name]??=[]).push({...p,grp});}
 obj.userData={head,parts,dynMats:{}};const rig=new WeaponRig(obj,type),steps=[];
 for(let i=0;i<120;i++){
  const dt=1/60,time=i*dt;const state={load:(i%35)/34,charge:(i%60)/59,windup:i>=65&&i<100?.75:0,spinV:i<60?1:0,power:i>=40&&i<60?.12:1,offline:false};
  Object.assign(rig,state,{t:time});rig._updateAuras(time,dt);if(rig.motes)rig._updateMotes(dt);if(rig.arcs)rig._updateArcs(dt);
  steps.push({time,dt,state,bands:rig.bands?.map(b=>({p:b.m.position.toArray(),r:b.m.scale.x,alpha:b.m.material.uniforms.uAlpha.value})),
    motes:rig.motes?{pos:Array.from(rig.motePos),size:Array.from(rig.moteSize),alpha:Array.from(rig.moteAlpha)}:null,
    arcs:rig.arcList?structuredClone(rig.arcList):null});
 }
 cases.push({type,modelScale:rig.modelScale,rail:rig.rails?.r,steps});rig.dispose();
}
const file='three/src/parts/weaponRig.js';
fs.writeFileSync(path.join(root,'tools/migration/source-weapon-effects.json'),JSON.stringify({provenance:{path:file,sha256:createHash('sha256').update(fs.readFileSync(path.join(source,file))).digest('hex')},cases}));
console.log('6 original persistent rigs / 720 source states');

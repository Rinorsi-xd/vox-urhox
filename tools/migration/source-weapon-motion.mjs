// Read-only source execution. GPU-only effects are omitted from mechanical fixtures.
import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const source='D:/Rino_Project/Vox',root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const url=p=>pathToFileURL(path.join(source,p)).href;
registerHooks({resolve(s,c,n){return n(s==='three'?url('three/vendor/three/build/three.module.js'):s.startsWith('@shared/')?url('shared/'+s.slice(8)):s,c);}});
const T=await import(url('three/vendor/three/build/three.module.js'));
globalThis.document={createElement(){return {width:64,height:64,getContext(){return {createRadialGradient(){return {addColorStop(){}}},fillRect(){}}}}}};
const {WeaponRig}=await import(url('three/src/parts/weaponRig.js'));
const {sizeProfile}=await import(url('shared/parts/modelSizing.js'));
const {WEAPON_GLB}=await import(url('shared/parts/weaponData.js'));
const {materialFor}=await import(url('three/src/parts/materials.js'));
WeaponRig.prototype._initMotes=function(){};WeaponRig.prototype._initAuras=function(){};
WeaponRig.prototype._updateArcs=function(){};
const oldRandom=Math.random;Math.random=()=>.5;
const profiles={},cases=[];
for(const type of Object.keys(WEAPON_GLB)){
 const data=JSON.parse(fs.readFileSync(path.join(root,`assets/Parts/Rigs/${type}.json`)));
 const z0=Math.min(...data.whole.layers.map(layer=>{
  const b=fs.readFileSync(path.join(root,'assets',layer.model));return b.readFloatLE(b.length-12*layer.slots.length-24+8);
 }));
 profiles[type]={motionScale:sizeProfile(type)?.motionScale||[1,1,1],z0};
 const obj=new T.Group(),head=new T.Group();obj.add(head);const spin=data.segments.spin?new T.Group():null;if(spin)head.add(spin);
 const parts={},ordered=[];
 for(const p of data.segments.parts||[]){const grp=new T.Group();grp.matrixAutoUpdate=false;grp.matrix.makeTranslation(...p.origin);head.add(grp);const item={...p,grp};(parts[p.name]??=[]).push(item);ordered.push(item);}
 const dynMats={};for(const slot of ['heatGlow','chargeGlow','glowBlue','glowRed']){
  const material=materialFor(slot,0xffcc22).clone();material.userData.flow=Object.fromEntries(['uTime','uFreq','uAmp','uPower','uSweep','uSweepI'].map(k=>[k,{value:0}]));dynMats[slot]=material;
 }
 obj.userData={head,spin,parts,dynMats};const rig=new WeaponRig(obj,type);const steps=[];
 let time=0,shotAt=-9,barrel=0;
 for(let i=0;i<260;i++){
  const dt=[1/60,1/30,.01][i%3];time+=dt;const firing=i>=24&&i<100;const offline=i>=120&&i<175;
  if(firing&&i%9===0){shotAt=time;barrel=(barrel+1)%(data.weapon.muzzles?.length||1);}
  const state={charge:offline?.15:i<80?1:(i%35)/34,windup:i>=195&&i<225?(i-195)/30:0,spin:firing?Math.min(1,(i-24)/24):0,spinRate:firing?12:0,spinAngle:(time*3)%(Math.PI*2),shotAt,barrel};
  rig.setState(state,time,{offline});rig.update(time,dt);
  const matrices=ordered.map(p=>p.grp.matrix.toArray());
  const mats=Object.fromEntries(Object.entries(dynMats).map(([k,m])=>[k,{intensity:m.emissiveIntensity,color:m.emissive.toArray(),flow:Object.fromEntries(Object.entries(m.userData.flow).map(([k,v])=>[k,v.value]))}]));
  steps.push({time,dt,state:{...state,barrel:barrel+1},offline,recoil:rig.recoil,kick:rig.kick,power:rig.power,load:rig.load,flowPhase:rig.flowPhase,matrices,spin:spin?.matrix.toArray(),mats,emits:structuredClone(rig.emits)});
 }
 cases.push({type,steps});rig.dispose();
}
Math.random=oldRandom;
const imported=JSON.parse(fs.readFileSync(path.join(root,'assets/Parts/WeaponMotion.json')));
if(JSON.stringify(imported)!==JSON.stringify(profiles))throw Error('Weapon motion profiles are stale; run export-parts.cjs --apply. Validation never writes production assets.');
const provenance=['three/src/parts/weaponRig.js','three/src/parts/weaponFlow.js','shared/parts/sizeData.js'].map(p=>({path:p,sha256:createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex')}));
fs.writeFileSync(path.join(root,'tools/migration/source-weapon-motion.json'),JSON.stringify({provenance,cases}));
console.log(`${cases.length} source weapon rigs / ${cases.reduce((s,c)=>s+c.steps.length,0)} mechanical and material samples`);

// Read-only source execution. GPU-only effects are omitted from mechanical fixtures.
import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const source=path.resolve(JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))).snapshot);
const url=p=>pathToFileURL(path.join(source,p)).href;
registerHooks({resolve(s,c,n){return n(s==='three'?url('three/vendor/three/build/three.module.js'):s.startsWith('@shared/')?url('shared/'+s.slice(8)):s,c);}});
const T=await import(url('three/vendor/three/build/three.module.js'));
globalThis.document={createElement(){return {width:64,height:64,getContext(){return {createRadialGradient(){return {addColorStop(){}}},fillRect(){}}}}}};
const {WeaponRig}=await import(url('three/src/parts/weaponRig.js'));
const {sizeProfile}=await import(url('shared/parts/modelSizing.js'));
const {WEAPON_GLB}=await import(url('shared/parts/weaponData.js'));
const {registerWeaponGLB}=await import(url('shared/parts/weaponModels.js'));
const {getModelSegments}=await import(url('shared/parts/models.js'));
const {materialFor}=await import(url('three/src/parts/materials.js'));
WeaponRig.prototype._initMotes=function(){};WeaponRig.prototype._initAuras=function(){};
WeaponRig.prototype._updateArcs=function(){};
const oldRandom=Math.random;Math.random=()=>.5;
const profiles={},cases=[];
for(const type of Object.keys(WEAPON_GLB).filter(type=>/^(mg|laser|sniper|missile)\d+$/.test(type))){
 const data=JSON.parse(fs.readFileSync(path.join(root,`assets/Parts/Rigs/${type}.json`)));
 const glb=fs.readFileSync(path.join(source,'shared/assets/weapons',WEAPON_GLB[type].file));
 registerWeaponGLB(type,glb.buffer.slice(glb.byteOffset,glb.byteOffset+glb.byteLength));
 const segments=getModelSegments(type);
 const signature=p=>[p.name,p.idx,p.origin,p.axis||null,p.open||0];
 for(const key of ['parts','podParts'])if(JSON.stringify((data.segments[key]||[]).map(signature))!==JSON.stringify((segments[key]||[]).map(signature)))throw Error(`${type} imported ${key} differ from frozen GLB`);
 const z0=Math.min(...data.whole.layers.map(layer=>{
  const b=fs.readFileSync(path.join(root,'assets',layer.model));return b.readFloatLE(b.length-12*layer.slots.length-24+8);
 }));
 profiles[type]={motionScale:sizeProfile(type)?.motionScale||[1,1,1],z0};
 const obj=new T.Group(),head=new T.Group();obj.add(head);const spin=data.segments.spin?new T.Group():null;if(spin){spin.matrixAutoUpdate=false;head.add(spin);}
 const pod=segments.pod?new T.Group():null;if(pod)head.add(pod);
 const parts={},ordered=[];
 for(const [parent,list] of [[head,segments.parts],[pod,segments.podParts]])for(const p of list||[]){const grp=new T.Group();grp.matrixAutoUpdate=false;grp.matrix.makeTranslation(...p.origin);parent.add(grp);const item={...p,grp};(parts[p.name]??=[]).push(item);ordered.push(item);}
 const dynMats={};for(const slot of ['heatGlow','chargeGlow','glowBlue','glowRed']){
  const material=materialFor(slot,0xffcc22).clone();material.userData.flow=Object.fromEntries(['uTime','uFreq','uAmp','uPower','uSweep','uSweepI'].map(k=>[k,{value:0}]));dynMats[slot]=material;
 }
 obj.userData={head,pod,spin,parts,dynMats};const rig=new WeaponRig(obj,type);const steps=[];
 let time=0,shotAt=-9,barrel=0;
 for(let i=0;i<260;i++){
  // Avoid JSON rounding landing on the source's discontinuous refill u>0.6 branch.
  const dt=[1/61,1/31,.0103][i%3];time+=dt;const firing=i>=24&&i<100;const offline=i>=120&&i<175;
  if(firing&&i%9===0){shotAt=time;barrel=(barrel+1)%(data.weapon.muzzles?.length||1);}
  const state={charge:offline?.15:i<80?1:(i%35)/34,windup:i>=195&&i<225?(i-195)/30:0,spin:firing?Math.min(1,(i-24)/24):0,spinRate:firing?12:0,spinAngle:(time*3)%(Math.PI*2),shotAt,barrel,
   open:firing?Math.min(1,(i-24)/10):i<120?Math.max(0,1-(i-100)/15):0,lock:i<24?i/24:1,mphase:i<24?'ready':i<100?'fire':i<120?'reload':'close',reload:Math.min(1,(i-100)/20),readyAt:-9,
   tubes:Array.from({length:data.weapon.muzzles?.length||1},(_,j)=>!firing||j!==((barrel-1+(data.weapon.muzzles?.length||1))%(data.weapon.muzzles?.length||1)))};
  rig.setState(state,time,{offline});rig.update(time,dt);
  const yaw=Math.sin(time)*.7,pitch=Math.sin(time*.7)*.4;
  const turn=new T.Quaternion().setFromAxisAngle(new T.Vector3(0,1,0),yaw);
  const tilt=new T.Quaternion().setFromAxisAngle(new T.Vector3(1,0,0),-pitch-rig.kick);
  const at=(node,p,q,recoil)=>{node.matrixAutoUpdate=false;node.matrix.compose(new T.Vector3(...p),q,new T.Vector3(1,1,1)).multiply(new T.Matrix4().makeTranslation(-p[0],-p[1],-p[2]-recoil));};
  at(head,data.weapon.pivot,pod?turn:turn.clone().multiply(tilt),pod?0:rig.recoil);
  if(pod)at(pod,data.weapon.tilt,tilt,rig.recoil);
  obj.updateMatrixWorld(true);
  const matrices=ordered.map(p=>p.grp.matrix.toArray());
  const aimHead=new T.Group();at(aimHead,data.weapon.pivot,pod?turn:turn.clone().multiply(tilt),0);
  const aimPod=new T.Group();if(pod)at(aimPod,data.weapon.tilt,tilt,0);
  const aim=aimHead.matrix.clone();if(pod)aim.multiply(aimPod.matrix);
  const aimMuzzles=(data.weapon.muzzles||[data.weapon.muzzle]).map(p=>new T.Vector3(...p).applyMatrix4(aim).toArray());
  const mats=Object.fromEntries(Object.entries(dynMats).map(([k,m])=>[k,{intensity:m.emissiveIntensity,color:m.emissive.toArray(),flow:Object.fromEntries(Object.entries(m.userData.flow).map(([k,v])=>[k,v.value]))}]));
  steps.push({time,dt,yaw,pitch,aimMuzzles,head:head.matrix.toArray(),pod:pod?.matrix.toArray(),state:{...state,barrel:barrel+1},visible:ordered.map(p=>p.grp.visible),offline,recoil:rig.recoil,kick:rig.kick,power:rig.power,load:rig.load,flowPhase:rig.flowPhase,matrices,spin:spin?.matrix.toArray(),mats,emits:structuredClone(rig.emits)});
 }
 cases.push({type,petals:parts.petal?.length||0,rounds:parts.round?.length||0,partCount:ordered.length,steps});rig.dispose();
}
Math.random=oldRandom;
const imported=JSON.parse(fs.readFileSync(path.join(root,'assets/Parts/WeaponMotion.json')));
for(const [type,profile] of Object.entries(profiles))if(JSON.stringify(imported[type])!==JSON.stringify(profile))throw Error(`Weapon motion profile ${type} is stale; validation never writes production assets.`);
const provenance=['three/src/parts/weaponRig.js','three/src/parts/weaponFlow.js','shared/parts/sizeData.js'].map(p=>({path:p,sha256:createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex')}));
fs.writeFileSync(path.join(root,'tools/migration/source-weapon-motion.json'),JSON.stringify({provenance,cases}));
console.log(`${cases.length} source weapon rigs / ${cases.reduce((s,c)=>s+c.steps.length,0)} mechanical and material samples`);

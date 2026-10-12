// Original H5 terrain/sample and Chips are the oracle; never rewrite source files.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const source='D:/Rino_Project/Vox',root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const url=p=>pathToFileURL(path.join(source,p)).href;
registerHooks({resolve(s,c,n){return n(s==='three'?url('three/vendor/three/build/three.module.js'):s,c);}});
const python=process.argv[2];assert(python,'Pass Python with Pillow installed');
const manifest=JSON.parse(fs.readFileSync(path.join(source,'shared/assets/maps/crater/manifest.json')));
const bake=path.join(source,'shared/assets/maps/crater',manifest.ground.file);
const read=spawnSync(python,['-c','from PIL import Image; import sys,struct; i=Image.open(sys.argv[1]).convert("RGBA"); sys.stdout.buffer.write(struct.pack("<II",*i.size)+i.tobytes())',bake],{maxBuffer:128*1024*1024});
assert.equal(read.status,0,String(read.stderr));
const width=read.stdout.readUInt32LE(0),height=read.stdout.readUInt32LE(4),pixels=read.stdout.subarray(8);
globalThis.fetch=async()=>({blob:async()=>({})});
globalThis.createImageBitmap=async()=>({width,height});
globalThis.OffscreenCanvas=class {getContext(){return {drawImage(){},getImageData(){return {data:pixels}}};}};
globalThis.document={createElement(){return {width:64,height:64,getContext(){return {createRadialGradient(){return {addColorStop(){}}},fillRect(){}}}}}};
const T=await import(url('three/vendor/three/build/three.module.js'));
const {buildTerrain,gridHeight}=await import(url('three/src/terrain/terrainMesh.js'));
const {outpostHeight}=await import(url('shared/battle/outpost.js'));
const {groundAO}=await import(url('three/src/battle/mapModules.js'));
const {Effects}=await import(url('three/src/drive/effects.js'));
const ao=await groundAO({...manifest,base:''});
const quiet=(x,z)=>{const a=ao(x,z);return a<.93?1:a>.99?0:(.99-a)/.06;};
const terrain=buildTerrain({size:640,step:1,height:gridHeight(outpostHeight,{size:640,step:2}),quiet});
const sample=terrain.userData.sample,position=terrain.attributes.position;
const packed=fs.readFileSync(path.join(root,'assets/Crater/VisualHeight.bin'));
assert.equal(packed.length,20+position.count*4);
let maxGridError=0;
for(let i=0;i<position.count;i++)maxGridError=Math.max(maxGridError,Math.abs(position.getY(i)-packed.readFloatLE(20+i*4)));
assert.equal(maxGridError,0,'Every exported visual height must equal source geometry');
let seed=9137;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
const points=[];
for(const x of [-400,-320,-319.99,0,319.99,320,400])for(const z of [-400,-320,-.01,0,320,400])points.push({x,z,h:sample(x,z).h});
for(let i=0;i<1000;i++){const x=random()*640-320,z=random()*640-320;points.push({x,z,h:sample(x,z).h});}
const low=points.reduce((a,b)=>a.h<b.h?a:b),high=points.reduce((a,b)=>a.h>b.h?a:b);
const spots=[low,high,points[300],points[550],{x:320,z:-320},{x:-321,z:322}];
const trajectories=[];
Math.random=()=>.5;
for(const [index,p] of spots.entries()){
 const fx=new Effects(new T.Scene());fx.groundAt=(x,z)=>sample(x,z).h;
 const pos=[p.x,sample(p.x,p.z).h+.25,p.z],vel=[index%2?1.7:-2.1,-1.5,.8];
 fx.chips.emit(pos,vel,.18,0xffbb55,2);
 const states=[];
 for(let i=0;i<90;i++){
  const dt=i%3===0?.025:.01;fx.chips.update(dt);const c=fx.chips.list[0];
  states.push({dt,pos:c.p.toArray(),vel:c.v.toArray(),age:c.age,spin:c.spin});
 }
 trajectories.push({pos,vel,size:.18,color:0xffbb55,life:2,states});
}
const hashes={};for(const p of ['three/src/terrain/terrainMesh.js','three/src/battle/mapModules.js','shared/battle/outpost.js','three/src/drive/effects.js'])hashes[p]=createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex');
hashes['shared/assets/maps/crater/'+manifest.ground.file]=createHash('sha256').update(fs.readFileSync(bake)).digest('hex');
const data={source_hashes:hashes,grid_samples:position.count,max_grid_error:maxGridError,points,trajectories};
fs.writeFileSync(path.join(root,'tools/migration/source-crater-ground.json'),JSON.stringify(data));
console.log(JSON.stringify({grid_samples:position.count,max_grid_error:maxGridError,samples:points.length,trajectories:trajectories.length}));

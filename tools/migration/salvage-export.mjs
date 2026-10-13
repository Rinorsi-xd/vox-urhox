import * as T from 'three';
import {loadSalvageTerrain} from '/shared/salvage/terrainBake.js';
import {buildGameplay,WRECKS,CRATE_LOOT,regionRisk,REGION_HUNTERS} from '/shared/salvage/salvageGameplay.js';
import {buildSalvageWorld,makeGroundAt} from '/three/src/review/salvageTerrain/world.js';
import {Kit} from '/three/src/review/salvageTerrain/hsKit.js';
import {lootCrate} from '/three/src/review/salvageTerrain/scenery.js';
import {makeRand} from '/three/src/review/salvageTerrain/mechParts.js';
import {CONTAINERS,REVEAL_TIME,OPS} from '/shared/salvage/salvageLoot.js';
import {SCAVENGERS,scavenger} from '/shared/salvage/scavengers.js';

async function convert(name,geometry,matrix=new T.Matrix4(),material=0){
 const g=geometry.clone().applyMatrix4(matrix);if(!g.attributes.normal)g.computeVertexNormals();
 const p=Array.from(g.attributes.position.array),n=Array.from(g.attributes.normal.array),count=p.length/3;
 const payload={folder:'Salvage',name,material,shadow:true,p,n,uv:g.attributes.uv?Array.from(g.attributes.uv.array):Array(count*2).fill(0),c:Array(count*4).fill(1),idx:g.index?Array.from(g.index.array):Array.from({length:count},(_,i)=>i)};
 const r=await fetch('/convert',{method:'POST',body:JSON.stringify(payload)});g.dispose();if(!r.ok)throw Error(await r.text());return r.json();
}
export async function build(){
 const map=await loadSalvageTerrain(),ground=makeGroundAt(map),gameplay=buildGameplay(map,ground);
 const W=buildSalvageWorld(map,{terrainStep:2,gameplay,log:console.log});W.group.rotation.y=Math.PI;W.group.updateMatrixWorld(true);
 // Loot remains independently removable. Static wrecks follow the source's
 // scenery contract; only crate prototypes are taken out of static batches.
 W.loot.group.removeFromParent();
 const n=512,size=map.size,cell=size/n,heights=[];
 for(let x=0;x<=n;x++)for(let z=0;z<=n;z++)heights.push(ground(size/2-x*cell,-size/2+z*cell));
 return {group:W.group,lights:[],terrain:{size,cell:map.cell,res:map.V},salvage:async material=>{
  const terrain=[],colliders=[],lootModels=[];
  for(let x=0;x<n;x+=32)for(let z=0;z<n;z+=32){
   const p=[],idx=[];for(let i=0;i<=32;i++)for(let j=0;j<=32;j++)p.push(-size/2+(x+i)*cell,heights[(x+i)*(n+1)+z+j],-size/2+(z+j)*cell);
   for(let i=0;i<32;i++)for(let j=0;j<32;j++){const a=i*33+j,b=a+33,c=a+1,d=b+1;idx.push(a,c,d,a,d,b);}
   const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(p,3));g.setIndex(idx);
   terrain.push(await convert('collision-terrain-'+x+'-'+z,g));g.dispose();
  }
  const root=W.group.matrixWorld,p=new T.Vector3(),q=new T.Quaternion(),s=new T.Vector3();
  const hullBatches=new Map();
  for(const c of W.colliders()){
   const m=new T.Matrix4().multiplyMatrices(root,c.m);m.decompose(p,q,s);
   const data={type:c.t,pos:p.toArray(),quat:q.toArray()};
   if(c.t==='ball'){data.diameter=2*c.r;colliders.push(data);continue;}
   let g;
   if(c.t==='mesh'){g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(c.pos,3));}
   else if(c.t==='box')g=new T.BoxGeometry(...c.h.map(h=>h*2));
   else if(c.t==='cyl')g=new T.CylinderGeometry(c.r,c.r,c.hh*2,24);
   else throw Error('Unsupported collider '+c.t);
   g.applyMatrix4(m);const pos=g.attributes.position,index=g.index;
   const key=Math.floor(p.x/128)+':'+Math.floor(p.z/128);if(!hullBatches.has(key))hullBatches.set(key,[]);
   const list=hullBatches.get(key);for(let k=0;k<(index?.count||pos.count);k++){
    const j=index?index.getX(k):k;list.push(pos.getX(j),pos.getY(j),pos.getZ(j));
   }g.dispose();
  }
  for(const [key,p] of hullBatches){
   const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(p,3));
   colliders.push({type:'mesh',pos:[0,0,0],quat:[0,0,0,1],model:(await convert('collision-hulls-'+key.replace(':','-'),g)).model});g.dispose();
  }
  for(let tier=0;tier<4;tier++){
   const K=new Kit(W.M);K.collide=false;K.at([0,0,0],[0,0,0],()=>lootCrate(K,tier,makeRand(9)),1.3);
   const proto=K.build();proto.updateMatrixWorld(true);const list=[];
   for(const [i,m] of proto.children.entries())list.push(await convert('loot-'+tier+'-'+i,m.geometry,new T.Matrix4().multiplyMatrices(root,m.matrixWorld),material(m.material)));
   lootModels.push(list);
  }
  const enemies={};for(const id of Object.keys(SCAVENGERS))enemies[id]=Array.from({length:4},(_,i)=>scavenger(id,i+1));
  console.log('Salvage gameplay: loot='+gameplay.loot.length+' wrecks='+gameplay.wrecks.length+' encounters='+gameplay.encounters.length+' hulls='+colliders.length);
  return {size,n,heights,terrain,colliders,lootModels,gameplay,rules:{containers:CONTAINERS,revealTime:REVEAL_TIME,ops:OPS,wrecks:WRECKS,crateLoot:CRATE_LOOT,regionHunters:REGION_HUNTERS,regionRisk:Object.fromEntries([...new Set(gameplay.loot.map(l=>l.region))].map(id=>[id,regionRisk(id)])),enemies}};
 }};
}

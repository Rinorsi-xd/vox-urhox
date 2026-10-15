import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const relative='three/src/battle/storyBoss.js',bytes=fs.readFileSync(path.join(baseline.snapshot,relative));
const hash=b=>createHash('sha256').update(b).digest('hex');
if(hash(bytes)!==baseline.files[relative].sha256)throw Error('Boss source drift');
const THREE=await import(pathToFileURL(path.join(baseline.snapshot,'three/vendor/three/build/three.module.js')).href);
const code=bytes.toString('utf8').split('function ringMesh( color ) {')[1].split('// ── 首领血条')[0];
const factories=vm.runInNewContext('function ringMesh( color ) {'+code.replace(/function glowSprite\( color, size \) \{[\s\S]*?\n\}/,'function glowSprite(color,size){const g=new THREE.Group();g.userData.glow={color,size};return g;}')+'\n({ringMesh,sectorMesh,laneMesh,podMesh,bomberMesh})',{THREE});
const {optimize}=createRequire(import.meta.url)('./crater-model.cjs');
const dest=path.join(root,'assets/Story/Boss');fs.mkdirSync(dest,{recursive:true});
const models=[],materials=[],modelMap=new Map(),materialMap=new Map();
function model(geometry){
 if(modelMap.has(geometry.uuid))return modelMap.get(geometry.uuid);
 const g=geometry.index?geometry.toNonIndexed():geometry.clone();if(!g.attributes.normal)g.computeVertexNormals();
 const p=g.attributes.position,n=g.attributes.normal,uv=g.attributes.uv,count=p.count,chunks=[];
 const u=(...v)=>{const b=Buffer.alloc(v.length*4);v.forEach((x,i)=>b.writeUInt32LE(x,i*4));chunks.push(b);};
 const f=(...v)=>{const b=Buffer.alloc(v.length*4);v.forEach((x,i)=>b.writeFloatLE(x,i*4));chunks.push(b);};
 chunks.push(Buffer.from('UMDL'));u(1,count,31,0,0);const vertices=Buffer.alloc(count*44),lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];
 for(let i=0;i<count;i++){
  const pos=[-p.getX(i),p.getY(i),p.getZ(i)];[...pos,-n.getX(i),n.getY(i),n.getZ(i)].forEach((v,j)=>vertices.writeFloatLE(v,i*44+j*4));
  vertices.fill(255,i*44+24,i*44+28);vertices.writeFloatLE(uv?uv.getX(i):0,i*44+28);vertices.writeFloatLE(uv?1-uv.getY(i):0,i*44+32);
  for(let j=0;j<3;j++){lo[j]=Math.min(lo[j],pos[j]);hi[j]=Math.max(hi[j],pos[j]);}
 }
 chunks.push(vertices);u(1,count,2);const indices=Buffer.alloc(count*2);for(let i=0;i<count;i+=3)[i,i+2,i+1].forEach((v,j)=>indices.writeUInt16LE(v,(i+j)*2));chunks.push(indices);
 u(1,0,1);f(0);u(0,0,0,0,count,0,0);f(...lo,...hi,...lo.map((v,i)=>(v+hi[i])/2));
 const b=optimize(Buffer.concat(chunks)),id=models.length+1,name='Story/Boss/model-'+id+'.bin';fs.writeFileSync(path.join(root,'assets',name),b);
 models.push({path:name,bytes:b.length,sha256:hash(b),triangles:count/3});modelMap.set(geometry.uuid,id);return id;
}
function material(m){
 if(materialMap.has(m.uuid))return materialMap.get(m.uuid);
 const id=materials.length+1;materials.push({shader:m.isMeshStandardMaterial?'Body':m.transparent?'Alpha':'Unlit',color:m.color.toArray(),alpha:m.opacity,
 roughness:m.roughness??.5,metalness:m.metalness??0,emission:m.emissive?.toArray()||[0,0,0]});materialMap.set(m.uuid,id);return id;
}
function tree(object){const nodes=[],ids=new Map();function walk(o,parent){const id=nodes.length+1;ids.set(o,id);nodes.push({parent,position:o.position.toArray(),quaternion:o.quaternion.toArray(),scale:o.scale.toArray(),visible:o.visible,
 ...(o.isMesh?{model:model(o.geometry),material:material(o.material),shadow:!!o.castShadow}:{}),...(o.userData.glow?{glow:o.userData.glow}:{})});for(const c of o.children)walk(c,id);}walk(object,0);return {nodes,ids};}
const red=0xff3b30;
const ring=factories.ringMesh(red),sector=factories.sectorMesh(red,140),lane=factories.laneMesh(0xff4a2a);
const r=tree(ring),s=tree(sector),l=tree(lane),p=tree(factories.podMesh()),b=tree(factories.bomberMesh());
const node=model(new THREE.IcosahedronGeometry(1.25,2)),shield=model(new THREE.IcosahedronGeometry(1,2)),missile=model(new THREE.ConeGeometry(.35,1.6,8).rotateX(Math.PI/2)),dome=model(new THREE.SphereGeometry(1,48,24,0,Math.PI*2,0,Math.PI/2));
const shock=model(new THREE.RingGeometry(.8,1,96).rotateX(-Math.PI/2)),bomb=model(new THREE.CapsuleGeometry(.45,1.2,4,8).rotateX(Math.PI/2));
const data={source:{commit:baseline.commit,files:{[relative]:hash(bytes)}},models,materials,ring:{nodes:r.nodes,fill:r.ids.get(ring.userData.fill),grow:r.ids.get(ring.userData.grow),line:r.ids.get(ring.userData.line)},
 sector:{nodes:s.nodes,fill:s.ids.get(sector.userData.fill),grow:s.ids.get(sector.userData.grow)},lane:{nodes:l.nodes},pod:{nodes:p.nodes},bomber:{nodes:b.nodes},node,shield,missile,dome,shock,bomb};
fs.writeFileSync(path.join(dest,'View.json'),JSON.stringify(data));console.log(JSON.stringify({models:models.length,materials:materials.length,bytes:models.reduce((a,b)=>a+b.bytes,0)}));

import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=path.resolve(baseline.snapshot),url=p=>pathToFileURL(path.join(source,p)).href;
const entry=url('three/src/drive/weaponFx.js');
registerHooks({
 resolve(s,c,next){return next(s==='three'?url('three/vendor/three/build/three.module.js'):s.startsWith('@shared/')?url('shared/'+s.slice(8)):s,c);},
 load(u,c,next){const r=next(u,c);return u===entry?{...r,source:String(r.source)+'\nexport {missileGeometry,missileGlowGeometry,MSL_SIZE};'}:r;}
});
const {missileGeometry,missileGlowGeometry,MSL_SIZE}=await import(entry);
const {optimize,parse}=createRequire(import.meta.url)('./crater-model.cjs');
function mdl(g){
 const p=g.attributes.position,n=g.attributes.normal,col=g.attributes.color,uv=g.attributes.uv,count=p.count;
 const chunks=[],u=(...values)=>{const b=Buffer.alloc(values.length*4);values.forEach((v,i)=>b.writeUInt32LE(v,i*4));chunks.push(b);};
 const f=(...values)=>{const b=Buffer.alloc(values.length*4);values.forEach((v,i)=>b.writeFloatLE(v,i*4));chunks.push(b);};
 chunks.push(Buffer.from('UMDL'));u(1,count,31,0,0);const vertices=Buffer.alloc(count*44),lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];
 for(let i=0;i<count;i++){
  const pos=[-p.getX(i),p.getY(i),p.getZ(i)],normal=n?[-n.getX(i),n.getY(i),n.getZ(i)]:[0,1,0];
  [...pos,...normal].forEach((v,j)=>vertices.writeFloatLE(v,i*44+j*4));
  for(let j=0;j<3;j++){lo[j]=Math.min(lo[j],pos[j]);hi[j]=Math.max(hi[j],pos[j]);vertices[i*44+24+j]=Math.round((col?col.array[i*3+j]:1)*255);}
  vertices[i*44+27]=255;vertices.writeFloatLE(uv?uv.getX(i):0,i*44+28);vertices.writeFloatLE(uv?1-uv.getY(i):0,i*44+32);
 }
 chunks.push(vertices);u(1,count,2);const indices=Buffer.alloc(count*2);
 for(let i=0;i<count;i+=3)[i,i+2,i+1].forEach((v,j)=>indices.writeUInt16LE(v,(i+j)*2));chunks.push(indices);
 u(1,0,1);f(0);u(0,0,0,0,count,0,0);f(...lo,...hi,...lo.map((v,i)=>(v+hi[i])/2));
 return optimize(Buffer.concat(chunks));
}
const resources={};
for(const [name,g] of [['body',missileGeometry()],['glow',missileGlowGeometry()]]){
 if(!g.attributes.normal)g.computeVertexNormals();const bytes=mdl(g),relative=`Combat/Missile-${name}.bin`;
 fs.writeFileSync(path.join(root,'assets',relative),bytes);resources[name]={path:relative,bytes:bytes.length,vertices:parse(bytes).count,triangles:parse(bytes).indexCount/3,sha256:createHash('sha256').update(bytes).digest('hex')};g.dispose();
}
const data={baseline:baseline.commit,source:'three/src/drive/weaponFx.js',sha256:createHash('sha256').update(fs.readFileSync(fileURLToPath(entry))).digest('hex'),sizes:MSL_SIZE,resources};
fs.writeFileSync(path.join(root,'assets/Combat/MissileView.json'),JSON.stringify(data));
console.log(JSON.stringify(data));

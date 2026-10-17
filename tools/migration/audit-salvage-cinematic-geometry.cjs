'use strict';
// CPU-only queries of the retained drop frame, using the recorded A/B poses.
const fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {model,triangle}=require('./audit-salvage-spawn-geometry.cjs');
const root=path.resolve(__dirname,'../..'),id=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-cached-1792189057538/identity.json'))),manifest=JSON.parse(fs.readFileSync(id.manifest_path));
const hashes={};
function resource(name){const row=manifest.files.find(r=>r.fs_path===name);assert.ok(row,name);const b=fs.readFileSync(path.join(id.source_directory,'dist/assets',row.uuid+'-'+row.hash+row.ext));assert.equal(b.length,row.size);assert.equal(zlib.crc32(b).toString(16).padStart(8,'0'),row.hash);hashes[name]=crypto.createHash('sha256').update(b).digest('hex');return b}
function rotate(v,q){const [x,y,z,w]=q,[a,b,c]=v;const tx=2*(y*c-z*b),ty=2*(z*a-x*c),tz=2*(x*b-y*a);return [a+w*tx+y*tz-z*ty,b+w*ty+z*tx-x*tz,c+w*tz+x*ty-y*tx]}
const data=JSON.parse(resource('SalvageCine/Manifest.json'));
const prior=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/evidence/salvage-spawn-geometry-f881.json')));
const cases=prior.cases.map(c=>({...c,rays:c.rays.filter(r=>r.label!=='vertical-ground').map(r=>({label:r.label,dir:r.dir,hits:[]}))}));
// These bounds were produced by frozen Blueprint:Load and VehicleSpec.Build,
// not by visual estimation. Same 78-part Warehouse starter as both recordings.
const bounds={min:[-2.4125,.5,-3.25],max:[2.4125,3.5,3.25]},a=bounds.min,b=bounds.max;
const scale=[Math.max(1,(b[2]-a[2]+1.6)/7),Math.max(1,(b[1]-a[1]+1.2)/5),Math.max(1,(b[0]-a[0]+1.4)/5.2)];
for(const c of cases){
 const spawn=prior.spawns.find(s=>s.id===(c.name==='A'?'S5':'S2')),yaw=Math.atan2(-Math.cos(spawn.yaw),Math.sin(spawn.yaw)),angle=Math.PI/2-yaw;
 const nodes=new Map(data.motion.map(d=>[d.id,{parent:d.parent,p:[-d.position[0],d.position[1],d.position[2]],q:[d.quaternion[0],-d.quaternion[1],-d.quaternion[2],d.quaternion[3]],s:d.scale.slice()}]));
 Object.assign(nodes.get('holder'),{p:[-c.cine.view.holder[0],c.cine.view.holder[1],c.cine.view.holder[2]],q:[0,Math.sin(angle/2),0,Math.cos(angle/2)]});
 nodes.get('frame').s=scale;
 const door=-Math.PI/2*.98;for(let i=1;i<=4;i++)nodes.get('door'+i).q=[Math.sin(door/2),0,0,Math.cos(door/2)];
 function transform(v,name){let n=nodes.get(name);while(n){v=rotate(v.map((x,i)=>x*n.s[i]),n.q).map((x,i)=>x+n.p[i]);n=nodes.get(n.parent)}return v}
 for(const row of data.models.filter(r=>r.motion==='frame'||r.motion.startsWith('door'))){const mesh=model(resource(row.model)),vertices=Array.from({length:mesh.count},(_,i)=>transform(mesh.vertex(i),row.motion));for(let i=0;i<mesh.indices;i+=3){const aa=vertices[mesh.at(i)],bb=vertices[mesh.at(i+1)],cc=vertices[mesh.at(i+2)];for(const ray of c.rays){const hit=triangle(c.origin,ray.dir,aa,bb,cc);if(hit){ray.hits.push({...hit,model:row.model,material:row.material,motion:row.motion});ray.hits.sort((a,b)=>a.distance-b.distance);ray.hits.length=Math.min(8,ray.hits.length)}}}}
 c.spawn=spawn.id;c.holderYawEngine=angle;c.frameScale=scale;c.holderVisible=c.cine.view.frameVisible;
}
const out={kind:'READ_ONLY_DYNAMIC_CPU_GEOMETRY',bounds,scale,cases,hashes,boundary:'Both faces queried. Frozen source matrices and final fully open door angle, actual recorded cameras and holder poses. Does not validate native scene submissions, shaders, fog or pixels. H5 _end(drop) also retains holder/frame.'};
const output=path.join(root,'docs/migration/evidence/salvage-cinematic-geometry-f881.json');fs.writeFileSync(output,JSON.stringify(out,null,2));
console.log(JSON.stringify({output,scale,cases:cases.map(c=>({name:c.name,rays:c.rays.map(r=>({label:r.label,nearest:r.hits[0]||null}))}))},null,2));

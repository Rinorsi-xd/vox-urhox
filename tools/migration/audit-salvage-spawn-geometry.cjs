'use strict';
// Read-only CPU geometry queries against the exact frozen package; no Runtime.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),zlib=require('node:zlib');
const ROOT=path.resolve(__dirname,'../..'),PREPARE=path.join(ROOT,'.tmp/outgame-cached-1792189057538/identity.json');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function dot(a,b){return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]}
function cross(a,b){return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]}
const sub=(a,b)=>a.map((v,i)=>v-b[i]);
function model(bytes){
 assert.equal(bytes.toString('ascii',0,4),'UMDL');assert.equal(bytes.readUInt32LE(4),1);
 const count=bytes.readUInt32LE(8),mask=bytes.readUInt32LE(12),stride={11:32,15:36,31:44}[mask];assert.ok(stride,'Known exported vertex format');
 const end=24+count*stride;assert.equal(bytes.readUInt32LE(end),1);const indices=bytes.readUInt32LE(end+4),size=bytes.readUInt32LE(end+8);assert.ok([2,4].includes(size));
 const trailer=end+12+indices*size;assert.equal(bytes.length-trailer,80);const box={min:[],max:[]};for(let i=0;i<3;i++){box.min.push(bytes.readFloatLE(trailer+44+i*4));box.max.push(bytes.readFloatLE(trailer+56+i*4))}
 return {count,indices,box,vertex(i){const start=24+i*stride;return [bytes.readFloatLE(start),bytes.readFloatLE(start+4),bytes.readFloatLE(start+8)]},at(i){return size===2?bytes.readUInt16LE(end+12+i*2):bytes.readUInt32LE(end+12+i*4)}};
}
function boxHit(origin,dir,box){let lo=0,hi=10000;for(let i=0;i<3;i++){if(Math.abs(dir[i])<1e-12){if(origin[i]<box.min[i]||origin[i]>box.max[i])return false;continue}const a=(box.min[i]-origin[i])/dir[i],b=(box.max[i]-origin[i])/dir[i];lo=Math.max(lo,Math.min(a,b));hi=Math.min(hi,Math.max(a,b));if(hi<lo)return false}return true}
function triangle(origin,dir,a,b,c){
 const ab=sub(b,a),ac=sub(c,a),h=cross(dir,ac),det=dot(ab,h);if(Math.abs(det)<1e-10)return null;
 const s=sub(origin,a),u=dot(s,h)/det;if(u<0||u>1)return null;const q=cross(s,ab),v=dot(dir,q)/det;if(v<0||u+v>1)return null;
 const t=dot(ac,q)/det;if(t<.00001)return null;const normal=cross(ab,ac),length=Math.hypot(...normal);return {distance:t,point:origin.map((value,i)=>value+t*dir[i]),normal:normal.map(value=>value/length),det};
}
function run(){
 const prepared=JSON.parse(fs.readFileSync(PREPARE)),manifest=JSON.parse(fs.readFileSync(prepared.manifest_path));const hashes={};
 const resource=name=>{const row=manifest.files.find(row=>row.fs_path===name);assert.ok(row,'Frozen resource '+name);const bytes=fs.readFileSync(path.join(prepared.source_directory,'dist/assets',row.uuid+'-'+row.hash+row.ext));assert.equal(bytes.length,row.size);assert.equal(zlib.crc32(bytes).toString(16).padStart(8,'0'),row.hash);hashes[name]=sha(bytes);return bytes};
 const data=JSON.parse(resource('Salvage/RunManifest.json')),height=resource('Salvage/Height.bin'),gp=JSON.parse(resource('Salvage/Gameplay.json'));
 const n=height.readUInt32LE(4),ox=height.readFloatLE(8),oz=height.readFloatLE(12),step=height.readFloatLE(16);
 function sample(x,z){const fx=(x-ox)/step,fz=(z-oz)/step,i=Math.max(0,Math.min(n-1,Math.floor(fx))),j=Math.max(0,Math.min(n-1,Math.floor(fz))),u=Math.max(0,Math.min(1,fx-i)),v=Math.max(0,Math.min(1,fz-j)),at=(a,b)=>height.readFloatLE(20+4*(a*(n+1)+b));return at(i,j)*(1-u)*(1-v)+at(i+1,j)*u*(1-v)+at(i,j+1)*(1-u)*v+at(i+1,j+1)*u*v}
 const cases=[['A','load-heap-short-f881-1792191171246'],['B','load-heap-short-f881-1792191998484']].map(([name,folder])=>{
  const directory=path.join(ROOT,'docs/migration/evidence',folder),report=JSON.parse(fs.readFileSync(path.join(directory,'result.json'))),states=fs.readFileSync(path.join(directory,'states.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
  const row=states.find(row=>row.state.mode==='trial'&&!row.state.loadingFlow.active&&row.state.salvageRun?.cine.playing===false&&row.state.pointer.captured===true);assert.ok(row);
  const s=name==='B'?report.activatedScreenshotState:row.state,origin=s.camera.position,yaw=s.camera.yaw*Math.PI/180,pitch=s.camera.pitch*Math.PI/180;
  const forward=[Math.sin(yaw)*Math.cos(pitch),-Math.sin(pitch),Math.cos(yaw)*Math.cos(pitch)],right=[Math.cos(yaw),0,-Math.sin(yaw)],up=cross(forward,right),rays=[];
  for(const [label,rx,uy]of [['center',0,0],['upper',0,.4],['lower',0,-.4],['left',-.7,0],['right',.7,0]]){const vector=forward.map((value,i)=>value+right[i]*rx+up[i]*uy),length=Math.hypot(...vector);rays.push({label,dir:vector.map(v=>v/length),hits:[]})}
  const game=[-origin[0],origin[1],origin[2]],ground=sample(game[0],game[2]);rays.push({label:'vertical-ground',dir:[0,-1,0],hits:[]});
  return {name,evidence:directory,sceneVisible:s.sceneVisible,origin,gameOrigin:game,groundHeight:ground,cameraGroundClearance:origin[1]-ground,vehicle:s.vehicle,camera:s.camera,cine:s.salvageRun.cine,simulationTime:s.salvageRun.time,rays};
 });
 for(const row of data.models){
  const bytes=resource(row.model),mesh=model(bytes),material=data.materials[row.material];const queries=cases.flatMap(c=>c.rays.filter(ray=>boxHit(c.origin,ray.dir,mesh.box)).map(ray=>({ray,origin:c.origin})));
  if(!queries.length)continue;
  for(let k=0;k<mesh.indices;k+=3){const a=mesh.vertex(mesh.at(k)),b=mesh.vertex(mesh.at(k+1)),c=mesh.vertex(mesh.at(k+2));for(const query of queries){const hit=triangle(query.origin,query.ray.dir,a,b,c);if(hit){query.ray.hits.push({...hit,model:row.model,material:row.material,ground:material.ground,double:material.double,opacity:material.opacity});query.ray.hits.sort((a,b)=>a.distance-b.distance);if(query.ray.hits.length>8)query.ray.hits.length=8}}}
 }
 return {kind:'READ_ONLY_CPU_GEOMETRY',frozenManifest:path.basename(prepared.manifest_path),sourceCommit:prepared.identity.sourceCommit,spawns:gp.spawns,cases,hashes,boundary:'CPU ray/triangle intersections use exported static identity-transform meshes and both triangle faces. They do not validate native culling, shader/fog output, dynamic meshes, postprocessing or actual screenshot pixels. Camera uses yaw/pitch from real snapshot; game X is mirrored relative to engine X.'};
}
module.exports={run,triangle,boxHit,model};
if(require.main===module){assert.equal(process.argv.length,2);const result=run(),out=path.join(ROOT,'docs/migration/evidence/salvage-spawn-geometry-f881.json');fs.writeFileSync(out,JSON.stringify(result,null,2));console.log(JSON.stringify({...result,hashes:Object.keys(result.hashes).length},null,2));}

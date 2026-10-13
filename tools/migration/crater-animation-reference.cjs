// Execute the original H5 animation function on original GLB rest transforms.
// No source writes, rendering, network or player-save access.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),source=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8')).snapshot;
(async()=>{
 const THREE=await import('file:///'+source+'/three/vendor/three/build/three.module.js');
 const code=fs.readFileSync(source+'/three/src/battle/mapModules.js','utf8');
 const animate=new Function('MAP_UNIFORMS',code.slice(code.indexOf('const SPIN =')).replace('export function','function')+';return animateDyn;')({uTime:{value:0}});
 const manifest=JSON.parse(fs.readFileSync(root+'/tools/migration/crater-source/Manifest.json','utf8'));
 const nodes=[];
 for(const entry of manifest.roots){
  const file=source+'/shared/assets/maps/crater/'+entry.id+'.glb';if(!fs.existsSync(file))continue;
  const bytes=fs.readFileSync(file),gltf=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)).toString());
  for(const n of gltf.nodes){
   if(!n.extras?.dyn)continue;
   const o=new THREE.Object3D();o.name=THREE.PropertyBinding.sanitizeNodeName(n.name);
   o.position.fromArray(n.translation||[0,0,0]);o.quaternion.fromArray(n.rotation||[0,0,0,1]);o.scale.fromArray(n.scale||[1,1,1]);
   o.userData={...n.extras};nodes.push(o);
  }
 }
 const samples=[];
 for(const time of [0,2.25,Math.PI/2/1.3,3*Math.PI/2/1.3]){
  animate([{dyn:nodes}],time);
  samples.push({time,nodes:nodes.map(o=>({name:o.name,kind:o.userData.dyn,p:o.position.toArray(),q:o.quaternion.toArray(),s:o.scale.toArray()}))});
 }
 const data={source:'Original mapModules.js animateDyn + six original GLBs',samples};
 fs.writeFileSync(root+'/tools/migration/crater-source-animation.json',JSON.stringify(data,null,2)+'\n');
 console.log(JSON.stringify({nodes:nodes.length,samples:samples.length}));
})().catch(e=>{console.error(e);process.exitCode=1});

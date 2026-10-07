// Execute the original H5 shield controller, retaining the real Three uniforms.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),source='D:/Rino_Project/Vox';
(async()=>{
 const THREE=await import('file:///'+source+'/three/vendor/three/build/three.module.js');
 const code=fs.readFileSync(source+'/three/src/battle/shieldFx.js','utf8');
 const build=new Function('THREE',code.replace(/import \* as THREE from 'three';/,'').replace('export function buildShield','function buildShield')+';return buildShield;')(THREE);
 const layout=JSON.parse(fs.readFileSync(root+'/assets/Crater/Layout.json','utf8'));
 const definition=layout.base.shield,mesh=build({shield:definition,team:'own'}),fx=mesh.userData.fx,U=mesh.material.uniforms;
 const hit=[definition.rx*.5,definition.pos[1]+definition.h*.6,definition.pos[2]+definition.rz*Math.sqrt(.39)];
 const actions=[['update',10],['hit',hit],['update',10.08],['update',10.4],['setHP',.1],['down'],['update',11.2],['raise'],['update',12.3],['update',13.4],['down',.8],['update',14.2],['raise',.4],['update',14.6]];
 for(let i=0;i<11;i++)actions.push(['update',15+i*.05],['hit',[hit[0]+i,hit[1],hit[2]]]);
 actions.push(['update',18]);
 const trace=[];
 for(const action of actions){
  const [method,value]=action;fx[method](method==='hit'?new THREE.Vector3(...value):value);
  trace.push({action,time:U.uTime.value,hp:U.uHP.value,down:U.uDown.value,raise:U.uRaise.value,hits:U.uHits.value.map(v=>v.toArray()),anim:!!fx.anim});
 }
 const data={source:'three/src/battle/shieldFx.js',sha256:crypto.createHash('sha256').update(code).digest('hex'),shield:definition,hit,team_color:U.uColor.value.toArray(),trace};
 fs.writeFileSync(__dirname+'/crater-shield-reference.json',JSON.stringify(data,null,2)+'\n');
 console.log(JSON.stringify({steps:trace.length,hit_slots:U.uHits.value.length,source_sha256:data.sha256}));
 mesh.geometry.dispose();mesh.material.dispose();
})().catch(e=>{console.error(e);process.exitCode=1});

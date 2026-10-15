import * as T from 'three';
import {buildCraterWorld} from '/three/src/battle/craterWorld.js';
const enginePit=new URL(import.meta.url).searchParams.get('map')==='EnginePit';
const prefix=enginePit?'EnginePit/':'Crater/';
const status=document.querySelector('#status');
const post=async(name,data)=>{const r=await fetch('/export/'+name,{method:'POST',body:typeof data==='string'||data instanceof Blob?data:JSON.stringify(data)});if(!r.ok)throw Error(await r.text())};
document.querySelector('#export').onclick=async()=>{try{
 document.querySelector('#export').disabled=true;
 const renderer=new T.WebGLRenderer({antialias:true});renderer.setSize(1280,720);renderer.setPixelRatio(1);document.body.append(renderer.domElement);
 renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.1;
 const camera=new T.PerspectiveCamera(48,1280/720,.1,2600);camera.position.set(350,220,-380);camera.lookAt(0,5,0);
 const build=enginePit?(await import('/three/src/battle/enginePitWorld.js')).buildEnginePitMap:buildCraterWorld;
 const world=await build({renderer,camera,progress:(k,s)=>status.textContent=Math.round(k*100)+'% '+s});
 // Preview animation must never become the authored rest pose in the export.
 const restPose=new Map();for(const mod of world.mods||[])for(const o of mod.dyn)restPose.set(o,{p:o.position.toArray(),q:o.quaternion.toArray(),s:o.scale.toArray()});
 world.update(0,10,camera,new T.Vector3(0,6,-279));renderer.render(world.scene,camera);
 const manifest={version:world.man?.version||1,materials:[],roots:[],geometryCount:0,scatterBoulders:world.scatter.userData.boulders,layout:world.layout};
 if(enginePit){
  // Record the source collider descriptors through its actual attachPhysics path.
  const descriptor=(type,args)=>({type,args,pos:[0,0,0],q:[0,0,0,1],setTranslation(x,y,z){this.pos=[x,y,z];return this},setRotation(q){this.q=[q.x,q.y,q.z,q.w];return this},setFriction(f){this.friction=f;return this}});
  const types={cuboid:'box',cylinder:'cylinder',convexHull:'hull',trimesh:'mesh'};
  const Rp={RigidBodyDesc:{fixed:()=>({})},TriMeshFlags:{FIX_INTERNAL_EDGES:1},ColliderDesc:{}};
  for(const [key,type] of Object.entries(types))Rp.ColliderDesc[key]=(...args)=>descriptor(type,args.map(v=>ArrayBuffer.isView(v)?Array.from(v):v));
  const cols=[];world.attachPhysics(Rp,{createRigidBody:()=>({}),createCollider:d=>{cols.push(d);return {setEnabled(enabled){d.disabled=!enabled}}}});
  const original=cols.map(d=>!!d.disabled);world.deck.collapse();
  cols.forEach((d,i)=>{if(original[i]!==!!d.disabled)d.group=original[i]?'fallen':'deck'});world.deck.reset();
  manifest.layout.enginePit.deck={center:world.deck.center,half:world.deck.half,yaw:world.deck.yaw,top:world.deck.top,pitY:world.deck.pitY};
  manifest.colliders=cols;
  manifest.layout.terrain.heights=Array.from(manifest.layout.terrain.heights);
  const heights=new Float32Array((501)**2);
  for(let x=0;x<=500;x++)for(let z=0;z<=500;z++)heights[x*501+z]=world.groundAt(-500+x*2,-500+z*2);
  await post('VisualHeight.bin',new Blob([heights.buffer]));
 }
 const chunks=['common','map_fragment','roughnessmap_fragment','normal_fragment_maps','aomap_fragment'];
 const hook=m=>{const shader={uniforms:{},vertexShader:'',fragmentShader:chunks.map(k=>'#include <'+k+'>').join('\n//CRATER_SPLIT\n')};m.onBeforeCompile(shader);return shader.fragmentShader.split('\n//CRATER_SPLIT\n')};
 let mapMat=world.mods?.[0].materials.find(m=>m.userData.uniforms);if(enginePit)world.struct.traverse(o=>{if(!mapMat&&o.material?.userData.uniforms)mapMat=o.material});
 await post('ShaderSources.json',{near:hook(world.matNear),far:hook(world.matFar),map:hook(mapMat),sky:world.sky.material.fragmentShader,fog:T.ShaderChunk.fog_fragment});
 delete manifest.layout.backdrop;
 const geos=new Map(),mats=new Map(),texs=new Map();let texCount=0;
 async function png(name,width,height,pixels){const canvas=document.createElement('canvas');canvas.width=width;canvas.height=height;canvas.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(pixels.buffer),width,height),0,0);await post(name,await new Promise(r=>canvas.toBlob(r,'image/png')));return prefix+name}
 async function texture(t){
  if(!t)return null;if(texs.has(t.uuid))return texs.get(t.uuid);
  const name='texture-'+texCount+++'.png',w=t.image.width,h=t.image.height;
  const scene=new T.Scene(),cam=new T.Camera(),mat=new T.ShaderMaterial({uniforms:{tex:{value:t}},vertexShader:'varying vec2 v;void main(){v=uv;gl_Position=vec4(position.xy,0.,1.);}',fragmentShader:'uniform sampler2D tex;varying vec2 v;void main(){gl_FragColor=texture2D(tex,v);}'});
  scene.add(new T.Mesh(new T.PlaneGeometry(2,2),mat));const rt=new T.WebGLRenderTarget(w,h);renderer.setRenderTarget(rt);renderer.render(scene,cam);const pixels=new Uint8Array(w*h*4);renderer.readRenderTargetPixels(rt,0,0,w,h,pixels);renderer.setRenderTarget(null);rt.dispose();mat.dispose();
  const result=await png(name,w,h,pixels);texs.set(t.uuid,result);return result;
 }
 // Array readback preserves the original linear samples, including height/AO.
 for(const [key,t] of [['albedo',world.matNear.userData.uniforms.tAlb.value],['nra',world.matNear.userData.uniforms.tNra.value]]){
  if(enginePit)continue;
  const scene=new T.Scene(),cam=new T.Camera(),mat=new T.ShaderMaterial({glslVersion:T.GLSL3,uniforms:{tex:{value:t},layer:{value:0}},vertexShader:'out vec2 v;void main(){v=uv;gl_Position=vec4(position.xy,0.,1.);}',fragmentShader:'uniform highp sampler2DArray tex;uniform float layer;in vec2 v;out vec4 color;void main(){color=texture(tex,vec3(v,layer));}'});
  scene.add(new T.Mesh(new T.PlaneGeometry(2,2),mat));const w=t.image.width,h=t.image.height,rt=new T.WebGLRenderTarget(w,h);
  for(let layer=0;layer<6;layer++){mat.uniforms.layer.value=layer;renderer.setRenderTarget(rt);renderer.render(scene,cam);const pixels=new Uint8Array(w*h*4);renderer.readRenderTargetPixels(rt,0,0,w,h,pixels);await png(key+'-'+layer+'.png',w,h,pixels)}
  renderer.setRenderTarget(null);rt.dispose();mat.dispose();
 }
 manifest.ground=await texture(world.ground||world.matNear.userData.uniforms.tGround.value);manifest.layers=world.matNear.userData.uniforms.uInvSize.value;
 // Store terrain heights without normalizing away negative crater elevations.
 const heights=manifest.layout.terrain;await post('Height.json',heights);
 async function material(m){
  if(mats.has(m.uuid))return mats.get(m.uuid);const id=manifest.materials.length+1;mats.set(m.uuid,id);
  const d={name:m.name,color:(m.userData.baseColor||m.color)?.toArray()||[1,1,1],rough:m.roughness??1,metal:m.metalness||0,opacity:m.opacity,alphaTest:m.alphaTest||0,kind:m.userData.mapKind||'scatter',defines:m.defines||{},uniforms:{},textures:{},emission:m.emissive?.toArray()||[0,0,0],emissionStrength:m.emissiveIntensity||0,side:m.side};
  if(m===world.matNear)d.kind='terrain';if(m===world.matFar)d.kind='far';
  for(const [k,u] of Object.entries(m.userData.uniforms||{})){
   if(['tTerrA','tTerrN','tAlb','tNra','tHeight','tGround'].includes(k))continue;const v=u.value;
   if(v?.isTexture)d.textures[k]=await texture(v);else if(v?.toArray)d.uniforms[k]=v.toArray();else if(typeof v==='number')d.uniforms[k]=v;
  }
  if(m.map)d.textures.map=await texture(m.map);if(m.normalMap){d.textures.normal=await texture(m.normalMap);d.normalScale=m.normalScale.toArray();}
  manifest.materials.push(d);return id;
 }
 async function geometry(g,group){
  const key=g.uuid+':'+group.start+':'+group.count;if(geos.has(key))return geos.get(key);
  const d={p:[],n:[],c:[],uv:[],uv2:[],idx:[]},remap=new Map(),a=g.attributes;
  const read=(attr,i,k,fallback)=>attr?attr.getComponent(i,k):fallback;
  const end=Math.min(group.start+group.count,g.index?.count||a.position.count);
  for(let j=group.start;j<end;j++){
   const i=g.index?g.index.getX(j):j;if(!remap.has(i)){
    remap.set(i,d.p.length/3);for(let k=0;k<3;k++){d.p.push(read(a.position,i,k,0));d.n.push(read(a.normal,i,k,k===1?1:0))}
    for(let k=0;k<4;k++)d.c.push(read(a.aW||a.aBake||a.color,i,k,1));
    for(let k=0;k<2;k++){d.uv.push(read(a.uv,i,k,0));d.uv2.push(a.aSun?(k===0?a.aSun.getX(i):0):read(a.uv1,i,k,0))}
   }d.idx.push(remap.get(i));
  }
  const name='mesh-'+manifest.geometryCount+++'.bin';await post(name,d);geos.set(key,prefix+name);return prefix+name;
 }
 async function node(o){
  const d={name:o.name,p:o.position.toArray(),q:o.quaternion.toArray(),s:o.scale.toArray(),dyn:o.userData.dyn,visible:o.visible,children:[],meshes:[]};
  if(restPose.has(o))Object.assign(d,restPose.get(o));
  if(o.isMesh&&!o.material.isShaderMaterial){
   const groups=o.geometry.groups.length?o.geometry.groups:[{start:0,count:o.geometry.index?.count||o.geometry.attributes.position.count,materialIndex:0}];
   for(const g of groups){const m=Array.isArray(o.material)?o.material[g.materialIndex]:o.material;
    const item={model:await geometry(o.geometry,g),material:await material(m),shadow:o.castShadow};
    if(o.isInstancedMesh){item.instances=[];const matrix=new T.Matrix4(),p=new T.Vector3(),q=new T.Quaternion(),s=new T.Vector3();for(let i=0;i<o.count;i++){o.getMatrixAt(i,matrix);matrix.decompose(p,q,s);item.instances.push({p:p.toArray(),q:q.toArray(),s:s.toArray()})}}
    d.meshes.push(item);
   }
  }
  for(const child of o.children){if(enginePit&&!child.visible)continue;const c=await node(child);if(c.meshes.length||c.children.length)d.children.push(c)}return d;
 }
 const roots=[...world.scene.children.filter(o=>['地形','远山'].includes(o.name)),...(enginePit?[world.struct]:world.mods.map(m=>m.root)),world.scatter,
  ...(enginePit?world.struct.children.filter(o=>!o.visible):[])];
 for(const root of roots){status.textContent='转换 '+root.name;const data=await node(root);const name=enginePit?'root-'+manifest.roots.length:root.name==='地形'?'terrain':root.name==='远山'?'far':root.name==='地表散布'?'scatter':root.name;await post(name+'.json',data);manifest.roots.push({id:root.name,file:prefix+name+'.json'})}
 await post('Manifest.json',manifest);status.textContent='完成：'+manifest.geometryCount+' 模型，'+manifest.materials.length+' 材质';renderer.render(world.scene,camera);
 }catch(e){status.textContent=String(e.stack||e);console.error(e)}};

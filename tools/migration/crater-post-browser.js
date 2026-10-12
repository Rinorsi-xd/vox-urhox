// Runs the actual readonly H5 Pipeline on the same diagnostic input as UrhoX.
import * as T from 'three';
import { Pipeline, DEFAULT_GFX } from '/three/src/render/pipeline.js';
const status=document.querySelector('#status');
async function save(name,body){
 const result=await fetch('/evidence/crater-h5-post-'+name,{method:'POST',body});
 if(!result.ok)throw Error(await result.text());
}
try {
 if(new URLSearchParams(location.search).has('map')) await captureMap(); else {
 const container=document.createElement('div');document.body.append(container);
 const pipeline=new Pipeline(container),scene=new T.Scene();
 scene.userData.post={ao:false,grade:{uContrast:1.08,uSaturation:1.05,uShadowTint:new T.Vector3(.93,.98,1.05),uHighTint:new T.Vector3(1.06,1,.91)}};
 const camera=new T.OrthographicCamera(-1,1,1,-1,.1,10);camera.position.z=2;camera.aspect=256/192;
 const material=new T.ShaderMaterial({uniforms:{shaftMode:{value:0}},depthTest:false,depthWrite:false,vertexShader:`varying vec2 vUv;void main(){vUv=uv;gl_Position=vec4(position.xy,0.,1.);}`,fragmentShader:`
 varying vec2 vUv;uniform float shaftMode;
 void main(){
  vec2 uv=vec2(vUv.x,1.-vUv.y);
  vec3 c=vec3(.02+.25*uv.x,.04+.4*uv.y,.12);
  if(length(uv-vec2(.35,.4))<.065)c=vec3(.3,4.,8.);
  if(uv.x>.61&&uv.x<.64&&uv.y>.2&&uv.y<.78)c=vec3(5.,2.,.03);
  float alpha=1.;
  if(shaftMode>.5){
   c=vec3(2.,1.8,1.3);alpha=0.;
   if(length(uv-vec2(.5))<.07)c=vec3(40.,35.,27.);
   if(uv.x>.44&&uv.x<.47){c=vec3(.2,.15,.1);alpha=1.;}
   if(shaftMode>1.5)alpha=1.;
  }
  gl_FragColor=vec4(c,alpha);
 }`});
 scene.add(new T.Mesh(new T.PlaneGeometry(2,2),material));pipeline.init(scene,camera);
 const cases=[['default',256,192,{}],['exposure',256,192,{exposure:.6}],['no-mist',256,192,{mist:0}],['no-bloom',256,192,{bloom:0}],['odd-resize',129,97,{}],['shafts',256,192,{shaftMode:1}],['shafts-blocked',256,192,{shaftMode:2}]];
 const records=[];
 for(const [name,w,h,options] of cases){
  pipeline.renderer.setPixelRatio(1);pipeline.renderer.setSize(w,h);
  pipeline.composer.setPixelRatio(1);pipeline.composer.setSize(w,h);
  pipeline.lens.uniforms.uResolution.value.set(w,h);pipeline.applyGraphics({...DEFAULT_GFX,...options});
  material.uniforms.shaftMode.value=options.shaftMode||0;
  scene.userData.post.shafts=options.shaftMode?{dir:new T.Vector3(0,0,-1),color:new T.Color(1,.8,.55),strength:.3}:null;
  pipeline._applyPost(scene);
  pipeline.render(1/60,0);
  const gl=pipeline.renderer.getContext(),pixels=new Uint8Array(w*h*4);gl.readPixels(0,0,w,h,gl.RGBA,gl.UNSIGNED_BYTE,pixels);
  const points=[];
  for(let y=7;y<h-7;y+=13)for(let x=7;x<w-7;x+=13){const i=((h-1-y)*w+x)*4;points.push({x,y,rgb:Array.from(pixels.slice(i,i+3))});}
  const image=await new Promise(resolve=>pipeline.renderer.domElement.toBlob(resolve,'image/png'));
  if(!image)throw Error('Cannot capture '+name);await save(name+'.png',image);
  records.push({name,width:w,height:h,points});status.textContent='Captured '+name;
 }
 await save('pixels.json',JSON.stringify({three_revision:T.REVISION,cases:records},null,2));
 status.textContent='DONE: actual H5 Pipeline captured seven reference cases';
 pipeline.composer.dispose();material.dispose();scene.children[0].geometry.dispose();pipeline.renderer.dispose();
 }
}catch(error){status.textContent='FAILED: '+(error.stack||error);console.error(error);}

async function captureMap(){
 const {buildCraterWorld}=await import('/three/src/battle/craterWorld.js');
 const container=document.createElement('div');document.body.append(container);
 const pipeline=new Pipeline(container),renderer=pipeline.renderer;
 const w=2040,h=1080,camera=new T.PerspectiveCamera(2*Math.atan(18/20/(w/h))*180/Math.PI,w/h,.3,3200);
 const sunView=new URLSearchParams(location.search).has('sun');
 camera.position.set(...(sunView?[70,5,140]:[100,-5,-20]));
 camera.lookAt(sunView?camera.position.clone().add(new T.Vector3(-.52,.5,-.69).normalize().multiplyScalar(1500)):new T.Vector3(-40,-2,10));camera.updateMatrixWorld();
 const world=await buildCraterWorld({renderer,camera,progress:(k,text)=>status.textContent=text});
 pipeline.init(world.scene,camera);pipeline.applyGraphics({...DEFAULT_GFX});pipeline.autoRes=false;
 renderer.setPixelRatio(1);renderer.setSize(w,h);pipeline.composer.setPixelRatio(1);pipeline.composer.setSize(w,h);
 pipeline.lens.uniforms.uResolution.value.set(w,h);
 if(new URLSearchParams(location.search).has('shield')){
  camera.position.set(70,28,-200);camera.lookAt(new T.Vector3(0,8,-272));camera.fov=2*Math.atan(18/26/(w/h))*180/Math.PI;camera.updateProjectionMatrix();camera.updateMatrixWorld();
  world.update(0,10,camera,camera.position);
  const sh=world.shields[0],fx=sh.userData.fx,s=world.layout.base.shield;
  const point=new T.Vector3(s.rx*.5,s.pos[1]+s.h*.6,s.pos[2]+s.rz*Math.sqrt(.39));
  const cases=[['intact',()=>fx.update(10)],['flash',()=>{fx.hit(point);fx.update(10.08)}],['ring',()=>fx.update(10.4)],['expired',()=>fx.update(12)],['low',()=>fx.setHP(.1)],['dissolve',()=>{fx.down();fx.update(12.8)}],['down',()=>fx.update(13.6)],['raise',()=>{fx.raise();fx.update(14.7)}],['raised',()=>fx.update(15.8)]];
  for(const [name,apply] of cases){
   apply();pipeline.render(1/60,10);
   const image=await new Promise(resolve=>renderer.domElement.toBlob(resolve,'image/png'));
   if(!image)throw Error('Cannot capture shield '+name);
   await save('shield-'+name+'.png',image);status.textContent='Captured original shield '+name;
  }
  await save('shield.json',JSON.stringify({source:'actual buildCraterWorld + shieldFx + Pipeline',width:w,height:h,eye:camera.position.toArray(),hit:point.toArray(),cases:cases.map(c=>c[0])},null,2));
  status.textContent='DONE: original H5 shield rendered in nine states';pipeline.composer.dispose();renderer.dispose();return;
 }
 const records=[];
 for(const [name,factor] of (sunView?[['sun-on',1],['sun-off',1]]:[['dim',.6],['bright',1]])){
  world.update(0,10,camera,camera.position);
  const materials=[];
  for(const module of world.mods)for(const material of module.materials){
   if(material.name==='反应堆光'){
    material.color.copy(material.userData.baseColor).multiplyScalar(factor);
    materials.push({name:material.name,base:material.userData.baseColor.toArray(),color:material.color.toArray()});
   }
  }
  if(sunView)pipeline.shafts.enabled=name==='sun-on';
  pipeline.render(1/60,10);
  const image=await new Promise(resolve=>renderer.domElement.toBlob(resolve,'image/png'));
  await save('map-'+name+'.png',image);records.push({name,factor,materials});
 }
 await save(sunView?'map-sun.json':'map-breath.json',JSON.stringify({time:10,width:w,height:h,records,limits:'Diagnostic captures hold reactor emission at original breathing extrema; all H5 source files remain unchanged.'},null,2));
 status.textContent='DONE: original map captured at both reactor breathing extrema';
 world.dispose?.();pipeline.composer.dispose();renderer.dispose();
}

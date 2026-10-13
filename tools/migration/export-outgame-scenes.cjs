// Convert the frozen authored scenes; never modify the H5 checkout.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const {optimize}=require('./crater-model.cjs');
const root=path.resolve(__dirname,'../..');
const source=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))).snapshot;
function model(g){
 const chunks=[],u=(...v)=>{const b=Buffer.alloc(v.length*4);v.forEach((x,i)=>b.writeUInt32LE(x,i*4));chunks.push(b)},f=(...v)=>{const b=Buffer.alloc(v.length*4);v.forEach((x,i)=>b.writeFloatLE(x,i*4));chunks.push(b)};
 const count=g.p.length/3,lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];
 chunks.push(Buffer.from('UMDL'));u(1,count,31,0,0);const vb=Buffer.alloc(count*44);
 for(let i=0;i<count;i++){
  const p=[-g.p[i*3],g.p[i*3+1],g.p[i*3+2]];
  p.forEach((v,k)=>{lo[k]=Math.min(lo[k],v);hi[k]=Math.max(hi[k],v)});
  [...p,-g.n[i*3],g.n[i*3+1],g.n[i*3+2]].forEach((v,k)=>vb.writeFloatLE(v,i*44+k*4));
  for(let k=0;k<4;k++)vb[i*44+24+k]=Math.round(Math.max(0,Math.min(1,g.c[i*4+k]))*255);
  [g.uv[i*2],1-g.uv[i*2+1],0,0].forEach((v,k)=>vb.writeFloatLE(v,i*44+28+k*4));
 }
 chunks.push(vb);u(1,g.idx.length,4);const ib=Buffer.alloc(g.idx.length*4);
 if(g.lines)g.idx.forEach((v,i)=>ib.writeUInt32LE(v,i*4));
 else for(let i=0;i<g.idx.length;i+=3)[g.idx[i],g.idx[i+2],g.idx[i+1]].forEach((v,k)=>ib.writeUInt32LE(v,(i+k)*4));
 chunks.push(ib);u(1,0,1);f(0);u(g.lines?1:0,0,0,0,g.idx.length);u(0,0);f(...lo,...hi);f(...lo.map((v,i)=>(v+hi[i])/2));
 return g.lines?Buffer.concat(chunks):optimize(Buffer.concat(chunks));
}
(async()=>{
 const server=http.createServer(async(req,res)=>{
  const url=new URL(req.url,'http://local');
  if(url.pathname==='/migration/salvage-export.js'){
   res.setHeader('Content-Type','text/javascript');fs.createReadStream(path.join(__dirname,'salvage-export.mjs')).pipe(res);return;
  }
  if(url.pathname==='/migration.html'){
   res.setHeader('Content-Type','text/html');res.end('<script type="importmap">{"imports":{"three":"/three/vendor/three/build/three.module.js","three/addons/":"/three/vendor/three/addons/","@shared/":"/shared/"}}</script>');return;
  }
  if(req.method==='POST'&&url.pathname==='/convert'){
   try{
    const buffers=[];for await(const b of req)buffers.push(b);const g=JSON.parse(Buffer.concat(buffers));
    if(!['Warehouse','Salvage','Story'].includes(g.folder))throw Error('Invalid output');
    const out=path.join(root,'assets',g.folder);fs.mkdirSync(out,{recursive:true});
    const name=(g.name||(g.folder==='Salvage'?'run-model-':'model-')+g.index)+'.bin',bytes=model(g);fs.writeFileSync(path.join(out,name),bytes);
    res.end(JSON.stringify({model:g.folder+'/'+name,material:g.material,shadow:g.shadow,triangles:g.idx.length/3,bytes:bytes.length}));
   }catch(e){res.writeHead(500);res.end(String(e));}return;
  }
  const file=path.resolve(source,'.'+decodeURIComponent(url.pathname));
  if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||fs.statSync(file).isDirectory()){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',path.extname(file)==='.js'?'text/javascript':'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const browser=await chromium.launch({headless:true,channel:'chrome'});
 try{
  const page=await browser.newPage();page.on('console',m=>console.log(m.text()));page.on('pageerror',e=>console.error(e));
  await page.goto('http://127.0.0.1:'+server.address().port+'/migration.html');
  const result=await page.evaluate(async(selected)=>{
   const T=await import('three');const scenes={};
   if(!selected||selected==='Warehouse'){
   const {Warehouse}=await import('/three/src/scene/warehouse.js');const wh=new Warehouse(new T.Scene());wh.setActive(true);wh.update(0,0);
   const {STARTER_CAR,STASH_CELLS}=await import('/shared/salvage/stash.js');
   wh.deck.top.material.name='WarehouseDeck';
   scenes.Warehouse={group:wh.group,lights:[],limit:wh.cameraLimit,starter:{...STARTER_CAR.source,name:STARTER_CAR.name},stashCells:STASH_CELLS};
   }
   if(!selected||selected==='Salvage'){
   scenes.Salvage=await (await import('/migration/salvage-export.js')).build();
   }
   if(selected==='Story'){
    const {StoryHolo,prepareTerrain}=await import('/three/src/ui/storyHolo.js');
    await prepareTerrain();
    const canvas=document.createElement('canvas');canvas.style='width:1920px;height:1080px';document.body.appendChild(canvas);
    const holo=new StoryHolo(canvas);await holo.loadModels();
    if(!holo.models)throw Error('Frozen story models failed to load');
    const {STORY_LEVELS}=await import('/shared/story/chapter1.js');
    scenes.Story={group:holo.scene,lights:[],levels:[]};
    for(const lv of STORY_LEVELS){
     holo.setLevel(lv);holo.level.updateMatrixWorld(true);
     const entries=[];
     holo.level.traverse(o=>{if(o.isMesh){o.userData.storyLevel=lv.no;entries.push(o.clone());}});
     scenes.Story.levels.push({no:lv.no,marks:holo.marks.map(m=>({label:m.label,kind:m.kind,position:m.top.toArray()}))});
     for(const o of entries)holo.scene.add(o);
    }
    holo.scene.remove(holo.level);
   }
   const output={};
   for(const [folder,scene] of Object.entries(scenes)){
    const textures=[],materials=[],matIds=new Map(),texIds=new Map(),batches=new Map();scene.group.updateMatrixWorld(true);
    function texture(t){
     if(!t)return null;if(texIds.has(t.uuid))return texIds.get(t.uuid);
     const c=document.createElement('canvas'),im=t.image;const max=1024;
     if(!im)return null;
     if(im.data){c.width=im.width;c.height=im.height;const ctx=c.getContext('2d'),pixels=ctx.createImageData(im.width,im.height);for(let i=0;i<pixels.data.length;i++)pixels.data[i]=im.data[i];ctx.putImageData(pixels,0,0);}
     else {const scale=Math.min(1,max/Math.max(im.width,im.height));c.width=Math.max(1,Math.round(im.width*scale));c.height=Math.max(1,Math.round(im.height*scale));c.getContext('2d').drawImage(im,0,0,c.width,c.height);}
     const id=textures.length;textures.push(c.toDataURL('image/png'));texIds.set(t.uuid,id);return id;
    }
    function material(m){
     if(matIds.has(m.uuid))return matIds.get(m.uuid);
     const id=materials.length;matIds.set(m.uuid,id);
     const ground=m.customProgramCacheKey?.()==='salvage-ground-v4';
     const beam=m.isShaderMaterial&&m.uniforms?.uColor;
     const color=m.color?.toArray()||beam?.value.toArray()||[.12,.15,.18];
     const fs=m.fragmentShader||'';
     const story=folder!=='Story'?null:fs.includes('float edge =')?'Terrain':fs.includes('float fine =')?'Floor':fs.includes('float rim =')?'Shell':fs.includes('gl_FragColor = vec4( 0.0 )')?'Depth':fs.includes('uLen')?'Dash':fs.includes('vUv.y')?'Beam':'Solid';
     materials.push({name:m.name||m.type,color,emission:m.emissive?.clone().multiplyScalar(m.emissiveIntensity||0).toArray()||[0,0,0],roughness:m.roughness??.8,metallic:m.metalness||0,opacity:m.opacity??1,unlit:m.isMeshBasicMaterial||m.isShaderMaterial,double:m.side===T.DoubleSide,map:texture(m.map),ground,matTexture:ground?texture(m.userData.uniforms.uMat.value):null,story,len:m.uniforms?.uLen?.value||0,order:m.colorWrite===false?10:0});return id;
    }
    function add(o,matrix){
     if(!o.geometry.attributes.position)return;
     const groups=o.geometry.groups.length?o.geometry.groups:[{start:0,count:o.geometry.index?.count||o.geometry.attributes.position.count,materialIndex:0}];
     const source=o.geometry;const g=source.clone();g.applyMatrix4(matrix);if(!g.attributes.normal)g.computeVertexNormals();
     const pos=new T.Vector3().setFromMatrixPosition(matrix),bucket=folder==='Warehouse'?16:256;
     for(const group of groups){
      const m=Array.isArray(o.material)?o.material[group.materialIndex]:o.material;if(m.visible===false)continue;
      const mi=material(m),key=[mi,Math.floor(pos.x/bucket),Math.floor(pos.z/bucket),o.userData.storyLevel||''].join(':');
      if(!batches.has(key))batches.set(key,{folder,material:mi,level:o.userData.storyLevel,shadow:o.castShadow,p:[],n:[],c:[],uv:[],idx:[]});
      const b=batches.get(key),remap=new Map();const count=Math.min(group.count,(g.index?.count||g.attributes.position.count)-group.start);
      for(let j=0;j<count;j++){
       const i=g.index?g.index.getX(group.start+j):group.start+j;
       if(!remap.has(i)){
        remap.set(i,b.p.length/3);for(const a of ['p','n']){const at=g.attributes[a==='p'?'position':'normal'];b[a].push(at.getX(i),at.getY(i),at.getZ(i));}
        const uv=g.attributes.uv;b.uv.push(uv?.getX(i)||0,uv?.getY(i)||0);
        const c=g.attributes.color,ic=o.userData.migrationInstanceColor;
        b.c.push((c?.getX(i)??1)*(ic?.r??1),(c?.getY(i)??1)*(ic?.g??1),(c?.getZ(i)??1)*(ic?.b??1),1);
       }b.idx.push(remap.get(i));
      }
     }g.dispose();
    }
    scene.group.traverse(o=>{
     if(o.isLight){const p=new T.Vector3().setFromMatrixPosition(o.matrixWorld);const target=o.target?new T.Vector3().setFromMatrixPosition(o.target.matrixWorld):null;scene.lights.push({type:o.type,color:o.color.toArray(),intensity:o.intensity,position:p.toArray(),target:target?.toArray(),direction:o.getWorldDirection(new T.Vector3()).toArray(),range:o.distance||100,angle:o.angle,penumbra:o.penumbra,width:o.width,height:o.height,shadow:o.castShadow});return;}
     if(o.isLineSegments2){
      const start=o.geometry.attributes.instanceStart,end=o.geometry.attributes.instanceEnd;
      const mi=material(o.material);materials[mi].story='Edges';materials[mi].order=12;
      const b={folder,material:mi,shadow:false,lines:true,p:[],n:[],c:[],uv:[],idx:[]};
      const p=new T.Vector3();
      for(let i=0;i<start.count;i++)for(const at of [start,end]){
       p.fromBufferAttribute(at,i).applyMatrix4(o.matrixWorld);b.idx.push(b.p.length/3);b.p.push(...p.toArray());b.n.push(0,1,0);b.c.push(1,1,1,1);b.uv.push(0,0);
      }
      batches.set('edges:'+mi,b);return;
     }
     if(!o.isMesh)return;
     for(let parent=o;parent;parent=parent.parent)if(parent.visible===false)return;
     if(o.isInstancedMesh){const im=new T.Matrix4();for(let i=0;i<o.count;i++){o.getMatrixAt(i,im);if(o.instanceColor){const c=new T.Color();o.getColorAt(i,c);o.userData.migrationInstanceColor=c;}add(o,new T.Matrix4().multiplyMatrices(o.matrixWorld,im));}delete o.userData.migrationInstanceColor;}
     else add(o,o.matrixWorld);
    });
    const models=[];let index=0;
    for(const g of batches.values()){
     g.index=index++;const response=await fetch('/convert',{method:'POST',body:JSON.stringify(g)});if(!response.ok)throw Error(await response.text());models.push({...await response.json(),level:g.level});
    }
    output[folder]={materials,textures,models,lights:scene.lights,limit:scene.limit,terrain:scene.terrain,levels:scene.levels,starter:scene.starter,stashCells:scene.stashCells};console.log(folder+' converted '+models.length+' batches');
    if(scene.salvage)output[folder].salvage=await scene.salvage(material);
   }return output;
  },process.env.VOX_EXPORT_SCENE||'');
  fs.writeFileSync(path.join(root,'.tmp/outgame-scenes-export.json'),JSON.stringify(result));
  for(const [folder,data] of Object.entries(result)){
   const out=path.join(root,'assets',folder);
   data.textures.forEach((t,i)=>fs.writeFileSync(path.join(out,'texture-'+i+'.png'),Buffer.from(t.split(',')[1],'base64')));delete data.textures;
   if(data.salvage){
    const s=data.salvage;const height=Buffer.alloc(20+s.heights.length*4);height.write('VHF1');height.writeUInt32LE(s.n,4);
    [-s.size/2,-s.size/2,s.size/s.n].forEach((v,i)=>height.writeFloatLE(v,8+i*4));s.heights.forEach((v,i)=>height.writeFloatLE(v,20+i*4));
    fs.writeFileSync(path.join(out,'Height.bin'),height);delete s.heights;
    fs.writeFileSync(path.join(out,'Gameplay.json'),JSON.stringify(s.gameplay));delete s.gameplay;
    fs.writeFileSync(path.join(out,'RunData.json'),JSON.stringify(s.rules));delete s.rules;
    fs.writeFileSync(path.join(out,'Physics.json'),JSON.stringify(s));delete data.salvage;
   }
   fs.writeFileSync(path.join(out,folder==='Salvage'?'RunManifest.json':'Manifest.json'),JSON.stringify(data));
   console.log(folder,JSON.stringify({models:data.models.length,materials:data.materials.length,triangles:data.models.reduce((n,m)=>n+m.triangles,0),MB:data.models.reduce((n,m)=>n+m.bytes,0)/1024/1024}));
  }
 }finally{await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

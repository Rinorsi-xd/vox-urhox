// Convert the source TrackView and its canvas textures. Source checkout is read-only.
const fs=require('fs'),path=require('path'),http=require('http'),crypto=require('node:crypto');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const source=path.resolve(process.argv[2]||'D:/Rino_Project/Vox'),root=path.resolve(__dirname,'../..');
const out=path.join(root,'assets/Track');
const isolatedArg=process.argv.find(arg=>arg.startsWith('--output='));
const destination=isolatedArg?path.resolve(isolatedArg.slice('--output='.length)):out;
if(isolatedArg&&destination===out)throw Error('Isolated output must differ from runtime assets/Track');
if(isolatedArg&&fs.existsSync(destination)&&fs.readdirSync(destination).length)throw Error('Isolated output must be empty to exclude stale exports');
fs.mkdirSync(destination,{recursive:true});
const dependencies=new Map(),sha256=body=>crypto.createHash('sha256').update(body).digest('hex');
function mdl(g){
 const chunks=[],u=(...a)=>{const b=Buffer.alloc(a.length*4);a.forEach((v,i)=>b.writeUInt32LE(v,i*4));chunks.push(b);},f=(...a)=>{const b=Buffer.alloc(a.length*4);a.forEach((v,i)=>b.writeFloatLE(v,i*4));chunks.push(b);};
 const n=g.p.length/3,ix=g.idx,lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];
 chunks.push(Buffer.from('UMDL'));u(1,n,11,0,0);const vb=Buffer.alloc(n*32);
 for(let i=0;i<n;i++){const p=[-g.p[i*3],g.p[i*3+1],g.p[i*3+2]];p.forEach((v,k)=>{lo[k]=Math.min(lo[k],v);hi[k]=Math.max(hi[k],v);});[...p,-g.n[i*3],g.n[i*3+1],g.n[i*3+2],g.uv[i*2]||0,1-(g.uv[i*2+1]||0)].forEach((v,k)=>vb.writeFloatLE(v,i*32+k*4));}
 chunks.push(vb);u(1,ix.length,4);const ib=Buffer.alloc(ix.length*4);
 for(let i=0;i<ix.length;i+=3)[ix[i],ix[i+2],ix[i+1]].forEach((v,k)=>ib.writeUInt32LE(v,(i+k)*4));
 chunks.push(ib);u(1,0,1);f(0);u(0,0,0,0,ix.length);u(0,0);f(...lo,...hi);f(...lo.map((v,i)=>(v+hi[i])/2));return Buffer.concat(chunks);
}
(async()=>{
 const server=http.createServer((req,res)=>{
  if(req.url==='/migration.html'){res.setHeader('Content-Type','text/html');res.end('<script type="importmap">{"imports":{"three":"/three/vendor/three/build/three.module.js","@shared/":"/shared/"}}</script>');return;}
  const file=path.resolve(source,'.'+decodeURIComponent(new URL(req.url,'http://local').pathname));
  if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||fs.statSync(file).isDirectory()){res.writeHead(404).end();return;}
  dependencies.set(path.relative(source,file).replaceAll('\\','/'),sha256(fs.readFileSync(file)));
  res.setHeader('Content-Type',path.extname(file)==='.js'?'text/javascript':'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const browser=await chromium.launch({headless:true,channel:'msedge'});
 try{
  const page=await browser.newPage();await page.goto('http://127.0.0.1:'+server.address().port+'/migration.html');
  const result=await page.evaluate(async()=>{
   const THREE=await import('three'),{TrackView}=await import('/three/src/drive/trackView.js'),{buildTrackLayout}=await import('/shared/drive/track.js'),{concreteDetail}=await import('/shared/scene/textures.js');
   const font=new FontFace('GameFont','url(/shared/fonts/ZCOOLQingKeHuangYou-Regular.woff2)');await font.load();document.fonts.add(font);
   const layout=buildTrackLayout(),renderer=new THREE.WebGLRenderer(),view=new TrackView(renderer,layout,{cones:[{}],targets:[{}]},concreteDetail());
   const materials=[],textures=[],texMap=new Map(),materialKeys=new Map();
   function texture(t){if(!t)return null;if(!texMap.has(t.image)){const c=document.createElement('canvas');c.width=t.image.width;c.height=t.image.height;c.getContext('2d').drawImage(t.image,0,0);texMap.set(t.image,textures.length);textures.push(c.toDataURL('image/png'));}return {id:texMap.get(t.image),repeat:t.repeat.toArray()};}
   function material(m,order){
    const data={color:m.color?.toArray()||[1,1,1],rough:m.roughness??1,metal:m.metalness||0,opacity:m.opacity,unlit:!!m.isMeshBasicMaterial,emission:m.emissive?.getHex()>0?(m.emissiveIntensity||0):0,map:texture(m.map),normal:texture(m.normalMap),normalScale:m.normalMap?(m.normalScale?.x||0):0,roughMap:texture(m.roughnessMap),alpha:m.transparent,depthWrite:m.depthWrite,order};
    const key=JSON.stringify(data);if(!materialKeys.has(key)){materialKeys.set(key,materials.length);materials.push(data);}return materialKeys.get(key);
   }
   function collect(root,skip=new Set()){
    const batches=new Map();root.updateMatrixWorld(true);const inv=root.matrixWorld.clone().invert();
    root.traverse(o=>{if(!o.isMesh||o.material.isShaderMaterial)return;for(let p=o;p;p=p.parent)if(skip.has(p))return;
     const g=o.geometry.clone().applyMatrix4(inv.clone().multiply(o.matrixWorld)),mats=Array.isArray(o.material)?o.material:[o.material];
     const groups=g.groups.length?g.groups:[{start:0,count:g.index?g.index.count:g.attributes.position.count,materialIndex:0}];
     for(const group of groups){const mi=material(mats[Array.isArray(o.material)?group.materialIndex:0],o.renderOrder);
      const pos=new THREE.Vector3().setFromMatrixPosition(o.matrixWorld),key=[mi,Math.floor(pos.x/32),Math.floor(pos.z/32),o.castShadow].join(':');
      if(!batches.has(key))batches.set(key,{material:mi,shadow:o.castShadow,p:[],n:[],uv:[],idx:[]});const b=batches.get(key),remap=new Map();
      const ix=g.index?Array.from(g.index.array).slice(group.start,group.start+group.count):Array.from({length:group.count},(_,i)=>group.start+i);
      for(const i of ix){if(!remap.has(i)){remap.set(i,b.p.length/3);b.p.push(...g.attributes.position.array.slice(i*3,i*3+3));b.n.push(...g.attributes.normal.array.slice(i*3,i*3+3));b.uv.push(...(g.attributes.uv?.array.slice(i*2,i*2+2)||[0,0]));}b.idx.push(remap.get(i));}
     }
    });return [...batches.values()];
   }
   const cone=view.cones[0],target=view.targets[0];
   const statics=collect(view.scene,new Set([cone,target.root]));
   const cones=collect(cone),targetBase=collect(target.root,new Set([target.pivot,target.bar])),targetBoard=collect(target.pivot);
   renderer.dispose();return {layout,materials,textures,statics,cones,targetBase,targetBoard};
  });
  result.textures.forEach((t,i)=>fs.writeFileSync(path.join(destination,'texture-'+i+'.png'),Buffer.from(t.split(',')[1],'base64')));delete result.textures;
  let count=0,vertices=0,triangles=0;
  for(const key of ['statics','cones','targetBase','targetBoard'])result[key]=result[key].map(g=>{const name='model-'+count+++'.mdl';vertices+=g.p.length/3;triangles+=g.idx.length/3;fs.writeFileSync(path.join(destination,name),mdl(g));return {model:'Track/'+name,material:g.material+1,shadow:g.shadow};});
  for(const m of result.materials)for(const key of ['map','normal','roughMap'])if(m[key])m[key].path='Track/texture-'+m[key].id+'.png';
  fs.writeFileSync(path.join(destination,'Manifest.json'),JSON.stringify(result));
  const report={source,models:count,vertices,triangles,materials:result.materials.length,blocks:result.layout.blocks.length,signs:result.layout.signs.length};
  if(isolatedArg){
   const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
   const inputs=[...dependencies].map(([file,hash])=>({file,sha256:hash,baselineMatches:baseline.files[file]?.sha256===hash}));
   if(!inputs.length||inputs.some(input=>!input.baselineMatches))throw Error('Export dependencies differ from frozen baseline');
   const outputs=fs.readdirSync(destination).filter(file=>file!=='provenance.json').map(file=>{
    const body=fs.readFileSync(path.join(destination,file)),target=path.join(out,file),digest=sha256(body);
    return {file:'Track/'+file,sha256:digest,bytes:body.length,status:!fs.existsSync(target)?'MISSING_TARGET':sha256(fs.readFileSync(target))===digest?'DERIVED_BASELINE_MATCH':'DERIVED_BASELINE_DIFF'};
   });
   fs.writeFileSync(path.join(destination,'provenance.json'),JSON.stringify({sourceCommit:baseline.commit,source,converter:'tools/migration/export-track.cjs',converterSha256:sha256(fs.readFileSync(__filename)),inputs,outputs,acceptance:'Independent isolated export. Does not verify compiled materials, collision, rendering or gameplay parity.'},null,2));
   console.log(JSON.stringify({...report,destination,inputs:inputs.length,outputs:outputs.reduce((a,o)=>(a[o.status]=(a[o.status]||0)+1,a),{})}));
  }else fs.writeFileSync(path.join(root,'docs/migration/evidence/track-import.json'),JSON.stringify(report,null,2));
 }finally{await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

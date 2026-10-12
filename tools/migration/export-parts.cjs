// Offline source conversion. Execute original engine-independent model loaders.
// Node 24+; no browser, network requests, or runtime Three.js dependency.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {pathToFileURL,fileURLToPath}=require('node:url');
const {registerHooks}=require('node:module');
const args=process.argv.slice(2),apply=args.includes('--apply');
const source=path.resolve(args.find(x=>!x.startsWith('--'))||'D:/Rino_Project/Vox');
const target=path.resolve(__dirname,'../..'),destination=path.join(target,'assets/Parts');
fs.mkdirSync(path.join(target,'.tmp'),{recursive:true});
const out=fs.mkdtempSync(path.join(target,'.tmp/source-parts-'));
fs.mkdirSync(path.join(out,'Models'));fs.mkdirSync(path.join(out,'Rigs'));
const written=new Set(),counts={models:0,vertices:0,triangles:0,bytes:0};
const sources=new Map(),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function remember(filename){
 const relative=path.relative(source,filename).replaceAll('\\','/');
 if(relative.startsWith('../')||path.isAbsolute(relative))throw Error('Source outside checkout: '+filename);
 const data=fs.readFileSync(filename),hash=sha(data);
 if(sources.has(relative)&&sources.get(relative)!==hash)throw Error('Source changed during export: '+relative);
 sources.set(relative,hash);return data;
}
registerHooks({resolve(specifier,context,next){
 if(specifier==='three')specifier=pathToFileURL(path.join(source,'three/vendor/three/build/three.module.js')).href;
 else if(specifier.startsWith('@shared/'))specifier=pathToFileURL(path.join(source,'shared',specifier.slice(8))).href;
 const result=next(specifier,context);
 if(result.url.startsWith('file:')){
  const file=fileURLToPath(result.url);
  if(file.startsWith(source+path.sep))remember(file);
 }
 return result;
}});
const load=p=>import(pathToFileURL(path.join(source,p)).href);
function glb(folder,file){
 const bytes=remember(path.resolve(source,'shared/assets',folder,file));
 return bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength);
}
function weld(g){
 const p=[],n=[],uv=[],idx=[],seen=new Map();
 for(const i of g.idx||Array.from({length:g.p.length/3},(_,i)=>i)){
  const v=[...g.p.slice(i*3,i*3+3),...g.n.slice(i*3,i*3+3),g.uv?.[i*2]||0,g.uv?.[i*2+1]||0].map(Math.fround);
  const key=v.join(',');let j=seen.get(key);
  if(j===undefined){j=p.length/3;seen.set(key,j);p.push(...v.slice(0,3));n.push(...v.slice(3,6));uv.push(...v.slice(6));}idx.push(j);
 }return {p,n,uv,idx};
}
function model(entries){
 entries=entries.map(([s,g])=>[s,weld(g)]);
 const chunks=[],u=(...a)=>{const b=Buffer.alloc(a.length*4);a.forEach((v,i)=>b.writeUInt32LE(v,i*4));chunks.push(b);},f=(...a)=>{const b=Buffer.alloc(a.length*4);a.forEach((v,i)=>b.writeFloatLE(v,i*4));chunks.push(b);};
 const lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];
 chunks.push(Buffer.from('UMDL'));u(entries.length);
 for(const [,g]of entries){
  const n=g.p.length/3;u(n,11,0,0);const b=Buffer.alloc(n*32);
  for(let i=0;i<n;i++){
   const p=[-g.p[i*3],g.p[i*3+1],g.p[i*3+2]];
   p.forEach((v,k)=>{lo[k]=Math.min(lo[k],v);hi[k]=Math.max(hi[k],v);});
   [...p,-g.n[i*3],g.n[i*3+1],g.n[i*3+2],g.uv?.[i*2]||0,1-(g.uv?.[i*2+1]||0)].forEach((v,k)=>b.writeFloatLE(v,i*32+k*4));
  }chunks.push(b);
 }
 u(entries.length);const sizes=[];
 for(const [,g]of entries){
  const idx=g.idx;const stride=g.p.length/3>65535?4:2;sizes.push(idx.length);u(idx.length,stride);
  const b=Buffer.alloc(idx.length*stride);for(let i=0;i<idx.length;i+=3)[idx[i],idx[i+2],idx[i+1]].forEach((v,k)=>stride===4?b.writeUInt32LE(v,(i+k)*stride):b.writeUInt16LE(v,(i+k)*stride));chunks.push(b);
 }
 u(entries.length);for(let i=0;i<entries.length;i++){u(0,1);f(0);u(0,i,i,0,sizes[i]);}
 u(0,0);f(...lo,...hi);for(const e of entries)f(...lo.map((v,i)=>(v+hi[i])/2));
 const buffer=Buffer.concat(chunks),hash=crypto.createHash('sha256').update(buffer).digest('hex').slice(0,24),name='Models/'+hash+'.mdl';
 if(!written.has(name)){fs.writeFileSync(path.join(out,name),buffer);written.add(name);counts.models++;counts.bytes+=buffer.length;counts.vertices+=entries.reduce((s,[,g])=>s+g.p.length/3,0);counts.triangles+=sizes.reduce((s,n)=>s+n/3,0);}
 return 'Parts/'+name;
}
const noShadow=new Set(['beamCyan','beamOrange','beamPaint','holoPaint']);
function convert(v){
 if(!v||typeof v!=='object')return v;
 if(Array.isArray(v))return v.map(convert);
 const entries=Object.entries(v);
 if(entries.length&&entries.every(([,g])=>g&&Array.isArray(g.p)&&Array.isArray(g.n))){
  return {layers:[false,true].flatMap(no=>{const es=entries.filter(([s,g])=>noShadow.has(s)===no&&g.p.length);return es.length?[{model:model(es),slots:es.map(([s])=>s),shadow:!no}]:[];})};
 }
 return Object.fromEntries(entries.map(([k,x])=>[k,convert(x)]));
}
function save(name,v){fs.writeFileSync(path.join(out,name),JSON.stringify(v));}
(async()=>{
 const d=await load('shared/parts/defs.js'),r=await load('shared/core/rotations.js');
 const {Blueprint}=await load('shared/build/blueprint.js'),p=await load('shared/build/prefab.js');
 const cfg=await load('shared/config.js');
 for(const [kind,table,folder] of [['Weapon','WEAPON_GLB','weapons'],['Wheel','WHEEL_GLB','wheels'],
   ['Track','TRACK_GLB','tracks'],['Thruster','THRUSTER_GLB','thrusters'],['Leg','LEG_GLB','legs'],
   ['Wing','WING_GLB','wings'],['Mech','MECH_GLB','mechlegs']]){
  const { [table]: entries }=await load('shared/parts/'+kind.toLowerCase()+'Data.js');
  const {[`register${kind}GLB`]:register}=await load('shared/parts/'+kind.toLowerCase()+'Models.js');
  for(const [id,info] of Object.entries(entries))register(id,glb(folder,info.file));
 }
 const {HOVER_GLB}=await load('shared/parts/hoverData.js');
 const {registerHoverGLB}=await load('shared/parts/hoverModels.js');
 for(const [id,variants] of Object.entries(HOVER_GLB))for(const [mount,info] of Object.entries(variants))registerHoverGLB(id,mount,glb('hovers',info.file));
 for(const [kind,folder,file] of [['Rotor','rotor','rotor.glb'],['Plate','plates','plates.glb'],['Scorpion','scorpion','scorpion.glb']]){
  const module=await load('shared/parts/'+kind.toLowerCase()+'Models.js');module['register'+kind+'GLB'](glb(folder,file));
 }
 const presets={};
 const planes=await load('shared/build/planePrefab.js'),vanguard=await load('shared/build/vanguard.js');
 const builders={...p,...planes,...vanguard};
 for(const name of ['buildRaceCar','buildEmpty','buildMegaMech','buildScorpion','buildHawk','buildFeather','buildVanguard','buildDrillTank','buildFuyuanTank','buildGruntOne','buildFuyuanGrunt']){
  const bp=builders[name](new Blueprint());presets[name]={name:bp.name,parts:[...bp.parts.values()].map(({type,pos,rot,color,shellColor,scale,g})=>({type,pos,rot,color,...(shellColor!=null?{shellColor}:{}),...(scale?{scale}:{}),...(g?{g}:{})}))};
 }
 const {MATS}=await load('three/src/parts/materials.js');
 const materials=Object.fromEntries(Object.entries(MATS).filter(([,m])=>m.color).map(([k,m])=>[k,{color:m.color.toArray(),emission:m.emissive?.toArray(),intensity:m.emissiveIntensity||0,rough:m.roughness,metal:m.metalness,coat:m.clearcoat||0,coatRough:m.clearcoatRoughness||0}]));
 const catalog={parts:d.PART_LIST,categories:d.CATEGORIES,retired:d.RETIRED_TYPES,presets,materials,rotations:r.ROTATIONS.map(x=>x.m),tiers:cfg.TIERS,cell:cfg.CELL,build:cfg.BUILD,mapClearance:cfg.MAP_CLEARANCE};
 save('Catalog.json',catalog);
 const ids=catalog.parts.map(x=>x.id);ids.push(...catalog.parts.filter(x=>x.hover).map(x=>x.id+'Side'));
 const manifest={source,exportedAt:new Date().toISOString(),converter:'offline-node24',parts:[],counts};
 const {getModel,getModelSegments}=await load('shared/parts/models.js');
 const {Geo}=await load('shared/parts/geo.js');
 const {WEAPON_GLB}=await load('shared/parts/weaponData.js'),{WHEEL_GLB}=await load('shared/parts/wheelData.js');
 const clean=v=>{
  if(v instanceof Geo)return {p:Array.from(v.position),n:Array.from(v.normal),uv:v.uv?Array.from(v.uv):null,idx:v.idx?Array.from(v.idx):null};
  if(ArrayBuffer.isView(v))return Array.from(v);
  if(Array.isArray(v))return v.map(clean);
  if(v&&typeof v==='object')return Object.fromEntries(Object.entries(v).filter(([,v])=>typeof v!=='function').map(([k,v])=>[k,clean(v)]));
  return v;
 };
 for(const id of ids){
  if(!/^[a-zA-Z0-9_]+$/.test(id))throw Error('Invalid part ID: '+id);
  const data=clean({whole:getModel(id),segments:getModelSegments(id),weapon:WEAPON_GLB[id],wheel:WHEEL_GLB[id]});
  save('Rigs/'+id+'.json',convert(data));manifest.parts.push({id,path:'Parts/Rigs/'+id+'.json'});
 }
 // Motion distances must be imported with the geometry they animate. Keeping
 // these in a test generator left stale scales after the last model resync.
 const {sizeProfile}=await load('shared/parts/modelSizing.js');
 const weaponMotion={};
 for(const id of Object.keys(WEAPON_GLB)){
  const rig=JSON.parse(fs.readFileSync(path.join(out,'Rigs/'+id+'.json')));
  const z0=Math.min(...rig.whole.layers.map(layer=>{
   const buffer=fs.readFileSync(path.join(out,layer.model.replace(/^Parts\//,'')));
   return buffer.readFloatLE(buffer.length-12*layer.slots.length-24+8);
  }));
  weaponMotion[id]={motionScale:sizeProfile(id)?.motionScale||[1,1,1],z0};
 }
 save('WeaponMotion.json',weaponMotion);
 const {partMasks}=await load('shared/parts/solid.js');
 const masks=Object.fromEntries(d.PART_LIST.filter(d=>d.shape||d.wheel).map(d=>[d.id,Array.from({length:24},(_,r)=>(partMasks(d.id,r)||[]).map(({c,mask})=>({c,mask:mask.toString(16).padStart(16,'0')})))]));
 save('SolidMasks.json',masks);save('HoverMounts.json',HOVER_GLB);
 const {LEG_GLB}=await load('shared/parts/legData.js');
 const {partZone}=await load('shared/build/zones.js');
 const zones=Object.fromEntries(d.PART_LIST.filter(p=>p.thruster||p.hover).map(p=>[p.id,Array.from({length:24},(_,rotation)=>partZone(p.id,[0,0,0],rotation))]));
 save('BuildRules.json',{retiredWheels:[...d.RETIRED_WHEELS],blockMaterials:d.BLOCK_MATS,legStances:Object.fromEntries(Object.entries(LEG_GLB).map(([k,v])=>[k,v.stanceCells])),zones});
 const {TRACK_GLB}=await load('shared/parts/trackData.js'),{THRUSTER_GLB}=await load('shared/parts/thrusterData.js');
 const {thrusterPivot}=await load('shared/parts/thrusterMount.js'),{HOVER_MIN_UP}=await load('shared/parts/hoverMount.js');
 const pick=(v,keys)=>Object.fromEntries(keys.map(k=>[k,v[k]]));
 const drive={rotations:r.ROTATIONS.map(r=>pick(r.quat,['x','y','z','w'])),
  wheels:Object.fromEntries(Object.entries(WHEEL_GLB).map(([id,g])=>[id,{r:g.r,cy:g.hub[1],w:g.w}])),
  tracks:Object.fromEntries(Object.entries(TRACK_GLB).map(([id,g])=>[id,pick(g,['cells','wheels','lanes','hull','thickness'])])),
  thrusters:Object.fromEntries(Object.entries(THRUSTER_GLB).map(([id,g])=>[id,{nozzles:g.nozzles,pivot:thrusterPivot(g)}])),
  legs:Object.fromEntries(Object.entries(LEG_GLB).map(([id,g])=>[id,{toe:g.origins.toe,lengths:g.lengths,bounds:g.bounds}])),hoverMinUp:HOVER_MIN_UP};
 save('DriveGeometry.json',drive);
 manifest.driveGeometry={path:'Drive/Geometry.json',sha256:sha(fs.readFileSync(path.join(out,'DriveGeometry.json')))};
 manifest.models=[...written].map(name=>'Parts/'+name);
 for(const filename of sources.keys())remember(path.join(source,filename));
 manifest.sourceHashes=Object.fromEntries([...sources].sort());
 const files=['Catalog.json','SolidMasks.json','HoverMounts.json','BuildRules.json','WeaponMotion.json',...ids.map(id=>'Rigs/'+id+'.json'),...written];
 manifest.files=Object.fromEntries(files.map(name=>[name,{sha256:sha(fs.readFileSync(path.join(out,name))),bytes:fs.statSync(path.join(out,name)).size}]));
 // Check every model reference before applying any files to the active project.
 for(const id of ids){
  const text=fs.readFileSync(path.join(out,'Rigs/'+id+'.json'),'utf8');
  for(const match of text.matchAll(/"model":"Parts\/(Models\/[a-f0-9]{24}\.mdl)"/g))if(!written.has(match[1]))throw Error('Unresolved model: '+match[1]);
 }
 const changes=files.filter(name=>!fs.existsSync(path.join(destination,name))||sha(fs.readFileSync(path.join(destination,name)))!==manifest.files[name].sha256);
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2));
 if(apply){
  // Originals are staged completely first; write only changed files and keep .meta identities.
  for(const name of changes){const dest=path.join(destination,name);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(out,name),dest);}
  const driveFile=path.join(target,'assets/Drive/Geometry.json');
  fs.mkdirSync(path.dirname(driveFile),{recursive:true});
  if(!fs.existsSync(driveFile)||sha(fs.readFileSync(driveFile))!==manifest.driveGeometry.sha256)fs.copyFileSync(path.join(out,'DriveGeometry.json'),driveFile);
  const external=[];
  for(const base of ['scripts','assets'])for(const item of fs.readdirSync(path.join(target,base),{recursive:true,withFileTypes:true})){
   if(!item.isFile()||!/[.](lua|xml|json)$/.test(item.name))continue;
   const file=path.join(item.parentPath,item.name);
   if(file.startsWith(path.join(destination,'Rigs')+path.sep)||file.startsWith(path.join(destination,'Models')+path.sep))continue;
   external.push(fs.readFileSync(file,'utf8'));
  }
  const referenced=external.join('\n');manifest.removedModels=[];
  for(const name of fs.readdirSync(path.join(destination,'Models'))){
   if(!/^[a-f0-9]{24}\.mdl$/.test(name)||written.has('Models/'+name)||referenced.includes('Parts/Models/'+name))continue;
   fs.unlinkSync(path.join(destination,'Models',name));
   if(fs.existsSync(path.join(destination,'Models',name+'.meta')))fs.unlinkSync(path.join(destination,'Models',name+'.meta'));
   manifest.removedModels.push(name);
  }
  for(const [name,record]of Object.entries(manifest.files))if(sha(fs.readFileSync(path.join(destination,name)))!==record.sha256)throw Error('Import mismatch: '+name);
  fs.writeFileSync(path.join(target,'docs/migration/parts-manifest.json'),JSON.stringify(manifest,null,2));
 }
 console.log(JSON.stringify({applied:apply,staging:out,parts:catalog.parts.length,variants:ids.length,prefabs:Object.fromEntries(Object.entries(catalog.presets).map(([k,v])=>[k,v.parts.length])),changes:changes.filter(n=>!n.startsWith('Models/')),changedModels:changes.filter(n=>n.startsWith('Models/')).length,sourceFiles:sources.size,...counts},null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});

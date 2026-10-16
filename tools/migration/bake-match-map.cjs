// Native capture/tone is shared with production. This tool only freezes inputs
// and publishes the exact lossless output after pixel and provenance checks.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),metaPath=path.join(root,'assets/Crater/Minimap.json');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=p=>fs.readFileSync(path.join(root,p));
const exists=p=>fs.existsSync(path.join(root,p));
// RT disposal/GC scheduling changes neither capture pixels nor the tone curve.
// Keep their capture provenance separate from the image-content signature.
const lifetimeInputs=new Set(['scripts/render/RenderTargetLifetime.lua','scripts/core/CollectionCycle.lua']);
const dependencyPolicy='pixel-inputs-v2-lifetime-separate';
function checksum(bytes){let h=0;for(const b of bytes)h=(Math.imul(h,65599)+b)>>>0;return h;}
// Line-ending variants: this Windows workspace checks out CRLF (core.autocrlf) while the
// Maker repository and Web package carry the committed LF bytes. Runtime accepts either.
function eolVariants(bytes,own){
 const lf=bytes.toString('latin1').replace(/\r\n/g,'\n'),out=[];
 for(const text of [lf,lf.replace(/\n/g,'\r\n')]){
  const b=Buffer.from(text,'latin1'),v={bytes:b.length,checksum:checksum(b)};
  if((v.bytes!==own.bytes||v.checksum!==own.checksum)&&!out.some(o=>o.bytes===v.bytes&&o.checksum===v.checksum))out.push(v);
 }
 return out;
}
function files(dir){return fs.readdirSync(path.join(root,dir),{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(dir+'/'+e.name):[dir+'/'+e.name]);}
function inputs(){
 const selected=new Set(['assets/Scenes/Crater.xml','.cli/build.json','tools/migration/bake-match-map-runtime.lua']);
 for(const resource of JSON.parse(read('assets/Crater/Resources.json'))){
  if(exists('assets/'+resource))selected.add('assets/'+resource);
  else assert(resource==='Models/Box.mdl','Missing map input '+resource);
 }
 for(const file of files('assets/Crater'))if(!/\/Minimap(?:\.|\/)/.test(file))selected.add(file);
 const pending=['scripts/render/MatchMapShot.lua','scripts/scene/Crater.lua','scripts/drive/CraterLayout.lua'];
 while(pending.length){const file=pending.pop();if(lifetimeInputs.has(file)||selected.has(file))continue;selected.add(file);
  const source=read(file).toString('utf8');
  for(const m of source.matchAll(/require\s*(?:\(\s*)?['"]([\w./-]+)['"]/g)){
   const candidate='scripts/'+m[1].replace(/\./g,'/')+'.lua';if(exists(candidate))pending.push(candidate);
  }
 }
 return Object.fromEntries([...selected].sort().map(file=>{const b=read(file);return[file,{sha256:sha(b),bytes:b.length,checksum:checksum(b)}];}));
}
function baseline(){const b=JSON.parse(read('docs/migration/outgame-baseline.json'));return{branch:b.branch,commit:b.commit,contentSha256:b.contentSha256};}
function assert(ok,message){if(!ok)throw Error(message);}
function reclassifyLifetime(meta,current){
 assert(meta.inputSha256===sha(Buffer.from(JSON.stringify(meta.inputs))),'Original capture input manifest hash invalid');
 const content={},implementation={...meta.captureImplementationInputs},checks={...meta.runtimeChecks};
 for(const [file,value]of Object.entries(meta.inputs)){
  if(lifetimeInputs.has(file)){implementation[file]=value;delete checks[file.replace(/^scripts\//,'')];}
  else content[file]=value;
 }
 assert(JSON.stringify(content)===JSON.stringify(current),'A pixel input changed; existing image cannot be reclassified without a new capture');
 return {...meta,dependencyPolicy,captureInputSha256:meta.captureInputSha256||meta.inputSha256,
  captureImplementationInputs:implementation,inputs:content,inputSha256:sha(Buffer.from(JSON.stringify(content))),runtimeChecks:checks};
}
async function main(){const mode=process.argv[2]||'check';
 if(mode==='prepare'){
  const stamp=new Date().toISOString().replace(/[:.]/g,'-'),out='.tmp/match-map-bake-'+stamp;
  fs.mkdirSync(path.join(root,out),{recursive:true});
  const request={version:1,out,source:baseline(),inputs:inputs(),scene:'Scenes/Crater.xml',image:out+'/base.png',result:out+'/native.json',validation:out+'/validation.json',size:1024,half:320};
  fs.writeFileSync(path.join(root,'.tmp/match-map-bake-request.json'),JSON.stringify(request,null,2)+'\n');
  fs.writeFileSync(path.join(root,out+'/request.json'),JSON.stringify(request,null,2)+'\n');console.log(JSON.stringify({out,inputs:Object.keys(request.inputs).length}));return;
 }
 if(mode==='publish'){
  const request=JSON.parse(read('.tmp/match-map-bake-request.json')),actualInputs=inputs();
  assert(JSON.stringify(request.inputs)===JSON.stringify(actualInputs),'Bake inputs changed during capture');
  assert(JSON.stringify(request.source)===JSON.stringify(baseline()),'Active source changed during capture');
  const native=JSON.parse(read(request.result).toString('utf8').replace(/\0+$/,''));
  assert(native.result==='PASSED','Native bake pixel/lifecycle assertions failed');
  assert(native.textureFilter==='trilinear'&&native.textureAnisotropy===1,'Native capture filtering differs from production');
  const bytes=read(request.image),sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
  const {data,info}=await sharp(bytes).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  assert(info.width===1024&&info.height===1024,'Invalid map size');const colors=new Set();
  for(let i=0;i<data.length;i+=4){assert(data[i+3]===255,'Map alpha differs');colors.add(data.readUInt32LE(i));}
  assert(colors.size>32,'Uniform/placeholder map refused');
  const runtimeChecks={};
  for(const file of ['assets/Scenes/Crater.xml',...Object.keys(actualInputs).filter(p=>p.startsWith('scripts/'))]){
   const resource=file.replace(/^(assets|scripts)\//,'');
   runtimeChecks[resource]={checksum:actualInputs[file].checksum,bytes:actualInputs[file].bytes,variants:eolVariants(read(file),actualInputs[file])};
  }
  for(const [file,value]of Object.entries(native.checksums))assert(runtimeChecks[file]?.checksum===value,'Native checksum algorithm differs: '+file);
  const captureImplementationInputs=Object.fromEntries([...lifetimeInputs].filter(exists).map(file=>{const b=read(file);return[file,{sha256:sha(b),bytes:b.length,checksum:checksum(b)}];}));
  const meta={version:1,revision:'crater-static-v1',scene:request.scene,image:'Crater/Minimap.bin',size:1024,half:320,dependencyPolicy,captureImplementationInputs,
   source:request.source,inputs:actualInputs,inputSha256:sha(Buffer.from(JSON.stringify(actualInputs))),runtimeChecks,
   imageSha256:sha(bytes),pixelsSha256:sha(data),colors:colors.size,bakedAt:new Date().toISOString(),
   capture:{height:1200,far:3000,views:5,tone:'production MatchMapShot.Process',environmentTime:1,randomSeed:1337,textureFilter:native.textureFilter,textureAnisotropy:native.textureAnisotropy,scope:'Authored static map with environment lighting; no session vehicles, objectives, combat or animated particle snapshot.'},nativeEvidence:request.result,validationEvidence:request.validation};
  fs.writeFileSync(path.join(root,'assets/Crater/Minimap.bin'),bytes);fs.writeFileSync(metaPath,JSON.stringify(meta,null,2)+'\n');
  console.log(JSON.stringify({result:'PASSED',asset:meta.image,bytes:bytes.length,colors:colors.size,inputSha256:meta.inputSha256,nativeEvidence:request.result}));return;
 }
 if(mode==='reclassify-lifetime'){
  const original=JSON.parse(fs.readFileSync(metaPath));
  assert(JSON.stringify(original.source)===JSON.stringify(baseline()),'Baked source baseline stale');
  assert(original.imageSha256===sha(read('assets/'+original.image)),'Original baked PNG bytes changed');
  const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
  const {data,info}=await sharp(read('assets/'+original.image)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  assert(info.width===1024&&info.height===1024&&sha(data)===original.pixelsSha256,'Original baked image pixels changed');
  const meta=reclassifyLifetime(original,inputs());
  fs.writeFileSync(metaPath,JSON.stringify(meta,null,2)+'\n');
  console.log(JSON.stringify({result:'PASSED',action:'reclassify-lifetime-only',pixelInputs:Object.keys(meta.inputs).length,implementationInputs:Object.keys(meta.captureImplementationInputs).length,imageSha256:meta.imageSha256,pixelsSha256:meta.pixelsSha256}));return;
 }
 if(mode==='check'){
  assert(fs.existsSync(metaPath),'No baked map metadata');const m=JSON.parse(fs.readFileSync(metaPath));
  assert(m.version===1&&m.revision==='crater-static-v1'&&m.size===1024&&m.half===320,'Baked map contract changed');
  assert(JSON.stringify(m.source)===JSON.stringify(baseline()),'Baked source baseline stale');
  const current=inputs();assert(JSON.stringify(m.inputs)===JSON.stringify(current),'Baked map inputs stale; run bake-match-map.ps1');
  assert(m.inputSha256===sha(Buffer.from(JSON.stringify(current))),'Input manifest hash invalid');
  assert(m.imageSha256===sha(read('assets/'+m.image)),'Baked PNG bytes changed');
  console.log(JSON.stringify({result:'PASSED',inputs:Object.keys(current).length,image:m.image,inputSha256:m.inputSha256,pixelsSha256:m.pixelsSha256}));return;
 }
 throw Error('Expected prepare, publish, check or reclassify-lifetime');
}
module.exports={reclassifyLifetime,inputs,lifetimeInputs};
if(require.main===module)main().catch(e=>{console.error(e.stack);process.exitCode=1;});

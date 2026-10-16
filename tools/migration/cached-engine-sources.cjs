// Explicit offline fixture for visual QA when the source CDN is unreachable.
// These are previously downloaded source snapshots, never a live stable check.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const directory=path.resolve(__dirname,'../../.tmp/web-engine/http-cache');
const snapshots={
 'engine-startup':{client:'e0c42c86',version:'1.0.29',manifest:'d8c0c003de676cee254c1fbf622ffc43abe69e18f2b874f68ecc6c8fe098f8b4'},
 'engine-res':{client:'60b25079',version:'1.1.925',manifest:'5b5cc23b8b446e2c0bdfa7c8099c7da610af93b675d45d36a8107eb2605b6521'},
 'urhox-libs':{client:'64f47a38',version:'1.0.47',manifest:'f8f20f88c846514e5c6f2de375db65afd9e0b2762fe1361d709ed7aabe58e265'},
 'official-res':{client:'153a2b71',version:'1.32.37',manifest:'d495b3d2d65fff47510b1cec9666952151af3c08680b1795b648e34d48ce8817'},
};
const packages={
 'engine-res':{key:'aa574cccd1a0ac0d12735920844fdd36af5a1eb49d048299236a7d4c7ab7f7dd',sha256:'001ec003f62e723c077840e21e91ad74e6d447309b64afbda41c5822b77cb69e'},
 'urhox-libs':{key:'6edc4ffbde96f007942097c49aa06b566964d649771a14d73883fd6f7d337dee',sha256:'943343dc7fd2c8452a5f8ba70af764bc681401c0c4c88ae0c06af6e7c8ba118a'},
};
const packageBodies=new Map();
function pinnedPackage(parsed){
 const match=parsed.pathname.match(/^\/src\/(engine-res|urhox-libs)\/(?:([^/]+)\/)?assets@windows\.7z$/);
 if(!match)return null;
 const source=match[1],snapshot=snapshots[source],version=match[2]||parsed.searchParams.get('v');
 if(version!==snapshot.version || (parsed.searchParams.has('v')&&parsed.searchParams.get('v')!==snapshot.version))return null;
 if(!packageBodies.has(source)){
  const spec=packages[source],file=path.join(directory,spec.key);
  if(!fs.existsSync(file))return null;
  const body=fs.readFileSync(file);
  if(crypto.createHash('sha256').update(body).digest('hex')!==spec.sha256)throw Error('Pinned source package changed: '+source);
  packageBodies.set(source,{body,headers:{'content-type':'application/x-7z-compressed'}});
 }
 return packageBodies.get(source);
}
let bundled,packed;
function bundledAsset(parsed){
 if(!/\/assets\/[^/]+$/.test(parsed.pathname))return null;
 if(parsed.pathname.startsWith('/src/urhox-libs/')){
  if(!packed){
   const archive=path.join(directory,'6edc4ffbde96f007942097c49aa06b566964d649771a14d73883fd6f7d337dee');
   const {execFileSync}=require('node:child_process');
   const names=execFileSync('tar',['-tf',archive],{encoding:'utf8',windowsHide:true}).trim().split(/\r?\n/);
   if(names.some(name=>!/^assets\/[A-Za-z0-9_-]+(?:\.[A-Za-z0-9]+)?$/.test(name)))throw Error('Unexpected library archive path');
   const extract=path.join(directory,'../packed-library-cache');fs.mkdirSync(extract,{recursive:true});
   execFileSync('tar',['-xf',archive,'-C',extract],{windowsHide:true});
   packed=path.join(extract,'assets');
  }
  const file=path.join(packed,parsed.pathname.split('/').pop());
  if(fs.existsSync(file))return {body:fs.readFileSync(file),headers:{'content-type':'application/octet-stream'}};
 }
 if(!bundled){
  const body=fs.readFileSync(path.join(directory,'../UrhoXRuntime.data'));
  if(body.subarray(0,8).toString()!=='URXRES1\0')throw Error('Unsupported bundled engine resource format');
  const length=body.readUInt32LE(8),metadata=JSON.parse(body.subarray(12,12+length));
  bundled={body,base:12+length,files:new Map(metadata.files.map(file=>[file.path,file]))};
 }
 const file=bundled.files.get('assets/'+parsed.pathname.split('/').pop());
 if(!file)return null;
 return {body:bundled.body.subarray(bundled.base+file.offset,bundled.base+file.offset+file.size),headers:{'content-type':'application/octet-stream'}};
}
function read(url){
 const parsed=new URL(url);if(parsed.hostname!=='tapcode-sce.spark.xd.com')return null;
 const source=parsed.pathname.split('/')[2],snapshot=snapshots[source];if(!snapshot)return null;
 // The Windows WASM runtime probes versioned and ?v= package candidates.
 // Only these audited snapshots have cached platform archives.
 if(/\/assets(?:@[^/]+)?\.7z$/.test(parsed.pathname))return pinnedPackage(parsed);
 let key;
 // The Web runtime asks engine-res for the wasm channel name directly. The
 // offline fixture only stores the pinned manifest by digest, so route this
 // channel to that exact snapshot instead of letting the source be skipped.
 if(source==='engine-res' && /\/wasm-1\.32\.json$/.test(parsed.pathname)){
  key=snapshot.manifest;
 }else if(/\/(stable|latest)\.json$/.test(parsed.pathname)){
  for(const file of fs.readdirSync(directory).filter(f=>!f.endsWith('.json'))){
   const candidate=path.join(directory,file);if(fs.statSync(candidate).size>200)continue;
   try{const tag=JSON.parse(fs.readFileSync(candidate));if(tag.client===snapshot.client&&tag.version===snapshot.version){key=file;break;}}catch{}
  }
 }else if(/\/manifest(?:-[^/]+)?\.json$/.test(parsed.pathname)&&parsed.pathname.includes(snapshot.client))key=snapshot.manifest;
 else key=crypto.createHash('sha256').update(parsed.origin+parsed.pathname).digest('hex');
 if(!key||!fs.existsSync(path.join(directory,key)))return bundledAsset(parsed);
 let body=fs.readFileSync(path.join(directory,key));
 // Engine source manifests are tag responses, and the pinned snapshot stores
 // its manifest with null tag fields. The runtime rejects that response unless
 // the channel client/version are present.
 if(source==='engine-res' && /\/wasm-1\.32\.json$/.test(parsed.pathname)){
  const manifest=JSON.parse(body);
  manifest.client=snapshot.client;
  manifest.version=snapshot.version;
  body=Buffer.from(JSON.stringify(manifest));
 }
 return {body,headers:JSON.parse(fs.readFileSync(path.join(directory,key+'.json')))};
}
module.exports={read,snapshots};

const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(options={}){
 const snapshot=path.resolve(root,options.snapshot||process.env.VOX_CALLBACK_SNAPSHOT||'.tmp/outgame-cached-1792120761228');
 const dist=path.join(snapshot,'dist'),engine=path.join(root,'.tmp/web-engine');
 const manifestPath=path.join(dist,'1.0.0/manifest-35b14da3.json'),manifestBytes=fs.readFileSync(manifestPath),manifest=JSON.parse(manifestBytes);
 const mode=options.mode||process.env.VOX_CALLBACK_MODE||'download';assert(['download','prepare'].includes(mode));
 const names=['Sounds/Music/hangar-04-lost-mining-belt.mp3','Sounds/Ambience/amb_hangar_a.wav'];
 const records=names.map(name=>{
  const row=manifest.files.find(f=>f.fs_path===name);assert(row,'Missing sound '+name);
  const payload=fs.readFileSync(path.join(dist,'assets',row.uuid+'-'+row.hash+row.ext));
  assert(payload.equals(fs.readFileSync(path.join(snapshot,'assets',name))),'Frozen sound identity '+name);
  return {name,sha256:sha(payload),bytes:payload.length,payload:row.uuid+'-'+row.hash+row.ext};
 });
 const gate=manifest.files.find(f=>f.fs_path==='app/ResourceGate.lua');assert(gate);
 const gateBytes=fs.readFileSync(path.join(dist,'assets',gate.uuid+'-'+gate.hash+gate.ext));
 assert(gateBytes.equals(fs.readFileSync(path.join(snapshot,'scripts/app/ResourceGate.lua'))));
 const probe=fs.readFileSync(path.join(__dirname,'probe-sound-callback.lua'),'utf8');
 const entry='SOUND_CALLBACK_PROBE_CONFIG=cjson.decode([==['+JSON.stringify({mode,paths:names})+']==])\n'+probe;
 const main=manifest.files.find(f=>f.fs_path==='main.lua');assert(main);const mainName=main.uuid+'-'+main.hash+main.ext;
 const originalEntry=fs.readFileSync(path.join(dist,'assets',mainName));main.size=Buffer.byteLength(entry);
 // Isolate startup, too: retain resource lookup identities but preload only
 // this entry, its exact production gate and the engine default startup font.
 const preload=new Set(['main.lua','app/ResourceGate.lua','Fonts/MiSans-Regular.ttf']);
 for(const file of manifest.files)file.groups=preload.has(file.fs_path)?['qa']:[];
 assert([...preload].every(n=>manifest.files.some(f=>f.fs_path===n)));
 manifest.preload_groups=['qa'];
 const wasm=fs.readFileSync(path.join(engine,'UrhoXRuntime.wasm'));
 assert.equal(sha(wasm),'4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765','Fixed return-profile runtime required');
 const identity={qa:true,soundCallbackProbe:true,servedManifest:'manifest-35b14da3.json',sourceDirectory:snapshot,mode,
  manifestSha256:sha(manifestBytes),qaManifestSha256:sha(Buffer.from(JSON.stringify(manifest))),originalEntrySha256:sha(originalEntry),
  entryOverrideSha256:sha(Buffer.from(entry)),probeSha256:sha(Buffer.from(probe)),gateSha256:sha(gateBytes),
  wasmSha256:sha(wasm),engineJsSha256:sha(fs.readFileSync(path.join(engine,'UrhoXRuntime.js'))),resources:records,
  preload:[...preload],boundary:'QA HTTP response overrides main and preload group only. Immutable frozen build, engine and exact resource/gate bytes unchanged. No game/UI/scene/audio player bootstrap.'};
 return {dist,engine,manifestPath,manifest,entry,mainName,identity};
}
const html='<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body{margin:0;background:#111}canvas{width:100vw;height:100vh;display:block}</style><canvas id="canvas" width="800" height="450"></canvas><script>(async()=>{const prefix="https://tapcode-sce.spark.xd.com/",local=u=>String(u).startsWith(prefix)?new URL("/cached-engine-source/"+String(u).slice(prefix.length),location.href).href:u,fetchRemote=fetch.bind(window),open=XMLHttpRequest.prototype.open;window.fetch=(r,i)=>fetchRemote(r instanceof Request?new Request(local(r.url),r):local(r),i);XMLHttpRequest.prototype.open=function(m,u,...a){return open.call(this,m,local(u),...a)};const bytes=await fetch("UrhoXRuntime.data").then(r=>r.arrayBuffer());window.Module={canvas:document.querySelector("canvas"),getPreloadedPackage:()=>bytes,print:console.log,printErr:console.error};const s=document.createElement("script");s.src="UrhoXRuntime.js";document.body.append(s)})().catch(console.error)</script>';
function createServer(prepared){
 const sourceCache=require('./cached-engine-sources.cjs');
 return http.createServer((req,res)=>{
  res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');res.setHeader('Cache-Control','no-store');
  let url;try{url=decodeURIComponent(req.url.split('?')[0])}catch{res.writeHead(400).end();return}
  if(url==='/identity.json'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(prepared.identity));return}
  if(url==='/'||url==='/sound-callback.html'){res.setHeader('Content-Type','text/html');res.end(html);return}
  if(url.startsWith('/cached-engine-source/')){
   const cached=sourceCache.read('https://tapcode-sce.spark.xd.com/'+url.slice('/cached-engine-source/'.length));
   if(!cached){res.writeHead(404).end();return}res.setHeader('Content-Type',cached.headers['content-type']||'application/octet-stream');res.end(cached.body);return;
  }
  const game=url.startsWith('/game-dist/'),base=game?prepared.dist:prepared.engine,relative=game?url.slice('/game-dist'.length):url;
  const file=path.resolve(base,'.'+relative);
  if(!file.startsWith(base+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404).end();return}
  res.setHeader('Content-Type',({'.js':'text/javascript','.wasm':'application/wasm','.json':'application/json'})[path.extname(file)]||'application/octet-stream');
  if(game&&path.basename(file)===prepared.mainName){res.end(prepared.entry);return}
  if(file===prepared.manifestPath){res.end(JSON.stringify(prepared.manifest));return}
  fs.createReadStream(file).pipe(res);
 });
}
if(require.main===module){const prepared=prepare();const port=Number(process.env.VOX_PREVIEW_PORT||4420);createServer(prepared).listen(port,'127.0.0.1',()=>console.log(JSON.stringify({port,identity:prepared.identity})))}
module.exports={prepare,createServer};

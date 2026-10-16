const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),engine=path.join(root,'.tmp/web-engine');
const prepared=JSON.parse(fs.readFileSync(path.resolve(root,process.env.VOX_PREPARE_FILE||'.tmp/outgame-prepare-cached.json'),'utf8').replace(/^\uFEFF/,''));
if(!prepared.ok)throw Error('Expected a successful frozen preparation');
const expected=process.env.VOX_EXPECT_MANIFEST||'manifest-80e98fd5.json';
if(path.basename(prepared.manifest_path)!==expected)throw Error('Expected exact frozen manifest '+expected);
const dist=path.join(prepared.source_directory,'dist'),manifest=JSON.parse(fs.readFileSync(prepared.manifest_path));
const mode=process.env.VOX_ARRAY_MODE||'background';if(!['background','synchronous'].includes(mode))throw Error('Invalid array mode');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const arrays=[{name:'Crater/albedo.xml',binding:'tAlb'},{name:'Crater/nra.xml',binding:'tNra'}];
const downloads=[...arrays.map(a=>a.name),...['albedo','nra'].flatMap(kind=>Array.from({length:6},(_,i)=>`Crater/${kind}-${i}.bin`)),
 'Crater/material-1.xml','Crater/texture-0.bin','Crater/dfg.png','Shaders/BLGL/Crater/Terrain.shader'];
const records=downloads.map(name=>{
 const file=manifest.files.find(f=>f.fs_path===name);if(!file)throw Error('Missing original resource '+name);
 const payload=fs.readFileSync(path.join(dist,'assets',file.uuid+'-'+file.hash+file.ext));
 const original=fs.readFileSync(path.join(prepared.source_directory,'assets',name));
 if(!payload.equals(original))throw Error('Frozen payload differs: '+name);
 return {name,sha256:hash(payload),bytes:payload.length};
});
const config={mode,arrays,downloads,material:'Crater/material-1.xml',width:1024,height:1024,levels:11,memoryBytes:33554792};
const probe=fs.readFileSync(path.join(__dirname,'probe-array-preparation.lua'),'utf8');
const entry='ARRAY_PROBE_CONFIG=cjson.decode([==['+JSON.stringify(config)+']==])\n'+probe;
const main=manifest.files.find(f=>f.fs_path==='main.lua');if(!main)throw Error('Missing frozen entry');
const mainName=main.uuid+'-'+main.hash+main.ext;main.size=Buffer.byteLength(entry);
const sourceCache=require('./cached-engine-sources.cjs');
const port=Number(process.env.VOX_PREVIEW_PORT||4418);
const html='<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body{margin:0;background:#111}canvas{width:100vw;height:100vh;display:block}</style><canvas id="canvas" width="1600" height="900"></canvas><script>(async()=>{const prefix="https://tapcode-sce.spark.xd.com/",local=u=>String(u).startsWith(prefix)?new URL("/cached-engine-source/"+String(u).slice(prefix.length),location.href).href:u,fetchRemote=fetch.bind(window),open=XMLHttpRequest.prototype.open;window.fetch=(r,i)=>fetchRemote(r instanceof Request?new Request(local(r.url),r):local(r),i);XMLHttpRequest.prototype.open=function(m,u,...a){return open.call(this,m,local(u),...a)};const bytes=await fetch("UrhoXRuntime.data").then(r=>r.arrayBuffer());window.Module={canvas:document.querySelector("canvas"),getPreloadedPackage:()=>bytes,print:console.log,printErr:console.error};const s=document.createElement("script");s.src="UrhoXRuntime.js";document.body.append(s)})().catch(console.error)</script>';
const identity={qa:true,arrayProbe:true,servedManifest:path.basename(prepared.manifest_path),mode,sourceDirectory:prepared.source_directory,
 manifestSha256:hash(fs.readFileSync(prepared.manifest_path)),originalEntrySha256:hash(fs.readFileSync(path.join(dist,'assets',mainName))),
 entryOverrideSha256:hash(Buffer.from(entry)),probeSha256:hash(Buffer.from(probe)),resources:records,
 boundary:'Standalone QA response overrides main only; original immutable build and ordinary servers are not changed. All tested texture/material bytes remain original frozen payloads.'};
http.createServer((req,res)=>{
 res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');res.setHeader('Cache-Control','no-store');
 const url=decodeURIComponent(req.url.split('?')[0]);
 if(url==='/identity.json'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(identity));return;}
 if(url==='/'||url==='/array-probe.html'){res.setHeader('Content-Type','text/html');res.end(html);return;}
 if(url.startsWith('/cached-engine-source/')){
  const cached=sourceCache.read('https://tapcode-sce.spark.xd.com/'+url.slice('/cached-engine-source/'.length));
  if(!cached){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',cached.headers['content-type']||'application/octet-stream');res.setHeader('Cross-Origin-Resource-Policy','same-origin');res.end(cached.body);return;
 }
 const game=url.startsWith('/game-dist/'),base=game?dist:engine,relative=game?url.slice('/game-dist'.length):url;
 const file=path.resolve(base,'.'+relative);
 if(!file.startsWith(base+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404).end();return;}
 res.setHeader('Content-Type',({'.js':'text/javascript','.wasm':'application/wasm','.json':'application/json'})[path.extname(file)]||'application/octet-stream');
 if(game&&path.basename(file)===mainName){res.end(entry);return;}
 if(file===prepared.manifest_path){res.end(JSON.stringify(manifest));return;}
 fs.createReadStream(file).pipe(res);
}).listen(port,'127.0.0.1',()=>console.log('Isolated array QA: http://127.0.0.1:'+port+'/array-probe.html?-game_url=http://127.0.0.1:'+port+'/game-dist/&-log=info'));

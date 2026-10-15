const fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),engine=path.join(root,'.tmp/web-engine');
const prepared=JSON.parse(fs.readFileSync(path.resolve(root,process.env.VOX_PREPARE_FILE||'.tmp/outgame-prepare.json'),'utf8').replace(/^\uFEFF/,''));
if(!prepared.ok)throw Error('Preparation failed. A cached visual fixture must be selected explicitly with VOX_PREPARE_FILE.');
const dist=path.join(prepared.source_directory,'dist');
const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path,'utf8'));
const main=manifest.files.find(f=>f.fs_path==='main.lua');
const mainName=main.uuid+'-'+main.hash+main.ext;
const qa=process.argv.includes('--qa');
const loadProfile=qa&&process.argv.includes('--profile-loads');
const combatProfile=qa&&process.argv.includes('--profile-combat');
const warmBatchArg=process.argv.find(arg=>arg.startsWith('--warm-batch-size='));
const warmBatchSize=warmBatchArg?Number(warmBatchArg.split('=')[1]):null;
if(warmBatchSize!==null&&(!loadProfile||!Number.isInteger(warmBatchSize)||warmBatchSize<1||warmBatchSize>64))throw Error('Warm-up batch size is a QA load-profile option, range 1..64');
const renderExperiment=qa&&process.argv.includes('--render-experiment');
const warmExperiment=renderExperiment&&process.argv.includes('--warm-experiment');
const warmIntroExperiment=warmExperiment&&process.argv.includes('--warm-intro-experiment');
const concurrencyArg=process.argv.find(arg=>arg.startsWith('--download-concurrency='));
const downloadConcurrency=concurrencyArg?Number(concurrencyArg.split('=')[1]):null;
if(downloadConcurrency!==null&&(!loadProfile||!Number.isInteger(downloadConcurrency)||downloadConcurrency<1||downloadConcurrency>16))throw Error('Download concurrency is a QA load-profile option, range 1..16');
const probe=qa?(loadProfile?'G0_DOWNLOAD_CONCURRENCY='+(downloadConcurrency??'nil')+'\nG0_WARM_BATCH_SIZE='+(warmBatchSize??'nil')+'\n'+fs.readFileSync(path.join(__dirname,'profile-load-bindings.lua'),'utf8')+'\n':'')+(renderExperiment?'G0_WARM_EXPERIMENT='+String(warmExperiment)+'\nG0_WARM_INTRO_EXPERIMENT='+String(warmIntroExperiment)+'\n'+fs.readFileSync(path.join(__dirname,'probe-render-experiment.lua'),'utf8')+'\n':'')+fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'),'utf8')+(combatProfile?'\n'+fs.readFileSync(path.join(__dirname,'probe-combat-performance.lua'),'utf8'):''):'';
const probeSha256=qa?require('node:crypto').createHash('sha256').update(probe).digest('hex'):null;
const port=Number(process.env.VOX_PREVIEW_PORT||4203);
const sourceCache=require('./cached-engine-sources.cjs');
const sourceBaseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const sourceRoot=path.resolve(root,sourceBaseline.snapshot);
const server=http.createServer((req,res)=>{
 if(req.url==='/identity.json'){
  res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');
  res.end(JSON.stringify({...prepared,qa,loadProfile,combatProfile,downloadConcurrency,warmBatchSize,renderExperiment,warmExperiment,warmIntroExperiment,probeSha256,port,processId:process.pid,servedManifest:path.basename(prepared.manifest_path)}));return;
 }
 if(req.url.startsWith('/baseline/')){
  const relative=decodeURIComponent(req.url.split('?')[0].slice('/baseline/'.length));
  const file=path.resolve(sourceRoot,relative),registered=sourceBaseline.files[relative];
  if(!file.startsWith(sourceRoot+path.sep)||!registered||!fs.existsSync(file)){res.writeHead(404).end();return;}
  const bytes=fs.readFileSync(file);
  if(require('node:crypto').createHash('sha256').update(bytes).digest('hex')!==registered.sha256){res.writeHead(409).end();return;}
  res.setHeader('Content-Type',({'.css':'text/css','.woff2':'font/woff2','.png':'image/png'})[path.extname(file)]||'application/octet-stream');
  res.setHeader('Cross-Origin-Resource-Policy','same-origin');res.end(bytes);return;
 }
 if(req.url.startsWith('/cached-engine-source/')){
  const cached=sourceCache.read('https://tapcode-sce.spark.xd.com/'+req.url.slice('/cached-engine-source/'.length));
  if(!cached){res.writeHead(404);res.end();return;}
  res.setHeader('Content-Type',cached.headers['content-type']||'application/octet-stream');res.setHeader('Cache-Control','no-store');
  res.setHeader('Cross-Origin-Resource-Policy','same-origin');res.end(cached.body);return;
 }
 if(qa&&(req.url==='/resize-host.html'||req.url==='/resize-host.html?restore=1')){
  res.setHeader('Content-Type','text/html');res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');
  const dimensions=req.url.endsWith('?restore=1')?'width:100vw;height:100vh':'width:0;height:0';
  res.end('<!doctype html><style>body{margin:0;background:#111}iframe{position:absolute;inset:0;border:0;'+dimensions+'}</style><iframe src="/outgame.html?-game_url=http://127.0.0.1:'+port+'/game-dist/&amp;-log=info&amp;cached=1"></iframe>');return;
 }
 const url=decodeURIComponent(req.url.split('?')[0]);const game=url.startsWith('/game-dist/');
 const base=game?dist:engine;const relative=game?url.slice('/game-dist'.length):url==='/'?'/outgame.html':url;
 const file=!game&&relative==='/outgame.html'?path.join(__dirname,'preview-outgame.html'):path.resolve(base,'.'+relative);
 if((!file.startsWith(base+path.sep)&&file!==path.join(__dirname,'preview-outgame.html'))||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
 res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');
 res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.json':'application/json'})[path.extname(file)]||'application/octet-stream');
 res.setHeader('Cache-Control','no-store');
 if(qa&&file.endsWith(mainName)){res.end(fs.readFileSync(file,'utf8')+'\n'+probe);return;}
 if(qa&&file===prepared.manifest_path){main.size=fs.statSync(path.join(dist,'assets',mainName)).size+Buffer.byteLength('\n'+probe);res.end(JSON.stringify(manifest));return;}
 fs.createReadStream(file).pipe(res);
});
server.listen(port,'127.0.0.1',()=>console.log(`Outgame preview: http://127.0.0.1:${port}/outgame.html?-game_url=http://127.0.0.1:${port}/game-dist/&-log=info`));
process.on('SIGINT',()=>server.close());

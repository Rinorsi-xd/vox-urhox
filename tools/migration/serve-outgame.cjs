const fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const crypto=require('node:crypto');
function createPerfLogReceiver(options={}){
 const maxBytes=256*1024,maxRecords=500,maxQueuedBytes=4*1024*1024;
 const directory=path.resolve(options.directory||path.join(__dirname,'../../docs/migration/evidence/performance-live',new Date().toISOString().replace(/[:.]/g,'-')+'-'+process.pid+'-'+crypto.randomBytes(3).toString('hex')));
 const sessions=new Map();let queuedBytes=0,pendingBatches=0,receivedRecords=0,writtenRecords=0,rejectedBatches=0,writeFailures=0,lastError=null,chain=Promise.resolve();
 const ready=fs.promises.mkdir(directory,{recursive:true});ready.catch(error=>{lastError=error.message});
 function status(){return {enabled:true,directory,identityFile:path.join(directory,'identity.json'),countsIncludeTransportRetries:true,receivedRecords,writtenRecords,queuedBytes,pendingBatches,rejectedBatches,writeFailures,lastError,sessions:[...sessions.values()].map(s=>({...s}))}}
 function trusted(req,requireOrigin){
  try{
   const host=req.headers.host;if(!host)return false;
   const origin=new URL('http://'+host);
   if(!['127.0.0.1','localhost'].includes(origin.hostname)||origin.port!==String(options.port))return false;
   if(req.headers['sec-fetch-site']==='cross-site')return false;
   return req.headers.origin?req.headers.origin===origin.origin:!requireOrigin;
  }catch{return false}
 }
 function json(res,code,value){res.writeHead(code,{'Content-Type':'application/json','Cache-Control':'no-store','Cross-Origin-Resource-Policy':'same-origin'});res.end(JSON.stringify(value))}
 function handle(req,res){
  const endpoint=req.url.split('?')[0];if(endpoint!=='/__vox_perf'&&endpoint!=='/__vox_perf_status')return false;
  if(!trusted(req,endpoint==='/__vox_perf')){rejectedBatches++;json(res,403,{error:'Same-origin local requests only'});return true}
  if(endpoint==='/__vox_perf_status'){if(req.method!=='GET'){json(res,405,{error:'GET required'});return true}json(res,200,status());return true}
  if(req.method!=='POST'){json(res,405,{error:'POST required'});return true}
  if(!/^(application\/json|text\/plain)(?:;|$)/i.test(req.headers['content-type']||'')){rejectedBatches++;json(res,415,{error:'JSON required'});return true}
  if(Number(req.headers['content-length'])>maxBytes){rejectedBatches++;json(res,413,{error:'Batch exceeds 256 KiB'});req.resume();return true}
  let size=0,finished=false;const chunks=[];
  req.on('data',chunk=>{
   if(finished)return;size+=chunk.length;
   if(size>maxBytes){finished=true;rejectedBatches++;json(res,413,{error:'Batch exceeds 256 KiB'});return}
   chunks.push(chunk);
  });
  req.on('error',()=>{finished=true});
  req.on('end',()=>{
   if(finished)return;finished=true;
   let records,serialized;try{
    const body=JSON.parse(Buffer.concat(chunks).toString('utf8'));records=Array.isArray(body)?body:body.records;
    if(!Array.isArray(records)||records.length<1||records.length>maxRecords||records.some(record=>!record||typeof record!=='object'||Array.isArray(record)||typeof record.session!=='string'||!record.session||record.session.length>160||typeof record.type!=='string'||record.type.length>80))throw Error('Expected 1..500 records with session/type');
    serialized=records.map(record=>JSON.stringify(record));
   }catch(error){rejectedBatches++;json(res,400,{error:error.message});return}
   const added=new Set(records.map(record=>record.session).filter(session=>!sessions.has(session)));
   if(sessions.size+added.size>128||queuedBytes+size>maxQueuedBytes){rejectedBatches++;json(res,429,{error:'Collector write queue or session limit reached'});return}
   const groups=new Map();
   for(let i=0;i<records.length;i++){
    const record=records[i];
    let session=sessions.get(record.session);
    if(!session){session={session:record.session,file:path.join(directory,'session-'+crypto.createHash('sha256').update(record.session).digest('hex').slice(0,24)+'.jsonl'),receivedRecords:0,writtenRecords:0};sessions.set(record.session,session)}
    session.receivedRecords++;const lines=groups.get(session)||[];lines.push(serialized[i]);groups.set(session,lines);
   }
   queuedBytes+=size;pendingBatches++;receivedRecords+=records.length;
   const write=chain.then(async()=>{
    await ready;
    for(const [session,lines] of groups){await fs.promises.appendFile(session.file,lines.join('\n')+'\n','utf8');session.writtenRecords+=lines.length;writtenRecords+=lines.length}
   });
   chain=write.catch(error=>{writeFailures++;lastError=error.message}).finally(()=>{queuedBytes-=size;pendingBatches--});
   write.then(()=>json(res,200,{accepted:records.length,written:true}),error=>json(res,500,{error:'Performance log write failed: '+error.message}));
  });return true;
 }
 function setIdentity(identity){const write=chain.then(async()=>{await ready;await fs.promises.writeFile(path.join(directory,'identity.json'),JSON.stringify(identity,null,2)+'\n','utf8')});chain=write.catch(error=>{writeFailures++;lastError=error.message});return write}
 return {handle,status,setIdentity,drain:()=>chain};
}
function startPreviewServer(){
const root=path.resolve(__dirname,'../..'),engine=path.join(root,'.tmp/web-engine');
const prepared=JSON.parse(fs.readFileSync(path.resolve(root,process.env.VOX_PREPARE_FILE||'.tmp/outgame-prepare.json'),'utf8').replace(/^\uFEFF/,''));
if(!prepared.ok)throw Error('Preparation failed. A cached visual fixture must be selected explicitly with VOX_PREPARE_FILE.');
const dist=path.join(prepared.source_directory,'dist');
const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path,'utf8'));
const main=manifest.files.find(f=>f.fs_path==='main.lua');
const mainName=main.uuid+'-'+main.hash+main.ext;
const qa=process.argv.includes('--qa');
const qaAimEngine=process.argv.includes('--qa-aim-engine');
if(qaAimEngine&&!qa)throw Error('Aim engine fixture requires explicit QA mode.');
const qaSalvageStock=process.argv.includes('--qa-salvage-stock');
if(qaSalvageStock&&!qa)throw Error('Salvage stock fixture requires explicit QA mode.');
if(qaSalvageStock&&qaAimEngine)throw Error('Run independent QA fixtures separately.');
const perfMonitor=process.argv.includes('--perf-monitor');
const monitorDisabled=process.argv.includes('--monitor-disabled');
const framePipelineProfile=process.argv.includes('--profile-frame-pipeline');
const fixedStepPipelineProfile=process.argv.includes('--profile-fixed-step-pipeline');
const presentationPipelineProfile=process.argv.includes('--profile-presentation-pipeline');
const beforeStepPipelineProfile=process.argv.includes('--profile-before-step-pipeline');
const vehiclePipelineProfile=process.argv.includes('--profile-vehicle-pipeline');
require('./build-frame-pipeline-probe.cjs').validateFramePipelineOptions(process.argv);
if(monitorDisabled&&!qa)throw Error('Monitor-disabled observation requires explicit QA mode.');
const monitorOverride=monitorDisabled?'\n'+fs.readFileSync(path.join(__dirname,'monitor-disabled-observer.lua'),'utf8'):'';
const storyRoute=qa&&process.argv.includes('--story-route');
const homeRoute=qa&&process.argv.includes('--home-route');
if(homeRoute&&storyRoute)throw Error('Select one QA route projection.');
const homeRouteProbe=homeRoute?fs.readFileSync(path.join(__dirname,'home-route-observer.lua'),'utf8')+'\n':'';
const storyRouteProbe=storyRoute?fs.readFileSync(path.join(__dirname,'story-combat-observer.lua'),'utf8')+'\n'+fs.readFileSync(path.join(__dirname,'story-route-observer.lua'),'utf8')+'\n':'';
const loadProfile=qa&&process.argv.includes('--profile-loads');
const combatProfile=qa&&process.argv.includes('--profile-combat');
const driveSectionsProfile=qa&&process.argv.includes('--profile-drive-sections');
if(process.argv.includes('--profile-drive-sections')&&!qa)throw Error('Detailed drive scopes require explicit QA mode.');
const trialSectionsProfile=process.argv.includes('--profile-trial-sections');
if(trialSectionsProfile&&!driveSectionsProfile)throw Error('Trial sections require explicit QA drive scopes.');
const afterStepProfile=process.argv.includes('--profile-after-step');
if(afterStepProfile&&!trialSectionsProfile)throw Error('AfterStep sections require explicit QA trial scopes.');
const loadingFailureTest=process.argv.includes('--loading-failure-test');
if(loadingFailureTest&&!qa)throw Error('Controlled loading failure requires explicit QA mode.');
const driveSectionsProbe=driveSectionsProfile?require('./build-drive-sections-probe.cjs').buildDriveSectionsProbe(prepared,{trialSections:trialSectionsProfile,afterStep:afterStepProfile})+'\n':'';
const warmBatchArg=process.argv.find(arg=>arg.startsWith('--warm-batch-size='));
const warmBatchSize=warmBatchArg?Number(warmBatchArg.split('=')[1]):null;
if(warmBatchSize!==null&&(!loadProfile||!Number.isInteger(warmBatchSize)||warmBatchSize<1||warmBatchSize>64))throw Error('Warm-up batch size is a QA load-profile option, range 1..64');
const renderExperiment=qa&&process.argv.includes('--render-experiment');
const warmExperiment=renderExperiment&&process.argv.includes('--warm-experiment');
const warmIntroExperiment=warmExperiment&&process.argv.includes('--warm-intro-experiment');
const concurrencyArg=process.argv.find(arg=>arg.startsWith('--download-concurrency='));
const downloadConcurrency=concurrencyArg?Number(concurrencyArg.split('=')[1]):null;
if(downloadConcurrency!==null&&(!loadProfile||!Number.isInteger(downloadConcurrency)||downloadConcurrency<1||downloadConcurrency>16))throw Error('Download concurrency is a QA load-profile option, range 1..16');
if(loadingFailureTest&&(storyRoute||homeRoute||loadProfile||combatProfile||driveSectionsProfile||trialSectionsProfile||renderExperiment))throw Error('Keep controlled loading failure separate from route projections and profiling experiments.');
const failureProbe=loadingFailureTest?'\n'+fs.readFileSync(path.join(__dirname,'qa-loading-failure.lua'),'utf8'):'';
const framePipelineProbe=framePipelineProfile?'\n'+require('./build-frame-pipeline-probe.cjs').buildFramePipelineProbe(prepared,{fixedSteps:fixedStepPipelineProfile,presentation:presentationPipelineProfile,beforeStep:beforeStepPipelineProfile,vehicle:vehiclePipelineProfile})+'\n'+fs.readFileSync(path.join(__dirname,'qa-frame-pipeline-control.lua'),'utf8'):'';
const probe=qa?storyRouteProbe+(loadProfile?'G0_DOWNLOAD_CONCURRENCY='+(downloadConcurrency??'nil')+'\nG0_WARM_BATCH_SIZE='+(warmBatchSize??'nil')+'\n'+fs.readFileSync(path.join(__dirname,'profile-load-bindings.lua'),'utf8')+'\n':'')+(renderExperiment?'G0_WARM_EXPERIMENT='+String(warmExperiment)+'\nG0_WARM_INTRO_EXPERIMENT='+String(warmIntroExperiment)+'\n'+fs.readFileSync(path.join(__dirname,'probe-render-experiment.lua'),'utf8')+'\n':'')+fs.readFileSync(path.join(__dirname,'qa-frame-wall-observer.lua'),'utf8')+'\n'+driveSectionsProbe+fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'),'utf8')+(combatProfile?'\n'+fs.readFileSync(path.join(__dirname,'probe-combat-performance.lua'),'utf8'):'')+monitorOverride+failureProbe+framePipelineProbe:'';
const aimEngineProbe=qaAimEngine?'\n'+fs.readFileSync(path.join(__dirname,'qa-aim-engine.lua'),'utf8'):'';
const salvageStockProbe=qaSalvageStock?'\n'+fs.readFileSync(path.join(__dirname,'qa-salvage-stock.lua'),'utf8'):'';
const fullProbe=probe+aimEngineProbe+salvageStockProbe;
const probeSha256=qa?require('node:crypto').createHash('sha256').update(homeRouteProbe+fullProbe).digest('hex'):null;
const port=Number(process.env.VOX_PREVIEW_PORT||4203);
const perfLogs=perfMonitor?createPerfLogReceiver({port}):null;
const sourceCache=require('./cached-engine-sources.cjs');
const sourceBaseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const sourceRoot=path.resolve(root,sourceBaseline.snapshot);
const previewIdentity=()=>({...prepared,qa,qaAimEngine,qaSalvageStock,perfMonitor,monitorDisabled,perfLogDirectory:perfLogs?.status().directory||null,storyRoute,homeRoute,loadProfile,combatProfile,driveSectionsProfile,trialSectionsProfile,afterStepProfile,framePipelineProfile,fixedStepPipelineProfile,...(presentationPipelineProfile?{presentationPipelineProfile:true}:{}),...(beforeStepPipelineProfile?{beforeStepPipelineProfile:true}:{}),...(vehiclePipelineProfile?{vehiclePipelineProfile:true}:{}),loadingFailureTest,downloadConcurrency,warmBatchSize,renderExperiment,warmExperiment,warmIntroExperiment,probeSha256,port,processId:process.pid,servedManifest:path.basename(prepared.manifest_path)});
if(perfLogs)perfLogs.setIdentity(previewIdentity()).catch(error=>console.error('Performance identity write failed: '+error.message));
const server=http.createServer((req,res)=>{
 if(req.url.split('?')[0]==='/favicon.ico'){
  res.writeHead(204,{'Cache-Control':'no-store'});res.end();return;
 }
 if(perfLogs&&perfLogs.handle(req,res))return;
 if(perfMonitor&&req.url==='/__vox_perf_collector.js'){
  res.writeHead(200,{'Content-Type':'text/javascript','Cache-Control':'no-store','Cross-Origin-Resource-Policy':'same-origin'});
  fs.createReadStream(path.join(__dirname,'perf-web-collector.js')).pipe(res);return;
 }
 if(req.url==='/identity.json'){
  res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');
  res.end(JSON.stringify(previewIdentity()));return;
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
 if(perfMonitor&&file===path.join(__dirname,'preview-outgame.html')){res.end(fs.readFileSync(file,'utf8').replace(/<!doctype html>/i,'$&\n<script src="/__vox_perf_collector.js"></script>'));return;}
 if(qa&&file.endsWith(mainName)){res.end(fs.readFileSync(file,'utf8')+'\n'+homeRouteProbe+fullProbe);return;}
 if(qa&&file===prepared.manifest_path){main.size=fs.statSync(path.join(dist,'assets',mainName)).size+Buffer.byteLength('\n'+homeRouteProbe+fullProbe);res.end(JSON.stringify(manifest));return;}
 fs.createReadStream(file).pipe(res);
});
server.listen(port,'127.0.0.1',()=>console.log(`Outgame preview: http://127.0.0.1:${port}/outgame.html?-game_url=http://127.0.0.1:${port}/game-dist/&-log=info`));
process.on('SIGINT',()=>server.close());
return server;
}
module.exports={createPerfLogReceiver,startPreviewServer};
if(require.main===module)startPreviewServer();

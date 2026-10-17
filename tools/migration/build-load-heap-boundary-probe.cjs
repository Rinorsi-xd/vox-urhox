'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
const modules=['main.lua','app/HangarApp.lua','app/SceneLoader.lua','app/LoadingFlow.lua','app/WebMapTransition.lua','drive/SalvagePhysics.lua','core/CollectionCycle.lua'];
function build(prepared){
 const moduleHashes={},sources={};
 for(const name of modules){const bytes=fs.readFileSync(path.join(prepared.source_directory,'scripts',name));moduleHashes[name]=sha(bytes);sources[name]=bytes.toString('utf8');assert.equal(moduleHashes[name],prepared.identity.scripts[name],'Frozen loading boundary module '+name);}
 const contracts={
  'main.lua':['local App=require "app.HangarApp"','function Start()'],
  'app/HangarApp.lua':['function App:Start(existingScene)','function App:EnterTrial(mapId,battleMode,roster,reuseLoading)','function App:Reload()','function App:ReleaseSettledAssets()',"checkpoint(.6,'session')",'preparedSession=TrialSession.New('],
  'app/SceneLoader.lua':['function Loader:ReadScene(path,token)','function Loader:Load(path,onReady,onError,options)','self.options.prepare(self.pending,function(progress,stage)'],
  'app/LoadingFlow.lua':['function M:Close()','self.active=false;',"self.phase='closed'"],
  'app/WebMapTransition.lua':['local ok,message=pcall(self.sweep)',"token.released=true;token.state='retiring'"],
 };
 for(const [name,anchors] of Object.entries(contracts))for(const anchor of anchors)assert.ok(sources[name].includes(anchor),'Explicit source boundary contract '+name+': '+anchor);
 const hangar=sources['app/HangarApp.lua'],worldAt=hangar.indexOf('DeferredModules[map.prepareWorld].Build('),checkpointAt=hangar.indexOf("checkpoint(.6,'session')"),sessionAt=hangar.indexOf('preparedSession=TrialSession.New(');
 assert.ok(worldAt>=0&&worldAt<checkpointAt&&checkpointAt<sessionAt,'Physics checkpoint is after world Build and before TrialSession.New');
 const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path,'utf8')),main=manifest.files.find(file=>file.fs_path==='main.lua');assert.ok(main,'Manifest main.lua');
 const lua=fs.readFileSync(path.join(__dirname,'qa-load-heap-boundaries.lua'),'utf8');
 const suffix='\ndo\nlocal loadHeapProbe=(function()\n'+lua+'\nend)()\nloadHeapProbe.Install(App)\nend\n';
 const heap=fs.readFileSync(path.join(__dirname,'wasm-heap-diagnostics.js'),'utf8');
 const observer=fs.readFileSync(path.join(__dirname,'load-heap-boundary-observer.js'),'utf8');
 const browserInit=heap+'\n'+observer+'\nwindow.VoxLoadHeapBoundaryObserver.install(window);\n';
 return {suffix,browserInit,identity:{kind:'load-heap-boundaries',moduleHashes,sourceContractsChecked:true,manifest:path.basename(prepared.manifest_path),mainAsset:main.uuid+'-'+main.hash+main.ext,suffixSha256:sha(suffix),browserInitSha256:sha(browserInit),heapHelperSha256:sha(heap),observerSha256:sha(observer),maximumAllocatorCalls:6,periodicAllocator:false,wasmReentrancy:false,zeroReentryEvidence:'Offline fake host only; unverified in Runtime',forcedGc:false,performanceAcceptance:false,boundary:'Explicit Lua method boundaries, coalesced queueMicrotask samples after the originating WASM job; non-atomic drift and same-frame coalescing must be preserved.'}};
}
module.exports={build,modules};
if(require.main===module){
 assert.equal(process.argv.length,4,'Usage: node build-load-heap-boundary-probe.cjs frozen-identity.json output-directory');
 const built=build(JSON.parse(fs.readFileSync(process.argv[2],'utf8'))),out=path.resolve(process.argv[3]);fs.mkdirSync(out,{recursive:true});
 for(const [name,value]of [['suffix.lua',built.suffix],['browser-init.js',built.browserInit],['identity.json',JSON.stringify(built.identity,null,2)]])fs.writeFileSync(path.join(out,name),value);
 console.log(JSON.stringify({result:'BUILT_OFFLINE',directory:out,...built.identity},null,2));
}

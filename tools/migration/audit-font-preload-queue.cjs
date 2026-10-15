// Offline replay of the measured 706d preload admission, not an HTTP trace.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const frozen=path.resolve(root,process.argv[2]||'.tmp/outgame-cached-1792072535275');
const evidence=path.resolve(root,process.argv[3]||'docs/migration/evidence/combat-performance-2026-10-15T13-56-49-208Z');
const output=process.argv[4]&&path.resolve(root,process.argv[4]);
const sha=data=>crypto.createHash('sha256').update(data).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const identity=read(path.join(frozen,'identity.json'));
const gameManifest=identity.manifest_path;
const snapshots=require('./cached-engine-sources.cjs').snapshots;
const cacheDir=path.join(root,'.tmp/web-engine/http-cache');
const manifestPaths={game:gameManifest};
for(const [name,info]of Object.entries(snapshots))manifestPaths[name]=path.join(cacheDir,info.manifest);
const manifests=Object.fromEntries(Object.entries(manifestPaths).map(([name,file])=>[name,read(file)]));
const consoleFile=path.join(evidence,'console.log');
const log=fs.readFileSync(consoleFile,'utf8');
const observed={
 found:Number(log.match(/Found (\d+) preload files/)[1]),
 needed:Number(log.match(/Need to download (\d+) files/)[1]),
 displayMiB:Number(log.match(/Need to download \d+ files \(([\d.]+)MB\)/)[1]),
};
// This is the source registration order printed by the measured bootstrap.
const order=['game','engine-startup','official-res','engine-res','urhox-libs'];
const resolved=new Map(),collisions=[];
for(const name of order)for(const file of manifests[name].files){
 if(file.source)continue;
 if(resolved.has(file.uuid))collisions.push({uuid:file.uuid,previous:resolved.get(file.uuid).owner,next:name});
 resolved.set(file.uuid,{...file,owner:name});
}
const selected=new Map(),reasons=new Map();
function add(uuid,reason){
 const file=resolved.get(uuid);if(!file)return;
 if(!reasons.has(uuid))reasons.set(uuid,[]);
 if(!reasons.get(uuid).includes(reason))reasons.get(uuid).push(reason);
 selected.set(uuid,file);
}
for(const owner of order){
 const manifest=manifests[owner];
 for(const file of manifest.files){
  const groups=file.groups||[];
  if(groups.some(group=>manifest.preload_groups.includes(group)))add(file.uuid,owner+':preload-group');
  if(owner==='game'&&groups.includes('#blocking'))add(file.uuid,'game:blocking');
 }
}
// Map iteration visits newly appended children, so this computes the closure.
for(const file of selected.values())for(const uuid of file.refs||[]){
 const dependency=resolved.get(uuid);
 if(dependency&&(dependency.groups||[]).includes('#blocking'))add(uuid,'blocking-ref:'+file.uuid);
}
const queue=[...selected.values()].map(file=>({
 owner:file.owner,uuid:file.uuid,path:file.fs_path,ext:file.ext,
 hash:file['hash@windows']??file.hash,bytes:file['size@windows']??file.size??0,
 assetName:file.uuid+'-'+(file['hash@windows']??file.hash)+file.ext,reasons:reasons.get(file.uuid),
})).sort((a,b)=>a.uuid.localeCompare(b.uuid));
const bytes=queue.reduce((sum,file)=>sum+file.bytes,0);
const hashes=new Map();
for(const file of queue){const key=file.hash+file.ext;if(!hashes.has(key))hashes.set(key,[]);hashes.get(key).push(file);}
const byOwner={};
for(const file of queue){byOwner[file.owner]??={files:0,bytes:0};byOwner[file.owner].files++;byOwner[file.owner].bytes+=file.bytes;}
const regular=queue.filter(file=>file.path==='Fonts/MiSans-Regular.ttf');
const project=regular.find(file=>file.owner==='game'),engine=regular.find(file=>file.owner==='engine-res');
if(!project||!engine)throw Error('Expected both project and engine Regular queue entries');
const runtimeData=path.join(root,'.tmp/web-engine/UrhoXRuntime.data');
const data=fs.readFileSync(runtimeData),headerLength=data.readUInt32LE(8);
if(data.subarray(0,8).toString()!=='URXRES1\0')throw Error('Unexpected bundled data format');
const header=JSON.parse(data.subarray(12,12+headerLength));
const bundled=header.files.find(file=>file.path==='assets/'+engine.assetName);
if(!bundled)throw Error('Engine Regular not found in the measured runtime data');
const base=12+headerLength+bundled.offset;
const engineBytes=data.subarray(base,base+bundled.size);
const localFont=fs.readFileSync(path.join(frozen,'assets',project.path));
const exactEqual=localFont.equals(engineBytes);
const checks={
 queueCountMatches:queue.length===observed.found,
 displayedSizeMatches:Number((bytes/1048576).toFixed(1))===observed.displayMiB,
 sameRegularHash:project.hash===engine.hash,
 sameRegularSize:project.bytes===engine.bytes,
 exactRegularBytesEqual:exactEqual,
 regularUUIDsDiffer:project.uuid!==engine.uuid,
 regularAssetNamesDiffer:project.assetName!==engine.assetName,
 hashCollapseDoesNotMatchObserved:hashes.size!==observed.found,
};
if(Object.values(checks).some(value=>!value))throw Error('Replay mismatch: '+JSON.stringify(checks));
const result={
 schema:1,result:'ADMISSION_REPLAY_MATCHED',boundary:'Read-only offline admission replay calibrated to existing measured log. No new browser, native run or per-request network trace.',
 sourceManifest:path.basename(gameManifest),sourceCommit:identity.identity.sourceCommit,scriptFingerprint:identity.identity.scriptFingerprint,
 inputs:Object.entries({...manifestPaths,console:consoleFile}).map(([name,file])=>({name,path:path.relative(root,file).replaceAll('\\','/'),sha256:sha(fs.readFileSync(file))})),
 observed,replay:{files:queue.length,bytes,MiB:bytes/1048576,byOwner,uuidOverrideCount:collisions.length,contentHashAndExtensionCount:hashes.size},
 regular:{project,engine,sha256:sha(localFont),bundled:{dataFile:path.relative(root,runtimeData).replaceAll('\\','/'),dataBytes:data.length,dataVersion:header.version,dataClient:header.client,...bundled},
  projectCopyUpperBoundBytes:project.bytes,
  conclusion:'Two distinct UUID/asset-name entries enter preload admission despite identical bytes; this layer does not merge by content hash. The engine copy also already exists inside the always-fetched Runtime.data. Aggregate completion counters do not prove downstream physical HTTP-byte deduplication or font parser/object counts.'},
 remainingBoundary:{alreadyAvailableCount:observed.found-observed.needed,alreadyAvailableUUIDs:'Not printed by the measured log; cannot assign the two exclusions or assert actual font HTTP fetches without a request/queue trace.',physicalTransferBytesSaved:'Not measured; at most one project copy (8122324 payload bytes). Runtime.data size and embedded font remain unchanged.',parserAndObjectSavings:'Not established. Existing nvgCreateFont/GetResource consumers still execute; changing resolution alone removes no call or context.'},
 checks,queue,
};
if(output){fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');}
console.log(JSON.stringify({...result,queue:undefined},null,2));

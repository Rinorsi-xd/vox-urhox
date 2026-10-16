// CPU/HTTP fixture audit; no engine, browser, production build or upload.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const crypto=require('node:crypto'),http=require('node:http'),zlib=require('node:zlib');
const {execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),directory=path.join(root,'.tmp/web-engine/http-cache');
const modulePath=path.join(__dirname,'cached-engine-sources.cjs');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const moduleHash=hash(fs.readFileSync(modulePath)),cache=require(modulePath);
const cases=[
 {source:'engine-res',key:'aa574cccd1a0ac0d12735920844fdd36af5a1eb49d048299236a7d4c7ab7f7dd',count:1085,bytes:65220730,
  missing:['i18n/en.json','urhox-libs/GameLobby/Runtime/Template/LobbyUI.lua','urhox-libs/Lobby/LobbyUI.lua','urhox-libs/Lobby/main.lua','urhox-libs/System/SystemNotification.lua']},
 {source:'urhox-libs',key:'6edc4ffbde96f007942097c49aa06b566964d649771a14d73883fd6f7d337dee',count:159,bytes:3378118,missing:[]},
];
async function main(){
 const results=[];let httpChecks=0;
 for(const item of cases){
  const snapshot=cache.snapshots[item.source],archive=path.join(directory,item.key);
  const manifest=JSON.parse(fs.readFileSync(path.join(directory,snapshot.manifest)));
  const rows=new Map();
  for(const row of manifest.files)for(const [key,value] of Object.entries(row)){
   if(key==='hash'||key.startsWith('hash@'))rows.set(`assets/${row.uuid}-${value}${row.ext}`,{row,hash:value,size:row['size'+key.slice(4)]??row.size??0});
  }
  const names=execFileSync('tar',['-tf',archive],{encoding:'utf8',windowsHide:true}).trim().split(/\r?\n/);
  assert.equal(names.length,item.count);
  assert.equal(new Set(names).size,names.length);
  assert.ok(names.every(name=>/^assets\/[A-Za-z0-9_-]+(?:\.[A-Za-z0-9]+)?$/.test(name)));
  const payload=execFileSync('tar',['-xOf',archive],{windowsHide:true,maxBuffer:128*1024*1024});
  let offset=0,equal=0;const unavailable=[];
  for(const name of names){
   const entry=rows.get(name);assert.ok(entry,'Archive entry absent from pinned manifest: '+name);
   const bytes=payload.subarray(offset,offset+entry.size);offset+=entry.size;
   assert.equal(bytes.length,entry.size);
   assert.equal(zlib.crc32(bytes).toString(16).padStart(8,'0'),entry.hash,name);
   const previous=cache.read('https://tapcode-sce.spark.xd.com/src/'+item.source+'/'+name);
   if(previous){assert.deepEqual(previous.body,bytes,'Existing per-file fallback changed: '+name);equal++;}
   else unavailable.push(entry.row.fs_path);
  }
  assert.equal(offset,payload.length);assert.equal(offset,item.bytes);
  assert.deepEqual(unavailable.sort(),[...item.missing].sort());
  results.push({source:item.source,version:snapshot.version,manifest:snapshot.manifest,archive:item.key,
   archiveSha256:hash(fs.readFileSync(archive)),compressedBytes:fs.statSync(archive).size,uncompressedBytes:offset,
   manifestPayloadChecks:names.length,oldFallbackEqual:equal,oldFallbackUnavailable:unavailable});
 }
 const server=http.createServer((req,res)=>{
  const cached=cache.read('https://tapcode-sce.spark.xd.com'+req.url);
  if(!cached){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',cached.headers['content-type']);res.end(cached.body);
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 try{
  const base='http://127.0.0.1:'+server.address().port;
  for(const item of cases){
   const version=cache.snapshots[item.source].version,prefix='/src/'+item.source+'/';
   for(const suffix of [version+'/assets@windows.7z','assets@windows.7z?v='+version]){
    const response=await fetch(base+prefix+suffix);assert.equal(response.status,200);
    assert.equal(response.headers.get('content-type'),'application/x-7z-compressed');
    assert.equal(hash(Buffer.from(await response.arrayBuffer())),results.find(r=>r.source===item.source).archiveSha256);httpChecks++;
   }
   for(const suffix of ['0.0.0/assets@windows.7z','assets@windows.7z?v=0.0.0','assets@windows.7z',
    version+'/assets@windows.7z?v=0.0.0',version+'/assets@web.7z',version+'/assets@android.7z',version+'/assets.7z']){
    const response=await fetch(base+prefix+suffix);assert.equal(response.status,404,suffix);await response.arrayBuffer();httpChecks++;
   }
  }
  for(const url of ['https://untrusted.invalid/src/engine-res/1.1.925/assets@windows.7z',
   'https://tapcode-sce.spark.xd.com/src/official-res/1.32.37/assets@windows.7z'])assert.equal(cache.read(url),null);
 }finally{await new Promise(resolve=>server.close(resolve));}
 assert.equal(hash(fs.readFileSync(modulePath)),moduleHash,'Fixture module changed during audit');
 const report={result:'PASS',productionChanges:false,toolHash:moduleHash,testHash:hash(fs.readFileSync(__filename)),packages:results,httpChecks,
  boundary:'Exact pinned cached Windows source archives. Per-entry CRC/size matches source manifest; existing per-file fallbacks compared byte for byte where available. Five absent engine fallbacks are explicitly reported. No boot timing, GPU, map-prefetch improvement or deployment acceptance.'};
 const output=path.join(root,'docs/migration/evidence/cached-engine-packages-offline.json');
 fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report));
}
main().catch(error=>{console.error(error);process.exitCode=1;});

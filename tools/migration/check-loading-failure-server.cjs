// Execute real preview request handlers with response/socket adapters; no network or runtime.
'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {createRequire}=require('node:module');
const ROOT=path.resolve(__dirname,'../..'),servePath=path.join(__dirname,'serve-outgame.cjs');
const file=process.argv[2]||'.tmp/outgame-cached-1792164278829/identity.json';
const prepared=JSON.parse(fs.readFileSync(path.resolve(ROOT,file)));
assert.equal(prepared.ok,true,'Explicit immutable prepared fixture');
const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path));
const main=manifest.files.find(item=>item.fs_path==='main.lua'),payload=main.uuid+'-'+main.hash+main.ext;
const packed=fs.readFileSync(path.join(prepared.source_directory,'dist/assets',payload));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
let checks=0;
function check(ok,label){assert.ok(ok,label);checks++}
function run(args){
 let handler;
 const socket={listen(){return this},close(){}};
 const localRequire=createRequire(servePath);
 const adaptedFs={...fs,createReadStream(file){return {pipe(response){response.end(fs.readFileSync(file))}}}};
 const context={require(name){
  if(name==='node:http')return {createServer(fn){handler=fn;return socket}};
  if(name==='node:fs')return adaptedFs;
  return localRequire(name);
 },module:{exports:{}},__dirname:path.dirname(servePath),Buffer,console:{log(){}},
 process:{env:{VOX_PREPARE_FILE:path.resolve(ROOT,file),VOX_PREVIEW_PORT:'49999'},argv:['node',servePath,...args],pid:process.pid,on(){}}};
 vm.runInNewContext(fs.readFileSync(servePath,'utf8'),context,{filename:servePath});
 context.module.exports.startPreviewServer();
 check(typeof handler==='function','Actual preview handler installed');
 function request(url){
  let body;const response={headers:{},setHeader(key,value){this.headers[key]=value},writeHead(code){this.status=code;return this},
   end(value){body=Buffer.isBuffer(value)?value:Buffer.from(value||'')}};
  handler({url},response);check(Buffer.isBuffer(body),'Actual request handler completed '+url);return body;
 }
 const identity=JSON.parse(request('/identity.json'));
 const actualMain=request('/game-dist/assets/'+payload);
 const actualManifest=JSON.parse(request('/game-dist/1.0.0/'+path.basename(prepared.manifest_path)));
 return {identity,actualMain,actualManifest};
}
const normal=run([]),defaultQa=run(['--qa','--monitor-disabled']),fault=run(['--qa','--monitor-disabled','--loading-failure-test']);
for(const item of [normal,defaultQa]){
 check(item.identity.loadingFailureTest===false,'Default mode reports injection off');
 check(!item.actualMain.includes(Buffer.from('VOX_QA_CONTROLLED_POST_INSTALL_WARMUP_FAILURE')),'Default main does not contain fault suffix');
}
check(normal.actualMain.equals(packed),'Ordinary main remains byte-identical to packed production');
assert.deepEqual(normal.actualManifest,manifest);checks++;
for(const item of [defaultQa,fault]){
 const suffix=item.actualMain.subarray(packed.length+1);
 check(item.actualMain.subarray(0,packed.length).equals(packed),'QA preserves exact production prefix');
 check(sha(suffix)===item.identity.probeSha256,'Identity signs actual served QA suffix');
 check(item.actualManifest.files.find(file=>file.fs_path==='main.lua').size===item.actualMain.length,'Served manifest advertises actual suffixed bytes');
}
const expectedFault=Buffer.concat([defaultQa.actualMain,Buffer.from('\n'),fs.readFileSync(path.join(__dirname,'qa-loading-failure.lua'))]);
check(fault.actualMain.equals(expectedFault),'Dedicated suffix appended exactly once after disabled-monitor observer');
check(fault.identity.loadingFailureTest===true,'Fault QA explicitly identifies itself');
let negative=0;
for(const args of [['--loading-failure-test'],['--qa','--loading-failure-test','--profile-combat'],
 ['--qa','--loading-failure-test','--story-route'],['--qa','--loading-failure-test','--profile-drive-sections'],
 ['--qa','--loading-failure-test','--render-experiment']]){
 assert.throws(()=>run(args),/requires explicit QA|Keep controlled loading failure separate/);negative++;
}
const report={result:'PASS',checks,negativeControls:negative,preparedFixture:path.resolve(ROOT,file),
 manifest:path.basename(prepared.manifest_path),normalMainSha256:sha(normal.actualMain),
 defaultQaSuffixSha256:defaultQa.identity.probeSha256,failureQaSuffixSha256:fault.identity.probeSha256,
 files:Object.fromEntries(['serve-outgame.cjs','qa-loading-failure.lua','check-loading-failure-server.cjs'].map(name=>
  ['tools/migration/'+name,sha(fs.readFileSync(path.join(__dirname,name)))])),
 boundary:'Real serve-outgame module and request handlers over a real frozen package; socket and response adapters. No actual HTTP server, browser, engine, GPU, gameplay or performance acceptance.'};
fs.writeFileSync(path.join(ROOT,'docs/migration/evidence/qa-loading-failure-server-offline.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));

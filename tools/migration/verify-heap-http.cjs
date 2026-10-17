const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
async function verifyHeapHttp(base,identity){
 const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
 assert.equal(identity.qa,true);assert.equal(identity.monitorDisabled,true);
 for(const flag of ['storyRoute','homeRoute','loadProfile','combatProfile','driveSectionsProfile','trialSectionsProfile','renderExperiment','warmExperiment','warmIntroExperiment','loadingFailureTest'])assert.equal(identity[flag],false,'Separate heap QA has no '+flag);
 const prepared=JSON.parse(fs.readFileSync(path.join(identity.source_directory,'identity.json')));
 assert.deepEqual(identity.identity,prepared.identity,'Frozen script identity');assert.deepEqual(identity.engineSources,prepared.engineSources,'Frozen engine source identity');
 const manifestBytes=fs.readFileSync(prepared.manifest_path),manifest=JSON.parse(manifestBytes),main=manifest.files.find(f=>f.fs_path==='main.lua');
 const name=main.uuid+'-'+main.hash+main.ext,packed=fs.readFileSync(path.join(identity.source_directory,'dist/assets',name));
 const suffix=Buffer.concat([fs.readFileSync(path.join(__dirname,'qa-frame-wall-observer.lua')),Buffer.from('\n'),fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua')),Buffer.from('\n'),fs.readFileSync(path.join(__dirname,'monitor-disabled-observer.lua'))]);
 assert.equal(identity.probeSha256,sha(suffix),'Exact wall observer + probe + monitor override suffix');
 const expected=Buffer.concat([packed,Buffer.from('\n'),suffix]);
 const read=async route=>{const response=await fetch(base+route,{signal:AbortSignal.timeout(20000)});assert.equal(response.status,200,route);return Buffer.from(await response.arrayBuffer());};
 const [servedMain,servedManifest,runtimeJs,runtimeWasm]=await Promise.all([read('/game-dist/assets/'+name),read('/game-dist/1.0.0/'+path.basename(prepared.manifest_path)),read('/UrhoXRuntime.js'),read('/UrhoXRuntime.wasm')]);
 assert.ok(servedMain.equals(expected),'Actual HTTP main is exact frozen production plus explicit suffix');
 const expectedManifest=JSON.parse(manifestBytes);expectedManifest.files.find(f=>f.fs_path==='main.lua').size=expected.length;
 assert.deepEqual(JSON.parse(servedManifest),expectedManifest,'Only declared QA main size differs');
 const localRoot=path.resolve(__dirname,'../../.tmp/web-engine');
 assert.ok(runtimeJs.equals(fs.readFileSync(path.join(localRoot,'UrhoXRuntime.js'))),'Actual HTTP runtime JS exact local artifact');
 assert.ok(runtimeWasm.equals(fs.readFileSync(path.join(localRoot,'UrhoXRuntime.wasm'))),'Actual HTTP runtime WASM exact local artifact');
 assert.deepEqual(JSON.parse(await read('/identity.json')),identity,'HTTP identity remains stable');
 return {result:'PASS',sourceDirectory:identity.source_directory,manifest:path.basename(prepared.manifest_path),scriptFingerprint:identity.identity.scriptFingerprint,main:{name,bytes:servedMain.length,sha256:sha(servedMain)},probeSha256:sha(suffix),runtimeJs:{bytes:runtimeJs.length,sha256:sha(runtimeJs)},runtimeWasm:{bytes:runtimeWasm.length,sha256:sha(runtimeWasm)},boundary:'HTTP bytes only; no engine execution or performance acceptance.'};
}
module.exports={verifyHeapHttp};

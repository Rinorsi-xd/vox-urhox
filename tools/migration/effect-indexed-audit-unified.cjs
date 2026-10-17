// Independent file/HTTP audit only. No browser, runtime, service or source edits.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const snapshot=path.resolve(root,process.argv[2]);const port=Number(process.argv[3]);const label=process.argv[4];
const expectedManifest=process.argv[5]||'manifest-2a92fa6d.json';
const expectedFingerprint=process.argv[6]||'7846662f5723b3f1a79c19e085ac9de5f7f119fccce9bd4359242763a257688e';
assert.match(expectedManifest,/^manifest-[a-f0-9]{8}\.json$/);assert.match(expectedFingerprint,/^[a-f0-9]{64}$/);
assert.ok(port>0&&Number.isInteger(port));assert.match(label,/^[A-Za-z0-9_-]+$/);
const output=path.join(root,'docs/migration/evidence',label+'.json');assert.ok(!fs.existsSync(output),'Preserve prior independent evidence');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const fileSha=file=>sha(fs.readFileSync(file));
function luaHashes(base){const result={};for(const entry of fs.readdirSync(base,{withFileTypes:true,recursive:true})){
 if(entry.isFile()&&entry.name.endsWith('.lua')){const file=path.join(entry.parentPath,entry.name);result[path.relative(base,file).replaceAll('\\','/')]=fileSha(file);}
}return result;}
async function bytes(route){const response=await fetch('http://127.0.0.1:'+port+route);assert.equal(response.status,200,route);return Buffer.from(await response.arrayBuffer());}
(async()=>{
 const identityBytes=fs.readFileSync(path.join(snapshot,'identity.json')),prepared=JSON.parse(identityBytes);
 const manifestBytes=fs.readFileSync(prepared.manifest_path),manifest=JSON.parse(manifestBytes);
 assert.equal(path.basename(prepared.manifest_path),expectedManifest);
 const current=luaHashes(path.join(root,'scripts')),frozen=luaHashes(path.join(snapshot,'scripts'));
 assert.deepEqual(Object.keys(current).sort(),Object.keys(frozen).sort(),'No missing/extra production Lua');
 assert.deepEqual(Object.keys(frozen).sort(),Object.keys(prepared.identity.scripts).sort(),'Identity lists exactly the frozen Lua');
 const payloads=[];
 for(const name of Object.keys(current).sort()){
  assert.equal(current[name],frozen[name],name+' production/frozen');assert.equal(frozen[name],prepared.identity.scripts[name],name+' identity');
  const matches=manifest.files.filter(row=>row.ext==='.lua'&&row.fs_path===name);assert.equal(matches.length,1,name+' unique payload');
  const row=matches[0],relative=row.uuid+'-'+row.hash+row.ext;
  const payload=fs.readFileSync(path.join(snapshot,'dist/assets',relative));assert.equal(sha(payload),current[name],name+' manifest payload');
  assert.equal(payload.length,row.size,name+' manifest size');assert.ok(row.groups.includes('#blocking'),name+' model loading contract');
  payloads.push({name,sha256:current[name],bytes:payload.length,payload:relative});
 }
 assert.equal(manifest.files.filter(row=>row.ext==='.lua').length,payloads.length,'No unexpected Lua manifest entries');
 const fingerprint=sha(JSON.stringify(Object.entries(frozen).sort()));assert.equal(fingerprint,prepared.identity.scriptFingerprint);
 assert.equal(fingerprint,expectedFingerprint);
 const experimentFiles=[...Object.keys(current),...Object.keys(frozen),...manifest.files.map(row=>row.fs_path)].filter(name=>/IndexedEffectCandidate|effect-indexed-(?:bounds|strict|mixed)/i.test(name));
 assert.deepEqual(experimentFiles,[],'No experiment in production/frozen/manifest');
 const servedIdentityBytes=await bytes('/identity.json'),servedIdentity=JSON.parse(servedIdentityBytes);
 assert.equal(servedIdentity.qa,false);assert.equal(servedIdentity.port,port);assert.equal(servedIdentity.probeSha256,null);
 assert.equal(path.resolve(servedIdentity.source_directory),snapshot);assert.deepEqual(servedIdentity.identity,prepared.identity);
 assert.deepEqual(servedIdentity.engineSources,prepared.engineSources);assert.equal(servedIdentity.servedManifest,path.basename(prepared.manifest_path));
 for(const flag of ['qaAimEngine','qaSalvageStock','monitorDisabled','storyRoute','homeRoute','loadProfile','combatProfile','driveSectionsProfile','trialSectionsProfile','afterStepProfile','framePipelineProfile','fixedStepPipelineProfile','loadingFailureTest','renderExperiment','warmExperiment','warmIntroExperiment'])assert.equal(servedIdentity[flag],false,flag);
 const servedManifest=await bytes('/game-dist/1.0.0/'+path.basename(prepared.manifest_path));assert.ok(servedManifest.equals(manifestBytes),'Actual HTTP manifest exact bytes');
 const names=['main.lua','render/CombatEffects.lua','render/WeaponEffects.lua','app/TrialSession.lua',
  'story/CaptureRules.lua','story/MissionRules.lua','story/Mission.lua','app/EndlessSession.lua','endless/View.lua','combat/BattleController.lua',
  'combat/CarUnit.lua','drive/SpawnSpecCache.lua','construction/TurretRange.lua'];
 const http=[];
 for(const name of names){const payload=payloads.find(row=>row.name===name);assert.ok(payload,name);
  const actual=await bytes('/game-dist/assets/'+payload.payload);assert.equal(sha(actual),payload.sha256,name+' actual HTTP bytes');
  http.push({...payload,httpSha256:sha(actual),httpBytes:actual.length,exactBytes:true});
 }
 assert.ok((await bytes('/identity.json')).equals(servedIdentityBytes),'HTTP identity remained byte-stable');
 const result={status:'INDEPENDENT_UNIFIED_CONTENT_HTTP_PASS',at:new Date().toISOString(),snapshot,port,
  manifest:path.basename(prepared.manifest_path),manifestSha256:sha(manifestBytes),identitySha256:sha(identityBytes),
  servedIdentitySha256:sha(servedIdentityBytes),sourceCommit:prepared.identity.sourceCommit,targetCommit:prepared.identity.targetCommit,
  fingerprint,luaCount:payloads.length,experimentFiles,allProductionFrozenIdentityPayloadEqual:true,
  allManifestLuaBlocking:true,actualHttpManifestExact:true,ordinary:true,monitorEnabled:servedIdentity.perfMonitor,
  http,payloads,boundary:'Read-only independent SHA256 and actual localhost HTTP bytes. No browser, Runtime, GPU, startup, gameplay, audio, sustained FPS or target-device acceptance. Existing root-owned service untouched.'};
 fs.writeFileSync(output,JSON.stringify(result,null,2),{flag:'wx'});
 console.log(JSON.stringify({status:result.status,luaCount:result.luaCount,fingerprint,httpModules:http.length,output}));
})().catch(error=>{console.error(error);process.exitCode=1});

// HTTP byte identity only: no browser, engine execution, or production writes.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),snapshot=path.resolve(root,process.argv[2]);
const ports=process.argv.slice(3).map(Number);assert.equal(ports.length,2);
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const prepared=JSON.parse(fs.readFileSync(path.join(snapshot,'identity.json')));
const manifestBytes=fs.readFileSync(prepared.manifest_path),manifest=JSON.parse(manifestBytes);
const main=manifest.files.find(f=>f.fs_path==='main.lua'),payload=`${main.uuid}-${main.hash}${main.ext}`;
const packedMain=fs.readFileSync(path.join(snapshot,'dist/assets',payload));
const probe=fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'));
async function bytes(port,route){const response=await fetch(`http://127.0.0.1:${port}${route}`);assert.equal(response.status,200,route);return Buffer.from(await response.arrayBuffer());}
(async()=>{
 const observations=[];
 for(const [index,port]of ports.entries()){
  const [identityBytes,servedManifest,servedMain]=await Promise.all([bytes(port,'/identity.json'),bytes(port,`/game-dist/1.0.0/${path.basename(prepared.manifest_path)}`),bytes(port,`/game-dist/assets/${payload}`)]);
  const identity=JSON.parse(identityBytes),qa=index===1;
  assert.equal(identity.qa,qa);assert.equal(identity.port,port);assert.equal(identity.servedManifest,path.basename(prepared.manifest_path));
  assert.equal(path.resolve(identity.source_directory),snapshot);assert.deepEqual(identity.identity,prepared.identity);assert.deepEqual(identity.engineSources,prepared.engineSources);
  for(const flag of ['loadProfile','combatProfile','renderExperiment','warmExperiment','warmIntroExperiment'])assert.equal(identity[flag],false,flag);
  const expected=qa?Buffer.concat([packedMain,Buffer.from('\n'),probe]):packedMain;
  assert.ok(servedMain.equals(expected),'HTTP main payload bytes');
  const expectedManifest=JSON.parse(manifestBytes);if(qa)expectedManifest.files.find(f=>f.fs_path==='main.lua').size=expected.length;
  assert.deepEqual(JSON.parse(servedManifest),expectedManifest,'only QA main.size may differ');
  if(qa)assert.equal(identity.probeSha256,sha(probe));else{assert.equal(identity.probeSha256,null);assert.ok(servedManifest.equals(manifestBytes));}
  const after=JSON.parse(await bytes(port,'/identity.json'));assert.deepEqual(after,identity,'HTTP identity remains stable');
  observations.push({port,processId:identity.processId,qa,sourceDirectory:identity.source_directory,servedManifest:identity.servedManifest,scriptFingerprint:identity.identity.scriptFingerprint,luaCount:Object.keys(identity.identity.scripts).length,probeSha256:identity.probeSha256,main:{file:payload,bytes:servedMain.length,sha256:sha(servedMain),packedSha256:sha(packedMain),exactExpectedBytes:true},manifest:{sha256:sha(servedManifest),diskSha256:sha(manifestBytes),exactExpectedStructure:true,rawEqualsDisk:servedManifest.equals(manifestBytes)},identitySha256:sha(identityBytes),profilesDisabled:true});
 }
 const report={result:'PASS',snapshot,manifest:path.basename(prepared.manifest_path),scriptFingerprint:prepared.identity.scriptFingerprint,probeFile:'tools/migration/probe-outgame-web.lua',probeFileSha256:sha(probe),observations,boundary:'Actual HTTP identity/manifest/main payload bytes and exact QA probe suffix. No browser, GPU, engine startup, natural gameplay, decoded audio, runtime memory or performance acceptance.'};
 const out=path.join(root,'docs/migration/evidence/http-snapshot-'+path.basename(prepared.manifest_path,'.json')+'-audit.json');fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({...report,evidence:out},null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});

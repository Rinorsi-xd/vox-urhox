// HTTP byte identity only: no browser, engine execution, or production writes.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),snapshot=path.resolve(root,process.argv[2]);
const ports=process.argv.slice(3).map(Number);assert.equal(ports.length,2);
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const prepared=JSON.parse(fs.readFileSync(path.join(snapshot,'identity.json')));
const manifestBytes=fs.readFileSync(prepared.manifest_path),manifest=JSON.parse(manifestBytes);
const main=manifest.files.find(f=>f.fs_path==='main.lua'),payload=`${main.uuid}-${main.hash}${main.ext}`;
const packedMain=fs.readFileSync(path.join(snapshot,'dist/assets',payload));
const probeFor=identity=>Buffer.concat([fs.readFileSync(path.join(__dirname,'qa-frame-wall-observer.lua')),Buffer.from('\n'),
 ...(identity.driveSectionsProfile?[Buffer.from(require('./build-drive-sections-probe.cjs').buildDriveSectionsProbe(prepared,{trialSections:identity.trialSectionsProfile===true,afterStep:identity.afterStepProfile===true})+'\n')]:[]),
 fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'))]);
async function bytes(port,route){const response=await fetch(`http://127.0.0.1:${port}${route}`);assert.equal(response.status,200,route);return Buffer.from(await response.arrayBuffer());}
(async()=>{
 const observations=[];
 for(const [index,port]of ports.entries()){
  const [identityBytes,servedManifest,servedMain]=await Promise.all([bytes(port,'/identity.json'),bytes(port,`/game-dist/1.0.0/${path.basename(prepared.manifest_path)}`),bytes(port,`/game-dist/assets/${payload}`)]);
  const identity=JSON.parse(identityBytes),qa=index===1;
  assert.equal(identity.qa,qa);assert.equal(identity.port,port);assert.equal(identity.servedManifest,path.basename(prepared.manifest_path));
  assert.equal(path.resolve(identity.source_directory),snapshot);assert.deepEqual(identity.identity,prepared.identity);assert.deepEqual(identity.engineSources,prepared.engineSources);
  for(const flag of ['loadProfile','combatProfile','renderExperiment','warmExperiment','warmIntroExperiment'])assert.equal(identity[flag],false,flag);
  assert.ok(!(identity.storyRoute&&identity.homeRoute),'Only one route projection');
  assert.ok(!identity.trialSectionsProfile||identity.driveSectionsProfile,'Trial sections extend explicit drive scopes');
  assert.ok(!identity.afterStepProfile||identity.trialSectionsProfile,'AfterStep extends explicit trial scopes');
  assert.equal(typeof identity.framePipelineProfile,'boolean','Explicit frame-pipeline identity');
  assert.ok(!identity.fixedStepPipelineProfile||identity.framePipelineProfile,'Fixed-step pipeline extends frame pipeline');
  assert.ok(!identity.presentationPipelineProfile||(identity.fixedStepPipelineProfile&&!identity.qaAimEngine&&!identity.qaSalvageStock),'Dedicated presentation extension');
  assert.ok(!identity.beforeStepPipelineProfile||identity.presentationPipelineProfile,'Dedicated BeforeStep extension');
  assert.ok(!identity.vehiclePipelineProfile||identity.beforeStepPipelineProfile,'Dedicated Vehicle extension');
  if(identity.framePipelineProfile)assert.ok(qa&&identity.monitorDisabled&&!identity.perfMonitor&&!identity.storyRoute&&!identity.homeRoute&&!identity.driveSectionsProfile&&!identity.trialSectionsProfile&&!identity.loadingFailureTest,'Dedicated dormant-wrapper frame-pipeline QA');
  const probe=probeFor(identity);
  const route=identity.homeRoute?'home-route-observer.lua':identity.storyRoute?'story-route-observer.lua':null;
  const routeProbe=route?Buffer.concat([...(identity.storyRoute?[fs.readFileSync(path.join(__dirname,'story-combat-observer.lua')),Buffer.from('\n')]:[]),fs.readFileSync(path.join(__dirname,route)),Buffer.from('\n'),probe]):probe;
  const monitorProbe=identity.monitorDisabled?Buffer.concat([routeProbe,Buffer.from('\n'),fs.readFileSync(path.join(__dirname,'monitor-disabled-observer.lua'))]):routeProbe;
  assert.equal(typeof identity.loadingFailureTest,'boolean','Explicit controlled-loading-failure identity');
  if(identity.loadingFailureTest)assert.ok(qa&&!identity.storyRoute&&!identity.homeRoute&&!identity.driveSectionsProfile&&!identity.trialSectionsProfile,'Dedicated failure QA without other projections');
  const failureProbe=identity.loadingFailureTest?Buffer.concat([monitorProbe,Buffer.from('\n'),fs.readFileSync(path.join(__dirname,'qa-loading-failure.lua'))]):monitorProbe;
  const pipelineProbe=identity.framePipelineProfile?Buffer.concat([failureProbe,Buffer.from('\n'+require('./build-frame-pipeline-probe.cjs').buildFramePipelineProbe(prepared,{fixedSteps:identity.fixedStepPipelineProfile===true,presentation:identity.presentationPipelineProfile===true,beforeStep:identity.beforeStepPipelineProfile===true,vehicle:identity.vehiclePipelineProfile===true})+'\n'),fs.readFileSync(path.join(__dirname,'qa-frame-pipeline-control.lua'))]):failureProbe;
  if(identity.qaAimEngine)assert.ok(qa,'Aim engine fixture requires QA');
  const aimProbe=identity.qaAimEngine?Buffer.concat([pipelineProbe,Buffer.from('\n'),fs.readFileSync(path.join(__dirname,'qa-aim-engine.lua'))]):pipelineProbe;
  if(identity.qaSalvageStock)assert.ok(qa&&!identity.qaAimEngine,'Independent salvage stock fixture requires QA');
  const servedProbe=identity.qaSalvageStock?Buffer.concat([aimProbe,Buffer.from('\n'),fs.readFileSync(path.join(__dirname,'qa-salvage-stock.lua'))]):aimProbe;
  const expected=qa?Buffer.concat([packedMain,Buffer.from('\n'),servedProbe]):packedMain;
  assert.ok(servedMain.equals(expected),'HTTP main payload bytes');
  const expectedManifest=JSON.parse(manifestBytes);if(qa)expectedManifest.files.find(f=>f.fs_path==='main.lua').size=expected.length;
  assert.deepEqual(JSON.parse(servedManifest),expectedManifest,'only QA main.size may differ');
  if(qa)assert.equal(identity.probeSha256,sha(servedProbe));else{assert.equal(identity.probeSha256,null);assert.ok(servedManifest.equals(manifestBytes));}
  const after=JSON.parse(await bytes(port,'/identity.json'));assert.deepEqual(after,identity,'HTTP identity remains stable');
  observations.push({port,processId:identity.processId,qa,sourceDirectory:identity.source_directory,servedManifest:identity.servedManifest,scriptFingerprint:identity.identity.scriptFingerprint,luaCount:Object.keys(identity.identity.scripts).length,probeSha256:identity.probeSha256,main:{file:payload,bytes:servedMain.length,sha256:sha(servedMain),packedSha256:sha(packedMain),exactExpectedBytes:true},manifest:{sha256:sha(servedManifest),diskSha256:sha(manifestBytes),exactExpectedStructure:true,rawEqualsDisk:servedManifest.equals(manifestBytes)},identitySha256:sha(identityBytes),profilesDisabled:!identity.driveSectionsProfile,driveSectionsProfile:identity.driveSectionsProfile===true,loadingFailureTest:identity.loadingFailureTest});
 }
 const report={result:'PASS',snapshot,manifest:path.basename(prepared.manifest_path),scriptFingerprint:prepared.identity.scriptFingerprint,probeFile:'tools/migration/probe-outgame-web.lua',probeFileSha256:sha(fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'))),observations,boundary:'Actual HTTP identity/manifest/main payload bytes and exact QA probe suffix, including explicitly identified optional drive sections and controlled-loading-failure injection. No browser, GPU, engine startup, natural gameplay, decoded audio, runtime memory or performance acceptance.'};
 const out=path.join(root,'docs/migration/evidence/http-snapshot-'+path.basename(prepared.manifest_path,'.json')+'-'+ports.join('-')+'-audit.json');fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({...report,evidence:out},null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});

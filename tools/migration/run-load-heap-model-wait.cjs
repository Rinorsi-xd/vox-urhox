'use strict';
// Single-file, request-scoped loading candidate; frozen package stays immutable.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),Module=require('node:module');
const ROOT=path.resolve(__dirname,'../..'),PREPARE='.tmp/outgame-cached-1792189057538/identity.json',NAME='app/SceneLoader.lua';
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
function once(source,needle,replacement){assert.equal(source.split(needle).length,2,'Unique model-wait candidate boundary '+needle.slice(0,100));return source.replace(needle,replacement)}
function candidate(){
 const prepared=JSON.parse(fs.readFileSync(path.join(ROOT,PREPARE),'utf8')),source=fs.readFileSync(path.join(prepared.source_directory,'scripts',NAME));
 assert.equal(sha(source),prepared.identity.scripts[NAME]);
 const original='self.warmIndex=self.warmIndex+1;self.warmWait=3';
 const replacement="self.warmIndex=self.warmIndex+1;self.warmWait=(item.type=='Model' and 0 or 3)";
 const bytes=Buffer.from(once(source.toString('utf8'),original,replacement));
 assert.equal(bytes.toString('utf8').replace(replacement,original),source.toString('utf8'),'Exactly one scheduling assignment differs');
 const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path)),asset=manifest.files.find(file=>file.fs_path===NAME);assert.ok(asset);
 const assetName=asset.uuid+'-'+asset.hash+asset.ext;
 assert.ok(fs.readFileSync(path.join(prepared.source_directory,'dist/assets',assetName)).equals(source),'Packed original module equals audited frozen Lua');
 return {bytes,original:source,assetName,identity:{kind:'model-warm-wait-only',manifest:path.basename(prepared.manifest_path),allowlist:[NAME],originalSha256:sha(source),candidateSha256:sha(bytes),originalBytes:source.length,candidateBytes:bytes.length,assetName,
  originalAssignment:original,candidateAssignment:replacement,phasePresentationGateUnchanged:true,textureWaitFrames:3,modelWaitFrames:0,downloadAndReadinessUnchanged:true,
  boundary:'Only successful ready Model resources skip the three no-work warmWait updates. Queue/readiness/failure/timeout/cancel/generation and all texture retirement waits remain original. Loading latency candidate, not a combat FPS optimization.'}};
}
function runnerSource(source){
 const data=candidate();
 source=once(source,"const builder=require('./build-load-heap-boundary-probe.cjs');","const builder=require('./build-load-heap-boundary-probe.cjs');\nconst modelWaitCandidate=require('./run-load-heap-model-wait.cjs').candidate();");
 source=once(source,"const injectedManifest=structuredClone(manifest);injectedManifest.files.find(file=>file.fs_path==='main.lua').size=injectedMain.length;",String.raw`
 const injectedManifest=structuredClone(manifest);injectedManifest.files.find(file=>file.fs_path==='main.lua').size=injectedMain.length;
 injectedManifest.files.find(file=>file.fs_path==='app/SceneLoader.lua').size=modelWaitCandidate.bytes.length;`);
 source=once(source,"report.toolSha256=sha(fs.readFileSync(__filename));",String.raw`
  report.toolSha256=sha(fs.readFileSync(__filename));
  report.candidate={...modelWaitCandidate.identity,adapterSha256:sha(fs.readFileSync(path.join(__dirname,'run-load-heap-model-wait.cjs')))};
  fs.writeFileSync(path.join(out,'candidate-identity.json'),JSON.stringify(report.candidate,null,2));
  fs.writeFileSync(path.join(out,'candidate-SceneLoader.lua'),modelWaitCandidate.bytes);`);
 source=once(source,"const interceptedPaths=['/game-dist/assets/'+payload.name,report.httpAudit.manifestRoute];","const interceptedPaths=['/game-dist/assets/'+payload.name,report.httpAudit.manifestRoute,'/game-dist/assets/'+modelWaitCandidate.assetName];");
 source=once(source,"if(report.httpAudit.injectionRequired)for(const routePath of interceptedPaths){","assert.equal(report.httpAudit.injectionRequired,true,'Candidate requires ordinary origin QA with request-only main/module/manifest injection');\n  for(const routePath of interceptedPaths){");
 source=once(source,"const main=routePath.endsWith(payload.name);if(main)assert.ok(original.equals(payload.originalMain));else assert.deepEqual(JSON.parse(original),payload.originalManifest);\n     const body=main?payload.injectedMain:Buffer.from(JSON.stringify(payload.injectedManifest));",String.raw`
     const main=routePath.endsWith(payload.name),model=routePath.endsWith(modelWaitCandidate.assetName);
     if(main)assert.ok(original.equals(payload.originalMain));else if(model)assert.ok(original.equals(modelWaitCandidate.original));else assert.deepEqual(JSON.parse(original),payload.originalManifest);
     const body=main?payload.injectedMain:model?modelWaitCandidate.bytes:Buffer.from(JSON.stringify(payload.injectedManifest));`);
 source=once(source,"if(url.pathname.endsWith(payload.name))assert.ok(bytes.equals(payload.injectedMain),'Actual browser main exact injected bytes');else assert.deepEqual(JSON.parse(bytes),payload.injectedManifest);",String.raw`
    if(url.pathname.endsWith(payload.name))assert.ok(bytes.equals(payload.injectedMain),'Actual browser main exact injected bytes');
    else if(url.pathname.endsWith(modelWaitCandidate.assetName))assert.ok(bytes.equals(modelWaitCandidate.bytes),'Actual browser SceneLoader equals allowlisted candidate');
    else assert.deepEqual(JSON.parse(bytes),payload.injectedManifest);`);
 source=once(source,"check(interceptedPaths.every(routePath=>report.browserInjection.responses.some(row=>row.path===routePath)),'Actual browser main and manifest response bytes verified');",String.raw`
  check(interceptedPaths.every(routePath=>report.browserInjection.responses.some(row=>row.path===routePath)),'Actual browser main, single allowlisted SceneLoader and manifest response bytes verified');
  check(report.browserInjection.fulfilled.length===3,'Exactly three scoped injection responses: existing QA main suffix, candidate SceneLoader, and manifest sizes');`);
 assert.ok(source.includes(data.identity.candidateSha256)===false,'Candidate bytes supplied through immutable adapter export');
 source=once(source,'module.exports={serverSource,sourceSuffix,auditHttp,verifyRecords,selfTest};','module.exports={run,serverSource,sourceSuffix,auditHttp,verifyRecords,selfTest};');
 return source;
}
function compile(file,source){const m=new Module(file,module);m.filename=file;m.paths=Module._nodeModulePaths(path.dirname(file));m._compile(source,file);return m.exports}
function selfTest(){
 const source=fs.readFileSync(path.join(__dirname,'run-load-heap-boundary-short.cjs'),'utf8');new(require('node:vm').Script)(runnerSource(source));
 assert.throws(()=>runnerSource(source.replace("const interceptedPaths=['/game-dist/assets/'+payload.name,report.httpAudit.manifestRoute];",'drift')));
 const c=candidate(),out=path.join(ROOT,'.tmp/load-heap-model-wait-f881');fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'SceneLoader.lua'),c.bytes);fs.writeFileSync(path.join(out,'identity.json'),JSON.stringify(c.identity,null,2));
 console.log(JSON.stringify({result:'PASS_OFFLINE',directory:out,...c.identity},null,2));
}
module.exports={candidate,runnerSource,selfTest};
if(require.main===module){
 if(process.argv.includes('--self-test'))selfTest();
 else{assert.deepEqual(process.argv.slice(2),[],'Candidate has no extra flags');process.env.VOX_PREPARE_FILE=PREPARE;const file=path.join(__dirname,'run-load-heap-boundary-short.cjs');compile(file,runnerSource(fs.readFileSync(file,'utf8'))).run().catch(error=>{console.error(error.stack);process.exitCode=1})}
}

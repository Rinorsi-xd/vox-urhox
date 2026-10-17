// Derive from the already successful actual Native capture entry and runner.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const cp=require('node:child_process');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const target=path.resolve(root,process.argv[2]||'.tmp/ray-static-shadow-4a3a-1017-a');
assert(target.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(target));
cp.execFileSync(process.execPath,[path.join(__dirname,'prepare-ray-static-query-capture.cjs'),path.relative(root,target)],{stdio:'pipe'});
const identityPath=path.join(target,'identity.json'),identity=JSON.parse(fs.readFileSync(identityPath));
let entry=fs.readFileSync(path.join(target,'scripts/ray-static-query-capture.lua'),'utf8');
function replace(text,from,to){assert.equal(text.split(from).length,2,'Exact fixture anchor '+from);return text.replace(from,to)}
entry=replace(entry,"recorder=require('ray-static-query-recorder').New{units=world.units}","recorder=require('ray-static-shadow').New(require('ray-static-candidate'))");
entry=replace(entry,"assert(result.vehicleCount==8,'Capture must cover eight actual vehicles')","assert(result.vehicles>=8,'Shadow must cover eight actual vehicles')");
entry=replace(entry,"assert(#result.records>0 and result.cold>0 and result.warm>0,'Actual cold and warm queries required')","assert(result.queries>0 and result.cold>0 and result.warm>0,'Actual cold and warm queries required')");
entry=replace(entry,"'INVALID_QUERY_CAPTURE_OVERHEAD'","'INVALID_SHADOW_OVERHEAD'");
fs.writeFileSync(path.join(target,'scripts/ray-static-query-capture.lua'),entry);
const candidatePath=path.join(root,'.tmp/ray-static-bounds-4a3a-1017-b/VehicleRay.candidate.lua');
const candidate=fs.readFileSync(candidatePath);assert.equal(sha(candidate),'65b25073b09a000cbbcaba954d88b14e14a5a19806ebdcbddaa425b6794ec25f');
const shadow=fs.readFileSync(path.join(__dirname,'ray-static-shadow.lua'));
fs.writeFileSync(path.join(target,'scripts/ray-static-candidate.lua'),candidate,{flag:'wx'});
fs.writeFileSync(path.join(target,'scripts/ray-static-shadow.lua'),shadow,{flag:'wx'});
identity.sourceHashes['scripts/ray-static-query-capture.lua']=sha(entry);
identity.sourceHashes['scripts/ray-static-candidate.lua']=sha(candidate);
identity.sourceHashes['scripts/ray-static-shadow.lua']=sha(shadow);
identity.timingValidity='INVALID_SHADOW_OVERHEAD';identity.shadow={candidateSha256:sha(candidate),observerSha256:sha(shadow)};
let runner=fs.readFileSync(path.join(target,'run-capture.ps1'),'utf8');
runner=runner.replaceAll('INVALID_QUERY_CAPTURE_OVERHEAD','INVALID_SHADOW_OVERHEAD')
 .replaceAll('ACTUAL_RAY_QUERY_CAPTURE_PASS','ACTUAL_RAY_SHADOW_PASS')
 .replaceAll('$result.vehicleCount -ne 8','$result.vehicles -lt 8')
 .replaceAll('$result.records.Count','$result.queries').replaceAll('$result.vehicleCount','$result.vehicles');
fs.writeFileSync(path.join(target,'run-shadow.ps1'),runner,{flag:'wx'});
identity.shadow.runnerSha256=sha(runner);identity.queryCapture.retainedCaptureRunnerUnused=true;
fs.writeFileSync(identityPath,JSON.stringify(identity,null,2)+'\n');
console.log(JSON.stringify({status:'READY_NOT_RUN',target,runner:'run-shadow.ps1',candidateSha256:sha(candidate)},null,2));

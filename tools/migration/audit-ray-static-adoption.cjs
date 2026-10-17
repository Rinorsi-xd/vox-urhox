// Independent read-only audit; no Runtime, browser, production or GC mutations.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const base=path.join(root,'.tmp/ray-static-shadow-4a3a-1017-a');
const json=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const result=json(path.join(base,'shadow-1.json')),processRecord=json(path.join(base,'shadow-1.process.json'));
const validation=json(path.join(base,'shadow-1.validation.json')),launch=json(path.join(base,'shadow-1.launch.json'));
const identityPath=path.join(base,'identity.json'),identity=json(identityPath);
assert.equal(result.status,'ACTUAL_RAY_SHADOW_PASS');assert.equal(result.restored,true);assert.equal(result.collectorRunning,true);
assert.equal(result.queries,1085);assert.equal(result.cold+result.warm,result.queries);assert.equal(result.vehicles,8);
assert.equal(result.timingValidity,'INVALID_SHADOW_OVERHEAD');assert.equal(result.rotorQueries,0);
assert.equal(processRecord.exitCode,0);assert.equal(processRecord.completedWithinDeadline,true);
assert.equal(validation.valid,true);assert.equal(validation.nativeErrors.length,0);
assert.equal(sha(fs.readFileSync(identityPath)),launch.identitySha256);
for(const [relative,digest]of Object.entries(identity.sourceHashes))assert.equal(sha(fs.readFileSync(path.join(base,relative))),digest,relative);
for(const [relative,digest]of Object.entries(identity.projectHashes))assert.equal(sha(fs.readFileSync(path.join(base,relative))),digest,relative);
const candidatePath=path.join(root,'.tmp/ray-static-bounds-4a3a-1017-b/VehicleRay.candidate.lua');
const candidate=fs.readFileSync(candidatePath),productionPath=path.join(root,'scripts/combat/VehicleRay.lua');
const production=fs.readFileSync(productionPath);
assert.equal(sha(candidate),'65b25073b09a000cbbcaba954d88b14e14a5a19806ebdcbddaa425b6794ec25f');
assert.equal(sha(candidate),identity.shadow.candidateSha256);
const comment='-- Isolated candidate. V and OriginalBounds are supplied by the exact baseline.\n';
assert.equal(candidate.toString().split(comment).length,2);
assert.equal(production.toString(),candidate.toString().replace(comment,''),'Only one nonsemantic comment removed');
const output=path.join(root,'docs/migration/evidence/ray-static-production-adoption-audit-1017-a.json');assert(!fs.existsSync(output));
const record={status:'PRODUCTION_RAY_STATIC_ADOPTION_AUDIT_PASS',actualNative:{queries:result.queries,cold:result.cold,warm:result.warm,hits:result.hits,
 vehicles:result.vehicles,rotorQueries:result.rotorQueries,exitCode:processRecord.exitCode,nativeErrors:0,originalRestored:result.restored,normalGC:result.collectorRunning},
 identitySha256:sha(fs.readFileSync(identityPath)),resultSha256:sha(fs.readFileSync(path.join(base,'shadow-1.json'))),
 productionSha256:sha(production),candidateSha256:sha(candidate),onlyRemovedComment:comment.trim(),
 boundary:'Source/project frozen hashes and actual Native shadow/process/validation evidence audited. Production differs solely by one removed explanatory comment. This is query correctness and production-source adoption evidence, not a production rendered match or FPS benchmark. Rotor/mech/destruction Native coverage remains unverified. Local Lua replay timing remains separate.'};
fs.writeFileSync(output,JSON.stringify(record,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(record,null,2));

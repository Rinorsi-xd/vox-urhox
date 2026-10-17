'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const frozen='.tmp/monitor-combat-flush-2a92-a/identity.json';
const baseline=JSON.parse(fs.readFileSync(path.join(root,frozen),'utf8'));
const proof=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/evidence/turret-spawn-adopt-offline-2026-10-17-v2.json'),'utf8'));
assert.equal(proof.status,'PASS');
const candidates={
 'combat/CarUnit.lua':'CarUnitTurretAdopt.lua',
 'construction/TurretRange.lua':'TurretRangeSpawnAdopt.lua',
 'drive/SpawnSpecCache.lua':'SpawnSpecCacheTurretAdopt.lua',
};
const argumentsForPrepare=['--frozen',frozen,'--out','.tmp/monitor-combat-adopt-2a92-a',
 '--probe-file',path.join(baseline.source_directory,'scripts/main.lua'),'--warmup','0','--steps','60'];
for(const [relative,name]of Object.entries(candidates)){
 const file=path.join(root,'tools/migration/candidates',name);
 assert.equal(baseline.identity.scripts[relative],proof.baselineHashes['scripts/'+relative]);
 assert.equal(sha(fs.readFileSync(file)),proof.candidateHashes['scripts/'+relative]);
 argumentsForPrepare.push('--variant',relative+'='+file);
}
const prepared=require('./g1-web-cpu-prepare.cjs').prepare(argumentsForPrepare);
for(const relative of Object.keys(candidates))prepared.monitorCombat.sources[relative]=prepared.identity.scripts[relative];
prepared.monitorCombat.boundary='Actual public eight-car Web App with the same controlled monitor-combat-flush workload. Three isolated cache-adoption candidate modules only. Extra diagnostics and uncontrolled combat timing preclude treating a single run as matched FPS A/B or mobile acceptance.';
prepared.g1WebCpu.boundary=prepared.monitorCombat.boundary;
prepared.damageCacheAdopt={correctnessSha256:sha(fs.readFileSync(path.join(root,'docs/migration/evidence/turret-spawn-adopt-offline-2026-10-17-v2.json'))),candidates};
fs.writeFileSync(path.join(prepared.source_directory,'identity.json'),JSON.stringify(prepared,null,2)+'\n');
console.log(JSON.stringify({status:'READY_NOT_RUN',identity:path.join(prepared.source_directory,'identity.json'),variants:prepared.g1WebCpu.variants}));

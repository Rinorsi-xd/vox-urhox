'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const target=path.join(root,'docs/migration/evidence/vehicle-ray-allocation-abba-2026-10-17');
assert(!fs.existsSync(target),'Preserve previous evidence');fs.mkdirSync(target,{recursive:true});
const files=[];
function copy(source,relative){
 const bytes=fs.readFileSync(path.join(root,source)),to=path.join(target,relative);fs.mkdirSync(path.dirname(to),{recursive:true});
 fs.copyFileSync(path.join(root,source),to,fs.constants.COPYFILE_EXCL);
 assert.equal(sha(bytes),sha(fs.readFileSync(to)));files.push({source,archived:relative,bytes:bytes.length,sha256:sha(bytes)});
}
for(const [source,dest]of [['.tmp/vehicle-allocation-fd97-a','allocation-a'],['.tmp/vehicle-allocation-fd97-c','allocation-c'],
 ['.tmp/vehicle-ray-normal-fd97-A','normal-A'],['.tmp/vehicle-ray-normal-fd97-B','normal-B']]){
 for(const entry of fs.readdirSync(path.join(root,source),{withFileTypes:true}))if(entry.isFile())copy(source+'/'+entry.name,dest+'/'+entry.name);
}
for(const file of ['qa-single-step-allocation.lua','vehicle-allocation-probe.lua','prepare-vehicle-allocation-probe.cjs',
 'check-single-step-allocation.py','analyze-single-step-allocation.cjs','run-vehicle-allocation-probe.ps1',
 'vehicle-ray-cylinder-candidate.lua','check-vehicle-ray-cylinder.py','prepare-vehicle-ray-normal.cjs',
 'vehicle-ray-normal-tail.lua','qa-native-owner-times.lua','analyze-vehicle-ray-normal.cjs','archive-vehicle-ray-evidence.cjs']){
 const source='tools/migration/'+file;if(fs.existsSync(path.join(root,source)))copy(source,'tools/'+file);
}
for(const [source,dest]of [
 ['.tmp/vehicle-allocation-fd97-c/scripts/vehicle-allocation-probe.lua','allocation-c/actual-entry.lua'],
 ['.tmp/vehicle-allocation-fd97-c/scripts/qa-single-step-allocation.lua','allocation-c/actual-factory.lua'],
 ['.tmp/vehicle-ray-normal-fd97-A/scripts/vehicle-ray-normal.lua','normal-A/actual-entry.lua'],
 ['.tmp/vehicle-ray-normal-fd97-B/scripts/vehicle-ray-normal.lua','normal-B/actual-entry.lua'],
 ['.tmp/vehicle-ray-normal-fd97-A/scripts/combat/VehicleRay.lua','source/VehicleRay-original.lua'],
 ['.tmp/vehicle-ray-normal-fd97-B/scripts/combat/VehicleRay.lua','source/VehicleRay-candidate.lua'],
 ['.tmp/vehicle-ray-normal-fd97-A/scripts/core/Math3.lua','source/Math3.lua'],
 ['.tmp/vehicle-ray-normal-fd97-independent-1.json','independent-normal-abba.json'],
 ['docs/migration/evidence/vehicle-ray-cylinder-candidate-offline.json','offline-cylinder-equivalence.json']]){
 if(fs.existsSync(path.join(root,source)))copy(source,dest);
}
const manifest={status:'ARCHIVED_SHA256_VERIFIED',files:files.length,bytes:files.reduce((s,r)=>s+r.bytes,0),records:files,
 boundary:'Preserved raw logs/identities/results/derived analyses/probes/candidate. Full assets/runtime and all548 production modules are referenced by hash in original identities, not duplicated. Original absolute paths remain provenance and may later expire. No optimization adopted from this candidate.'};
fs.writeFileSync(path.join(target,'archive-manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({target,status:manifest.status,files:manifest.files,bytes:manifest.bytes}));

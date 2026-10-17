// Build a source-only isolated candidate; never executes a Runtime.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function transform(original,candidate){
 assert.equal(sha(original),'f15cd3d58efd061e22bcbd442229b6c23304f8021cba45c564f5973701bf215c','Reviewed exact baseline');
 assert.equal(original.split('local function Bounds(vehicle)').length,2);
 assert.equal(original.split('function M.Cast(vehicle,origin,direction,length)').length,2);
 const body=candidate.slice(0,candidate.lastIndexOf('return Bounds')).trimEnd()+'\n';
 assert(body.startsWith('-- Isolated candidate.'));
 return original.replace('local function Bounds(vehicle)','local function OriginalBounds(vehicle)')
  .replace('function M.Cast(vehicle,origin,direction,length)',body+'function M.Cast(vehicle,origin,direction,length)');
}
module.exports={transform};
if(require.main===module){
 const target=path.resolve(root,process.argv[2]||'.tmp/ray-static-bounds-4a3a-1017-a');
 assert(target.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(target),'Preserve previous candidate');
 const frozen=path.join(root,'.tmp/outgame-cached-1792216032419/identity.json');const identity=JSON.parse(fs.readFileSync(frozen));
 const original=fs.readFileSync(path.join(identity.source_directory,'scripts/combat/VehicleRay.lua'),'utf8');
 assert.equal(sha(original),identity.identity.scripts['combat/VehicleRay.lua']);
 const candidate=fs.readFileSync(path.join(__dirname,'vehicle-ray-static-bounds-candidate.lua'),'utf8');
 const replacement=transform(original,candidate);fs.mkdirSync(target,{recursive:true});
 fs.writeFileSync(path.join(target,'VehicleRay.baseline.lua'),original,{flag:'wx'});
 fs.writeFileSync(path.join(target,'VehicleRay.candidate.lua'),replacement,{flag:'wx'});
 const record={status:'SOURCE_ONLY_READY_NOT_RUN',baselineSha256:sha(original),candidateSha256:sha(replacement),
  candidateBlockSha256:sha(candidate),sourceFrozen:frozen,sourceFrozenSha256:sha(fs.readFileSync(frozen)),
  boundary:'No production change or timing benefit. Only no-rotor vehicles cache static three-list extrema; all rotor vehicles use exact original Bounds. Dynamic leg/mech/wheel union and final arithmetic/order retained. Native query replay with actual captured inputs is still required before a normal-GC benchmark.'};
 fs.writeFileSync(path.join(target,'identity.json'),JSON.stringify(record,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({...record,target},null,2));
}

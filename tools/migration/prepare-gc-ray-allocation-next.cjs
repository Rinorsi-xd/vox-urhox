// Freeze paired baseline/detailed allocation probes. Never starts a Runtime.
'use strict';
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function once(source,old,value){assert.equal(source.split(old).length,2,'Exact probe boundary: '+old);return source.replace(old,value)}
function amend(source,detailed){
 source=once(source,'    local snapshots={};local baseline=',(detailed?String.raw`    local rayObserver=require('gc-ray-allocation-routes').Install(probe,require('combat.VehicleRay'),require('core.Math3'))
`:'')+'    local snapshots={};local baseline=');
 source=once(source,'    local report=probe:Report();probe:Restore();RestoreGuard()',String.raw`    local rngFinal={global=math.random(),cars={}}
    for i,entry in ipairs(entries)do
        rngFinal.cars[i]={driver=entry.driver and entry.driver.random()or false,weapon=entry.unit.weapons.random()}
    end
    local report=probe:Report();probe:Restore();RestoreGuard()`);
 source=once(source,'        allocation=report,exercised=',`        rngFinal=rngFinal,rayObserverRestored=${detailed?'rayObserver.Restored()':'true'},allocation=report,exercised=`);
 return source;
}
function prepare(options){
 const out=path.resolve(root,options.out);assert(out.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(out),'Preserve previous paired evidence');
 const outputs=[];
 for(const detailed of [false,true]){
  const target=path.join(out,detailed?'detailed':'baseline');
  const result=cp.spawnSync(process.execPath,[path.join(__dirname,'prepare-vehicle-allocation-probe.cjs'),
   '--frozen',options.frozen,'--roster',options.roster,'--out',target],{cwd:root,encoding:'utf8'});
  assert.equal(result.status,0,result.stderr||result.stdout);
  const identityPath=path.join(target,'identity.json');const identity=JSON.parse(fs.readFileSync(identityPath));
  const entryPath=path.join(target,'scripts/vehicle-allocation-probe.lua');
  const entry=amend(fs.readFileSync(entryPath,'utf8'),detailed);fs.writeFileSync(entryPath,entry);
  identity.sourceHashes['scripts/vehicle-allocation-probe.lua']=sha(entry);
  if(detailed){
   const routes=fs.readFileSync(path.join(__dirname,'gc-ray-allocation-routes.lua'));
   const relative='scripts/gc-ray-allocation-routes.lua';assert(!fs.existsSync(path.join(target,relative)));
   fs.writeFileSync(path.join(target,relative),routes,{flag:'wx'});identity.sourceHashes[relative]=sha(routes);
  }
  identity.gcRayAttribution={detailed,kind:'ALLOCATION_ONLY',preparedBy:sha(fs.readFileSync(__filename)),
   boundary:'Single bounded stopped-GC step. No valid performance timing. Cold means rayBounds absent on entry, including a ray that misses bounds. Math rows include only calls dynamically below VehicleRay.Cast; inclusive rows overlap. Final RNG sentinel consumes one value after all samples, identically in both fixtures; it is not an assertion of every RNG call.'};
  fs.writeFileSync(identityPath,JSON.stringify(identity,null,2)+'\n');
  outputs.push({detailed,target,identity:identityPath,identitySha256:sha(fs.readFileSync(identityPath))});
 }
 const paired={status:'READY_NOT_RUN',outputs,boundary:'Only QA entry and observer differ; all production modules remain exact frozen source. Root owns serial Native runs. No production optimization or FPS claim.'};
 fs.writeFileSync(path.join(out,'paired-identity.json'),JSON.stringify(paired,null,2)+'\n',{flag:'wx'});return paired;
}
module.exports={amend,prepare};
if(require.main===module){const options={};for(let i=2;i<process.argv.length;i+=2)options[process.argv[i].slice(2)]=process.argv[i+1];assert(options.frozen&&options.roster&&options.out);console.log(JSON.stringify(prepare(options),null,2))}

// Offline preparation only; the root agent owns all Runtime launches.
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const opts={};for(let i=2;i<process.argv.length;i+=2){assert(process.argv[i].startsWith('--'));assert(process.argv[i+1]);opts[process.argv[i].slice(2)]=process.argv[i+1]}
assert(opts.out,'--out required');assert(['A','C'].includes(opts.variant),'A production instrumentation or C truly disabled');
const frozenPath=path.resolve(root,opts.frozen||'.tmp/outgame-cached-1792206583227/identity.json');
const base=path.resolve(root,opts.base||'.tmp/vehicle-ray-normal-fd97-A'),out=path.resolve(root,opts.out);
assert(out.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(out),'Fresh fixture required');
const frozenBytes=fs.readFileSync(frozenPath),frozen=JSON.parse(frozenBytes),old=JSON.parse(fs.readFileSync(path.join(base,'identity.json')));
assert.equal(frozen.ok,true);assert.equal(old.configuration.variant,'A');assert.equal(old.configuration.profile,false);
for(const [relative,hash]of Object.entries(old.sourceHashes))assert.equal(sha(fs.readFileSync(path.join(base,relative))),hash,relative);
const source=fs.readFileSync(path.join(base,'scripts/vehicle-ray-normal.lua'),'utf8');
const begin=source.indexOf("local World=require"),end=source.indexOf('    local timing=false');assert(begin>0&&end>begin);
const configuration={seed:1016,fixedDt:1/60,warmup:120,steps:Number(opts.steps||240),variant:opts.variant,profile:false};
assert(Number.isInteger(configuration.steps)&&configuration.steps>=240&&configuration.steps<=600&&configuration.steps%60===0);
const setup=source.slice(begin,end).replace('and config.steps==240','and config.steps>=240 and config.steps<=600');
const tailPath=path.join(__dirname,'monitor-native-normal-tail.lua'),tail=fs.readFileSync(tailPath,'utf8');
const entry='VEHICLE_NORMAL_CONFIG=cjson.decode([=['+JSON.stringify(configuration)+']=])\n'+setup+tail;
const scripts={};
for(const [relative,hash]of Object.entries(frozen.identity.scripts)){
 assert(/^[A-Za-z0-9_/-]+\.lua$/.test(relative)&&!relative.includes('..'));
 assert.equal(sha(fs.readFileSync(path.join(frozen.source_directory,'scripts',relative))),hash,relative);scripts['scripts/'+relative]=hash;
}
for(const key of ['diagnostics/PerformanceMonitor.lua','diagnostics/PerformanceBindings.lua','drive/Vehicle.lua','combat/EnemyDriver.lua','combat/CarUnit.lua','combat/WeaponSystem.lua','drive/CraterWorld.lua']){
 assert.equal(frozen.identity.scripts[key],old.sourceHashes['scripts/'+key],'Fixture setup modules must match newer freeze '+key);
}
fs.mkdirSync(out,{recursive:true});fs.cpSync(path.join(frozen.source_directory,'scripts'),path.join(out,'scripts'),{recursive:true});
fs.cpSync(path.join(frozen.source_directory,'.project'),path.join(out,'.project'),{recursive:true});
fs.symlinkSync(path.join(frozen.source_directory,'assets'),path.join(out,'assets'),'junction');
fs.copyFileSync(path.join(base,'allocation-roster.json'),path.join(out,'allocation-roster.json'));
fs.writeFileSync(path.join(out,'scripts/monitor-native-normal.lua'),entry,{flag:'wx'});
scripts['scripts/monitor-native-normal.lua']=sha(entry);scripts['allocation-roster.json']=sha(fs.readFileSync(path.join(out,'allocation-roster.json')));
const projectHashes={};
function scan(directory){for(const item of fs.readdirSync(directory,{withFileTypes:true})){const file=path.join(directory,item.name);if(item.isDirectory())scan(file);else projectHashes[path.relative(out,file).replaceAll('\\','/')]=sha(fs.readFileSync(file))}}
scan(path.join(out,'.project'));
const identity={status:'READY_NOT_RUN',target:out,configuration,entry:'monitor-native-normal.lua',
 sourceFrozen:frozenPath,sourceFrozenSha256:sha(frozenBytes),sourceHashes:scripts,projectHashes,
 assetRoot:path.join(frozen.source_directory,'assets'),roster:old.roster,
 tools:{[path.basename(__filename)]:sha(fs.readFileSync(__filename)),[path.basename(tailPath)]:sha(tail),
 originalNormalEntry:old.sourceHashes['scripts/vehicle-ray-normal.lua']},
 timingValidity:'NORMAL_GC_FIXED_WORKLOAD_WALL',
 boundary:'CPU simulation instrumentation A/C matched derivative. Copies every production script from current freeze with exact hashes; only fresh QA entry and captured roster added. A uses real production Monitor/Bindings lifecycle; C is disabled at construction and never installs wrappers. No files/JSON/panel/render/audio in timed loop. Root must execute independent serial A1/C1/C2/A2 processes and demand exact state/workload/global+AI RNG match.'};
fs.writeFileSync(path.join(out,'identity.json'),JSON.stringify(identity,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:identity.status,out,variant:opts.variant,entry:identity.entry,configuration,identitySha256:sha(fs.readFileSync(path.join(out,'identity.json'))),productionScripts:Object.keys(frozen.identity.scripts).length},null,2));

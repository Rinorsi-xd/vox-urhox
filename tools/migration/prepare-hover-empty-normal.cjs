// Derives two isolated fixtures; never launches Runtime or edits production.
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {candidate}=require('./hover-empty-candidate.cjs');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const opts={};for(let i=2;i<process.argv.length;i+=2)opts[process.argv[i].slice(2)]=process.argv[i+1];
assert(opts.out,'--out fresh workspace .tmp required');
const base=path.resolve(root,opts.base||'.tmp/vehicle-ray-normal-fd97-A'),out=path.resolve(root,opts.out);
const variant=opts.variant;assert(['A','B'].includes(variant));assert(out.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(out));
const identityPath=path.join(base,'identity.json'),old=JSON.parse(fs.readFileSync(identityPath,'utf8'));
assert.equal(old.timingValidity,'NORMAL_GC_FIXED_WORKLOAD_WALL');assert.equal(old.configuration.profile,false);
for(const [relative,hash]of Object.entries(old.sourceHashes))assert.equal(sha(fs.readFileSync(path.join(base,relative))),hash,relative);
const relative='scripts/drive/HoverControl.lua',before=fs.readFileSync(path.join(base,relative),'utf8'),after=candidate(before);
const originalEntry=fs.readFileSync(path.join(base,'scripts/vehicle-ray-normal.lua'),'utf8');
const configuration={...old.configuration,variant,profile:false};
const configBoundary=originalEntry.indexOf('\n');assert(configBoundary>0);
assert(originalEntry.slice(0,configBoundary).startsWith('VEHICLE_NORMAL_CONFIG=cjson.decode('));
const entry='VEHICLE_NORMAL_CONFIG=cjson.decode([=['+JSON.stringify(configuration)+']=])'+originalEntry.slice(configBoundary);
fs.mkdirSync(out,{recursive:true});fs.cpSync(path.join(base,'scripts'),path.join(out,'scripts'),{recursive:true});
fs.cpSync(path.join(base,'.project'),path.join(out,'.project'),{recursive:true});
fs.symlinkSync(old.assetRoot,path.join(out,'assets'),'junction');
fs.copyFileSync(path.join(base,'allocation-roster.json'),path.join(out,'allocation-roster.json'));
fs.writeFileSync(path.join(out,'scripts/vehicle-ray-normal.lua'),entry);
if(variant==='B')fs.writeFileSync(path.join(out,relative),after);
const sourceHashes={...old.sourceHashes,'scripts/vehicle-ray-normal.lua':sha(entry),[relative]:sha(variant==='B'?after:before)};
const identity={...old,target:out,configuration,sourceHashes,
 derivation:{base,identitySha256:sha(fs.readFileSync(identityPath)),builderSha256:sha(fs.readFileSync(__filename)),
 candidateToolSha256:sha(fs.readFileSync(path.join(__dirname,'hover-empty-candidate.cjs')))},
 candidate:{path:relative,original:sha(before),replacement:sha(after),productionChanged:false},
 boundary:'Isolated empty-hover early path only. Fresh hoverStates and result, identical zero-support expression and scale; nonempty implementation unchanged. Existing actual captured eight-source roster,120warmup+240steps,normal automatic GC,7AI and held player fire. Primary timing has no extra wrappers. No full-match render/audio/UI/objective consumers, FPS or target-device claim.'};
fs.writeFileSync(path.join(out,'identity.json'),JSON.stringify(identity,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:'READY_NOT_RUN',out,variant,configuration,candidate:identity.candidate},null,2));
module.exports={};

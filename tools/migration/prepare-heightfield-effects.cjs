// Builds an isolated A/B fixture. Runtime execution belongs to the root agent.
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const opts={};for(let i=2;i<process.argv.length;i+=2)opts[process.argv[i].slice(2)]=process.argv[i+1];
assert(opts.frozen&&opts.out&&['A','B'].includes(opts.variant));
const input=path.resolve(root,opts.frozen),frozen=JSON.parse(fs.readFileSync(input,'utf8'));
const out=path.resolve(root,opts.out),base=frozen.source_directory;
assert(out.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(out));
assert.equal(Object.keys(frozen.identity.scripts).length,548);
for(const [name,hash]of Object.entries(frozen.identity.scripts))assert.equal(sha(fs.readFileSync(path.join(base,'scripts',name))),hash,name);
const original=fs.readFileSync(path.join(base,'scripts/core/HeightField.lua'));
const candidate=fs.readFileSync(path.join(__dirname,'heightfield-cell-cache-candidate.lua'));
assert.equal(sha(candidate),'6e595e1a0f7fce56013ddbff63aca3ce9e2c60b86734990e105c9530675e4872');
const configuration={seed:17102026,fixedDt:1/60,warmup:120,steps:480,variant:opts.variant,profile:false};
const entry='HEIGHTFIELD_EFFECTS_CONFIG=cjson.decode([=['+JSON.stringify(configuration)+']=])\n'+fs.readFileSync(path.join(__dirname,'heightfield-effects-native.lua'),'utf8');
fs.mkdirSync(out,{recursive:true});fs.cpSync(path.join(base,'scripts'),path.join(out,'scripts'),{recursive:true});
fs.cpSync(path.join(base,'.project'),path.join(out,'.project'),{recursive:true});
const assetRoot=fs.realpathSync(path.join(base,'assets'));fs.symlinkSync(assetRoot,path.join(out,'assets'),'junction');
fs.mkdirSync(path.join(out,'scripts/qa'),{recursive:true});
fs.writeFileSync(path.join(out,'scripts/qa/HeightFieldOriginal.lua'),original,{flag:'wx'});
fs.writeFileSync(path.join(out,'scripts/heightfield-effects-native.lua'),entry,{flag:'wx'});
if(opts.variant==='B')fs.writeFileSync(path.join(out,'scripts/core/HeightField.lua'),candidate);
const sourceHashes={};for(const [name]of Object.entries(frozen.identity.scripts))sourceHashes['scripts/'+name]=sha(fs.readFileSync(path.join(out,'scripts',name)));
sourceHashes['scripts/qa/HeightFieldOriginal.lua']=sha(original);sourceHashes['scripts/heightfield-effects-native.lua']=sha(entry);
const projectHashes={};for(const name of fs.readdirSync(path.join(out,'.project')))if(fs.statSync(path.join(out,'.project',name)).isFile())projectHashes['.project/'+name]=sha(fs.readFileSync(path.join(out,'.project',name)));
const identity={status:'READY_NOT_RUN',target:out,entry:'heightfield-effects-native.lua',sourceFrozen:input,sourceFrozenSha256:sha(fs.readFileSync(input)),
 sourceHashes,projectHashes,assetRoot,configuration,timingValidity:'NORMAL_GC_FIXED_WORKLOAD_WALL',
 candidate:{originalSha256:sha(original),candidateSha256:sha(candidate),onlyProductionDifference:'core/HeightField.lua'},
 boundary:'Real Native CombatEffects.Update, Native CustomGeometry and actual Crater VisualHeight.bin. Normal automatic GC, no method/particle instrumentation. Fixed emitted particle/smoke workload at original production caps; no viewport. CPU Update wall timing only, excludes emission/state hashing and not full-game FPS or mobile acceptance. Real Native height equivalence checks include Crater and Salvage before timing.'};
fs.writeFileSync(path.join(out,'identity.json'),JSON.stringify(identity,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:'READY_NOT_RUN',identity:path.join(out,'identity.json'),configuration,candidate:identity.candidate},null,2));

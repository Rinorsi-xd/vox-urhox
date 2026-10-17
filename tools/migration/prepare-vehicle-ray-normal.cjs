// Isolated normal-GC eight-source fixture; never launches a Runtime.
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const opts={};for(let i=2;i<process.argv.length;i+=2)opts[process.argv[i].slice(2)]=process.argv[i+1];
assert(opts.out,'--out required');
const base=path.resolve(root,opts.base||'.tmp/vehicle-allocation-fd97-c'),out=path.resolve(root,opts.out),variant=opts.variant;
assert(['A','B'].includes(variant));assert(out.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(out));
const old=JSON.parse(fs.readFileSync(path.join(base,'identity.json'),'utf8'));
for(const [relative,hash]of Object.entries(old.sourceHashes))assert.equal(sha(fs.readFileSync(path.join(base,relative))),hash,relative);
const original=fs.readFileSync(path.join(base,'scripts/combat/VehicleRay.lua'),'utf8');
assert.equal(sha(original),'f15cd3d58efd061e22bcbd442229b6c23304f8021cba45c564f5973701bf215c');
const candidate=fs.readFileSync(path.join(__dirname,'vehicle-ray-cylinder-candidate.lua'),'utf8');
assert.equal(sha(candidate),'36fd7c1e7d3aed549d39778673180da5ac765447ba2b8d792d35efe1e367d31c');
const start=original.indexOf('local function Cylinder('),end=original.indexOf('local function Bounds',start);
assert(start>=0&&end>start);const body=candidate.slice(0,candidate.lastIndexOf('return Cylinder')).trimEnd()+'\n';
assert(body.includes('local function Cylinder('));
const replacement=original.slice(0,start)+body+original.slice(end);
const source=fs.readFileSync(path.join(__dirname,'vehicle-allocation-probe.lua'),'utf8');
const cut=source.indexOf('    for index=1,config.warmup do api.Step(index)end');assert(cut>0);
const setup=source.slice(source.indexOf("local World=require"),cut)
 .replace("local config=assert(VEHICLE_ALLOCATION_CONFIG,'Derived isolated fixture configuration required')",'local config=VEHICLE_NORMAL_CONFIG')
 .replace("assert(config.seed==1016 and config.fixedDt==1/60 and config.samples<=16 and config.normalBetween>=1)","assert(config.seed==1016 and config.fixedDt==1/60 and config.steps==240)");
const tail=fs.readFileSync(path.join(__dirname,'vehicle-ray-normal-tail.lua'),'utf8');
const configuration={seed:1016,fixedDt:1/60,warmup:120,steps:240,variant,profile:opts.profile==='true'};
const entry='VEHICLE_NORMAL_CONFIG=cjson.decode([=['+JSON.stringify(configuration)+']=])\n'+setup+tail;
fs.mkdirSync(out,{recursive:true});fs.cpSync(path.join(base,'scripts'),path.join(out,'scripts'),{recursive:true});
fs.cpSync(path.join(base,'.project'),path.join(out,'.project'),{recursive:true});
fs.symlinkSync(old.assetRoot,path.join(out,'assets'),'junction');
fs.copyFileSync(path.join(base,'allocation-roster.json'),path.join(out,'allocation-roster.json'));
fs.writeFileSync(path.join(out,'scripts/vehicle-ray-normal.lua'),entry,{flag:'wx'});
fs.copyFileSync(path.join(__dirname,'qa-native-owner-times.lua'),path.join(out,'scripts/qa-native-owner-times.lua'));
if(variant==='B')fs.writeFileSync(path.join(out,'scripts/combat/VehicleRay.lua'),replacement);
const sourceHashes={...old.sourceHashes,'scripts/vehicle-ray-normal.lua':sha(entry),'scripts/qa-native-owner-times.lua':sha(fs.readFileSync(path.join(out,'scripts/qa-native-owner-times.lua')))};
sourceHashes['scripts/combat/VehicleRay.lua']=sha(fs.readFileSync(path.join(out,'scripts/combat/VehicleRay.lua')));
const identity={...old,target:out,configuration,sourceHashes,timingValidity:'NORMAL_GC_FIXED_WORKLOAD_WALL',
 candidate:{path:path.join(__dirname,'vehicle-ray-cylinder-candidate.lua'),sha256:sha(candidate),original:sha(original),replacement:sha(replacement)},
 boundary:'Normal automatic GC; 120 warmup plus 240 fixed steps, eight actual starting vehicles, seven AI, manual held fire. No renderer/audio/UI/objective effects consumer; this is CPU simulation wall-time, not full-game FPS or mobile acceptance. Natural damage/death preserved and compared. Primary mode has no method timing wrappers.'};
fs.writeFileSync(path.join(out,'identity.json'),JSON.stringify(identity,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({out,variant,configuration,identity:path.join(out,'identity.json')},null,2));

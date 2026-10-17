// Freeze a Native-only diagnostic fixture. This does not launch a Runtime.
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const options={};for(let i=2;i<process.argv.length;i+=2){assert(process.argv[i].startsWith('--'));assert(process.argv[i+1]);options[process.argv[i].slice(2)]=process.argv[i+1]}
assert(options.frozen&&options.roster&&options.out,'--frozen identity.json --roster capture.json --out .tmp/name required');
const frozenPath=path.resolve(root,options.frozen),capturePath=path.resolve(root,options.roster),target=path.resolve(root,options.out);
assert(target.startsWith(path.join(root,'.tmp')+path.sep),'Workspace .tmp only');assert(!fs.existsSync(target),'Preserve prior fixture');
const frozenBytes=fs.readFileSync(frozenPath),frozen=JSON.parse(frozenBytes);
assert.equal(frozen.ok,true);const source=frozen.source_directory;
const captureBytes=fs.readFileSync(capturePath),capture=JSON.parse(captureBytes);
const captureReportPath=path.join(path.dirname(capturePath),'report.json');
const captureReportBytes=fs.readFileSync(captureReportPath),captureReport=JSON.parse(captureReportBytes);
assert.equal(capture.status,'CAPTURED');assert.equal(captureReport.status,'PASS');assert.equal(captureReport.shutdown,'CLOSED');
assert.deepEqual(captureReport.errors,[]);assert.deepEqual(captureReport.httpErrors,[]);
assert.equal(captureReport.identity.identity.targetCommit,frozen.identity.targetCommit,'Same current baseline commit');
assert.equal(captureReport.identity.identity.sourceCommit,frozen.identity.sourceCommit,'Same frozen H5 source');
assert.equal(capture.before.roster.length,8);
assert.equal(capture.before.roster[0].team,'blue');
const sourceHashes={};
for(const [relative,expected]of Object.entries(frozen.identity.scripts)){
 assert(/^[A-Za-z0-9_/-]+\.lua$/.test(relative)&&!relative.includes('..'));
 const bytes=fs.readFileSync(path.join(source,'scripts',relative));assert.equal(sha(bytes),expected,'Frozen source '+relative);
 sourceHashes['scripts/'+relative]=expected;
}
const configuration={seed:1016,fixedDt:1/60,samples:Number(options.samples||8),warmup:Number(options.warmup||120),normalBetween:Number(options['normal-between']||1)};
assert(Number.isInteger(configuration.samples)&&configuration.samples>=1&&configuration.samples<=16);
assert(Number.isInteger(configuration.warmup)&&configuration.warmup>=0&&configuration.warmup<=120);
assert(Number.isInteger(configuration.normalBetween)&&configuration.normalBetween>=1&&configuration.normalBetween<=30);
const probePath=path.join(__dirname,'vehicle-allocation-probe.lua'),factoryPath=path.join(__dirname,'qa-single-step-allocation.lua');
const probe=fs.readFileSync(probePath),factory=fs.readFileSync(factoryPath);
const configJson=JSON.stringify(configuration);assert(!configJson.includes(']=]'));
const entry=Buffer.from('VEHICLE_ALLOCATION_CONFIG=cjson.decode([=['+configJson+']=])\n'+probe.toString('utf8'));
const roster={identity:{capturePath,captureSha256:sha(captureBytes),captureReportPath,captureReportSha256:sha(captureReportBytes),
 sourceFrozen:frozenPath,sourceFrozenSha256:sha(frozenBytes),
 manifestPath:frozen.manifest_path,scriptFingerprint:frozen.identity.scriptFingerprint},
 roster:capture.before.roster.map(row=>({name:row.name,team:row.team,role:row.role||false,source:row.source}))};
for(const row of roster.roster){assert(row.source&&Array.isArray(row.source.parts)&&row.source.parts.length>0);assert(['blue','red'].includes(row.team))}
fs.mkdirSync(target,{recursive:true});
fs.cpSync(path.join(source,'scripts'),path.join(target,'scripts'),{recursive:true});
fs.cpSync(path.join(source,'.project'),path.join(target,'.project'),{recursive:true});
fs.symlinkSync(path.join(source,'assets'),path.join(target,'assets'),'junction');
const extra={
 'scripts/vehicle-allocation-probe.lua':entry,
 'scripts/qa-single-step-allocation.lua':factory,
 'allocation-roster.json':Buffer.from(JSON.stringify(roster)),
};
for(const [relative,bytes]of Object.entries(extra)){
 assert(!fs.existsSync(path.join(target,relative)),'No production module overwritten');
 fs.writeFileSync(path.join(target,relative),bytes,{flag:'wx'});sourceHashes[relative]=sha(bytes);
}
const projectHashes={};
function scan(directory){for(const item of fs.readdirSync(directory,{withFileTypes:true})){const file=path.join(directory,item.name);if(item.isDirectory())scan(file);else projectHashes[path.relative(target,file).replaceAll('\\','/')]=sha(fs.readFileSync(file))}}
scan(path.join(target,'.project'));
const identity={status:'READY_NOT_RUN',target,configuration,sourceFrozen:frozenPath,sourceFrozenSha256:sha(frozenBytes),
 sourceHashes,projectHashes,assetRoot:path.join(source,'assets'),roster:roster.identity,
 tools:{[path.basename(probePath)]:sha(probe),[path.basename(factoryPath)]:sha(factory),[path.basename(__filename)]:sha(fs.readFileSync(__filename))},
 timingValidity:'INVALID_FOR_PERFORMANCE',
 boundary:'Native-only derivative copies exact frozen production Lua and project config; assets junction is a read-only input by convention. Adds two QA modules and captured eight-source roster without changing production. One fixed step per bounded stopped-GC interval, 16MiB/250ms checked at instrumented boundaries; original mode never changed. Root owns serial hardware runs. Not a browser package or full-match/FPS/target-device acceptance.'};
fs.writeFileSync(path.join(target,'identity.json'),JSON.stringify(identity,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:identity.status,target,identity:path.join(target,'identity.json'),configuration,timingValidity:identity.timingValidity},null,2));

// Persist the completed root-owned ABBA runs without copying assets or Runtime.
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence/heightfield-cache-native-2026-10-17');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
if(process.argv.includes('--append-fixed-baseline')){
 const manifestFile=path.join(out,'archive-manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestFile,'utf8'));
 for(const [relative,hash]of Object.entries(manifest.files))assert.equal(sha(fs.readFileSync(path.join(out,relative))),hash,'Previous archive preserved '+relative);
 const add=(relative,bytes)=>{assert(!fs.existsSync(path.join(out,relative)),'Preserve earlier evidence');fs.mkdirSync(path.dirname(path.join(out,relative)),{recursive:true});fs.writeFileSync(path.join(out,relative),bytes);manifest.files[relative]=sha(bytes)};
 add('tools/check-heightfield-cell-cache-fixed-baseline.py',fs.readFileSync(path.join(__dirname,'check-heightfield-cell-cache.py')));
 add('tools/archive-heightfield-evidence-final.cjs',fs.readFileSync(__filename));
 add('independent-audit.json',fs.readFileSync(path.join(root,'docs/migration/evidence/heightfield-effects-independent-2026-10-17.json')));
 const rerun=cp.spawnSync('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',[path.join(__dirname,'check-heightfield-cell-cache.py')],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
 assert.equal(rerun.status,0,rerun.stderr);assert.equal(JSON.parse(rerun.stdout).baselineSha256,'9e95855a228e49fd6c3b7fd8b7b7091a713d5478e0e3ca2fc112f1a096b8946a');
 add('offline-fixed-baseline-verification.json',Buffer.from(rerun.stdout));
 manifest.addendum='Original pre-adoption tools/output retained; fixed-baseline checker locks the archived original SHA and rejects candidate-as-baseline. Independent second-agent actual ABBA audit added.';
 fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n');
 for(const [relative,hash]of Object.entries(manifest.files))assert.equal(sha(fs.readFileSync(path.join(out,relative))),hash,'Final archive integrity '+relative);
 console.log(JSON.stringify({status:'ARCHIVE_ADDENDUM_VERIFIED',files:Object.keys(manifest.files).length,originalEvidencePreserved:true}));
 process.exit(0);
}
assert(!fs.existsSync(out),'Preserve previous archive');
const a=path.join(root,'.tmp/heightfield-effects-2a97-A'),b=path.join(root,'.tmp/heightfield-effects-2a97-B');
const inputs=[path.join(a,'A1.json'),path.join(b,'B1.json'),path.join(b,'B2.json'),path.join(a,'A2.json')];
const analysis=cp.spawnSync(process.execPath,[path.join(__dirname,'analyze-heightfield-effects.cjs'),...inputs],{encoding:'utf8',maxBuffer:4*1024*1024});
assert.equal(analysis.status,0,analysis.stderr);const verification=JSON.parse(analysis.stdout);assert.equal(verification.status,'MATCHED_ABBA_ANALYZED');
fs.mkdirSync(out,{recursive:true});
function Copy(source,relative){const destination=path.join(out,relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.copyFileSync(source,destination)}
for(const [directory,label]of [[a,'A1'],[b,'B1'],[b,'B2'],[a,'A2']])for(const suffix of ['.json','.launch.json','.process.json','.validation.json','.stdout.log','.stderr.log'])Copy(path.join(directory,label+suffix),'runs/'+label+suffix);
for(const [directory,variant]of [[a,'A'],[b,'B']]){
 Copy(path.join(directory,'identity.json'),'fixtures/'+variant+'/identity.json');
 Copy(path.join(directory,'scripts/heightfield-effects-native.lua'),'fixtures/'+variant+'/heightfield-effects-native.lua');
 Copy(path.join(directory,'scripts/core/HeightField.lua'),'fixtures/'+variant+'/core/HeightField.lua');
 fs.cpSync(path.join(directory,'.project'),path.join(out,'fixtures',variant,'.project'),{recursive:true});
}
// A single full frozen script tree is enough; variant B differs in the two files above.
fs.cpSync(path.join(a,'scripts'),path.join(out,'source-baseline/scripts'),{recursive:true});
for(const name of ['heightfield-cell-cache-candidate.lua','check-heightfield-cell-cache.py','heightfield-effects-native.lua','prepare-heightfield-effects.cjs','analyze-heightfield-effects.cjs','run-vehicle-allocation-probe.ps1','archive-heightfield-evidence.cjs'])Copy(path.join(__dirname,name),'tools/'+name);
Copy(path.join(root,'.tmp/outgame-cached-1792204236638/identity.json'),'source-frozen-identity.json');
Copy(path.join(root,'.tmp/perf-damage-flush-adopt-c935-1017/identity.json'),'support-runtime-identity.json');
fs.writeFileSync(path.join(out,'independent-analysis.json'),JSON.stringify(verification,null,2)+'\n');
const python='C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe';
const offline=cp.spawnSync(python,[path.join(__dirname,'check-heightfield-cell-cache.py')],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
assert.equal(offline.status,0,offline.stderr);assert.equal(JSON.parse(offline.stdout).status,'HEIGHTFIELD_EXACT_CACHE_OFFLINE_PASS');
fs.writeFileSync(path.join(out,'offline-verification.json'),offline.stdout);
const files={};function Scan(directory){for(const entry of fs.readdirSync(directory,{withFileTypes:true})){const file=path.join(directory,entry.name);if(entry.isDirectory())Scan(file);else files[path.relative(out,file).replaceAll('\\','/')]=sha(fs.readFileSync(file))}}Scan(out);
fs.writeFileSync(path.join(out,'archive-manifest.json'),JSON.stringify({status:'ARCHIVED_VERIFIED',files,noAssetOrRuntimeCopies:true,originalTmpPreserved:true},null,2)+'\n');
for(const [relative,hash]of Object.entries(files))assert.equal(sha(fs.readFileSync(path.join(out,relative))),hash,'Archive copy integrity '+relative);
console.log(JSON.stringify({status:'ARCHIVED_VERIFIED',out,files:Object.keys(files).length,bytes:Object.keys(files).reduce((n,p)=>n+fs.statSync(path.join(out,p)).size,0),nativeReductionPercent:verification.reductionPercent},null,2));

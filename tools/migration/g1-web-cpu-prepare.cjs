'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const crc32=bytes=>require('node:zlib').crc32(bytes).toString(16).padStart(8,'0');
function options(args){const out={variants:[]};for(let i=0;i<args.length;i++){const key=args[i];assert(key.startsWith('--'));const value=args[++i];assert(value!==undefined,key);if(key==='--variant')out.variants.push(value);else out[key.slice(2)]=value}return out}
function prepare(args){
 const opts=options(args);assert(opts.frozen&&opts.out,'--frozen identity.json --out .tmp/g1-web-cpu-label required');
 const before=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8').replace(/^\uFEFF/,''));assert(before.ok);
 const destination=path.resolve(root,opts.out);assert(destination.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(destination),'Preserve prior fixture');
 const configuration={seed:1016,mode:opts.mode||'timing',scenario:opts.scenario||'lanes',warmup:Number(opts.warmup||120),steps:Number(opts.steps||600),snapshotEvery:60};
 assert(['lanes','crater','damage'].includes(configuration.scenario));
 assert(['timing','profile','equivalence'].includes(configuration.mode));assert(Number.isInteger(configuration.steps)&&configuration.steps>=60&&configuration.steps<=1200&&configuration.steps%60===0);
 assert(Number.isInteger(configuration.warmup)&&configuration.warmup>=0&&configuration.warmup<=300);
 const originalDist=path.join(before.source_directory,'dist'),manifest=JSON.parse(fs.readFileSync(before.manifest_path));
 const sourceVersion=JSON.parse(fs.readFileSync(path.join(originalDist,'latest.json'))).version;
 assert.equal(manifest.entry,'main.lua');assert.equal(manifest.assets_pak,0,'Loose payload fixture required');
 const originalMain=manifest.files.find(row=>row.fs_path==='main.lua');assert(originalMain);
 const sourceHashes={};for(const [name,expected]of Object.entries(before.identity.scripts)){
  const bytes=fs.readFileSync(path.join(before.source_directory,'scripts',name));assert.equal(sha(bytes),expected,'Frozen identity '+name);sourceHashes[name]=expected;
 }
 const replacement=new Map();const variantHashes={};
 for(const variant of opts.variants){const equal=variant.indexOf('=');assert(equal>0,'--variant drive/LegGait.lua=path');const relative=variant.slice(0,equal),file=path.resolve(root,variant.slice(equal+1));
  assert(/^[A-Za-z0-9_/-]+\.lua$/.test(relative)&&!relative.includes('..')&&relative!=='main.lua');assert(sourceHashes[relative],'Existing module required');assert(!replacement.has(relative),'Duplicate module replacement');
  const bytes=fs.readFileSync(file);replacement.set(relative,bytes);variantHashes[relative]={baselineSha256:sourceHashes[relative],candidateSha256:sha(bytes),file};
 }
 const probe=fs.readFileSync(opts['probe-file']?path.resolve(root,opts['probe-file']):path.join(__dirname,'g1-web-cpu-probe.lua'),'utf8');
 const damage=fs.readFileSync(path.join(__dirname,'g1-web-cpu-damage.lua'),'utf8');
 const damageFixtures=fs.readFileSync(path.join(__dirname,'source-damage-fixtures.json'));
 const bridge=JSON.parse(damageFixtures).cases.find(row=>row.name==='bridge-detach').source;
 const bridgeJson=JSON.stringify(bridge);assert(!bridgeJson.includes(']=]'));
 const luaConfig='{seed=1016,mode='+JSON.stringify(configuration.mode)+',scenario='+JSON.stringify(configuration.scenario)+',warmup='+configuration.warmup+',steps='+configuration.steps+',snapshotEvery=60}';
 replacement.set('main.lua',Buffer.from('G1_WEB_CPU_CONFIG='+luaConfig+'\n'+(configuration.scenario==='damage'?'G1_WEB_CPU_BRIDGE_SOURCE=cjson.decode([=['+bridgeJson+']=])\nG1_WEB_CPU_DAMAGE=(function()\n'+damage+'\nend)()\n':'')+probe));
 fs.mkdirSync(path.join(destination,'dist/assets'),{recursive:true});fs.cpSync(path.join(before.source_directory,'scripts'),path.join(destination,'scripts'),{recursive:true});
 const bootstrapFiles={};
 for(const relative of ['project.json',path.join(sourceVersion,'project.json')]){
  const bytes=fs.readFileSync(path.join(originalDist,relative));const output=path.join(destination,'dist',relative);
  fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,bytes);bootstrapFiles[relative.replaceAll('\\','/')]=sha(bytes);
 }
 const oldAssetDirectory=path.join(originalDist,'assets'),newAssetDirectory=path.join(destination,'dist/assets');
 const replacedNames=new Set(manifest.files.filter(row=>replacement.has(row.fs_path)).map(row=>row.uuid+'-'+row.hash+row.ext));
 for(const name of fs.readdirSync(oldAssetDirectory)){if(replacedNames.has(name))continue;const source=path.join(oldAssetDirectory,name);if(fs.statSync(source).isFile())fs.linkSync(source,path.join(newAssetDirectory,name))}
 for(const [relative,bytes]of replacement){
  const entry=manifest.files.find(row=>row.fs_path===relative);assert(entry,'Packaged module '+relative);
  const frozenBytes=fs.readFileSync(path.join(oldAssetDirectory,entry.uuid+'-'+entry.hash+entry.ext));assert.equal(sha(frozenBytes),sourceHashes[relative],'Frozen payload '+relative);
  entry.hash=crc32(bytes);entry.size=bytes.length;
  fs.writeFileSync(path.join(newAssetDirectory,entry.uuid+'-'+entry.hash+entry.ext),bytes);
  fs.writeFileSync(path.join(destination,'scripts',relative),bytes);sourceHashes[relative]=sha(bytes);
 }
 const latest=JSON.parse(fs.readFileSync(path.join(originalDist,'latest.json')));delete latest.server;
 const manifestBytes=Buffer.from(JSON.stringify(manifest));latest.client=crc32(manifestBytes);
 const manifestPath=path.join(destination,'dist',latest.version,'manifest-'+latest.client+'.json');fs.mkdirSync(path.dirname(manifestPath),{recursive:true});fs.writeFileSync(manifestPath,manifestBytes);
 const versionBytes=Buffer.from(JSON.stringify(latest));
 for(const relative of ['latest.json',path.join(latest.version,'version.json'),latest.version.split('.')[0]+'.x.x.json']){
  fs.writeFileSync(path.join(destination,'dist',relative),versionBytes);bootstrapFiles[relative.replaceAll('\\','/')]=sha(versionBytes);
 }
 const prepared={...before,source_directory:destination,manifest_path:manifestPath,
  identity:{...before.identity,scripts:sourceHashes,scriptFingerprint:sha(JSON.stringify(Object.entries(sourceHashes).sort()))},
  g1WebCpu:{isolated:true,sourceFrozen:path.resolve(root,opts.frozen),originalMainSha256:before.identity.scripts['main.lua'],
   probeSha256:sha(probe),damageProbeSha256:sha(damage),damageFixturesSha256:sha(damageFixtures),entrySha256:sha(replacement.get('main.lua')),configuration,variants:variantHashes,bootstrapFiles,
   boundary:'Dedicated main entry replaces gameplay only in derived fixture. All other unchanged assets are hardlinked read-only by convention; never overwrite them. No normal App/Trial/GUI/audio/render scene is created. Source freeze and production bytes are untouched.'}};
 fs.writeFileSync(path.join(destination,'identity.json'),JSON.stringify(prepared,null,2)+'\n');return prepared;
}
module.exports={prepare,options};
if(require.main===module){try{const prepared=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'PREPARED_NOT_RUN',file:path.join(prepared.source_directory,'identity.json'),cpu:prepared.g1WebCpu}))}catch(error){console.error(error.stack);process.exitCode=1}}

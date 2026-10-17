'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(frozenFile,out,batchSize){
 assert([8,32].includes(batchSize),'Explicit baseline or candidate batch size');
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,frozenFile),'utf8'));
 const source=fs.readFileSync(path.join(frozen.source_directory,'scripts/render/SceneWarmup.lua'),'utf8');
 assert.equal(sha(source),frozen.identity.scripts['render/SceneWarmup.lua']);
 assert.equal(source.split('batchSize=batchSize or 8').length,2,'One unchanged production default');
 const candidate=source.replace('batchSize=batchSize or 8','batchSize=batchSize or '+batchSize);
 const main=fs.readFileSync(path.join(frozen.source_directory,'scripts/main.lua'));
 const suffix=fs.readFileSync(path.join(__dirname,'respawn-cache-web-observer.lua'));
 const prefix=path.resolve(root,out);assert(prefix.startsWith(path.join(root,'.tmp')+path.sep));
 const variantFile=prefix+'-SceneWarmup.lua',entryFile=prefix+'-entry.lua';
 assert(!fs.existsSync(variantFile)&&!fs.existsSync(entryFile));
 fs.writeFileSync(variantFile,candidate);fs.writeFileSync(entryFile,Buffer.concat([main,Buffer.from('\n'),suffix]));
 const p=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',frozenFile,'--out',out,'--probe-file',entryFile,
  '--variant','render/SceneWarmup.lua='+variantFile,'--warmup','0','--steps','60']);
 p.respawnCacheWeb={isolated:true,sources:Object.fromEntries(['main.lua','combat/BattleController.lua','combat/CarUnit.lua',
  'drive/SpawnSpecCache.lua','render/SceneWarmup.lua'].map(n=>[n,p.identity.scripts[n]])),
  boundary:'Explicit scene warmup batch experiment. Full production public eight-car entry, actual NPC core destruction/respawn and public return. No gameplay quality reduction. No sustained FPS or device acceptance.'};
 p.sceneBatchExperiment={batchSize,baselineSha256:sha(source),candidateSha256:sha(candidate),
  boundary:'Only SceneWarmup default batch size differs; compare full compiler sets, covered stage times and loading frame intervals before production merge.'};
 p.g1WebCpu.boundary=p.respawnCacheWeb.boundary;
 fs.writeFileSync(path.join(p.source_directory,'identity.json'),JSON.stringify(p,null,2)+'\n');
 return {identity:path.join(p.source_directory,'identity.json'),experiment:p.sceneBatchExperiment};
}
module.exports={prepare};
if(require.main===module)try{console.log(JSON.stringify(prepare(process.argv[2],process.argv[3],Number(process.argv[4]))))}catch(e){console.error(e.stack);process.exitCode=1}

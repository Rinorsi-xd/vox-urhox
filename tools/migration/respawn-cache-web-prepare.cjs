'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv);
 assert.deepEqual(Object.keys(opts).sort(),['frozen','out','variants']);assert.equal(opts.variants.length,0);
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8'));
 const main=fs.readFileSync(path.join(frozen.source_directory,'scripts/main.lua'));
 assert.equal(sha(main),frozen.identity.scripts['main.lua']);
 const suffix=fs.readFileSync(path.join(__dirname,'respawn-cache-web-observer.lua'));
 const entry=path.resolve(root,opts.out)+'-entry.lua';assert(!fs.existsSync(entry));
 assert(entry.startsWith(path.join(root,'.tmp')+path.sep));
 fs.writeFileSync(entry,Buffer.concat([main,Buffer.from('\n'),suffix]));
 const p=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',opts.frozen,'--out',opts.out,'--probe-file',entry,'--warmup','0','--steps','60']);
 p.respawnCacheWeb={isolated:true,productionMainSha256:sha(main),suffixSha256:sha(suffix),
  sources:Object.fromEntries(['main.lua','combat/BattleController.lua','combat/CarUnit.lua','drive/SpawnSpecCache.lua'].map(n=>[n,frozen.identity.scripts[n]])),
  boundary:'Production main plus isolated F7 read-only state and F10 NPC core Destroy/Flush. Actual public 4v4 entry and return. Wait real production BeforeStep respawn. No timing instrumentation, scene relocation, clock edits, or performance claim.'};
 p.g1WebCpu.boundary=p.respawnCacheWeb.boundary;
 fs.writeFileSync(path.join(p.source_directory,'identity.json'),JSON.stringify(p,null,2)+'\n');return p;
}
module.exports={prepare};
if(require.main===module){try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'READY_NOT_RUN',identity:path.join(p.source_directory,'identity.json')}))}catch(e){console.error(e.stack);process.exitCode=1}}

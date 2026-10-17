'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv);assert.equal(opts.variants.length,0);
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8'));
 const checked=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/evidence/story-boss-missile-feedback-offline.json'),'utf8'));
 assert.equal(checked.result,'PASS');assert.equal(frozen.identity.sourceCommit,'b276064942ae09c0227ec28d4cfda1d5ff006455');
 assert.equal(frozen.identity.scripts['combat/StoryBoss.lua'],checked.productionHashes['scripts/combat/StoryBoss.lua']);
 const names=['combat/StoryBoss.lua','story/Mission.lua','story/MissionRules.lua','story/BossRules.lua','combat/CarUnit.lua','app/TrialSession.lua','ui/PauseMenu.lua'];
 const sources=Object.fromEntries(names.map(name=>[name,frozen.identity.scripts[name]]));
 const main=fs.readFileSync(path.join(frozen.source_directory,'scripts/main.lua'));assert.equal(sha(main),frozen.identity.scripts['main.lua']);
 const suffix=fs.readFileSync(path.join(__dirname,'boss-missile-web-observer.lua'));
 const entry=path.resolve(root,opts.out)+'-entry.lua';assert(!fs.existsSync(entry));assert(entry.startsWith(path.join(root,'.tmp')+path.sep));
 fs.writeFileSync(entry,Buffer.concat([main,Buffer.from('\n'),suffix]));
 const prepared=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',opts.frozen,'--out',opts.out,'--probe-file',entry,'--warmup','0','--steps','60']);
 prepared.bossMissileWeb={isolated:true,sources,productionMainSha256:sha(main),suffixSha256:sha(suffix),
  boundary:'Controlled actual EnterTrial story5 loading; explicit Go(2)/Events creates production Boss, sets fight state, then actual AddMissile/Projectiles with real physics LOS and player Explode/Flush/Fx. Three atomic impacts record immediate trauma before ordinary next-frame decay. Temporary wrappers call originals and restore immediately. Actual Escape/menu return verifies disposal. Not natural S5, subjective shake, audible cue, visual parity, FPS or mobile acceptance.'};
 prepared.g1WebCpu.boundary=prepared.bossMissileWeb.boundary;
 fs.writeFileSync(path.join(prepared.source_directory,'identity.json'),JSON.stringify(prepared,null,2)+'\n');return prepared;
}
module.exports={prepare};
if(require.main===module)try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'PREPARED_NOT_RUN',identity:path.join(p.source_directory,'identity.json')}))}catch(e){console.error(e.stack);process.exitCode=1}

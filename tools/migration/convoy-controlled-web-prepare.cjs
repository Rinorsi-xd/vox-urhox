'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv);assert.equal(opts.variants.length,0);
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8'));
 const checked=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/evidence/convoy-sequence-production-offline.json'),'utf8'));
 assert.equal(checked.status,'PASS');const sources={};
 for(const name of ['story/ConvoyRules.lua','story/Mission.lua']){
  assert.equal(frozen.identity.scripts[name],checked.productionHashes['scripts/'+name],name);sources[name]=frozen.identity.scripts[name];
 }
 for(const name of ['story/MissionRules.lua','audio/StoryComms.lua','audio/StoryRadio.lua','ui/PauseMenu.lua','app/TrialSession.lua'])sources[name]=frozen.identity.scripts[name];
 const main=fs.readFileSync(path.join(frozen.source_directory,'scripts/main.lua'));assert.equal(sha(main),frozen.identity.scripts['main.lua']);
 const suffix=fs.readFileSync(path.join(__dirname,'convoy-controlled-web-observer.lua'));
 const entry=path.resolve(root,opts.out)+'-entry.lua';assert(!fs.existsSync(entry));assert(entry.startsWith(path.join(root,'.tmp')+path.sep));
 fs.writeFileSync(entry,Buffer.concat([main,Buffer.from('\n'),suffix]));
 const p=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',opts.frozen,'--out',opts.out,'--probe-file',entry,'--warmup','0','--steps','60']);
 p.convoyControlledWeb={isolated:true,sources,productionMainSha256:sha(main),suffixSha256:sha(suffix),
  boundary:'Actual public S2 selection/start, actual Mission/Rules/consumer calls. F10 explicitly places player at meet, then changes only convoy d/v/pos/yaw and actual Mission.Place before each threshold. Does not write rule progress, phase, clock, cp, health, stats, beats, enemies or voice. Real next updates cross thresholds. Real pause page and Continue retain same mission and saved checkpoint while source neutral simulation continues. Actual public return checks mission/world/heightfield disposal. Not Retry, natural full mission, audible listening, visual 1:1 or performance acceptance.'};
 p.g1WebCpu.boundary=p.convoyControlledWeb.boundary;
 fs.writeFileSync(path.join(p.source_directory,'identity.json'),JSON.stringify(p,null,2)+'\n');return p;
}
module.exports={prepare};
if(require.main===module){try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'READY_NOT_RUN',identity:path.join(p.source_directory,'identity.json')}))}catch(error){console.error(error.stack);process.exitCode=1}}

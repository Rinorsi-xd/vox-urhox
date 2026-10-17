'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const options=require('./g1-web-cpu-prepare.cjs').options(argv);
 assert(options.frozen&&options.out,'--frozen NEW_UNIFIED_IDENTITY --out .tmp/reactor-feedback-LABEL');
 assert.deepEqual(Object.keys(options).sort(),['frozen','out','variants']);assert.equal(options.variants.length,0);
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,options.frozen),'utf8').replace(/^\uFEFF/,''));
 const reference=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/evidence/reactor-feedback-1015-offline.json'),'utf8'));
 assert.equal(reference.status,'PASS');assert.equal(reference.sourceCommit,'b276064942ae09c0227ec28d4cfda1d5ff006455');
 const modules={};
 for(const name of ['render/ObjectiveView.lua','combat/BattleObjectives.lua']){
  const bytes=fs.readFileSync(path.join(frozen.source_directory,'scripts',name));
  assert.equal(sha(bytes),reference.files['scripts/'+name],'New unified freeze must include tested repair: '+name);
  assert.equal(sha(bytes),frozen.identity.scripts[name],'Frozen production identity: '+name);modules[name]=sha(bytes);
 }
 const probe=path.join(__dirname,'reactor-feedback-render.lua');
 const prepared=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',options.frozen,'--out',options.out,
  '--scenario','lanes','--steps','60','--warmup','0','--probe-file',probe]);
 prepared.reactorFeedback={isolated:true,kind:'rendered-functional-fixture',modules,probeSha256:sha(fs.readFileSync(probe)),
  stages:['before','hit','decayed','explosion-hit','culled','cull-return','shielded'],
  boundary:'Dedicated derived main; frozen production modules untouched, no App/gameplay/save/inventory. Synthetic rules/aims used only by fixture. Fixed 1/60 dt for reproducible visual stages; not natural combat or a performance benchmark.'};
 fs.writeFileSync(path.join(prepared.source_directory,'identity.json'),JSON.stringify(prepared,null,2)+'\n');return prepared;
}
module.exports={prepare};
if(require.main===module){try{const r=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'PREPARED_NOT_RUN',identity:path.join(r.source_directory,'identity.json'),fixture:r.reactorFeedback}))}catch(e){console.error(e.stack);process.exitCode=1}}

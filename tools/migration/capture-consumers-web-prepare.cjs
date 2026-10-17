'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv);assert.equal(opts.variants.length,0);
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8'));
 const checked=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/evidence/capture-sequence-offline.json'),'utf8'));assert.equal(checked.status,'PASS');
 const sources={};for(const name of ['story/CaptureRules.lua','story/MissionRules.lua','story/Mission.lua']){
  assert.equal(frozen.identity.scripts[name],checked.hashes['scripts/'+name],'Frozen production must include tested capture change');sources[name]=frozen.identity.scripts[name];
 }
 const main=fs.readFileSync(path.join(frozen.source_directory,'scripts/main.lua'));assert.equal(sha(main),frozen.identity.scripts['main.lua']);
 const suffix=fs.readFileSync(path.join(__dirname,'capture-consumers-web-observer.lua'));
 const entry=path.resolve(root,opts.out)+'-entry.lua';assert(!fs.existsSync(entry));assert(entry.startsWith(path.join(root,'.tmp')+path.sep));
 fs.writeFileSync(entry,Buffer.concat([main,Buffer.from('\n'),suffix]));
 const p=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',opts.frozen,'--out',opts.out,'--probe-file',entry,'--warmup','0','--steps','60']);
 p.captureConsumersWeb={isolated:true,sources,productionMainSha256:sha(main),suffixSha256:sha(suffix),
  boundary:'Real public S4 App/Trial entry. Actual Mission events call actual radio/voice/view consumers. F7 reads state; F10 uses actual Mission.Place at current capture; F9 destroys enemy cores via actual Destroy/Flush. Hold actual G for scrub. No production clock, p, phase, stage or stat edits. Controlled placement/destruction is not natural combat or performance evidence.'};
 p.g1WebCpu.boundary=p.captureConsumersWeb.boundary;fs.writeFileSync(path.join(p.source_directory,'identity.json'),JSON.stringify(p,null,2)+'\n');return p;
}
module.exports={prepare};
if(require.main===module){try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'READY_NOT_RUN',identity:path.join(p.source_directory,'identity.json')}))}catch(e){console.error(e.stack);process.exitCode=1}}

'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const options=require('./g1-web-cpu-prepare.cjs').options(argv);assert(options.frozen&&options.out);assert.equal(options.variants.length,0);
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,options.frozen),'utf8'));
 const reference=require('../../docs/migration/evidence/epilogue-panel-motion-offline.json');assert.equal(reference.status,'PASS');
 const modules={};for(const name of ['ui/Epilogue.lua','ui/EpilogueMotion.lua']){
  const hash=sha(fs.readFileSync(path.join(frozen.source_directory,'scripts',name)));
  assert.equal(hash,reference.hashes['scripts/'+name],'Unified frozen build must include tested change: '+name);assert.equal(hash,frozen.identity.scripts[name]);modules[name]=hash;
 }
 const p=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',options.frozen,'--out',options.out,'--probe-file',path.join(__dirname,'epilogue-panel-motion-render.lua'),'--warmup','0','--steps','60']);
 p.epiloguePanelMotion={isolated:true,modules,stages:['panel-mid','panel-settled','impact-mid','impact-settled','zoom-mid','zoom-settled','deal-impact-mid','deal-impact-settled'],
  boundary:'Dedicated staged UI render using actual authored epilogue panels and unchanged frozen production modules. Synthetic times; no App/save/gameplay/audio or performance benchmark.'};
 fs.writeFileSync(path.join(p.source_directory,'identity.json'),JSON.stringify(p,null,2)+'\n');return p;
}
module.exports={prepare};
if(require.main===module){try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'PREPARED_NOT_RUN',identity:path.join(p.source_directory,'identity.json')}))}catch(e){console.error(e.stack);process.exitCode=1}}

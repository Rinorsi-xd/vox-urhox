'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv);assert(opts.frozen&&opts.out);assert.equal(opts.variants.length,0);
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8'));
 const reference=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/evidence/rotor-disc-offline.json'),'utf8'));assert.equal(reference.status,'PASS');
 const modules={};for(const [full,expected]of Object.entries(reference.productionHashes)){
  const name=full.slice('scripts/'.length);const actual=sha(fs.readFileSync(path.join(frozen.source_directory,'scripts',name)));
  assert.equal(actual,expected,'Freeze must include tested rotor candidate '+name);assert.equal(frozen.identity.scripts[name],expected);modules[name]=actual;
 }
 const prepared=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',opts.frozen,'--out',opts.out,'--probe-file',path.join(__dirname,'rotor-disc-render.lua'),'--warmup','0','--steps','60']);
 prepared.rotorDisc={isolated:true,modules,stages:['top-default','top-double','bottom-default','bottom-double','oblique-default','oblique-double'],
  boundary:'Production authored rotor discs and normal materials in isolated diagnostic scene. Three types, both sides, fixed poses; double-sided material clones only in fixture. No gameplay or performance claim; culling requires screenshot inspection.'};
 fs.writeFileSync(path.join(prepared.source_directory,'identity.json'),JSON.stringify(prepared,null,2)+'\n');return prepared;
}
module.exports={prepare};
if(require.main===module){try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'PREPARED_NOT_RUN',identity:path.join(p.source_directory,'identity.json')}))}catch(e){console.error(e.stack);process.exitCode=1}}

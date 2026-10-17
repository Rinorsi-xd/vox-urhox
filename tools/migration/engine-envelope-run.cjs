'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const sparse=require('./sparse-combat-run.cjs'),{analyze}=require('./engine-envelope-analyze.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
async function run(base,out,duration=45000){
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.engineEnvelope?.isolated);
 for(const[name,expected]of Object.entries(identity.engineEnvelope.tools))assert.equal(sha(fs.readFileSync(path.join(__dirname,name))),expected,'Frozen tool changed: '+name);
 assert(!global.__voxSparseAnalyze);global.__voxSparseAnalyze=r=>({...sparse.analyze(r),engineEnvelope:analyze(r)});
 try{return await sparse.buildRunner()(base,out,duration,require('./sparse-combat-cpu.cjs').create(out));}
 finally{delete global.__voxSparseAnalyze;}
}
module.exports={run};
if(require.main===module)run(process.argv[2],path.resolve(process.argv[3]),Number(process.argv[4]||45000)).catch(e=>{console.error(e.stack);process.exitCode=1});

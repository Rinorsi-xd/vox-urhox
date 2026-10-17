// Dedicated opt-in entry; importing it never opens a browser.
'use strict';
const path=require('node:path'),assert=require('node:assert/strict');
async function run(base,out,duration=45000){
 const diagnostic=require('./monitor-combat-cdp.cjs').create(out);
 const report=await require('./monitor-combat-run.cjs').run(base,out,duration,diagnostic);
 assert.equal(report.status,'PASS');assert.equal(report.shutdown,'CLOSED');assert.equal(diagnostic.metadata.status,'COLLECTED');assert.equal(diagnostic.metadata.detached,true);
 return report;
}
module.exports={run};
if(require.main===module)run(process.argv[2],path.resolve(process.argv[3]),Number(process.argv[4]||45000)).catch(error=>{console.error(error.stack);process.exitCode=1});

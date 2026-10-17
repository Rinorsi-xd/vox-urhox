const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const source=path.join(root,'.tmp/perf-damage-flush-scalar-c935-1017');
const target=path.join(root,'docs/migration/evidence/native-damage-scalar-rejected-2026-10-17');
assert(!fs.existsSync(target),'Preserve existing archive');
const sha=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const read=f=>JSON.parse(fs.readFileSync(f,'utf8').replace(/^\uFEFF/,''));
const labels=['scalar-A1','scalar-B1','scalar-B2','scalar-A2'];
const strict=spawnSync(process.execPath,[path.join(root,'tools/migration/perf-damage-flush-scalar-analyze.cjs')],{cwd:root,encoding:'utf8'});
assert.notEqual(strict.status,0,'Expected preserved strict native-state failure');
const timings=[];let firstMismatch;
for(const label of labels){
  const report=read(path.join(source,label+'.json'));
  const processRecord=read(path.join(source,label+'.process.json'));
  const validation=read(path.join(source,label+'.validation.json'));
  assert.equal(processRecord.exitCode,0);assert.equal(report.status,'PASS');assert.equal(validation.valid,true);
  assert.equal(report.steps.length,192);assert.equal(report.batches,8);assert.equal(report.cleanup,true);assert.equal(report.collectorRunning,true);
  timings.push({label,flushTotalWallMs:report.steps.reduce((n,s)=>n+s.flush.wallMs,0),turretForTotalWallMs:report.steps.reduce((n,s)=>n+s.stats['turretRange.For'].wallMs,0)});
  if(!firstMismatch) for(const step of report.steps){
    for(const key of ['p','q','lv','av']) for(const component of Object.keys(step.stateBefore[key])){
      const before=step.stateBefore[key][component],after=step.stateAfter[key][component];
      if(before!==after){firstMismatch={label,batch:step.batch,unit:step.unit,step:step.step,key,component,before,after,absoluteDifference:Math.abs(before-after)};break;}
    }
    if(firstMismatch)break;
  }
}
assert(firstMismatch);
fs.mkdirSync(target,{recursive:true});
const archiveEntries=[];
function copy(src,name){const dst=path.join(target,name);fs.mkdirSync(path.dirname(dst),{recursive:true});fs.copyFileSync(src,dst);assert.equal(sha(src),sha(dst));archiveEntries.push({source:path.relative(root,src).replaceAll('\\','/'),archive:name,sha256:sha(src),bytes:fs.statSync(src).size});}
for(const entry of fs.readdirSync(source,{withFileTypes:true})) if(entry.isFile())copy(path.join(source,entry.name),'originals/'+entry.name);
for(const name of ['perf-damage-flush-scalar-native.lua','perf-damage-flush-scalar-prepare.cjs','perf-damage-flush-scalar-run.ps1','perf-damage-flush-scalar-analyze.cjs','check-turret-prepare-scalar.lua','check-turret-prepare-scalar.py'])copy(path.join(root,'tools/migration',name),'tools/'+name);
copy(path.join(root,'tools/migration/candidates/TurretRangePrepareScalar.lua'),'candidate/TurretRangePrepareScalar.lua');
copy(path.join(source,'A/scripts/construction/TurretRange.lua'),'baseline/TurretRange.lua');
copy(path.join(root,'docs/migration/evidence/turret-prepare-scalar-offline-2026-10-17.json'),'offline-correctness.json');
fs.writeFileSync(path.join(target,'strict-analyzer-failure.log'),strict.stdout+strict.stderr);
const report={status:'REJECTED_NO_GAIN',acceptance:'STRICT_EQ_FAILURE',timingsAreExploratoryOnly:true,firstMismatch,timings,
  boundary:'Four normal-GC actual Native runs exit zero and runtime tolerance assertions pass, but unchanged strict analyzer rejects an original baseline Native state roundtrip. Scalar candidate has no repeatable timing gain and is rejected. Raw native values preserved. No assertion relaxed and no production change. Prior runtime state assertion used tolerance and is not bit-exact acceptance. The original scalar probe iterated native state via generic Same, while its later strict independent analyzer caught the difference; any derived Native tolerance in newer experiments is separately predeclared and does not retroactively accept these runs.',
  strictAnalyzer:{exitCode:strict.status,stdout:strict.stdout,stderr:strict.stderr},archiveEntries};
fs.writeFileSync(path.join(target,'rejection.json'),JSON.stringify(report,null,2));
fs.writeFileSync(path.join(target,'archive-sha256.json'),JSON.stringify({originalsPreserved:true,entries:archiveEntries,derived:['rejection.json','strict-analyzer-failure.log']},null,2));
console.log(JSON.stringify({status:report.status,acceptance:report.acceptance,target,files:archiveEntries.length,firstMismatch,timings}));

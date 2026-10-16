// Re-evaluate preserved real telemetry. Does not launch or modify a game session.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),api=require('./story-convoy-acceptance.cjs');
const input=path.resolve(root,process.argv[2]||'docs/migration/evidence/story-natural-s2-manifest-6a53673c-2026-10-16T04-20-20-834Z/result.json');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),bytes=fs.readFileSync(input),original=JSON.parse(bytes);
assert.equal(original.result,'PASS','preserved actual run passed its original acceptance');
const level=require('../../assets/Story/Mission/Level2.json').level,run=api.create(level),checks=[];
const inputs=[...original.convoyAcceptance.inputs].sort((a,b)=>a.wallMs-b.wallMs);
let index=0;
for(let i=0;i<original.samples.length;i++){
 const sample=original.samples[i],next=original.samples[i+1]?.at??Infinity;
 api.observe(run,sample.story,sample.at,(ok,label)=>{assert(ok,label);checks.push(label);});
 while(index<inputs.length&&inputs[index].wallMs<next){
  const actual=inputs[index++];assert(actual.wallMs>=sample.at,'actual input follows the observed choice');
  assert.equal(sample.story.choice?.id,actual.id,'actual public input belongs to the observed choice');
  assert.equal(api.option(run,sample.story.choice,actual.wallMs),actual.key,'original real key matches nondefault option');
 }
}
assert.equal(index,inputs.length,'all original public inputs were replayed');
assert.equal(run.result,'FUNCTIONAL_PASS');assert.equal(run.encounterIdentity.result,'OPEN');
const finished=original.samples.find(s=>s.story.finished),delivery=original.transitions.find(t=>t.story.phase==='complete');
assert(finished,'preserved actual finished sample');
assert.equal(sha(fs.readFileSync(input)),sha(bytes),'original evidence was not modified');
const output=path.join(root,'docs/migration/evidence/story-convoy-6a-offline-recheck.json');
const files=['tools/migration/recheck-story-convoy-result.cjs','tools/migration/story-convoy-acceptance.cjs','assets/Story/Mission/Level2.json'];
const report={result:'PASS',kind:'OFFLINE_RECHECK_OF_ACTUAL_WEB_TELEMETRY',source:{path:path.relative(root,input),sha256:sha(bytes),
 manifest:original.identity.servedManifest,originalToolSha256:original.toolSha256,originalResult:original.result,originalChecks:original.checks,originalErrors:original.errors},
 checks,observed:{deliveryMissionSeconds:delivery?.story.time,finishedMissionSeconds:finished.story.time,finishedWallMs:finished.at,
  grade:finished.story.grade,stats:finished.story.stats,truck:finished.story.truck},rechecked:run,
 inputs:Object.fromEntries(files.map(p=>[p,sha(fs.readFileSync(path.join(root,p)))])),
 boundary:'Offline replay of unchanged actual Web samples and recorded public number keys. The newer road-navigation tool was not run in this original Web attempt. PASS confirms recorded delivery, choices, checkpoints, H5 grade formula and actual/result HP agreement. Three separate enemy-wave identities, presentation parity, audio continuity, isolated performance and physical mobile remain unaccepted.'};
fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({result:report.result,checks:checks.length,grade:run.grade,grading:run.grading,output}));

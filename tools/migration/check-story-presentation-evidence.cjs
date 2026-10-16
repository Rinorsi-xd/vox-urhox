const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {choiceEvidence}=require('./story-presentation-evidence.cjs');
const fields=['at','frame','choiceId','choicePicked','choiceOn','choiceVisible','choiceHideAt'];
const held=[100,1,'surrender',2,true,true,590],exited=[700,2,'surrender',2,false,false,false];
const sample=(name,rows)=>({name,state:{story:{presentation:{frameFields:fields,frames:rows,historyMode:rows.length===1?'last':'full'}}}});
let checks=0;const check=(ok,label)=>{assert(ok,label);checks++;};
const accepted=e=>e.heldObserved&&e.exitObserved&&e.timerWithinSource&&e.orderedExit;
const baseline=[sample('choice-selected',[held]),sample('choice-exited',[held,exited])];
let e=choiceEvidence(baseline,'surrender',2);
check(accepted(e),'Frozen snapshots preserve observed hold and exit');
check(e.frames===2&&e.held===1&&e.exited===1,'Overlapping rings are deduplicated');
e=choiceEvidence([...baseline,sample('automatic-last',[exited])],'surrender',2);
check(accepted(e),'Later automatic last-frame observer cannot erase earlier actual evidence');
const rejectedMutations=[];
for(const [name,samples]of [
 ['missing held',[sample('choice-exited',[exited])]],
 ['missing exit',[sample('choice-selected',[held])]],
 ['timer over source500ms',[sample('choice-selected',[[100,1,'surrender',2,true,true,601],exited])]],
 ['wrong selected option',[sample('choice-selected',[[100,1,'surrender',1,true,true,590],exited])]],
 ['wrong authored choice',[sample('choice-selected',[[100,1,'other',2,true,true,590],exited])]],
 ['exit preceding hold',[sample('choice-selected',[[50,0,'surrender',2,false,false,false],held])]],
 ]){check(!accepted(choiceEvidence(samples,'surrender',2)),'Reject '+name);rejectedMutations.push(name);}
assert.throws(()=>choiceEvidence([...baseline,sample('conflict',[[100,1,'surrender',2,false,true,590]])],'surrender',2),/Overlapping/);checks++;
const report={result:'PASS',checks,rejectedMutations,boundary:'CPU observer aggregation checks only; synthetic negatives are not gameplay evidence. Optional replay uses immutable recorded actual frames and does not rerun Web, change the original result, or complete unexecuted return-to-hall checks.'};
if(process.argv[2]){
 const input=path.resolve(process.argv[2]),bytes=fs.readFileSync(input),actual=JSON.parse(bytes);
 e=choiceEvidence(actual.samples.filter(s=>s.name.startsWith('choice-')),'surrender',2);
 check(accepted(e),'Recorded actual snapshots contain valid source-timed confirmation and ordered exit');
 report.checks=checks;report.replay={input,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),originalResult:actual.result,originalFailure:actual.failure,
  manifest:actual.identity.servedManifest,probeSha256:actual.identity.probeSha256,choiceEvidence:e};
 const output=path.join(path.dirname(input),path.basename(input,'.json')+'-choice-history-replay.json');fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
}
console.log(JSON.stringify(report,null,2));

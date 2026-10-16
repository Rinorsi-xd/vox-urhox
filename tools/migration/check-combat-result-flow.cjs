const assert=require('node:assert/strict');
const {finishMvp,assertNewRoster}=require('./combat-result-flow.cjs');
let checks=0;
function check(fn){fn();checks++;}
async function scenario({preparing=false,done=false,failed=false,t=0,ignored=false,preparationFailure=false,finishFailure=false}={}){
 const show={preparing,active:!preparing&&!done,done,failed,t};const s={battle:{mvp:show},widgets:[]};let presses=0;const phases=[];
 async function wait(fn,label){phases.push(label);if(label==='MVP resource preparation'&&preparing){show.preparing=false;show.active=!preparationFailure;show.failed=preparationFailure;show.done=preparationFailure;}
  if(label==='MVP continuation fade'&&show.finishing!=null){show.done=true;show.active=false;show.failed=finishFailure;}
  if(label==='result button'&&show.done)s.widgets=[{text:'再来一局',rect:[20,30,156,50]}];
  assert(fn(s),'Mock wait predicate: '+label);return structuredClone(s);}
 async function key(value){assert.equal(value,'Space');presses++;if(show.done||show.preparing||ignored)return;if(show.t<7.1){show.t=7.1;show.jumped=true;}else show.finishing=0;}
 const result=await finishMvp({key,dump:async()=>structuredClone(s),wait});return {presses,phases,result};
}
(async()=>{
 const early=await scenario();check(()=>assert.equal(early.presses,2));check(()=>assert.equal(early.result[1].t,7.1));check(()=>assert.equal(early.result[2].finishing,0));check(()=>assert(early.result.at(-1).done));
 const late=await scenario({t:8});check(()=>assert.equal(late.presses,1));
 const ready=await scenario({preparing:true});check(()=>assert.equal(ready.presses,2));
 const ended=await scenario({done:true});check(()=>assert.equal(ended.presses,0));
 await assert.rejects(()=>scenario({failed:true,done:true}),/Production MVP preparation failed/);checks++;
 await assert.rejects(()=>scenario({preparing:true,preparationFailure:true}),/Production MVP preparation failed/);checks++;
 await assert.rejects(()=>scenario({ignored:true}),/First Space/);checks++;
 await assert.rejects(()=>scenario({finishFailure:true}),/Production MVP preparation failed/);checks++;
 check(()=>assertNewRoster(['a','b'],['c','d']));
 for(const next of [['b','a'],['a','c'],['c','c'],['c'],['c','']]){check(()=>assert.throws(()=>assertNewRoster(['a','b'],next)));}
 console.log(JSON.stringify({result:'PASS',checks,boundary:'Pure Node tool-control tests; no browser/GPU or production behavior acceptance.'}));
})().catch(error=>{console.error(error);process.exitCode=1;});

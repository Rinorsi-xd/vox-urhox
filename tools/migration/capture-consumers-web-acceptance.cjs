'use strict';
const assert=require('node:assert/strict');
function check(state,site){
 assert.equal(state.story.id,'s4');assert(state.consumer,'Actual mission consumers must be attached');
 const calls=state.calls.filter(e=>e.site===site),start=calls.findIndex(e=>e.kind==='radio'&&e.cue==='alert');assert(start>=0,'Actual encounter radio consumer');
 assert.equal(calls[start-1].kind,'say');assert.equal(calls[start+1].kind,'HideBeacon','Actual alert before beacon removal');
 const install=calls.findIndex(e=>e.kind==='radio'&&e.cue==='install');assert(install>=0);
 assert.equal(calls[install-1].kind,'Banner');assert.equal(calls[install-2].kind,'SiteCaptured');assert.equal(calls[install-2].captured,true,'Actual view changes capture state');
 assert.equal(calls[install+1].kind,'say','Actual install consumer precedes voice queue');
 const scrub=calls.findIndex(e=>e.kind==='Scrub');assert(scrub>=0&&Number.isFinite(calls[scrub].scrubbed),'Actual view scrub timestamp');
 assert.equal(calls[scrub+1].kind,'radio');assert.equal(calls[scrub+1].cue,'pickup','Actual scrub precedes pickup audio');
 for(const cue of ['install','pickup']){
  const event=calls.find(e=>e.kind==='radio'&&e.cue===cue);assert.equal(event.accepted,true,'Actual '+cue+' cue accepted');
  assert(event.after.slots.some(s=>s.order===event.after.order&&s.source.playing),'Actual '+cue+' SoundSource is playing after Play');
 }
 const view=state.consumer.sites[site];assert(view.captured&&Number.isFinite(view.scrubbed));
 return {site,events:calls.length,status:'CONSUMERS_PASS',boundary:'Actual consumer order, mutated view state and engine SoundSource playing flags only. Screenshot inspection and audible output verification are separate; controlled QA placement/destruction is not natural combat or performance evidence.'};
}
function checkComplete(state){
 assert.equal(state.story.id,'s4');assert.equal(state.story.finished,true,'Actual result reached after production timer/voice');
 const calls=state.calls,index=calls.findIndex(e=>e.kind==='Banner'&&e.title==='任务完成');assert(index>=6);
 const order=calls.slice(index-5,index+2);assert.deepEqual(order.map(e=>e.kind),
  ['HideBeacon','ClearEnemies','viewObjective','choiceCancel','objectiveDone','Banner','radio']);
 assert.equal(order[0].beaconEnabled,false);assert.equal(order[1].remaining,0);
 assert.equal(order[2].cleared,true);assert.equal(order[2].zoneEnabled,false);assert.equal(order[2].beaconEnabled,false);
 assert.equal(order[3].on,false);assert.equal(order[3].choosing,false);assert.equal(order[4].done,true);
 assert.equal(order[5].ms,5200);assert.equal(order[5].style,'ok');
 const cue=order[6];assert.equal(cue.cue,'done');assert.equal(cue.accepted,true);
 assert(cue.after.slots.some(s=>s.order===cue.after.order&&s.source.playing),'Actual done SoundSource playing at consumption');
 assert.equal(calls.filter(e=>e.kind==='radio'&&e.cue==='done').length,1,'Single actual completion cue');
 return {status:'COMPLETION_CONSUMERS_PASS',order:order.map(e=>e.kind),boundary:'Actual completion consumer calls and view/choice/objective state plus SoundSource playing flag. Does not assert audible output or visual identity.'};
}
function selfTest(){
 const playing={order:1,slots:[{order:1,source:{playing:true}}]};
 const fixture={story:{id:'s4'},consumer:{sites:{A:{captured:true,scrubbed:8}}},calls:[
  {site:'A',kind:'say'},{site:'A',kind:'radio',cue:'alert'},{site:'A',kind:'HideBeacon'},
  {site:'A',kind:'SiteCaptured',captured:true},{site:'A',kind:'Banner'},{site:'A',kind:'radio',cue:'install',accepted:true,after:playing},
  {site:'A',kind:'say'},{site:'A',kind:'Scrub',scrubbed:8},
  {site:'A',kind:'radio',cue:'pickup',accepted:true,after:playing}]};
 check(fixture,'A');let rejected=0;
 for(const mutate of [
  s=>{[s.calls[1],s.calls[2]]=[s.calls[2],s.calls[1]]},
  s=>{[s.calls[5],s.calls[6]]=[s.calls[6],s.calls[5]]},
  s=>{[s.calls[7],s.calls[8]]=[s.calls[8],s.calls[7]]},
  s=>{s.calls[5].accepted=false},s=>{s.calls[5].after.slots[0].source.playing=false},
  s=>{s.consumer.sites.A.captured=false},s=>{delete s.calls[7].scrubbed}]){
  const bad=structuredClone(fixture);mutate(bad);assert.throws(()=>check(bad,'A'));rejected++;
 }
 const complete={story:{id:'s4',finished:true},calls:[{kind:'prefix'},
  {kind:'HideBeacon',beaconEnabled:false},{kind:'ClearEnemies',remaining:0},
  {kind:'viewObjective',cleared:true,zoneEnabled:false,beaconEnabled:false},
  {kind:'choiceCancel',on:false,choosing:false},{kind:'objectiveDone',done:true},
  {kind:'Banner',title:'任务完成',ms:5200,style:'ok'},{kind:'radio',cue:'done',accepted:true,after:playing}]};
 checkComplete(complete);
 for(const mutate of [s=>{const cue=s.calls.pop();s.calls.splice(1,0,cue)},s=>{s.calls[2].remaining=1},
  s=>{s.calls[3].zoneEnabled=true},s=>{s.calls[4].choosing=true},s=>{s.calls[5].done=false},
  s=>{s.calls[7].accepted=false},s=>{s.calls.push(structuredClone(s.calls[7]))}]){
  const bad=structuredClone(complete);mutate(bad);assert.throws(()=>checkComplete(bad));rejected++;
 }
 return {status:'PASS',rejected,boundary:'Acceptance assertion self-test only; no game runtime.'};
}
module.exports={check,checkComplete,selfTest};
if(require.main===module)console.log(JSON.stringify(selfTest()));

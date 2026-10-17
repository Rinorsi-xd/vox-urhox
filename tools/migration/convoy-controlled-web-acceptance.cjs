'use strict';
const assert=require('node:assert/strict');
const step=require('../../assets/Story/Mission/Level2.json').level.steps.find(s=>s.kind==='escort');
const asArray=value=>Array.isArray(value)?value:[];
function checkpoints(state){
 const records=asArray(state.checkpoints);assert.equal(records.length,2,'Exactly two actual checkpoint notifications');
 for(const [i,r]of records.entries()){
  assert.equal(r.mission,'s2');assert.equal(r.checkpoint,i+1);assert.equal(r.sequence,i+1);assert.equal(r.generation,1);
  assert(r.hp>0&&r.hp<=1);assert.equal(r.hp,r.cpHp);assert.equal(r.d,r.cpD);
  assert(r.d/r.total>=step.checkpoints[i]);assert(r.d/r.total<step.checkpoints[i]+.01);
  const calls=r.calls.slice(0,3);assert.deepEqual(calls.map(c=>c.kind),['Banner','radio','say']);
  assert(calls.every(c=>c.frame===r.frame),'Same actual HandleUpdate dispatch');
  const [banner,radio,say]=calls;
  assert.equal(banner.kick,'检查点');assert.equal(banner.title,'检查点 '+(i+1));assert.equal(banner.style,'install');assert.equal(banner.ms,2400);
  assert.equal(banner.banner.title,banner.title);assert.equal(radio.cue,'install');assert.equal(radio.accepted,true);assert.equal(radio.playing,true);
  assert.deepEqual(say.lines,step.cpLines[i]);assert.equal(say.urgent,false);
  const queue=asArray(say.after.queue);assert(queue.length>=say.lines.length,'Actual Say queued the authored lines');
  assert.deepEqual(queue.slice(-say.lines.length),step.cpLines[i],'Actual queue tail keeps authored order');
 }
 return {status:'PASS_TWO_CHECKPOINT_CONSUMERS',checkpoints:2,sourceOrder:'Banner -> accepted playing radio -> Say queue'};
}
function preparations(state){
 const records=asArray(state.preparations);assert.deepEqual(records.map(r=>r.placement),['meet','checkpoint-1','checkpoint-2']);
 for(const r of records){
  assert.equal(r.kind,'explicit-qa-place');
  for(const key of ['index','progress','time','stats','checkpoint','beats','voice'])assert.deepEqual(r.before[key],r.after[key],'Preparation must not write '+key);
  for(const key of ['hp','cp','cpD','cpHp','total'])assert.deepEqual(r.before.truck[key],r.after.truck[key],'Preparation must not write truck '+key);
  if(r.placement==='meet')assert.deepEqual(r.before.truck,r.after.truck);
  else{
   const cp=Number(r.placement.slice(-1)),truck=r.after.truck;
   assert.equal(truck.cp,cp-1);assert.equal(truck.d,step.checkpoints[cp-1]*truck.total-.001);assert.equal(truck.v,step.speed);
   assert.deepEqual(r.requestedPlace.pos,[truck.pos[0],truck.pos[1]+1.5,truck.pos[2]]);
   assert.equal(r.requestedPlace.yaw,truck.yaw);
   assert(r.after.player.every(Number.isFinite),'Actual centered vehicle position recorded');
  }
 }
 return {status:'PASS_CONTROLLED_PLACEMENT_BOUNDARY',placements:3};
}
function pause(before,after,resumed){
 for(const s of [before,after,resumed]){assert.equal(s.generation,1);assert.equal(s.sameMission,true);assert.equal(s.story.id,'s2');assert.equal(s.story.truck.cp,1)}
 assert.equal(before.unified,true);assert.equal(after.unified,true);assert.equal(before.captured,false);assert.equal(after.captured,false);
 assert(after.story.time>before.story.time,'Frozen source keeps neutral simulation running under this menu');
 for(const s of [after,resumed]){
  for(const key of ['cp','cpD','cpHp'])assert.equal(s.story.truck[key],before.story.truck[key],'Menu must preserve saved truck '+key);
  assert.deepEqual(s.story.checkpoint,before.story.checkpoint,'Saved player checkpoint preserved');
  assert.equal(s.story.stats.fails,before.story.stats.fails);assert.equal(s.story.stats.deaths,before.story.stats.deaths);
 }
 assert.equal(resumed.dialog,false);assert.equal(resumed.captured,true);assert(resumed.story.worldTime>=after.story.worldTime);
 return {status:'PASS_PAUSE_CONTINUE_SAME_MISSION',neutralSimulation:true,retryCovered:false};
}
function returned(state){
 assert.equal(state.mode,'hangar');assert.equal(state.loading,false);assert.equal(state.sameMission,false);
 assert.equal(state.worldReleased,true);assert.equal(state.terrainReleased,true);
 const d=state.disposed;assert(d);for(const key of ['missionDisposed','voiceReleased','radioReleased','viewReleased','convoyReleased'])assert.equal(d[key],true,key);
 assert.equal(d.entries,0);assert.equal(d.before.generation,1);assert.equal(d.before.truck.cp,2);
 return {status:'PASS_PUBLIC_RETURN_RELEASE'};
}
function selfTest(){
 const records=[1,2].map(cp=>({mission:'s2',checkpoint:cp,sequence:cp,generation:1,hp:1,cpHp:1,d:step.checkpoints[cp-1]*500,total:500,cpD:step.checkpoints[cp-1]*500,frame:cp,
  calls:[{kind:'Banner',frame:cp,kick:'检查点',title:'检查点 '+cp,style:'install',ms:2400,banner:{title:'检查点 '+cp}},
   {kind:'radio',frame:cp,cue:'install',accepted:true,playing:true},{kind:'say',frame:cp,lines:step.cpLines[cp-1],urgent:false,after:{queue:step.cpLines[cp-1]}}]}));
 checkpoints({checkpoints:records});let rejected=0;
 for(const mutate of [r=>r.pop(),r=>r.push(structuredClone(r[0])),r=>r[0].calls.reverse(),r=>r[0].calls[1].accepted=false,
  r=>r[0].calls[1].playing=false,r=>r[0].calls[2].after.queue=[],r=>r[0].calls[2].after.queue=[['yun','wrong']],
  r=>r[0].calls[2].frame=99,r=>r[0].cpHp=.3,r=>r[0].d=0]){
  const bad=structuredClone(records);mutate(bad);assert.throws(()=>checkpoints({checkpoints:bad}));rejected++;
 }
 const p={generation:1,sameMission:true,unified:true,captured:false,story:{id:'s2',time:4,worldTime:4,truck:{cp:1,cpD:170,cpHp:1},checkpoint:{pos:[1,2,3]},stats:{fails:0,deaths:0}}};
 const after=structuredClone(p);after.story.time=6;after.story.worldTime=6;
 const resumed=structuredClone(after);resumed.dialog=false;resumed.captured=true;
 pause(p,after,resumed);
 for(const mutate of [r=>r.generation=2,r=>r.story.truck.cpD=171,r=>r.story.stats.fails=1,r=>r.captured=false]){
  const bad=structuredClone(resumed);mutate(bad);assert.throws(()=>pause(p,after,bad));rejected++;
 }
 const prepareRecords=['meet','checkpoint-1','checkpoint-2'].map((placement,i)=>{
  const before={index:i===0?1:2,progress:0,time:2,stats:{fails:0},checkpoint:{pos:[0,1,2]},beats:{},voice:{queue:[]},
   truck:{hp:1,cp:Math.max(0,i-1),cpD:0,cpHp:1,total:500,d:0,v:0,pos:[1,2,3],yaw:0}};
  const after=structuredClone(before);after.player=[4,5,6];
  if(i>0){after.truck.d=step.checkpoints[i-1]*500-.001;after.truck.v=step.speed}
  return{kind:'explicit-qa-place',placement,before,after,requestedPlace:{pos:[1,3.5,3],yaw:0}};
 });
 preparations({preparations:prepareRecords});
 for(const mutate of [r=>r[1].after.progress=.34,r=>r[1].after.voice.queue=[['yun','injected']],
  r=>r[1].after.truck.cp=1,r=>r[1].requestedPlace.pos[1]=99]){
  const bad=structuredClone(prepareRecords);mutate(bad);assert.throws(()=>preparations({preparations:bad}));rejected++;
 }
 const hall={mode:'hangar',loading:false,sameMission:false,worldReleased:true,terrainReleased:true,
  disposed:{before:{generation:1,truck:{cp:2}},missionDisposed:true,voiceReleased:true,radioReleased:true,viewReleased:true,convoyReleased:true,entries:0}};
 returned(hall);
 for(const mutate of [r=>r.terrainReleased=false,r=>r.disposed.voiceReleased=false]){
  const bad=structuredClone(hall);mutate(bad);assert.throws(()=>returned(bad));rejected++;
 }
 return {status:'PASS',negativeControls:rejected,boundary:'Synthetic checker controls only; no Runtime launched'};
}
module.exports={checkpoints,preparations,pause,returned,selfTest};
if(require.main===module)console.log(JSON.stringify(selfTest()));

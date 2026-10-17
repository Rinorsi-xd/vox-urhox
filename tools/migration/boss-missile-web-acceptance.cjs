'use strict';
const assert=require('node:assert/strict');
function impacts(state){
 assert.equal(state.sameMission,true);assert.equal(state.story.id,'s5');
 const setup=state.setup;assert(setup);assert.equal(setup.mission,'s5');assert.equal(setup.index,2);assert.equal(setup.bossAlive,true);
 assert(setup.bossParts>2000);assert.equal(setup.flow,'fight');assert.equal(setup.authoredOutsideAbsent,true);
 assert.equal(setup.wrappersRestored,true);assert.equal(setup.finalMissiles,0);assert.equal(setup.time,setup.afterTime);
 const cases=state.cases;assert.equal(cases.length,3);assert.deepEqual(cases.map(r=>r.name),['player-impact','stronger-impact','distant-miss']);
 assert(cases.every(r=>r.frame===cases[0].frame),'Atomic same-frame production consumers');
 for(const [i,r]of cases.entries()){
  assert.equal(r.before.alive,true);assert.equal(r.after.alive,true);assert.equal(r.missilesBefore,0);assert.equal(r.enqueued,1);assert.equal(r.remaining,0);
  assert.equal(r.fxCalls,1);assert.equal(r.attackerCleared,true);
  assert.equal(r.hitDelta,i<2?1:0);assert.equal(r.explodeCalls,i<2?1:0);assert.equal(r.flushCalls,i<2?1:0);
  assert.equal(r.traumaBefore,[0,.8,0][i]);assert(Math.abs(r.traumaAfter-[.35,.8,0][i])<1e-9);
  assert.equal(r.offset,i<2?0:50);
  if(i<2){
   assert(r.dealt>0,'Real player explosion must apply nonzero damage');assert.equal(r.explosion.attackerIsBoss,true);
   assert.equal(r.explosion.damage,5);assert.equal(r.explosion.radius,7.5);
   const roof=r.rays.find(ray=>ray.direction[1]===1&&ray.length===90);assert(roof);assert.equal(roof.excludesPlayer,true);
   assert(r.rays.some(ray=>ray.direction[1]!==1),'Real line-of-sight ray must execute');
  }
 }
 assert.equal(cases[1].hitsBefore,cases[0].hitsAfter);assert.equal(cases[2].hitsBefore,cases[1].hitsAfter);
 return {status:'PASS_CONTROLLED_BOSS_PROJECTILE_CONSUMERS',cases:3};
}
function returned(state){
 assert.equal(state.mode,'hangar');assert.equal(state.trial,false);assert.equal(state.loading,false);assert.equal(state.releaseWaiting,false);
 assert.equal(state.sameMission,false);assert.equal(state.worldReleased,true);assert.equal(state.terrainReleased,true);
 for(const field of ['mission','boss','voice','radio','view'])assert.equal(state.disposed[field],true,field);
 assert.equal(state.disposed.entries,0);return {status:'PASS_REAL_MENU_RETURN_DISPOSAL'};
}
function selfTest(){
 const cases=['player-impact','stronger-impact','distant-miss'].map((name,i)=>({name,frame:40,before:{alive:true},after:{alive:true},
  missilesBefore:0,enqueued:1,remaining:0,fxCalls:1,attackerCleared:true,hitDelta:i<2?1:0,explodeCalls:i<2?1:0,flushCalls:i<2?1:0,
  traumaBefore:[0,.8,0][i],traumaAfter:[.35,.8,0][i],offset:i<2?0:50,dealt:i<2?5:0,hitsBefore:Math.min(i,2),hitsAfter:Math.min(i+1,2),
  explosion:{attackerIsBoss:true,damage:5,radius:7.5},rays:[{direction:[0,-1,0],length:1},{direction:[0,1,0],length:90,excludesPlayer:true}]}));
 const sample={sameMission:true,story:{id:'s5'},setup:{mission:'s5',index:2,bossAlive:true,bossParts:2227,flow:'fight',authoredOutsideAbsent:true,wrappersRestored:true,finalMissiles:0,time:10,afterTime:10},cases};
 impacts(sample);let rejected=0;
 for(const mutate of [s=>s.cases.pop(),s=>{s.cases[0].traumaAfter=0},s=>{s.cases[1].traumaAfter=.35},s=>{s.cases[2].traumaAfter=.35},
  s=>{s.cases[0].dealt=0},s=>{s.cases[0].rays=[]},s=>{s.setup.wrappersRestored=false},s=>{s.cases[0].remaining=1},s=>{s.cases[1].frame++},s=>{s.setup.authoredOutsideAbsent=false}]){
  const invalid=structuredClone(sample);mutate(invalid);assert.throws(()=>impacts(invalid));rejected++;
 }
 const hall={mode:'hangar',trial:false,loading:false,releaseWaiting:false,sameMission:false,worldReleased:true,terrainReleased:true,
  disposed:{mission:true,boss:true,voice:true,radio:true,view:true,entries:0}};returned(hall);
 for(const mutate of [s=>{s.terrainReleased=false},s=>{s.disposed.boss=false},s=>{s.releaseWaiting=true}]){const invalid=structuredClone(hall);mutate(invalid);assert.throws(()=>returned(invalid));rejected++}
 return {status:'PASS',rejected,boundary:'Synthetic acceptance controls; no actual Runtime or browser'};
}
module.exports={impacts,returned,selfTest};
if(require.main===module)console.log(JSON.stringify(selfTest()));

const assert=require('node:assert/strict');

async function finishMvp({key,dump,wait}){
 const prepared=await wait(s=>!!(s.battle?.mvp?.active||s.battle?.mvp?.done||s.battle?.mvp?.failed),'MVP resource preparation');
 const snapshots=[structuredClone(prepared.battle.mvp)];
 const healthy=s=>assert(!s.battle?.mvp?.failed,'Production MVP preparation failed');
 healthy(prepared);
 if(!prepared.battle.mvp.done){
  await key('Space');const first=await dump();healthy(first);snapshots.push(structuredClone(first.battle.mvp));
  assert(first.battle.mvp.done||first.battle.mvp.t>=7.1,'First Space reaches MVP title or starts continuation');
  if(!first.battle.mvp.done&&first.battle.mvp.finishing==null){await key('Space');const second=await dump();healthy(second);snapshots.push(structuredClone(second.battle.mvp));assert(second.battle.mvp.done||second.battle.mvp.finishing!=null,'Second Space begins MVP continuation');}
  const ended=await wait(s=>s.battle?.mvp?.done||s.battle?.mvp?.failed,'MVP continuation fade');healthy(ended);snapshots.push(structuredClone(ended.battle.mvp));
 }
 await wait(s=>Array.isArray(s.widgets)&&s.widgets.some(w=>w.text==='再来一局'&&!w.disabled&&w.rect?.length===4&&w.rect.every(Number.isFinite)&&w.rect[2]>0&&w.rect[3]>0),'result button');
 return snapshots;
}

function assertNewRoster(previous,next){
 assert(previous.length>0,'Previous match has bot roster');assert.equal(next.length,previous.length,'Rematch keeps configured bot count');
 assert(next.every(name=>typeof name==='string'&&name.length>0),'Rematch names exist');
 assert.equal(new Set(next).size,next.length,'Rematch names are unique');
 const old=new Set(previous);assert(next.every(name=>!old.has(name)),'Rematch excludes previous roster through recent-name pool');
}
module.exports={finishMvp,assertNewRoster};

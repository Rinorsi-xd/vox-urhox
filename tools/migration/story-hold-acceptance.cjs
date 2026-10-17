const assert=require('node:assert/strict');

function create(level){
 const hold=level.steps.find(s=>s.kind==='hold');
 assert(level.id==='s3'&&hold&&hold.duration===120,'Frozen S3 hold contract');
 return {result:'NOT_REACHED',steps:[],choices:{},inputs:[],attempts:[],duration:hold.duration,par:level.par,
  expectedOptions:{surrender:3,lunch:2},waves:hold.beats.filter(b=>b.spawn).map(b=>({time:b.t,count:b.spawn.length})),
  waveIdentity:{result:'OPEN',reason:'Snapshot enemy counts cannot identify individual authored wave spawns.'},
  boundary:'Actual public input and mission snapshots only. Complete hold, choices, pickup and grade are required; wave identity, visuals, audio and performance remain separate.'};
}
function option(run,choice,wallMs){
 const index=run.expectedOptions[choice.id],seen=run.choices[choice.id];
 assert(seen&&index&&choice.options?.[index-1],'Observed authored S3 non-default choice');
 assert(wallMs>=seen.seenAt&&wallMs-seen.seenAt<(choice.timeout??14)*1000,'S3 input precedes actual choice timeout');
 run.inputs.push({id:choice.id,index,key:String(index),wallMs});return String(index);
}
function grade(run,s){
 const n=s.stats;let result=n.deaths===0&&n.fails===0&&s.time<run.par[0]?'S':n.deaths+n.fails<=1&&s.time<run.par[1]?'A':'B';
 if(n.shield<.3&&result==='S')result='A';return result;
}
function observe(run,s,wallMs,check){
 assert(s.id==='s3','Actual S3 mission');
 if(s.step&&!run.steps.includes(s.step))run.steps.push(s.step);
 if(s.choice){
  if(run.activeChoice!==s.choice.id)run.choices[s.choice.id]={seenAt:wallMs,timeout:s.choice.timeout};
  run.activeChoice=s.choice.id;
 }else run.activeChoice=null;
 for(const [id,c]of Object.entries(run.choices))if(Object.hasOwn(s.flags||{},id))c.flag=s.flags[id];
 if(s.step==='hold'&&s.hold&&!s.failing){
  const h=s.hold;assert(Number.isFinite(h.left)&&Number.isFinite(h.energy),'Finite actual hold clock and energy');
  let a=run.attempts.at(-1);
  if(!a||s.stats.fails!==a.fails){a={fails:s.stats.fails,startTime:s.time,firstLeft:h.left,minLeft:h.left,firstEnergy:h.energy};run.attempts.push(a);}
  a.minLeft=Math.min(a.minLeft,h.left);a.lastEnergy=h.energy;a.lastTime=s.time;run.result='HOLDING';
 }
 if(s.step==='coupon'&&!run.coupon){
  check(Array.isArray(s.target)&&s.target.length===3&&s.target.every(Number.isFinite),'S3 real coupon drop has a finite target');
  check(s.stats.intel===0,'S3 coupon is observed before pickup');
  run.coupon={time:s.time,target:[...s.target],shield:s.stats.shield};
 }
 if(!s.finished)return false;
 check(['gate','parley','hold','coupon'].every(id=>run.steps.includes(id)),'S3 naturally traverses all four authored objectives');
 for(const id of ['surrender','lunch']){
  const c=run.choices[id],input=run.inputs.find(i=>i.id===id);
  check(!!c&&!!input&&input.index===run.expectedOptions[id]&&c.flag===input.index-1,'S3 non-default '+id+' input reaches actual story flag');
 }
 const a=run.attempts.at(-1);
 check(!!a&&a.fails===s.stats.fails&&a.firstLeft>=run.duration-2&&a.minLeft<=2,'S3 successful attempt observes the actual hold countdown from start to end');
 check(!!run.coupon&&run.coupon.time-a.startTime>=run.duration-2,'S3 complete hold precedes the actual coupon objective');
 check(s.stats.intel===1,'S3 actually picks up the single authored coupon');
 check(Number.isFinite(s.stats.shield)&&s.stats.shield>0&&s.stats.shield<=1,'S3 result retains a positive actual shield');
 check(Number.isFinite(s.time)&&Number.isInteger(s.stats.deaths)&&Number.isInteger(s.stats.fails),'S3 actual grade inputs are present');
 check(s.grade===grade(run,s),'S3 result grade matches source time/death/retry/shield cap');
 run.result='FUNCTIONAL_PASS';run.final=structuredClone(s);return true;
}
module.exports={create,option,observe,grade};

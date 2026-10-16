// Read-only S2 coverage over real mission snapshots and actual number-key inputs.
const assert=require('node:assert/strict');
function create(level){
 const step=level.steps.find(s=>s.kind==='escort');assert(step&&level.id==='s2','S2 escort data');
 const waves=step.beats.filter(b=>b.spawn).map(b=>({from:b.p,authoredCount:b.spawn.length,maxEnemies:0,blocked:false,samples:0}));
 return {result:'NOT_REACHED',steps:[],choices:{},inputs:[],checkpoints:[],encounterWindows:waves,travel:{first:null,max:0,last:null},
  encounterIdentity:{result:'OPEN',reason:'Progress-window enemy counts cannot identify three separate authored waves; one surviving enemy can appear in every window.'},
  grading:{par:[...(level.par||[420,600])]},expectedOptions:{rate:2,road:3},boundary:'Functional delivery acceptance only. Enemy windows are diagnostics and never close three-wave identity or presentation acceptance. Checkpoint, choices and delivery are actual snapshots. No gameplay state is changed.'};
}
function expectedGrade(par,s){
 const st=s.stats;assert(Number.isFinite(s.time)&&Number.isFinite(st.deaths)&&Number.isFinite(st.fails),'actual grade time and attempt counts');
 let grade=st.deaths===0&&st.fails===0&&s.time<par[0]?'S':st.deaths+st.fails<=1&&s.time<par[1]?'A':'B';
 const cap=st.truckHp<.35?'B':st.truckHp<.7?'A':null;
 if(cap&&'SAB'.indexOf(grade)<'SAB'.indexOf(cap))grade=cap;
 return grade;
}
function option(run,choice,wallMs){
 const index=run.expectedOptions[choice.id];assert(index&&choice.options?.[index-1],'authored non-default S2 option');
 const record=run.choices[choice.id];assert(record,'choice must be observed before input');
 assert(wallMs-record.seenAt<choice.timeout*1000,'real number key is sent before authored wall timeout');
 run.inputs.push({id:choice.id,index,key:String(index),wallMs});return String(index);
}
function observe(run,s,wallMs,check){
 assert(s.id==='s2','actual S2 mission');
 if(s.step&&!run.steps.includes(s.step))run.steps.push(s.step);
 if(s.choice){
  if(run.activeChoice!==s.choice.id)run.choices[s.choice.id]={seenAt:wallMs,prompt:s.choice.prompt,timeout:s.choice.timeout,options:s.choice.options.map(o=>o.label)};
  run.activeChoice=s.choice.id;
 }else run.activeChoice=null;
 for(const [id,record]of Object.entries(run.choices))if(s.flags&&Object.hasOwn(s.flags,id))record.flag=s.flags[id];
 const truck=s.truck;
 if(truck){
  assert(Number.isFinite(truck.d)&&Number.isFinite(truck.total)&&truck.total>0,'finite real convoy path');
  run.travel.first??=truck.d;run.travel.max=Math.max(run.travel.max,truck.d);run.travel.last=truck.d;run.travel.total=truck.total;
  if(!run.checkpoints.includes(truck.cp))run.checkpoints.push(truck.cp);
  const p=truck.d/truck.total;
  for(let i=0;i<run.encounterWindows.length;i++){
   const w=run.encounterWindows[i],end=run.encounterWindows[i+1]?.from??1.000001;
   if(s.step==='convoy'&&p>=w.from&&p<end){w.samples++;w.maxEnemies=Math.max(w.maxEnemies,s.enemies||0);w.blocked||=truck.blocked===true;}
  }
 }
 if(!s.finished)return false;
 check(run.steps.includes('meet')&&run.steps.includes('convoy'),'S2 naturally observes meet and escort objectives');
 for(const id of ['rate','road']){
  const input=run.inputs.find(i=>i.id===id),choice=run.choices[id];
  check(!!input&&!!choice&&input.index===run.expectedOptions[id]&&choice.flag===input.index-1,'S2 actual non-default '+id+' key is reflected by source flags');
 }
 check(run.checkpoints.includes(1)&&run.checkpoints.includes(2),'S2 observes both actual convoy checkpoint states');
 check(!!truck&&run.travel.first===0&&run.travel.max>=truck.total-.001&&truck.d>=truck.total-.001,'S2 real convoy travels the authored route from origin to delivery');
 check(s.stats.checkpoints===3&&s.stats.truckHp>0&&s.stats.truckHp<=1,'S2 delivered transport has real final checkpoint and remaining health');
 const wanted=expectedGrade(run.grading.par,s);
 check(s.grade===wanted,'S2 actual result grade matches frozen H5 time, deaths, fails and truck HP formula');
 run.grading.expected=wanted;run.grading.actual=s.grade;run.grading.time=s.time;
 if(Object.hasOwn(truck,'hp')){
  check(Number.isFinite(truck.hp)&&Math.abs(truck.hp-s.stats.truckHp)<1e-6,'S2 final result truck HP matches actual convoy health');
  run.grading.truckHpCrosscheck={result:'PASS',actual:truck.hp,stats:s.stats.truckHp};
 }else run.grading.truckHpCrosscheck={result:'UNOBSERVED',reason:'Actual convoy HP field is absent; no value was inferred.'};
 run.result='FUNCTIONAL_PASS';run.resultStats=structuredClone(s.stats);run.grade=s.grade;return true;
}
module.exports={create,option,observe,expectedGrade};

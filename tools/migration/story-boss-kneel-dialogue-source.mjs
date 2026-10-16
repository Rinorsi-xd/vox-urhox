import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const context=vm.createContext({THREE:{Vector3:class{}},Blueprint:class{},buildDrillTank:()=>({toJSON:()=>({})}),Math:Object.create(Math)});
const source={branch:baseline.branch,commit:baseline.commit,files:{}};
for(const [path,name] of [['three/src/battle/storyBoss.js','FoxBoss'],['shared/story/level5.js','LEVEL5']]){
  const bytes=fs.readFileSync(`${baseline.snapshot}/${path}`);
  const hash=crypto.createHash('sha256').update(bytes).digest('hex');
  if(hash!==baseline.files[path].sha256)throw new Error(`Frozen source drift: ${path}`);
  source.files[path]=hash;
  vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')}\nglobalThis.${name}=${name};})()`,context);
}
const lines=context.LEVEL5.steps.find(s=>s.kind==='boss').lines;
function run(test){
  const calls=[];let draws=0;
  const boss=Object.create(context.FoxBoss.prototype);
  Object.assign(boss,{L:lines,hp:100,kneels:test.initialKneels??1,nodes:Array.from({length:4},()=>({broken:false})),
    m:{stats:{},drive:{player:{}},hud:{retitle(){},banner(){},say(l,urgent,append){calls.push({lines:l,urgent,append});}}},
    _cancelAttacks(){},snap(){}});
  const frames=[];
  for(const step of test.steps){
    boss.phase=step.phase;boss.time=step.time;boss.state='fight';boss._storyUntil=step.storyUntil;
    boss.m.hud.talking=step.talking;context.Math.random=()=>{draws++;return step.random;};
    boss._kneel();
    frames.push({selected:boss._lastKneelLine,calls:structuredClone(calls),draws,storyUntil:boss._storyUntil,kneels:boss.kneels});
  }
  return frames;
}
const cases=[];
function add(name,steps,initialKneels=1){const test={name,steps,initialKneels};cases.push({test,expected:run(test)});}
const step=(phase,random,other={})=>({phase,random,time:10,storyUntil:0,talking:false,...other});
for(const phase of [1,2,3])for(const random of [0,.249999,.25,.333333,.333334,.499999,.5,.666666,.666667,.749999,.75,.999999]){
  for(const [talking,storyUntil] of [[false,0],[true,0],[false,9.999999],[false,10],[false,10.000001],[true,20]]){
    add(`phase-${phase}/rng-${random}/talk-${talking}/until-${storyUntil}`,[step(phase,random,{talking,storyUntil})]);
  }
}
for(const phase of [1,2,3])for(const random of [0,.34,.67,.99]){
  add(`no-consecutive-repeat-${phase}-${random}`,Array.from({length:8},(_,i)=>step(phase,random,{time:10+i})));
}
add('phase-switch-reference-identity',[step(2,.99),step(3,.99),step(2,.99),step(1,.99),step(1,.99)]);
add('suppressed-bark-still-remembers',[step(2,.99,{talking:true}),step(2,.99),step(2,.99,{storyUntil:20}),step(2,.99)]);
add('first-kneel-authored-lines-unchanged',[step(1,0)],0);
console.log(JSON.stringify({source,cases,authoredLines:lines}));

import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const context=vm.createContext({THREE:{Vector3:class{}},Blueprint:class{},buildDrillTank:()=>({toJSON:()=>({})}),radio(){}});
const source={commit:baseline.commit,files:{}};
for(const [path,names]of [['three/src/battle/storyBoss.js',['FoxBoss','BOSS_KIND']],['shared/story/level5.js',['LEVEL5']]]){
 const bytes=fs.readFileSync(`${baseline.snapshot}/${path}`),hash=crypto.createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[path].sha256)throw Error('Frozen source drift: '+path);
 source.files[path]=hash;
 vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')}\n${names.map(n=>`globalThis.${n}=${n};`).join('\n')}})()`,context);
}
const step=context.LEVEL5.steps.find(s=>s.kind==='boss');
function run(test){
 const calls=[];let cinematic=false;
 const boss=Object.create(context.FoxBoss.prototype);
 const m={bossFlow:{stage:'fight',t:1},stats:{},drive:{},ground:()=>0,
  hud:{talking:test.talking,queue:['stale battle line'],retitle(){},banner(){},
   comms:{skipLine(){}},say(lines,urgent,append){calls.push({lines,urgent,append});}}};
 Object.assign(boss,{L:step.lines,s:step,state:'dying',time:10,_storyUntil:test.until,unit:{pos:[0,0,0]},m,
  update(){},cine(v){cinematic=v;},snap(){},cockpit:()=>[0,5,0],look(){},group:{remove(){}}});m.boss=boss;
 context.BOSS_KIND.update(m,step,0);
 const atDefeat={calls:structuredClone(calls),storyUntil:boss._storyUntil,stage:m.bossFlow.stage,cinematic};
 const finishes=[];
 if(test.finish==='skip')m.bossFlow.skip=true;
 else{
  m.bossFlow.t=20;m.bossFlow.open=0;m.bossFlow.pod={};
  m.bossFlow.truck={t:7.99,from:[0,0,0],to:[0,0,0],view:{setPose(){}}};
 }
 m.hud.talking=false;
 for(const dt of [0,.02,.02]){
  const done=context.BOSS_KIND.update(m,step,dt);
  finishes.push({done,state:boss.state,stage:m.bossFlow.stage,cinematic});
 }
 return {atDefeat,finishes};
}
const cases=[];
for(const until of [0,10,10.000001,40])for(const talking of [false,true])for(const finish of ['normal','skip']){
 const test={name:`until-${until}/talk-${talking}/${finish}`,until,talking,finish};cases.push({test,expected:run(test)});
}
console.log(JSON.stringify({source,downLines:step.lines.down,cases}));

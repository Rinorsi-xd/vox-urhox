import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const context=vm.createContext({THREE:{Vector3:class{}},Blueprint:class{},buildDrillTank:()=>({toJSON:()=>({})}),radio(){},setTimeout(){}});
const source={commit:baseline.commit,files:{}};
for(const [path,names]of [['three/src/battle/storyBoss.js',['FoxBoss','BOSS_KIND']],['shared/story/level5.js',['LEVEL5']]]){
 const bytes=fs.readFileSync(`${baseline.snapshot}/${path}`),hash=crypto.createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[path].sha256)throw Error('Frozen source drift: '+path);
 source.files[path]=hash;
 vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')}\n${names.map(n=>`globalThis.${n}=${n};`).join('\n')}})()`,context);
}
function run(test){
 const drive={trauma:test.trauma},flow={stage:test.stage,t:0},boss=Object.create(context.FoxBoss.prototype);
 const m={bossFlow:flow,boss,drive,ground:()=>0,hud:{talking:false,banner(){},retitle(){}}};
 Object.assign(boss,{m,phase:1,state:'fight',cool:{},L:{},unit:{pos:[0,0,0]},at:{enter:[0,0,0]},
  update(){},look(){},cine(){},talk(){},_cancelAttacks(){},say(){}});
 const frames=[];
 for(const s of test.steps){
  if(s.reset!==undefined)drive.trauma=s.reset;
  if(test.stage==='introCine'){flow.skip=!!s.skip;context.BOSS_KIND.update(m,context.LEVEL5.steps.find(s=>s.kind==='boss'),s.dt);}
  else boss._phase(s.phase);
  frames.push({trauma:drive.trauma??0,shook:!!flow.shook,stage:flow.stage,phase:boss.phase});
 }
 return frames;
}
const cases=[];
const add=test=>cases.push({test,expected:run(test)});
for(const trauma of [0,.3,.7,1]){
 add({name:'intro-boundaries-'+trauma,stage:'introCine',trauma,steps:[{dt:1.2},{dt:.000001},{dt:.1,reset:0},{dt:7}]});
 add({name:'intro-skip-early-'+trauma,stage:'introCine',trauma,steps:[{dt:.1,skip:true}]});
 add({name:'intro-stall-'+trauma,stage:'introCine',trauma,steps:[{dt:9}]});
 add({name:'phase-'+trauma,stage:'fight',trauma,steps:[{phase:2},{phase:2,reset:0},{phase:3},{phase:2,reset:.2}]});
}
console.log(JSON.stringify({source,cases}));

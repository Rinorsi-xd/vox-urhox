import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
let wall=0,queue=[],serial=0,log=[];
const context=vm.createContext({THREE:{Vector3:class{}},BOSS_KIND:{},
  radio:cue=>{if(cue==='alert')log.push({kind:'radio',cue});},
  setTimeout:(callback,delay)=>{const timer={callback,at:wall+delay,id:++serial};queue.push(timer);return timer;},
  clearTimeout:timer=>{if(timer)timer.cancelled=true;}});
const files={};
for(const [relative,name] of [['three/src/battle/storyKinds.js','KINDS'],['three/src/battle/storyMission.js','StoryMission']]){
  const bytes=fs.readFileSync(`${baseline.snapshot}/${relative}`),hash=crypto.createHash('sha256').update(bytes).digest('hex');
  if(hash!==baseline.files[relative].sha256)throw Error(`Frozen source drift: ${relative}`);
  files[relative]=hash;
  vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')}\nglobalThis.${name}=${name};})()`,context);
}
const choice={id:'test',prompt:'Choose',timeout:1,default:1,options:[{label:'A',reply:[['nono','alpha']]},{label:'B',reply:[['nono','beta']]}]};
const hold={kind:'hold',pos:[0,2,0],retryLines:[['nono','retry']],beats:[]};
const escort={kind:'escort',path:[[0,0],[0,100]],retryLines:[['yun','retry']],beats:[]};
const cases=[
 {name:'hold-retry-paused',kind:'hold',op:'fail',actions:[{wall:0},{wall:2999},{wall:3000},{wall:3400}]},
 {name:'escort-retry-paused',kind:'escort',op:'fail',actions:[{wall:0},{wall:2999},{wall:3000}]},
 {name:'failure-duplicate',kind:'hold',op:'fail',repeat:true,actions:[{wall:0},{wall:3000}]},
 {name:'leaving-suppresses-retry',kind:'hold',op:'fail',actions:[{wall:0},{wall:2999,reason:'quit'},{wall:3000}]},
 {name:'choice-paused',kind:'hold',op:'ask',actions:[{wall:0},{wall:999},{wall:1000},{wall:2000}]},
 {name:'choice-explicit-before-timeout',kind:'hold',op:'ask',actions:[{wall:0},{wall:999,pick:0},{wall:1000}]},
 {name:'beat-ask-paused',kind:'hold',op:'beat',actions:[{wall:0},{wall:299},{wall:300},{wall:1299},{wall:1300}]},
];
function run(test){
  wall=10000;queue=[];serial=0;log=[];
  let choose;
  const step=structuredClone(test.kind==='escort'?escort:hold);
  if(test.op==='beat')step.beats=[{t:0,ask:choice}];
  const m=Object.create(context.StoryMission.prototype);
  Object.assign(m,{level:{steps:[step]},i:0,time:10,stepT:0,progress:.8,beatsFired:new Set(),stats:{fails:0},failing:false,
    drive:{player:{alive:true}},truck:{d:50,v:4,hp:.2,cpD:10,cpHp:.8},truckPath:{P:[[0,0,0],[0,0,100]],L:[0,100],total:100},
    hud:{talking:false,choosing:false,banner:(kick,title,sub,kind,ms)=>log.push({kind:'banner',kick,title,sub,tone:kind,ms}),
      say:(lines,urgent=false)=>{if(lines?.length)log.push({kind:'say',lines,urgent});},
      choice(spec,callback){choose=callback;this.choosing=true;log.push({kind:'choice',prompt:spec.prompt});},
      pick(index){if(this.choosing){this.choosing=false;choose(index);}}},
    clearEnemies:()=>log.push({kind:'clearEnemies'}),
    _place:at=>log.push({kind:'place',at}),
    _go:index=>log.push({kind:'objective',index}),flags:{}});
  if(test.op==='fail'){m.fail('failed',[['nono','failure']]);if(test.repeat)m.fail('duplicate',[['nono','wrong']]);}
  if(test.op==='ask')m.ask(choice);
  if(test.op==='beat')m._beats(step,.1);
  const frames=[];
  for(const action of test.actions){
    wall=10000+action.wall;
    if(action.reason)m.reason=action.reason;
    if(action.pick!==undefined)m.hud.pick(action.pick);
    const due=queue.filter(timer=>!timer.cancelled&&timer.at<=wall).sort((a,b)=>a.at-b.at||a.id-b.id);
    queue=queue.filter(timer=>timer.cancelled||timer.at>wall);
    for(const timer of due)timer.callback();
    frames.push({log:structuredClone(log),failing:!!m.failing,choice:m.hud.choosing,flag:m.flags.test??null,simTime:m.time});
  }
  return frames;
}
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,files},choice,hold,escort,cases:cases.map(test=>({test,expected:run(test)}))}));

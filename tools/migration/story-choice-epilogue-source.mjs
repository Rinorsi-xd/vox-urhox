import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
let now=0,serial=0,timers=[];
const stored=new Map();
let play;
const context=vm.createContext({THREE:{Vector3:class{}},KINDS:{},radio(){},performance:{now:()=>now*1000},
  localStorage:{getItem:key=>stored.get(key),setItem:(key,value)=>stored.set(key,value)},
  playEpilogue:(...args)=>play(...args),
  setTimeout:(fn,ms)=>{const id=++serial;timers.push({id,at:now+ms/1000,fn});return id;},
  clearTimeout:id=>{timers=timers.filter(t=>t.id!==id);}});
const source={branch:baseline.branch,commit:baseline.commit,files:{}};
for(const [path,name] of [['three/src/battle/storyMission.js','StoryMission'],
  ['shared/story/level2.js','LEVEL2'],['shared/story/level3.js','LEVEL3'],
  ['shared/story/level4.js','LEVEL4']]){
  const bytes=fs.readFileSync(`${baseline.snapshot}/${path}`);
  const hash=crypto.createHash('sha256').update(bytes).digest('hex');
  if(hash!==baseline.files[path].sha256)throw Error(`Frozen source drift: ${path}`);
  source.files[path]=hash;
  vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')}\nglobalThis.${name}=${name};})()`,context);
}
function advance(to){
  while(true){timers.sort((a,b)=>a.at-b.at||a.id-b.id);const next=timers[0];if(!next||next.at>to)break;
    timers.shift();now=next.at;next.fn();}
  now=to;
}
const choiceCases=[];
for(const level of [context.LEVEL2,context.LEVEL3,context.LEVEL4]){
  for(const step of level.steps){
    const authored=[...(step.ask?[{spec:step.ask}]:[]),...(step.beats||[]).filter(b=>b.ask).map(beat=>({spec:beat.ask,beat}))];
    for(const {spec,beat} of authored){
      now=0;timers=[];
      let menu=null,callback,choicesOpened=0;
      const replies=[];
      const m=Object.create(context.StoryMission.prototype);
      Object.assign(m,{level:{steps:[step]},i:0,begun:true,finished:false,deadAt:0,time:0,
        stepT:beat?.t??0,progress:beat?.p??0,beatsFired:new Set(),flags:{},
        drive:{player:{alive:false,pos:[0,0,0]}},view:{update(){}},fx:{update(){}},
        hud:{talking:false,choosing:false,update(){},dead(){},marker(){},pips(){},
          say(lines){replies.push(structuredClone(lines));},
          choice(data,fn){choicesOpened++;menu=data;callback=fn;this.choosing=true;},
          pick(index){this.choosing=false;menu=null;callback(index);}}});
      m._beats(beat?{beats:[beat]}:{ask:spec},.6);
      const frames=[];
      const times=beat?[.299,.301,spec.timeout+.25,spec.timeout+.35,spec.timeout+.5]:[0,spec.timeout-.05,spec.timeout+.05,spec.timeout+.2];
      let last=0;
      for(const to of times){
        m.time=last;m.deadAt=to-.1;
        advance(to);
        m.update(to-last);last=to;
        frames.push({time:to,choice:menu?.prompt??null,flag:m.flags[spec.id]??null,
          reply:replies.at(-1)??null,choicesOpened,sayEvents:replies.length,stepT:m.stepT});
      }
      choiceCases.push({level:level.id,step:step.id,id:spec.id,delayed:!!beat,times,frames});
    }
  }
}
const epilogueCases=[];
for(const prior of [0,5,6])for(const finish of [false,true]){
  stored.clear();if(prior)stored.set(`vox.story.epilogue.s5.${prior}`,'1');
  let starts=0,exits=0,done;
  play=(_data,callback)=>{starts++;done=callback;};
  const m=Object.create(context.StoryMission.prototype);
  Object.assign(m,{level:{id:'s5',epilogue:{version:6}},epilogueKey:'vox.story.epilogue.s5.6',
    epiloguePending:!stored.has('vox.story.epilogue.s5.6'),drive:{exit(){exits++;}}});
  const sample=()=>({starts,exits,watched:stored.has('vox.story.epilogue.s5.6')});
  m.leave('back');const first=sample();m.leave('back');const repeat=sample();
  if(finish&&done)done();const final=sample();
  const second=Object.create(context.StoryMission.prototype);
  Object.assign(second,{level:m.level,epilogueKey:m.epilogueKey,epiloguePending:!stored.has(m.epilogueKey),drive:m.drive});
  second.leave('back');
  epilogueCases.push({prior,finish,first,repeat,final,reenter:sample()});
}
console.log(JSON.stringify({source,choiceCases,epilogueCases}));

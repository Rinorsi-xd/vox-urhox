import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const relative='three/src/battle/storyBoss.js';
const bytes=fs.readFileSync(`${baseline.snapshot}/${relative}`);
const sha256=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha256!==baseline.files[relative].sha256)throw new Error('Frozen Boss source drift');
const context=vm.createContext({THREE:{Vector3:class{}}});
vm.runInContext(bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.FoxBoss=FoxBoss;',context);

function Run(test){
  const control=test.control===false?null:{};
  if(control&&test.initial!==null)control.kneel=test.initial;
  const boss=Object.create(context.FoxBoss.prototype);
  let allies=null,vehicle=null;
  Object.assign(boss,{m:{drive:{player:{},sim:{fx:[]}}},at:{enter:[0,0,0]},
    unit:{pos:[0,0,0],vehicle:{mechControl:control,yaw:0,body:{angvel:()=>({y:0})}},
      weapons:{groups:[]},flush(){},step(){vehicle=control?.kneel??null;},fire(){return [];}},
    _stepAllies(){allies=control?.kneel??null;},_focus(){return null;},cockpit(){return [0,10,0];},_missiles(){},_fly(){}});
  const frames=[];
  for(const step of test.steps){
    boss.state=step.state;boss.beforeStep(step.dt);
    frames.push({kneel:control?.kneel??null,atAllies:allies,atVehicle:vehicle});
  }
  return frames;
}
const states=['idle','intro','standoff','fight','stomp','sweep','lanes','ult','recover','slamCrouch','slamAir','stuck','kneel','rise','barrage','transition','dying','dead','ending'];
const cases=[];
for(const state of states)for(const initial of [null,0,.45,1])for(const dt of [0,1/120,1/60,.4]){
  const test={name:`${state}/${initial}/${dt}`,initial,steps:[{state,dt}]};cases.push({test,expected:Run(test)});
}
for(const control of [false,true]){
  const steps=[];
  for(const state of ['fight','kneel','rise','fight','dying','dead','ending']){
    for(let i=0;i<30;i++)steps.push({state,dt:1/60});
  }
  const test={name:`full-transition-control-${control}`,control,initial:null,steps};
  cases.push({test,expected:Run(test)});
}
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,path:relative,sha256},cases}));

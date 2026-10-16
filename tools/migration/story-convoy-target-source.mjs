import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const relative='three/src/battle/storyMission.js';
const bytes=fs.readFileSync(`${baseline.snapshot}/${relative}`);
const sha256=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha256!==baseline.files[relative].sha256)throw new Error('Frozen storyMission source drift');
const code=bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'')
  .replace('export class StoryMission','class StoryMission')+'\nglobalThis.StoryMission=StoryMission;';
const context={THREE:{Vector3:class{}},KINDS:{}};
vm.createContext(context);vm.runInContext(code,context);
const scenarios=[];
for(const alive of [false,true])for(const target of ['default','player','truck'])
for(const convoy of [false,true])for(const trigger of [false,true]){
  const sample={alive,target,convoy,trigger,driverCalls:0,fireActive:0,throttle:0,handbrake:true,victim:null};
  const player={alive,pos:[11,2,13],health:1};
  const enemy={alive:true,pos:[1,2,3],flush(){},step(_dt,command){sample.throttle=command.throttle;sample.handbrake=command.handbrake;},
    fire(_dt,command){if(command.firing)sample.fireActive++;return []}};
  const mission=Object.create(context.StoryMission.prototype);
  mission.level={steps:[]};mission.drive={player,sim:{time:0,fx:[]}};
  if(convoy)mission.truck={pos:[31,4,37]};
  mission._doomed=()=>false;
  const normalized=target==='default'?'player':target;
  mission.enemies=new Map([[enemy,{target:normalized,driver:{step(_dt,env){
    sample.driverCalls++;sample.victim=env.target.radius===4?'truck':'player';
    return {command:{throttle:.75,steer:.2,handbrake:false},aim:[41,5,43],trigger};
  }}}]]);
  mission.beforeStep(.016);scenarios.push(sample);
}
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,path:relative,sha256},scenarios}));

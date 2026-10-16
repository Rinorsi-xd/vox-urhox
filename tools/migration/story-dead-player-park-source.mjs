import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const files={};
const context={THREE:{Vector3:class{}},KINDS:{},applyRotorWeapons(){context.sample.rotorWeapons++;}};
vm.createContext(context);
function load(relative,name){
 const bytes=fs.readFileSync(`${baseline.snapshot}/${relative}`),sha256=crypto.createHash('sha256').update(bytes).digest('hex');
 if(sha256!==baseline.files[relative].sha256)throw Error(`Frozen source drift: ${relative}`);
 files[relative]=sha256;
 const code=bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'');
 return vm.runInContext(`(()=>{${code}\nreturn ${name};})()`,context);
}
const Mission=load('three/src/battle/storyMission.js','StoryMission');
const Unit=load('shared/combat/carUnit.js','CarUnit');
const cases=[];
for(const alive of [false,true])for(const target of ['default','player','truck'])for(const convoy of [false,true])for(const trigger of [false,true]){
 const sample={alive,target,convoy,trigger,driver:0,physics:0,rotors:0,rotorAim:null,rotorWeapons:0,weapons:0,firing:0,fx:0,throttle:null,handbrake:null};context.sample=sample;
 const player={alive,pos:[11,2,13],health:1};
 const enemy=Object.create(Unit.prototype);
 Object.defineProperty(enemy,'pos',{value:[1,2,3]});
 enemy.alive=true;enemy.flush=()=>{};enemy._regenStructure=()=>{};
 enemy.vehicle={rotors:[],body:{translation:()=>({x:1,y:2,z:3}),linvel:()=>({x:0,y:0,z:0}),rotation:()=>({})},
  step(command){sample.physics++;sample.throttle=command.throttle;sample.handbrake=command.handbrake;},
  stepRotors(command){sample.rotors++;sample.rotorAim=command.aim??null;}};
 enemy.env={};enemy.weapons={drill:{controlsBody:false},fx:[{type:'fixture'}],step(_dt,command){sample.weapons++;if(command.firing)sample.firing++;}};
 enemy.weaponEnv={};
 const mission=Object.create(Mission.prototype);mission.level={steps:[]};mission.drive={player,sim:{time:0,fx:[]}};
 if(convoy)mission.truck={pos:[31,4,37]};mission._doomed=()=>false;
 mission.enemies=new Map([[enemy,{target:target==='default'?'player':target,driver:{step(){sample.driver++;return {command:{throttle:.75,steer:.2,handbrake:false},aim:[41,5,43],trigger};}}}]]);
 mission.beforeStep(.016);sample.fx=mission.drive.sim.fx.length;cases.push(sample);
}
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,files},cases}));

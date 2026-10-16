import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const context={THREE:{Vector3:class{}},KINDS:{}};
const source={branch:baseline.branch,commit:baseline.commit,files:{}};
vm.createContext(context);
for(const [relative,classes] of [
  ['three/src/battle/storyBoss.js',['FoxBoss']],
  ['three/src/battle/storyMission.js',['StoryMission']],
]){
  const bytes=fs.readFileSync(`${baseline.snapshot}/${relative}`);
  const sha256=crypto.createHash('sha256').update(bytes).digest('hex');
  if(sha256!==baseline.files[relative].sha256)throw new Error(`Frozen source drift: ${relative}`);
  source.files[relative]=sha256;
  // Isolate each real source module so its private constants keep module scope.
  const code=bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'');
  vm.runInContext(`(()=>{${code}\n${classes.map(name=>`globalThis.${name}=${name};`).join('\n')}})()`,context);
}
const states=['idle','intro','standoff','fight','stomp','sweep','lanes','ult','recover','slamCrouch','slamAir','stuck','kneel','rise','barrage','transition','dying','dead','ending'];
const drills=(...items)=>items.map(([id,x,alive=true,tag='drill'])=>({id,pos:[x,100,0],alive,tag}));
const nodes=[{pos:[30,3,0],broken:false},{pos:[5,4,0],broken:false}];
const variants=[
  {name:'no-drill'},
  {name:'nearest-unsorted',drills:drills(['far',50],['near',10])},
  {name:'dead-and-wrong-tag',drills:drills(['dead',1,false],['other',2,true,'guard'],['live',40])},
  {name:'drill-inside',drills:drills(['inside',69.999])},
  {name:'drill-boundary',drills:drills(['boundary',70])},
  {name:'drill-outside',drills:drills(['outside',70.001])},
  {name:'drill-tie-first',drills:drills(['first',10],['second',-10])},
  {name:'broken-node',nodes:[{pos:[1,4,0],broken:true},nodes[0]]},
  {name:'all-broken',nodes:nodes.map(n=>({...n,broken:true}))},
  {name:'empty-nodes',nodes:[]},
  {name:'node-tie-last',nodes:[{pos:[5,1,0]},{pos:[-5,2,0]}]},
  {name:'roof-nearest',roofs:[{center:[40,30,0]},{center:[-8,100,0]}],drills:drills(['near',2])},
  {name:'roof-tie-last',roofs:[{center:[8,30,0]},{center:[-8,100,0]}]},
  {name:'already-under-roof',underRoof:true,roofs:[{center:[-8,100,0]}]},
];
const targets=[];
function makeBoss(test,sample){
  const boss=Object.create(context.FoxBoss.prototype);
  const unit={id:'ally',alive:true,health:1,pos:[0,2,0],flush(){},vehicle:{},weapons:{},
    step(_dt,command){sample.throttle=command.throttle;sample.handbrake=command.handbrake;},
    fire(_dt,command){sample.fireCalls++;sample.firing=command.firing;sample.salvo=command.salvo;return []}};
  const mission=Object.create(context.StoryMission.prototype);
  mission.enemies=new Map((test.drills||[]).map(d=>[{...d},{tag:d.tag}]));
  mission.drive={sim:{fx:[]}};
  boss.m=mission;boss.state=test.state;boss.t=test.t;boss.hp=test.hp??1;boss.time=test.elapsed??16;
  boss.unit={id:'boss'};boss.nodes=test.nodes||nodes;
  boss.map={ceilings:test.roofs||[],underRoof:()=>test.underRoof===true,groundAt:()=>7};
  boss.cockpit=()=>[3,12,4];
  boss.allies=[{dead:test.dead?0:null,unit,driver:{step(_dt,env){
    sample.driverCalls++;return {command:{throttle:.75,handbrake:false},aim:env.target.pos,
      trigger:!env.target.radius,salvo:true};
  }}}];
  boss._spawnAlly=()=>sample.spawns++;
  return {boss,unit};
}
function run(test){
  const sample={driverCalls:0,fireCalls:0,firing:false,salvo:false,throttle:0,handbrake:true,spawns:0};
  const {boss,unit}=makeBoss(test,sample);
  if(!test.dead){const target=boss._allyTarget(unit);sample.target=target?{pos:target.pos,passive:!!target.radius,unit:target.unit?.id??null}:null;}
  boss._stepAllies(.016);return sample;
}
for(const state of states)for(const variant of variants){
  const test={state,t:2,...variant};targets.push({test,expected:run(test)});
}
for(const t of [1,1.001])for(const underRoof of [false,true]){
  const test={state:'ult',t,underRoof,roofs:[{center:[-8,100,0]}],name:`ult-charge-${t}-${underRoof}`};
  targets.push({test,expected:run(test)});
}
const respawns=[];
for(const state of states)for(const elapsed of [14.999,15,15.001])for(const hp of [0,1]){
  const test={state,t:2,dead:true,elapsed,hp};respawns.push({test,expected:run(test)});
}
console.log(JSON.stringify({source,targets,respawns}));

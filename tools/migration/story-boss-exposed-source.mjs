import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
let wall=0, timers=[];
const context=vm.createContext({THREE:{Vector3:class{}},Blueprint:class{},buildDrillTank:()=>({toJSON:()=>({})}),
  Math:Object.create(Math),setTimeout:(callback,delay)=>timers.push({callback,at:wall+delay})});
const hashes={};
for(const [path,name] of [['three/src/battle/storyBoss.js','FoxBoss'],['shared/story/level5.js','LEVEL5']]){
  const bytes=fs.readFileSync(`${baseline.snapshot}/${path}`), hash=crypto.createHash('sha256').update(bytes).digest('hex');
  if(hash!==baseline.files[path].sha256)throw Error(`Frozen source drift: ${path}`);
  hashes[path]=hash;
  vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')}\nglobalThis.${name}=${name};})()`,context);
}
const lines=context.LEVEL5.steps.find(x=>x.kind==='boss').lines;
function run(test){
  wall=10000;timers=[];const calls=[],trace=[];
  const boss=Object.create(context.FoxBoss.prototype);
  Object.assign(boss,{L:lines,hp:100,time:10,phase:1,kneels:test.initialKneels??1,_storyUntil:test.until??0,
    nodes:Array.from({length:4},()=>({broken:false})),_cancelAttacks(){},snap(){},
    m:{stats:{},drive:{player:{}},hud:{talking:!!test.talking,retitle(){},banner(){},say(l,urgent,append){calls.push({wall,lines:l,urgent,append});}}}});
  context.Math.random=()=>0;
  for(const action of test.actions){
    wall=10000+action.wall;
    if(action.hp!==undefined)boss.hp=action.hp;
    if(action.reason!==undefined)boss.m.reason=action.reason;
    if(action.finished!==undefined)boss.m.finished=action.finished;
    if(action.kneel){boss.nodes.forEach((node,i)=>node.broken=i<action.broken);boss.state='fight';boss._kneel();}
    const due=timers.filter(timer=>timer.at<=wall);timers=timers.filter(timer=>timer.at>wall);
    for(const timer of due)timer.callback();
    trace.push({calls:structuredClone(calls),storyUntil:boss._storyUntil,scheduled:!!boss._exposedSaid,pending:timers.length});
  }
  return trace;
}
const start={wall:0,kneel:true,broken:4};
const cases=[
 {name:'three-legs',actions:[{wall:0,kneel:true,broken:3},{wall:2600},{wall:6000}]},
 {name:'deadline-and-repeat',actions:[start,{wall:2599},{wall:2600},{wall:2601},{wall:2700,kneel:true,broken:4},{wall:5300}]},
 {name:'first-kneel-order',initialKneels:0,actions:[start,{wall:2599},{wall:2600}]},
 {name:'alive-deadline',actions:[start,{wall:2599,hp:0},{wall:2600},{wall:3000,hp:100},{wall:4000,kneel:true,broken:4},{wall:6600}]},
 {name:'reason-cancels',actions:[start,{wall:2599,reason:'exit'},{wall:2600},{wall:3000,reason:false},{wall:4000,kneel:true,broken:4},{wall:6600}]},
 {name:'finished-not-reason',actions:[start,{wall:2599,finished:true},{wall:2600}]},
 {name:'paused-simulation-wall-clock',actions:[start,{wall:5000}]},
 {name:'busy-story-queues',until:100,actions:[start,{wall:2600}]},
 {name:'talking-card-urgent',talking:true,actions:[start,{wall:2600}]},
 {name:'leave-disposes',actions:[start,{wall:1300,reason:'quit',dispose:true},{wall:2600}]},
];
console.log(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit,hashes},lines,cases:cases.map(test=>({test,expected:run(test)}))}));

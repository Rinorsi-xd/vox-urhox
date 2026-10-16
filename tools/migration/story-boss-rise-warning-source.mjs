import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const path='three/src/battle/storyBoss.js',bytes=fs.readFileSync(`${baseline.snapshot}/${path}`);
const sha256=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha256!==baseline.files[path].sha256)throw Error('Frozen boss source drift');
const context=vm.createContext({THREE:{Vector3:class{}},Blueprint:class{},buildDrillTank:()=>({toJSON:()=>({})}),radio(){},setTimeout(){}});
vm.runInContext(bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.FoxBoss=FoxBoss;globalThis.config=FOX_BOSS;',context);
const levelPath='shared/story/level5.js',levelBytes=fs.readFileSync(`${baseline.snapshot}/${levelPath}`);
const levelSha256=crypto.createHash('sha256').update(levelBytes).digest('hex');
if(levelSha256!==baseline.files[levelPath].sha256)throw Error('Frozen level source drift');
vm.runInContext(levelBytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.lines=LEVEL5.steps.find(s=>s.kind===\'boss\').lines;',context);
const config=context.config;
function run(test){
 const boss=Object.create(context.FoxBoss.prototype);let warnings=0;
 Object.assign(boss,{s:{title:'boss'},hpMax:20000,hp:test.hp*20000,phase:3,state:'kneel',t:test.age,time:100,kneels:1,kneelDealt:0,
  _riseWarned:test.warned,nodes:Array.from({length:4},(_,i)=>({broken:false,hp:100,max:100,pos:[20+i*10,0,0]})),
  cool:{stomp:99,slam:99,missile:99,sweep:99,lanes:99,ult:99},missiles:[],said:new Set(),slams:[],L:context.lines,
  unit:{pos:[0,0,0],vehicle:{yaw:0}},
  m:{stats:{},reason:false,drive:{player:{alive:false,weapons:{}},sim:{recordDamage(){}},trauma:0},fx:{explode(){}},clearEnemies(){},
   hud:{talking:false,banner(){},retitle(text){if(text==='它要站起来了')warnings++;},say(){}}},
  warn:{},slamRing:{},sector:{},laneMeshes:[],dome:{},bar:{ult(){},set(){},show(){}},
  _raidStep(){},_visuals(){},cockpit:()=>[0,0,0],snap(){},threat:()=>false});
 const frames=[];
 for(const op of test.ops){
  let damage=null;
  if(op.kind==='step')boss.update(op.dt);
  else damage=boss.onHit(op.node?[20,0,0]:[0,0,0],op.damage);
  frames.push({state:boss.state,t:boss.t,hp:boss.hp,riseWarned:!!boss._riseWarned,warnings,damage});
 }
 return frames;
}
const cases=[];
for(const age of [0,6.499999,6.5,7.9])for(const warned of [false,true])for(const scale of [.5,1,2]){
 const test={name:`age-${age}/warned-${warned}/damage-${scale}`,age,warned,hp:1,ops:[
  {kind:'step',dt:0},{kind:'hit',damage:20000*config.kneelCap/config.cockpit*scale},
  {kind:'step',dt:config.rise},{kind:'step',dt:config.brace+.01},
  {kind:'hit',node:true,damage:200},{kind:'step',dt:config.kneel-config.riseWarn-.000001},
  {kind:'step',dt:.000002},{kind:'step',dt:config.riseWarn},{kind:'step',dt:config.rise} ]};
 cases.push({test,expected:run(test)});
}
for(const hp of [.1,.18,.180001])for(const warned of [false,true]){
 const test={name:`lethal-boundary-${hp}/${warned}`,age:7,warned,hp,ops:[{kind:'hit',damage:10000}]};
 cases.push({test,expected:run(test)});
}
console.log(JSON.stringify({source:{commit:baseline.commit,branch:baseline.branch,path,sha256,levelPath,levelSha256},config,cases}));

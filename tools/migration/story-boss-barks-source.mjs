import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const ctx=vm.createContext({THREE:{Vector3:class{}},Blueprint:class{},buildDrillTank:()=>({toJSON:()=>({})}),Math:Object.create(Math),radio(){}});
const source={branch:baseline.branch,commit:baseline.commit,files:{}};
for(const [path,name] of [['three/src/battle/storyBoss.js','FoxBoss'],['shared/story/level5.js','LEVEL5']]){
  const bytes=fs.readFileSync(`${baseline.snapshot}/${path}`);
  const hash=crypto.createHash('sha256').update(bytes).digest('hex');
  if(hash!==baseline.files[path].sha256)throw new Error(`Frozen source drift: ${path}`);
  source.files[path]=hash;
  const exportBarks=name==='FoxBoss'?'globalThis.BARKS=[...BARKS];':'';
  vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')}\nglobalThis.${name}=${name};${exportBarks}})()`,ctx);
}
const lines=ctx.LEVEL5.steps.find(s=>s.kind==='boss').lines;
const urgentEvents=new Set(['firstKneel','exposed','phase2','phase3','cry','ult','ultAgain','crush','slamWarn','lanesWarn']);
function run(test){
  const calls=[];
  const player={pos:[0,0,0],bodyHpMax:3000,hullEnabled:true,_hurtHull(){},explode(){},flush(){}};
  const b=Object.create(ctx.FoxBoss.prototype);
  Object.assign(b,{time:10,_storyUntil:test.until,L:{...lines},s:{title:'boss'},unit:{},said:new Set(),
    dome:{position:{x:0,z:0}},bar:{ult(){},boom(){}},map:{underRoof:()=>test.safe},
    m:{drive:{player,sim:{recordDamage(){}},_syncPlayer(){}},ground:()=>0,fx:{explode(){}},
       hud:{talking:test.talking,say(l,urgent,append){calls.push({lines:l,urgent,append});},retitle(){}}},
    _team:()=>[player],_sheltered:()=>false});
  if(test.synthetic)b.L[test.key]=['nono','synthetic bark gate','nono_deadpan'];
  if(test.mode==='ult')b._ultBlast();else b.say(test.key,urgentEvents.has(test.key));
  return {calls,storyUntil:b._storyUntil};
}
const cases=[];
const conditions=[];
for(const talking of [false,true])for(const until of [0,9.999999,10,10.000001,20])conditions.push({talking,until});
for(const key of [...ctx.BARKS,'firstKneel','exposed','phase2','phase3','cry','ult','ultAgain','crush','firstRise'])for(const condition of conditions){
  // Retired keys are tested synthetically for set membership, and separately
  // with the real authored data to prove they remain silent in production.
  for(const synthetic of lines[key]?[false]:[false,true]){
    const test={key,mode:'event',synthetic,...condition};cases.push({test,expected:run(test)});
  }
}
for(const safe of [false,true])for(const condition of conditions){
  const test={mode:'ult',safe,...condition};cases.push({test,expected:run(test)});
}
function element(){
 const children=new Map();let classes=new Set();
 return {dataset:{},style:{},textContent:'',innerHTML:'',parentNode:null,
  get className(){return [...classes].join(' ');},set className(value){classes=new Set(value.split(/\s+/));},
  classList:{contains(name){return classes.has(name);},remove(name){classes.delete(name);},toggle(name,on){if(on)classes.add(name);else classes.delete(name);}},
  appendChild(node){node.parentNode=this;},remove(){this.parentNode=null;},
  querySelector(selector){if(!children.has(selector))children.set(selector,element());return children.get(selector);},
  querySelectorAll(){return [];},animate(){},
 };
}
const commsPath='shared/ui/nonoComms.js';const commsBytes=fs.readFileSync(`${baseline.snapshot}/${commsPath}`);
source.files[commsPath]=crypto.createHash('sha256').update(commsBytes).digest('hex');
if(source.files[commsPath]!==baseline.files[commsPath].sha256)throw new Error('Frozen communications source drift');
Object.assign(ctx,{URL,document:{createElement:element},storyVoice:{preload(){},find(){return null;},fade(){}},mechFrame(){},HUHU_FACES:{talk:'face'}});
vm.runInContext(`(()=>{${commsBytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'').replaceAll('import.meta.url',JSON.stringify('file:///frozen/shared/ui/nonoComms.js'))}\nglobalThis.NonoComms=NonoComms;})()`,ctx);
const playerCases=[];
for(const key of ['firstRise','pod','truck','entrance','down','phase2','ultHit'])for(const until of [0,20])for(const age of [.5,2]){
 const card=new ctx.NonoComms(element());card.time=10-age;
 card.say([['nono','retained previous bark']],false,false);card.update(.001);card.time=10;
 const b=Object.create(ctx.FoxBoss.prototype);Object.assign(b,{time:10,_storyUntil:until,L:lines,said:new Set(),m:{hud:card}});
 if(key==='firstRise')b.once(key);
 else if(key==='down'){b._storyUntil=0;b.say(key,true);}
 else b.say(key,urgentEvents.has(key)||key==='entrance'||key==='ultHit');
 playerCases.push({test:{key,until,age},expected:{current:card.comm?.text??false,queue:card.queue,storyUntil:b._storyUntil}});
 card.dispose();
}
const onceCases=[];
for(const key of ['allyDown','stompHit','sweepHit','lanesHit']){
 const calls=[];const hud={talking:true,say(l,urgent,append){calls.push({lines:l,urgent,append});}};
 const b=Object.create(ctx.FoxBoss.prototype);Object.assign(b,{time:10,_storyUntil:0,L:lines,said:new Set(),m:{hud}});
 const trace=[];
 for(const talking of [true,false,false]){hud.talking=talking;b.once(key);trace.push({calls:[...calls],said:b.said.has(key),storyUntil:b._storyUntil});}
 onceCases.push({key,trace});
}
const eventCases=[];
for(const key of ['allyDown','stompHit','sweepHit','lanesHit']){
 const calls=[];const player={pos:[0,0,0],alive:true,explode(){},flush(){}};
 const hud={talking:true,say(l,urgent,append){calls.push({lines:l,urgent,append});}};
 const b=Object.create(ctx.FoxBoss.prototype);Object.assign(b,{time:10,_storyUntil:0,L:lines,said:new Set(),allies:[],
  unit:{},cool:{},sweepAt:[0,0,0],sweepYaw:0,sector:{},laneFrom:[0,0,0],laneAngles:[0],laneMeshes:[],
  shock:{position:{set(){}},userData:{}},_team:()=>[player],_hitUnit(){},_removeAlly(){},
  m:{hud,fx:{explode(){}},ground:()=>0,drive:{player,vehicle:{telemetry:{contact:1}},sim:{},_syncPlayer(){}}}});
 const trace=[];
 for(const talking of [true,false,false]){
  hud.talking=talking;
  if(key==='allyDown'){b.allies=[{dead:null,unit:{pos:[0,0,0],alive:false,flush(){}}}];b._stepAllies(.01);}
  else if(key==='stompHit')b._impact([0,0,0],10,1,'stomp');
  else if(key==='sweepHit')b._sweepHit();else b._lanesHit();
  trace.push({calls:[...calls],said:b.said.has(key),storyUntil:b._storyUntil});
 }
 eventCases.push({key,trace});
}
console.log(JSON.stringify({source,barks:ctx.BARKS,authoredLines:lines,cases,playerCases,onceCases,eventCases}));

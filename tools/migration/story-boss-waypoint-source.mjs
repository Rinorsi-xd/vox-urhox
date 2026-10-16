import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const context=vm.createContext({THREE:{Vector3:class{}},Blueprint:class{},buildDrillTank:()=>({toJSON:()=>({})})});
const source={branch:baseline.branch,commit:baseline.commit,files:{}};
for(const [path,names] of [
  ['shared/ai/driver.js',['findPath']],
  ['three/src/battle/storyBoss.js',['FoxBoss']],
  ['shared/story/level5.js',['LEVEL5']],
]){
  const bytes=fs.readFileSync(`${baseline.snapshot}/${path}`);
  const hash=crypto.createHash('sha256').update(bytes).digest('hex');
  if(hash!==baseline.files[path].sha256)throw new Error(`Frozen source drift: ${path}`);
  source.files[path]=hash;
  vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')}\n${names.map(n=>`globalThis.${n}=${n};`).join('\n')}})()`,context);
}
const findPath=context.findPath;
const nodes={a:[0,0,0],b:[30,0,30],c:[80,0,30],d:[150,0,0],e:[200,0,0]};
const wide={nodes,edges:[['a','b',5],['b','c',5],['c','d',5],['d','e',5]]};
const cases=[];
function sample(test){
  const calls=[];
  context.findPath=(nav,from,to,width)=>{calls.push({from:[...from],to:[...to],width});return findPath(nav,from,to,width);};
  const boss=Object.create(context.FoxBoss.prototype);
  const position=[0,0,0];boss.unit={pos:position};boss.m={drive:{layout:{nav:test.nav}}};
  return test.steps.map(step=>{
    boss.time=step.time;position.splice(0,3,...step.pos);
    const target=[...step.to];const goal=boss._waypoint(target);
    const before=boss._pathTo?.slice()??null;
    if(step.mutateTarget)target[0]+=500;
    return {goal:[...goal],path:boss._path?.map(p=>[...p])??null,pathTo:boss._pathTo??null,
      pathUntil:boss._pathT??null,calls:calls.map(c=>({...c})),copiedTarget:JSON.stringify(before)===JSON.stringify(boss._pathTo??null)};
  });
}
function add(name,nav,steps){const test={name,nav,steps};cases.push({test,expected:sample(test)});}
add('stationary-120-steps',wide,Array.from({length:120},(_,i)=>({time:i/60,pos:[0,0,0],to:[180,0,0]})));
add('strict-clock-and-target-thresholds',wide,[
  {time:0,pos:[0,0,0],to:[150,0,0],mutateTarget:true},
  {time:1.5,pos:[0,0,0],to:[175,200,0]},
  {time:1.5,pos:[0,0,0],to:[175.00001,200,0]},
  {time:3,pos:[0,0,0],to:[175.00001,200,0]},
  {time:3.00001,pos:[0,0,0],to:[175.00001,200,0]},
]);
add('consume-route-close-thresholds',wide,[
  {time:0,pos:[0,0,0],to:[150,0,0]},
  {time:.1,pos:[10,0,30],to:[150,0,0]},
  {time:.2,pos:[10.00001,0,30],to:[150,0,0]},
  {time:.3,pos:[80,0,30],to:[150,0,0]},
  {time:.4,pos:[90,0,0],to:[150,0,0]},
  {time:.5,pos:[150,0,0],to:[150,0,0]},
]);
add('narrow-fallback',{nodes,edges:wide.edges.map(([a,b])=>[a,b,4.99999])},[
  {time:0,pos:[0,0,0],to:[180,0,0]},
  {time:1,pos:[0,0,0],to:[180,0,0]},
  {time:1.50001,pos:[0,0,0],to:[180,0,0]},
]);
for(const [name,nav] of [['absent-nav',null],['no-nodes',{}],['empty-nodes',{nodes:{},edges:[]}],
  ['isolated-nodes',{nodes,edges:[]}],['disconnected',{nodes,edges:[['a','b',5],['d','e',5]]}]]){
  add(name,nav,[{time:0,pos:[0,0,0],to:[180,0,0]},{time:1,pos:[0,0,0],to:[180,0,0]},
    {time:1.5,pos:[0,0,0],to:[180,0,0]},{time:1.50001,pos:[0,0,0],to:[180,0,0]}]);
}
for(const far of [59.99999,60,60.00001])add(`direct-distance-${far}`,wide,[{time:0,pos:[0,0,0],to:[far,0,0]}]);
const retiredBarks=[];
for(const key of ['laserHit','chaseUnder','pipe']){
  let calls=0;const boss=Object.create(context.FoxBoss.prototype);
  boss.L=context.LEVEL5.steps.find(s=>s.kind==='boss').lines;boss.said=new Set();
  boss.m={hud:{say(){calls++;}}};
  retiredBarks.push({key,lineExists:Object.hasOwn(boss.L,key),onceResult:boss.once(key),said:boss.said.has(key),dialogueCalls:calls});
}
console.log(JSON.stringify({source,cases,retiredBarks}));

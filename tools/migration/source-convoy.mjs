import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const url=p=>pathToFileURL(path.join(baseline.snapshot,p)).href;
registerHooks({resolve(s,c,n){return n(s.startsWith('@shared/')?url('shared/'+s.slice(8)):s,c);},
 load(u,c,n){if(u===url('shared/story/radio.js'))return {format:'module',source:'export function radio() {}',shortCircuit:true};return n(u,c);}});
const {KINDS}=await import(url('three/src/battle/storyKinds.js'));
const {LEVEL2}=await import(url('shared/story/level2.js'));
const step=LEVEL2.steps[1],nav=JSON.parse(fs.readFileSync(path.join(root,'assets/Crater/Layout.json'))).nav;
const noop=()=>{};const hud={row:noop,retitle:noop,say:noop,banner:noop,talking:false};
const player={alive:true,pos:[-198,-12,-24]},enemies=new Map();
const m={time:0,stats:{},hud,drive:{layout:{nav},player},view:{addTruck:()=>({setPose:noop,hit:noop})},
 ground:(x,z,hint=40)=>hint,progress:0,beatsFired:new Set(),fail:()=>m.failing=true,_place:noop};
KINDS.escort.prepare(m,step);KINDS.escort.enter(m,step);
const trace=[];
function sample(kind,dt,pos,enemyPositions=[],dead=false){
 player.pos=pos;player.alive=!dead;enemies.clear();for(const p of enemyPositions)enemies.set({alive:true,pos:p},{});m.enemies=enemies;m.time+=dt;
 const done=KINDS.escort.update(m,step,dt,dead);
 trace.push({op:'update',dt,pos,enemyPositions,alive:!dead,time:m.time,done,
 expected:{d:m.truck.d,v:m.truck.v,hp:m.truck.hp,cp:m.truck.cp,cpD:m.truck.cpD,cpHp:m.truck.cpHp,pos:m.truck.pos,yaw:m.truck.yaw,far:m.truck.far,blocked:m.truck.blocked,progress:m.progress||0}});
}
for(let i=0;i<80;i++)sample('travel',.25,[...m.truck.pos]);
sample('far',1,[300,30,300]);sample('dead',1,[...m.truck.pos],[],true);
for(let i=0;i<50;i++)sample('blocked',.2,[...m.truck.pos],[[...m.truck.pos]]);
for(let i=0;i<210;i++)sample('travel',.25,[...m.truck.pos]);
sample('failure',200,[...m.truck.pos],[[...m.truck.pos]]);
KINDS.escort.retry(m,step);trace.push({op:'retry',expected:{d:m.truck.d,hp:m.truck.hp,v:m.truck.v,pos:m.truck.pos,progress:m.progress}});
fs.writeFileSync(path.join(root,'tools/migration/source-convoy.json'),JSON.stringify({nav,step,trace}));
console.log(JSON.stringify({source:baseline.commit,samples:trace.length,routeMetres:m.truckPath.total}));

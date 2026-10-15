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
const {LEVEL3}=await import(url('shared/story/level3.js'));
const step=LEVEL3.steps[2],trace=[];let healed=0,restored=0,failed=0;
const noop=()=>{},player={alive:true,pos:[0,6,-234],heal:n=>healed+=n,restoreMissing:n=>(restored+=n,[])};
const m={stepT:0,stats:{},hud:{clock:noop,row:noop,retitle:noop},view:{showZone:noop},drive:{player},enemies:new Map(),fail:()=>failed++};
KINDS.hold.enter(m,step);
function sample(dt,time,pos,enemies=[],alive=true){
 m.stepT=time;player.pos=pos;player.alive=alive;m.enemies.clear();for(const p of enemies)m.enemies.set({alive:true,pos:p},{});
 const done=KINDS.hold.update(m,step,dt,!alive);
 trace.push({dt,stepT:time,pos,enemies,alive,expected:{...m.hold,progress:m.progress||0,healed,restored,failed,done}});
}
sample(.1,3.9,[0,6,-234]);sample(.1,4,[0,6,-234]);
sample(2.4,6.4,[26,6,-234]);sample(2.5,8.9,[0,6,-234]);sample(.1,9,[0,6,-234]);
sample(.1,9.1,[0,6,-234],[[70,6,-234]]);sample(.1,9.2,[0,6,-234],[[69.99,6,-234]]);
sample(.1,9.3,[0,6,-234],[[0,200,-234]],false);
for(let i=0;i<450;i++)sample(.25,10+i*.25,[0,6,-234],i%3===0?[[0,6,-234]]:[],i%11!==0);
sample(110,130,[0,6,-234],[[0,6,-234],[0,6,-234]]);
fs.writeFileSync(path.join(root,'tools/migration/source-siege.json'),JSON.stringify({baseline:baseline.commit,trace}));
console.log(JSON.stringify({source:baseline.commit,samples:trace.length}));

import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
if(baseline.commit!=='b276064942ae09c0227ec28d4cfda1d5ff006455')throw Error('Unexpected frozen baseline');
const files=[];
function read(file){
 const text=fs.readFileSync(path.join(baseline.snapshot,file),'utf8');
 const sha256=createHash('sha256').update(text).digest('hex');
 if(sha256!==baseline.files[file]?.sha256)throw Error('Frozen source changed: '+file);
 files.push({file,sha256});return text;
}
const kindsText=read('three/src/battle/storyKinds.js');
const kinds=vm.runInNewContext(kindsText.replace(/^import .*;\r?$/gm,'').replace('export const KINDS','const KINDS')+'\nKINDS;',{BOSS_KIND:{},radio(){}});
const missionText=read('three/src/battle/storyMission.js');
const Mission=vm.runInNewContext(missionText.replace(/^import .*;\r?$/gm,'').replace('export class','class')+'\nStoryMission;',{KINDS:kinds,THREE:{Vector3:class {}},performance:{now:()=>2000}});
const levelText=read('shared/story/level1.js');
const level=vm.runInNewContext(levelText.replace('export const LEVEL1','const LEVEL1')+'\nLEVEL1;');
const scout=level.steps.find(s=>s.id==='scouts');
if(scout.enemies.length!==3||level.steps.find(s=>s.id==='log').kind!=='pickup')throw Error('Actual scout/log route changed');

function run(name,states,clear=false){
 const trace=[],disposed=[],player={alive:true,pos:[0,2,0]};
 const units=states.map((state,i)=>({
  id:i+1,alive:state==='alive'||state==='flee',integrity:state==='flee'?.2:1,
  pos:[(i+1)*100,2,10*(i+1)],spec:{bounds:{radius:state==='bossDead'?8:3}},
  dispose(){disposed.push(this.id);},
 }));
 const entries=units.map((u,i)=>[u,{flee:states[i]==='flee'?.5:undefined,
  scripted:states[i]==='scriptedDead',noBlast:states[i]==='noBlastDead',boss:states[i]==='bossDead'}]);
 const step={...scout,kind:clear?'clear':'capture',fleeLines:[['huhu','跑了']]};
 const m=Object.create(Mission.prototype);
 Object.assign(m,{drive:{player,sim:{units:[player,...units]},trauma:.1},enemies:new Map(entries),stats:{kills:0,deaths:0},
  level:{steps:[step]},i:0,lastKill:null,deadAt:null,time:2,finished:false,
  fx:{explode(p,size,big){trace.push({kind:'explode',pos:[...p],size,big:!!big});},update(){}},
  view:{spawnFlash(p){trace.push({kind:'stomp',pos:[p[0],p[1]-1,p[2]],strength:.8});},update(){},addIntel(id,p){trace.push({kind:'intel',id,pos:[...p]});}},
  hud:{say(lines,urgent){trace.push({kind:'say',lines,urgent:!!urgent});},banner(kick,title,sub,kind,ms){trace.push({kind:'banner',kick,title,sub,style:kind,ms});},update(){},retitle(){},talking:false},
 });
 m.afterStep(1/60);
 const lastKill=m.lastKill&&[...m.lastKill],firstTrace=JSON.parse(JSON.stringify(trace)),firstKills=m.stats.kills;
 const surviving=[...m.enemies.keys()].map(u=>u.id);
 m.afterStep(1/60);
 if(m.stats.kills!==firstKills||JSON.stringify(trace)!==JSON.stringify(firstTrace))throw Error('Source processed a removed unit twice');
 let drop=null;
 if(clear){
  Object.assign(m,{begun:true,phase:'fight',fightAt:0,stepT:0,beatsFired:new Set(),asked:false,_marker(){},_done(){this.completed=true;}});
  m.update(1/60);drop=m.dropPos&&[...m.dropPos];
 }
 return {name,states,clear,lastKill,kills:firstKills,surviving,trace:firstTrace,drop:drop||null,trauma:m.drive.trauma};
}
const cases=[];
for(let mask=1;mask<8;mask++)cases.push(run('scout-mask-'+mask,[0,1,2].map(i=>mask&(1<<i)?'dead':'alive'),true));
const states=['alive','dead','flee','scriptedDead','noBlastDead','bossDead'];
for(const a of states)for(const b of states)for(const c of states)cases.push(run('mixed-'+cases.length,[a,b,c]));
console.log(JSON.stringify({source:{commit:baseline.commit,files},cases}));

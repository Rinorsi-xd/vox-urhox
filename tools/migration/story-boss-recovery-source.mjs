import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const source={commit:baseline.commit,files:{}};
class Vec {
 constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z;}
 clone(){return new Vec(this.x,this.y,this.z);}
 copy(v){this.x=v.x;this.y=v.y;this.z=v.z;return this;}
 lerp(v,t){this.x+=(v.x-this.x)*t;this.y+=(v.y-this.y)*t;this.z+=(v.z-this.z)*t;return this;}
 sub(v){this.x-=v.x;this.y-=v.y;this.z-=v.z;return this;}
 length(){return Math.hypot(this.x,this.y,this.z);}
 divideScalar(v){this.x/=v;this.y/=v;this.z/=v;return this;}
 addScaledVector(v,t){this.x+=v.x*t;this.y+=v.y*t;this.z+=v.z*t;return this;}
 toArray(){return [this.x,this.y,this.z];}
}
const context=vm.createContext({THREE:{Vector3:Vec},Blueprint:class{},buildDrillTank:()=>({toJSON:()=>({})}),radio(){}});
for(const [path,names]of [['three/src/battle/storyBoss.js',['FoxBoss','BOSS_KIND']],['shared/story/level5.js',['LEVEL5']]]){
 const bytes=fs.readFileSync(`${baseline.snapshot}/${path}`),hash=crypto.createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[path].sha256)throw Error('Frozen source drift: '+path);
 source.files[path]=hash;
 const adapter=path.endsWith('storyBoss.js')?"podMesh=()=>({position:{set(){}},rotation:{set(){}},userData:{flame:{scale:{setScalar(){}}}}});":'';
 vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')}\n${adapter}${names.map(n=>`globalThis.${n}=${n};`).join('\n')}})()`,context);
}
const step=context.LEVEL5.steps.find(s=>s.kind==='boss');
const openCases=[];
for(const type of ['empty','wall','self','ties']){
 const rays=[];let i=0;const boss=Object.create(context.FoxBoss.prototype);
 Object.assign(boss,{unit:{pos:[12,4,-18]},m:{drive:{vehicle:{body:'player'},sim:{castRay(origin,direction,length,exclude){
  const index=i++;rays.push({origin,direction,length,exclude});
  if(type==='empty')return null;
  if(type==='self')return {dist:index===3?2:10,owner:{ref:boss.unit}};
  return {dist:type==='wall'?(index===7?45:5):10+index*.1,owner:{ref:null}};
 }}}}});
 openCases.push({type,angle:boss.openDir(48),rays});
}
const recoveryCases=[];
for(const angle of [0,.7,Math.PI,5.8])for(const time of [0,.1,1,4,6,7.99,8,9]){
 let pose=null,shot=null;const boss=Object.create(context.FoxBoss.prototype);
 const at=[10,4,-20],from=[at[0]+Math.sin(angle)*62,2,at[2]+Math.cos(angle)*62],to=[at[0]+Math.sin(angle)*22,3,at[2]+Math.cos(angle)*22];
 const m={bossFlow:{stage:'ending',t:20,open:angle,pod:{},truck:{t:time,from,to,view:{setPose(...args){pose=args;},update(){}}}},drive:{},ground:(x,z)=>2+x*.01+z*.02,hud:{talking:true}};
 Object.assign(boss,{m,unit:{pos:at},update(){},cockpit:()=>[10,10,-20],look(eye,target,blend){shot={eye,target,blend};}});m.boss=boss;
 const done=context.BOSS_KIND.update(m,step,0);
 recoveryCases.push({angle,time,from,to,pose,shot,done});
}
const captureCues=[];
for(const kind of ['kneel-first','kneel-second','ult-start']){
 const cues=[];const boss=Object.create(context.FoxBoss.prototype);
 Object.assign(boss,{state:'fight',hp:100,kneels:kind==='kneel-second'?1:0,nodes:[{broken:false},{broken:false},{broken:false},{broken:false}],phase:1,
  L:step.lines,ultsDone:0,cool:{},dome:{position:{set(){}},scale:{setScalar(){}},material:{}},
  m:{stats:{},drive:{player:{weapons:{}}},hud:{retitle(){},banner(){}}},
  _cancelAttacks(){},_go(state){this.state=state;},say(){},talk(){},snap(...args){cues.push(args);}});
 if(kind==='ult-start')boss._startUlt();else boss._kneel();
 captureCues.push({kind,cues});
}
const transitions=[];
for(const stage of ['pod-spawn','pod-line','truck-spawn']){
 const snaps=[],says=[],looks=[];const boss=Object.create(context.FoxBoss.prototype);
 const flow={stage:'ending',t:6,open:.7};
 if(stage==='pod-line'||stage==='truck-spawn')flow.pod={from:[10,10,-20],t:stage==='pod-line'?1.21:7.01,mesh:{position:{set(){}},rotation:{set(){}},userData:{flame:{scale:{setScalar(){}}}}}};
 const m={bossFlow:flow,drive:{},ground:()=>2,fx:{explode(){}},view:{addTruck(from,yaw){return {from,yaw};}},hud:{talking:false}};
 Object.assign(boss,{m,unit:{pos:[10,4,-20]},update(){},cockpit:()=>[10,10,-20],look(...args){looks.push(args);},group:{add(){},remove(){}},talk(lines){says.push(lines);},snap(...args){snaps.push(args);}});m.boss=boss;
 context.BOSS_KIND.update(m,step,0);
 transitions.push({stage,snaps,says,looks,truck:flow.truck?{from:flow.truck.from,to:flow.truck.to,t:flow.truck.t}:null});
}
const cameraCases=[];
for(const collision of ['none','wall','self']){
 const frames=[],rays=[];const boss=Object.create(context.FoxBoss.prototype);
 const camera={position:new Vec(-20,15,35),up:new Vec(),lookAt(v){this.target=v.toArray();}};
 Object.assign(boss,{unit:{},m:{drive:{camera,vehicle:{body:'player'},sim:{castRay(origin,direction,length,exclude){
  rays.push({origin,direction,length,exclude});return collision==='none'?null:{dist:4,owner:{ref:collision==='self'?boss.unit:null}};
 }}}}});
 for(const shot of [{eye:[40,12,10],target:[0,4,0],blend:.06},{eye:[24,20,-10],target:[8,6,-4],blend:.12},{eye:[7,9,3],target:[0,3,0],blend:1}]){
  boss.look(shot.eye,shot.target,shot.blend);frames.push({shot,eye:camera.position.toArray(),target:camera.target});
 }
 cameraCases.push({collision,frames,rays});
}
console.log(JSON.stringify({source,openCases,recoveryCases,transitions,captureCues,cameraCases}));

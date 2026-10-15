import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const relative='shared/audio/damageMix.js',file=path.resolve(root,baseline.snapshot,relative);
const hash=createHash('sha256').update(fs.readFileSync(file)).digest('hex');
if(hash!==baseline.files[relative]?.sha256)throw Error('Frozen CollisionAudio changed');
const {CollisionAudio}=await import(pathToFileURL(file));
const inputs=[];
for(const delta of [0,1.799,1.8,3.5,7,14])for(const normal of [0,.599,.6,1])inputs.push({delta,normal});
for(const age of [.249,.25,.251])inputs.push({delta:7,normal:0,age});
inputs.push({delta:7,normal:0,dead:true},{delta:7,normal:0,rebuild:true});
const cases=inputs.map(input=>{
 let velocity={x:0,y:0,z:0};const body={linvel:()=>velocity};
 const unit={vehicle:{body,colliders:[{}]},pos:[1,2,3]};
 const sim={combatUnits:[unit],time:10,world:{
  contactPairsWith(c,visit){visit({});},
  contactPair(c,other,visit){visit({numContacts:()=>1,normal:()=>({x:0,y:input.normal,z:0})});}
 }};
 const detector=new CollisionAudio();if(input.age!=null)detector.last.set(unit,10-input.age);
 detector.beforeStep(sim);velocity={x:Math.fround(input.delta),y:0,z:0};
 if(input.dead)unit.vehicle=null;
 if(input.rebuild)unit.vehicle={body:{linvel:()=>velocity}};
 const events=detector.afterStep(sim);
 return {...input,count:events.length,strength:events[0]?.strength??null};
});
const output=path.join(root,'.tmp/source-collision-audio.json');
fs.writeFileSync(output,JSON.stringify({sourceCommit:baseline.commit,provenance:{[relative]:hash},cases}));
console.log(JSON.stringify({output,cases:cases.length}));

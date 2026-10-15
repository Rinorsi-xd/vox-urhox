import fs from 'node:fs';import path from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));const source=path.resolve(baseline.snapshot);
const module=await import(pathToFileURL(path.join(source,'shared/ai/drillRaider.js')));const {EnemyDriver}=await import(pathToFileURL(path.join(source,'shared/ai/driver.js')));
EnemyDriver.prototype.step=function(){return {command:{throttle:.77,steer:.11,handbrake:false},aim:[99,0,0],trigger:true,mode:'approach'};};
const rows=[];
for(const range of [15,20,23,27,32,36,44])for(const angle of [0,.04,.1,.25,-.25])for(const held of [false,true])for(const windup of [0,1]){
 const aim=[Math.sin(angle)*range,0,Math.cos(angle)*range],speed=rows.length%3===0?2:0;
 const c=Object.create(module.DrillRaiderDriver.prototype);Object.assign(c,{width:4,chargeWait:0});let cancelled=0;
 const drill={held:held?{}:null,cancel(){this.held=null;cancelled++;}};const w={stats:{drill:true},cool:0,windup};
 const vehicle={body:{translation:()=>({x:0,y:1,z:0}),rotation:()=>({x:0,y:0,z:0,w:1}),linvel:()=>({x:0,y:0,z:speed})},yaw:0,spec:{bounds:{min:[-2,-1,-2],max:[2,2,2]}}};
 const sim={castRay:(p,d,len)=>d[1]===-1?{point:[p[0],0,p[2]],dist:p[1]}:null};const sys={drill,group:{weapons:[w]},muzzle:()=>({pos:[0,0,0],dir:[0,0,1]})};
 const result=c.step(1/60,{vehicle,target:{pos:aim},weaponSystem:sys,sim,shield:{active:false}});
 const aimBits=aim.map(x=>{const bytes=Buffer.alloc(8);bytes.writeDoubleLE(x);return bytes.toString('hex');});
 rows.push({range,angle,held,windup,speed,aim,aimBits,result,cancelled,chargeWait:c.chargeWait});
}
const provenance={};for(const relative of ['shared/ai/drillRaider.js','shared/ai/driver.js']){const sha=createHash('sha256').update(fs.readFileSync(path.join(source,relative))).digest('hex');if(baseline.files[relative]?.sha256!==sha)throw Error('baseline mismatch '+relative);provenance[relative]=sha;}
fs.writeFileSync(path.join(root,'tools/migration/source-drill-raider.json'),JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},provenance,rows}));console.log(rows.length);

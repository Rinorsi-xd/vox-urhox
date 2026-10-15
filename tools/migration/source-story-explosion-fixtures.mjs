import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const sources={};
for(const name of ['storyBoss','storyMission']){
 const file=`three/src/battle/${name}.js`,text=fs.readFileSync(path.join(baseline.snapshot,file),'utf8');
 const sha256=createHash('sha256').update(text).digest('hex');
 if(sha256!==baseline.files[file].sha256)throw Error('Frozen source changed: '+file);
 sources[name]={file,sha256,text};
}
const C=JSON.parse(fs.readFileSync('assets/Story/Mission/Level5.json')).boss;
const cases=[];
for(const kind of ['sweep','lanes','ultBlast'])for(const yaw of kind==='ultBlast'?[0]:[-2.1,0,.7]){
 const methodName={sweep:'_sweepHit',lanes:'_lanesHit',ultBlast:'_ultBlast'}[kind];
 const text=sources.storyBoss.text.match(new RegExp(`\\t${methodName}\\(\\) \\{[\\s\\S]*?\\n\\t\\}\\r?\\n`))[0].trim().replace(methodName,'function');
 let seed=842648926;const math=Object.create(Math);math.random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
 const method=vm.runInNewContext('('+text+')',{FOX_BOSS:C,Math:math,radio:()=>{}});
 const blasts=[],ground=(x,z)=>x*.01+z*.03;
 const pos=[13,4,-22],center=[-20,-32,46];
 const boss={sweepAt:pos,sweepYaw:yaw,laneFrom:pos,laneAngles:Array.from({length:C.lanes.n},(_,i)=>yaw+i*Math.PI*2/C.lanes.n),
  sector:{visible:true},laneMeshes:[],cool:{},_team:()=>[],dome:{visible:true,position:{x:center[0],y:center[1],z:center[2]}},bar:{ult(){},boom(){}},say(){},s:{title:'source'},
  m:{ground,fx:{explode:(p,size,big)=>blasts.push({pos:p,size,big:!!big})},drive:{trauma:.1,player:{}},hud:{retitle(){}}}};
 method.call(boss);cases.push({kind,yaw,pos,center,seed:842648926,blasts,trauma:boss.m.drive.trauma});
}
const block=sources.storyMission.text.match(/if \( ! e\.flee && ! e\.scripted && ! e\.noBlast \) \{[\s\S]*?\n\t\t\t\t\}/)[0];
const death=vm.runInNewContext('(function(u,e,d){'+block+'})',{Math});
const deaths=[];
for(const e of [{},{boss:true},{flee:.3},{scripted:true},{noBlast:true}])for(const distance of [0,35,90]){
 const blasts=[],u={pos:[distance,2,0],spec:{bounds:{radius:e.boss?8:3}}},d={player:{pos:[0,2,0]},trauma:.1};
 death.call({lastKill:u.pos,fx:{explode:(p,size,big)=>blasts.push({pos:p,size,big:!!big})}},u,e,d);
 deaths.push({entry:e,distance,radius:u.spec.bounds.radius,blasts,trauma:d.trauma});
}
fs.writeFileSync('tools/migration/source-story-explosion-fixtures.json',JSON.stringify({source:{commit:baseline.commit,files:Object.values(sources).map(({text,...item})=>item)},cases,deaths}));
console.log(JSON.stringify({bossCases:cases.length,deathCases:deaths.length,blasts:cases.reduce((n,c)=>n+c.blasts.length,0)}));

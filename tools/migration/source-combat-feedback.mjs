import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const {RecoveryMix}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/audio/recoveryMix.js')));
const scenarios=[
 [{h:1,t:0},{h:1,t:1},{h:1,t:2}],
 [{h:.5,t:0},{h:.6,t:.1,event:'unitHealed',id:'heal'},{h:.6,t:.2,event:'unitHealed',id:'heal'},{h:.7,t:.5,event:'partRestored'},{h:.7,t:.94},{h:.7,t:.951},{h:1,t:1,event:'unitHealed'},{h:1,t:2}],
 [{h:.24,t:0},{h:.24,t:2},{h:.28,t:3},{h:.31,t:4},{h:.24,t:6}],
 [{h:1,t:0},{h:0,t:1,alive:false,event:'unitKilled'},{h:1,t:2,event:'unitSpawn'},{h:1,t:3}],
 [{h:.6,t:0,event:'partRestored'},{h:1,t:1,replace:true,event:'unitSpawn'},{h:1,t:2}],
];
const cases=[];
for(const steps of scenarios){
 let plays=[],loop;const player={stop(){},play:(id,options={})=>plays.push({id,rate:options.rate||1}),setListener(){},setLoop:(id,amount,rate)=>loop={amount,rate}};
 const mix=new RecoveryMix(player),saved=new Map();let unit={alive:true,env:{time:0},pos:[0,0,0],life:1};const trace=[];
 const camera={matrixWorld:{elements:[1,0,0,0,0,1,0,0,0,0,1,0]},position:{toArray:()=>[0,0,0]}};
 for(const step of steps){
  if(step.replace)unit={alive:true,env:{time:0},pos:[0,0,0],life:1};
  unit.alive=step.alive!==false;unit.life=step.h;unit.env.time=step.t;plays=[];
  const events=[];if(step.event){let e=step.id&&saved.get(step.id);if(!e){e={type:step.event,unit};if(step.id)saved.set(step.id,e);}events.push(e);}
  mix.consume(events,unit,camera);trace.push({step,plays,loop});
 }
 cases.push(trace);
}
fs.writeFileSync(path.join(root,'tools/migration/source-combat-feedback.json'),JSON.stringify({baseline:baseline.commit,cases}));
console.log(`Executed frozen RecoveryMix: ${cases.reduce((n,c)=>n+c.length,0)} observations`);

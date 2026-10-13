import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const root=process.cwd();const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const {ConquestRules,EscortRules}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/battle/match.js')));
const {findMatch}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/battle/matchmaker.js')));
const cases=[];
for(const mode of ['conquest','escort']){
 const rule=mode==='conquest'?new ConquestRules():new EscortRules(undefined,420),steps=[];
 for(let i=0;i<1600;i++){
  const world=mode==='conquest'?{inPoint:{A:{blue:i%150<100?2:0,red:i%150>=100?1:0},B:{blue:0,red:i%200<100?3:0},C:{blue:i%240<160?1:0,red:i%240<60?1:0}}}:{near:{blue:i%100<85?2:0,red:i%100>=70?2:0}};
  rule.step(.5,world);let kill,steal;
  if(mode==='conquest'&&i%97===0){kill=i%2?'red':'blue';rule.kill(kill);}
  if(mode==='conquest'&&i%101===0){steal=i%2?'red':'blue';rule.steal(steal,300);}
  const snapshot={state:rule.state,t:rule.t,score:rule.score,winner:rule.winner};
  if(mode==='conquest')Object.assign(snapshot,{points:rule.points.map(p=>({v:p.v,owner:p.owner,contested:p.contested})),shield:rule.shield});
  else Object.assign(snapshot,{s:rule.s,half:rule.half,passed:rule.passed,attack:rule.attack,contested:rule.contested,overtime:rule.overtime});
  steps.push({dt:.5,world,kill,steal,...(i%20===0||i===1599?{snapshot:JSON.parse(JSON.stringify(snapshot))}:{})});
 }
 cases.push({mode,steps});
}
fs.writeFileSync('tools/migration/battle-rule-reference.json',JSON.stringify({source:baseline.commit,cases,roster:findMatch({size:4,tier:3,seed:90862445})}));
console.log('Generated original H5 rule replays for two modes');

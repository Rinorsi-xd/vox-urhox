import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const file='three/src/battle/storyBoss.js',bytes=fs.readFileSync(`${baseline.snapshot}/${file}`),sha=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha!==baseline.files[file].sha256)throw Error('Frozen source drift');
let wall=0,cinematic=false;
const context=vm.createContext({THREE:{Vector3:class{}},performance:{now:()=>wall},document:{body:{classList:{contains:()=>cinematic}}}});
vm.runInContext(bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.KIND=BOSS_KIND;',context);
function run(test){
 wall=0;const flow={},m={bossFlow:flow,hud:{comms:{skipLine(){}}}},frames=[];
 for(const s of test.steps){
  wall+=s.dt*1000;cinematic=s.cine;
  if(s.newFlow)m.bossFlow={};
  if(s.down)context.KIND.key(m,{}, {code:'Enter',repeat:!s.press,preventDefault(){}});
  frames.push({skip:!!m.bossFlow.skip});
 }
 m.bossFlow.stage='ending';m.bossFlow.t=4;m.bossFlow.open=0;
 m.hud.queue=[];m.hud.banner=()=>{};m.ground=()=>0;
 m.boss={unit:{pos:[0,0,0]},update(){},cine(){},cockpit:()=>[0,0,0],look(){},group:{remove(){}}};
 const endingSkipped=context.KIND.update(m,{},0);
 return {frames,endingSkipped};
}
const cases=[];const add=test=>cases.push({test,expected:run(test)});
add({name:'fight-release-ending',steps:[{dt:0,cine:false,down:true,press:true},{dt:1.2,cine:false,down:true},{dt:.1,cine:false,down:false},{dt:.1,cine:true,down:false,newFlow:true}]});
add({name:'held-across-fight-ending',steps:[{dt:0,cine:false,down:true,press:true},{dt:1.2,cine:false,down:true},{dt:.1,cine:true,down:true,newFlow:true},{dt:2,cine:true,down:true}]});
add({name:'fresh-cinematic-threshold',steps:[{dt:0,cine:true,down:true,press:true},{dt:.9,cine:true,down:true},{dt:.0001,cine:true,down:true}]});
add({name:'release-repress-resets',steps:[{dt:0,cine:true,down:true,press:true},{dt:.8,cine:true,down:true},{dt:.2,cine:true,down:false},{dt:0,cine:true,down:true,press:true},{dt:.8,cine:true,down:true},{dt:.101,cine:true,down:true}]});
add({name:'cross-cinematic-flow-requires-fresh-press',steps:[{dt:0,cine:true,down:true,press:true},{dt:.6,cine:true,down:true},{dt:.6,cine:true,down:true,newFlow:true},{dt:.7,cine:true,down:true},{dt:0,cine:true,down:false},{dt:0,cine:true,down:true,press:true},{dt:.901,cine:true,down:true}]});
add({name:'first-press-does-not-charge-previous-frame',steps:[{dt:1.2,cine:true,down:true,press:true},{dt:.8,cine:true,down:true},{dt:.101,cine:true,down:true}]});
// Real H5 reuses F through intro/fight/ending and never clears holdAt. Lua
// deliberately requires a fresh press on its replacement ending flow.
const historicalDifferences=[];
for(const held of [false,true]){
 const test={name:held?'stale-intro-hold-through-fight-ending':'stale-intro-release-fight-ending',steps:[
  {dt:0,cine:true,down:true,press:true},
  {dt:.1,cine:true,down:held},
  {dt:2,cine:false,down:held},
  {dt:.1,cine:true,down:true,luaNewFlow:true},
 ]};
 historicalDifferences.push({test,source:run(test),expectedCurrent:{frames:test.steps.map(()=>({skip:false})),endingSkipped:false}});
}
console.log(JSON.stringify({source:{commit:baseline.commit,files:{[file]:sha}},cases,historicalDifferences}));

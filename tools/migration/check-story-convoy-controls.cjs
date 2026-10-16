// Detector controls only. This does not simulate or complete a game mission.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const api=require('./story-convoy-acceptance.cjs'),root=path.resolve(__dirname,'../..');
const payload=require('../../assets/Story/Mission/Level2.json'),level=payload.level,step=level.steps.find(s=>s.kind==='escort');
const baseline=require('../../docs/migration/outgame-baseline.json'),source='shared/story/level2.js',sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert.equal(sha(fs.readFileSync(path.join(baseline.snapshot,source))),baseline.files[source].sha256);
assert.equal(payload.source.scriptSha256,baseline.files[source].sha256,'older import metadata has actual 10/15 source bytes');
let checks=2;
function run(mutate){
 const tracker=api.create(level),states=[
  {step:'meet',d:0,cp:0},
  {step:'convoy',d:0,cp:0,choice:step.ask},
  {step:'convoy',d:160,cp:0,flags:{rate:1},enemies:3,blocked:true},
  {step:'convoy',d:350,cp:1,flags:{rate:1}},
  {step:'convoy',d:510,cp:1,flags:{rate:1},enemies:4,blocked:true},
  {step:'convoy',d:610,cp:1,flags:{rate:1},choice:step.beats.find(b=>b.ask).ask},
  {step:'convoy',d:700,cp:2,flags:{rate:1,road:2}},
  {step:'convoy',d:780,cp:2,flags:{rate:1,road:2},enemies:3,blocked:true},
  {d:1000,cp:2,flags:{rate:1,road:2},finished:true,grade:'A',stats:{checkpoints:3,truckHp:.8,kills:8,deaths:0,fails:0}}
 ].map((r,i)=>({id:'s2',time:400,enemies:r.enemies||0,stats:r.stats||{},...r,truck:{pos:[0,0,r.d],d:r.d,total:1000,cp:r.cp,hp:.8,blocked:r.blocked===true},wallMs:i*1000}));
 if(mutate)mutate(states,tracker);
 for(const s of states){api.observe(tracker,s,s.wallMs,(ok,label)=>{assert(ok,label);checks++;});if(s.choice){const key=api.option(tracker,s.choice,s.wallMs+50);assert.equal(key,s.choice.id==='rate'?'2':'3');checks++;}}
 assert.equal(tracker.result,'FUNCTIONAL_PASS');assert.equal(tracker.encounterIdentity.result,'OPEN');return tracker;
}
const accepted=run();let rejected=0;
for(const [label,mutate]of [
 ['complete without meet',rows=>rows.shift()],
 ['default score choice',rows=>rows.forEach(s=>{if(s.flags?.rate!==undefined)s.flags.rate=0;})],
 ['wrong road choice',rows=>rows.forEach(s=>{if(s.flags?.road!==undefined)s.flags.road=0;})],
 ['missing checkpoint one',rows=>rows.forEach(s=>{if(s.truck.cp===1)s.truck.cp=0;})],
 ['missing checkpoint two',rows=>rows.forEach(s=>{if(s.truck.cp===2)s.truck.cp=1;})],
 ['not fully delivered',rows=>{rows.at(-1).truck.d=990;}],
 ['destroyed transport',rows=>{rows.at(-1).stats.truckHp=0;}],
 ['missing final checkpoint',rows=>{rows.at(-1).stats.checkpoints=2;}],
 ['missing actual result grade',rows=>{delete rows.at(-1).grade;}],
 ['incorrect actual result grade',rows=>{rows.at(-1).grade='S';}],
 ['result HP differs from actual convoy',rows=>{rows.at(-1).truck.hp=.9;}],
 ['no actual choice input',rows=>rows.forEach(s=>{delete s.choice;})]
 ]){assert.throws(()=>run(mutate),label);rejected++;}
const tracker=api.create(level);api.observe(tracker,{id:'s2',step:'convoy',choice:step.ask},0,assert);assert.throws(()=>api.option(tracker,step.ask,12000));rejected++;
const survivor=run(rows=>rows.forEach(s=>{s.enemies=1;if(s.stats)s.stats.kills=0;}));
assert(survivor.encounterWindows.every(w=>w.maxEnemies===1));
assert.equal(survivor.result,'FUNCTIONAL_PASS');
assert.equal(survivor.encounterIdentity.result,'OPEN','one survivor must never sign off three separate waves');checks+=3;rejected++;
const retry=api.create(level);
api.observe(retry,{id:'s2',step:'convoy',choice:step.ask},0,assert);
assert.equal(api.option(retry,step.ask,50),'2');
api.observe(retry,{id:'s2',step:'convoy'},1000,assert);
api.observe(retry,{id:'s2',step:'convoy',choice:step.ask},20000,assert);
assert.equal(retry.choices.rate.seenAt,20000);
assert.equal(api.option(retry,step.ask,20050),'2');checks+=3;
api.observe(retry,{id:'s2',step:'convoy',choice:step.ask},31000,assert);
assert.equal(retry.choices.rate.seenAt,20000);checks++;
assert.throws(()=>api.option(retry,step.ask,32000),'repeated samples cannot extend a single choice timeout');rejected++;
for(const [time,deaths,fails,truckHp,grade]of [
 [329.999,0,0,1,'S'],[330,0,0,1,'A'],[480,0,0,1,'B'],
 [100,1,0,1,'A'],[100,0,1,1,'A'],[100,1,1,1,'B'],
 [100,0,0,.7,'S'],[100,0,0,.6999,'A'],[100,0,0,.35,'A'],[100,0,0,.3499,'B'],
 [600,0,0,.6,'B'],[100,2,0,.6,'B']]){
 assert.equal(api.expectedGrade(level.par,{time,stats:{deaths,fails,truckHp}}),grade);checks++;
}
const files=['tools/migration/story-convoy-acceptance.cjs','tools/migration/check-story-convoy-controls.cjs','tools/migration/check-story-natural-web.cjs'];
const report={result:'PASS',checks,negativeControls:rejected,baseline:baseline.commit,sourceSha256:baseline.files[source].sha256,detectorExample:accepted,singleSurvivorCounterexample:survivor,
 inputs:Object.fromEntries(files.map(p=>[p,sha(fs.readFileSync(path.join(root,p)))])),boundary:'CPU observer and input-selection controls over synthetic telemetry. No browser, GPU, native mission, driving, combat, performance or completion evidence.'};
fs.writeFileSync(path.join(root,'docs/migration/evidence/story-convoy-controls-offline.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({result:report.result,checks,negativeControls:rejected}));

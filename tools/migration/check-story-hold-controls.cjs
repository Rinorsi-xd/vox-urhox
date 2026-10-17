const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const api=require('./story-hold-acceptance.cjs'),level=require('../../assets/Story/Mission/Level3.json').level;
const baseline=require('../../docs/migration/outgame-baseline.json'),source='shared/story/level3.js';
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert.equal(hash(path.join(baseline.snapshot,source)),baseline.files[source].sha256);
assert.equal(require('../../assets/Story/Mission/Level3.json').source.scriptSha256,baseline.files[source].sha256);
const choices=[level.steps.find(s=>s.id==='parley').ask,level.steps.find(s=>s.id==='hold').beats.find(b=>b.ask).ask];
let checks=2;
function test(mutate){
 const rows=[
  {step:'gate',time:2},{step:'parley',time:5,choice:choices[0]},
  {step:'hold',time:20,hold:{left:120,energy:1},flags:{surrender:2}},
  {step:'hold',time:78,hold:{left:66,energy:.8},choice:choices[1],flags:{surrender:2}},
  {step:'hold',time:143,hold:{left:1,energy:.6},flags:{surrender:2,lunch:1}},
  {step:'coupon',time:144,target:[0,6.2,-214],flags:{surrender:2,lunch:1},shield:.6},
  {time:180,finished:true,grade:'S',flags:{surrender:2,lunch:1},intel:1,shield:.6}
 ].map((s,i)=>({id:'s3',wallMs:i*1000,stats:{intel:s.intel||0,shield:s.shield,deaths:0,fails:0},...s}));
 const run=api.create(level);if(mutate)mutate(rows,run);
 for(const s of rows){api.observe(run,s,s.wallMs,(ok,label)=>{assert(ok,label);checks++;});if(s.choice){api.option(run,s.choice,s.wallMs+20);checks++;}}
 assert.equal(run.result,'FUNCTIONAL_PASS');assert.equal(run.waveIdentity.result,'OPEN');return run;
}
const example=test();let negatives=0;
for(const [label,change]of [
 ['missing objective',r=>r.shift()],['default lunch',r=>r.forEach(s=>{if(s.flags?.lunch!==undefined)s.flags.lunch=0;})],
 ['no actual input',r=>r.forEach(s=>delete s.choice)],['hold starts late',r=>r[2].hold.left=100],
 ['hold never reaches end',r=>r[4].hold.left=50],['shortened hold',r=>r[5].time=100],
 ['coupon not picked',r=>r.at(-1).stats.intel=0],['no coupon target',r=>delete r[5].target],
 ['shield destroyed',r=>r.at(-1).stats.shield=0],['wrong grade',r=>r.at(-1).grade='B'],
 ['incomplete successful retry',r=>{r[4].stats.fails=1;r[5].stats.fails=1;r[6].stats.fails=1;}]
 ]){assert.throws(()=>test(change),label);negatives++;}
const waiting=api.create(level);api.observe(waiting,{id:'s3',choice:choices[1]},0,assert);
api.observe(waiting,{id:'s3',choice:choices[1]},9000,assert);
assert.throws(()=>api.option(waiting,choices[1],10000),'Repeated snapshots do not extend choice timeout');negatives++;
for(const [time,deaths,fails,shield,wanted]of [[239.9,0,0,1,'S'],[240,0,0,1,'A'],[360,0,0,1,'B'],[100,0,0,.29,'A'],[100,0,0,.3,'S'],[100,1,1,1,'B']]){assert.equal(api.grade(example,{time,stats:{deaths,fails,shield}}),wanted);checks++;}
const retry=api.create(level),observeRetry=s=>api.observe(retry,{id:'s3',step:'hold',time:20,stats:{fails:0},hold:{left:120,energy:1},...s},0,assert);
observeRetry({});observeRetry({time:63.66,failing:true,stats:{fails:1},hold:{left:81.03,energy:-.00045}});
assert.equal(retry.attempts.length,1,'Failure dialogue retains the old attempt rather than creating a false retry');checks++;
observeRetry({time:70,failing:false,stats:{fails:1},hold:{left:120,energy:1}});
assert.equal(retry.attempts.length,2);assert.equal(retry.attempts[1].firstLeft,120);assert.equal(retry.attempts[1].startTime,70);checks+=3;
observeRetry({time:71,failing:false,stats:{fails:1},hold:{left:119,energy:.99}});
assert.equal(retry.attempts.length,2,'One active retry keeps one independent countdown');checks++;
const vm=require('node:vm'),helper=fs.readFileSync(path.join(__dirname,'story-hold-acceptance.cjs'),'utf8');
assert(helper.includes("s.step==='hold'&&s.hold&&!s.failing"));
const mutant={exports:{}};vm.runInNewContext(helper.replace("s.step==='hold'&&s.hold&&!s.failing","s.step==='hold'&&s.hold"),{module:mutant,require,structuredClone});
const bad=mutant.exports.create(level);mutant.exports.observe(bad,{id:'s3',step:'hold',failing:true,time:63.66,stats:{fails:1},hold:{left:81.03,energy:-.00045}},0,assert);
assert.notEqual(bad.attempts.length,0,'Negative control exposes false attempt registration during failure dialogue');negatives++;checks++;
const inputs=Object.fromEntries(['tools/migration/story-hold-acceptance.cjs','tools/migration/check-story-hold-controls.cjs','tools/migration/check-story-natural-web.cjs'].map(f=>[f,hash(path.resolve(__dirname,'../..',f))]));
const report={result:'PASS',checks,negativeControls:negatives,baseline:baseline.commit,sourceSha256:baseline.files[source].sha256,inputs,example,
 boundary:'CPU observer controls using synthetic telemetry; not an actual hold, natural completion, Lua behavior, browser, rendered or performance acceptance.'};
fs.writeFileSync(path.resolve(__dirname,'../../docs/migration/evidence/story-hold-controls-offline.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({result:'PASS',checks,negativeControls:negatives}));

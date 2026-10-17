const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),runner=path.join(__dirname,'check-story-natural-web.cjs');
const source=fs.readFileSync(runner,'utf8'),start=source.indexOf('   const sample={at:'),end=source.indexOf('report.samples.push(sample);',start);
assert(start>=0&&end>start,'Actual natural-runner sample block exists');
const block=source.slice(start,end+'report.samples.push(sample);'.length);
let checks=0;
function execute(code,state){
 const context={state,s:state.story,held:new Set(['w']),firing:true,begun:1000,Date:{now:()=>1500},structuredClone,report:{samples:[]}};
 vm.runInNewContext(code,context);return context.report.samples[0];
}
function controls(code){
 const weapons={energy:.71,shots:41,hits:79,kills:2,blocked:1,turning:0};
 const pointer={captured:true,left:true,fire:true};
 const storyCombat={units:[{id:1,bodyHp:700,struct:100}],muzzles:[{hit:{ownerType:'wall',collider:17}}]};
 const state={story:{id:'s3',stats:{fails:0}},vehicle:{position:[0,6,-234]},weapons,pointer,storyCombat,performance:{arrayBytes:256}};
 const sample=execute(code,state);
 assert.deepEqual(sample.weapons,weapons);assert.notEqual(sample.weapons,weapons);
 assert.deepEqual(sample.pointer,pointer);assert.notEqual(sample.pointer,pointer);
 assert.deepEqual(sample.storyCombat,storyCombat);assert.notEqual(sample.storyCombat,storyCombat);
 assert.deepEqual(Array.from(sample.keys),['w']);assert.equal(sample.firing,true);assert.equal(sample.at,500);
 weapons.shots=42;pointer.captured=false;storyCombat.units[0].bodyHp=650;
 assert.equal(sample.weapons.shots,41);assert.equal(sample.pointer.captured,true);
 assert.equal(sample.storyCombat.units[0].bodyHp,700);
 const missing=execute(code,{story:state.story,vehicle:state.vehicle});
 assert.equal(missing.weapons,null);assert.equal(missing.pointer,null);assert.equal(missing.storyCombat,null);
 // Existing world hit counts include NPC hits; observations must not clamp them to player shots.
 assert.equal(sample.weapons.hits,79);
}
controls(block);checks++;
const rejected=[];
for(const [name,before,after]of [
 ['discard weapon evidence','weapons:structuredClone(state.weapons||null)','weapons:null'],
 ['keep mutable counter alias','weapons:structuredClone(state.weapons||null)','weapons:state.weapons||null'],
 ['discard actual capture state','pointer:structuredClone(state.pointer||null)','pointer:null'],
 ['invent zero counters when unavailable','state.weapons||null','state.weapons||{shots:0,hits:0}']
]){
 assert(block.includes(before));assert.throws(()=>controls(block.replace(before,after)),name);rejected.push(name);checks++;
}
const report={result:'PASS',checks,rejectedMutations:rejected,
 inputs:Object.fromEntries([runner,__filename,path.join(__dirname,'story-route-observer.lua')].map(file=>[path.relative(root,file).replaceAll('\\','/'),crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')])),
 boundary:'Executes the actual runner recording block in a controlled CPU context. Preserves existing observations and missing values; does not create a shot/hit/kill, prove line of sight, assert a player hit rate, run gameplay or measure performance.'};
fs.writeFileSync(path.join(root,'docs/migration/evidence/story-hold-combat-observation-offline.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));

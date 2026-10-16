const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const helperFile=path.join(__dirname,'story-boss-natural-input.cjs'),source=fs.readFileSync(helperFile,'utf8');
const {bossPlan}=require('./story-boss-natural-input.cjs'),{aimSolution}=require('./story-natural-input.cjs');
let checks=0;const check=(ok,label)=>{assert.ok(ok,label);checks++;};
function state(){return {vehicle:{position:[0,5,0]},story:{target:[0,5,60],marker:{kind:'enemy'},boss:{flow:'fight',state:'fight',cinematic:false,kneel:false,braced:false,cockpit:[0,20,60],nodes:[
 {hp:100,broken:false,pos:[-8,4,50]}, {hp:100,broken:false,pos:[8,4,50]}, {hp:0,broken:true,pos:[0,4,40]}, {hp:100,broken:false,pos:[0,4,70]}],targetViews:{nodes:[{x:.2,y:.5,behind:false},{x:.8,y:.5,behind:false},{x:.5,y:.5,behind:false},{x:.5,y:.5,behind:false}],cockpit:{x:.5,y:.3,behind:false}}}}};}
function verify(api){
 let s=state(),plan=api.bossPlan(s);assert.equal(plan.targetKey,'node:0');assert.deepEqual(Array.from(plan.point),s.story.boss.nodes[0].pos);
 s.story.marker.kind='goal';plan=api.bossPlan(s);assert.equal(plan.reason,'shelter-navigation');assert.equal(plan.firing,false);assert.equal(plan.point,null);
 s=state();s.story.boss.kneel=true;plan=api.bossPlan(s);assert.equal(plan.targetKey,'cockpit');assert.deepEqual(Array.from(plan.point),s.story.boss.cockpit);
 s=state();s.story.boss.braced=true;assert.equal(api.bossPlan(s).targetKey,'cockpit');
 s=state();delete s.story.boss.cockpit;assert.equal(api.bossPlan(s).firing,false);
 s=state();s.story.boss.targetViews.nodes[0].behind=true;assert.equal(api.bossPlan(s).targetKey,'node:1');
 return 6;
}
checks+=verify({bossPlan});
check(bossPlan({story:{}})===null,'ordinary mission does not enter boss controller');
for(const phase of ['wait','introCine','talk','ending','done']){const s=state();s.story.boss.flow=phase;const p=bossPlan(s);check(!p.firing&&!p.point&&p.reason==='natural-cinematic-wait','authored '+phase+' never sends cinematic skip or fake damage');}
for(const phase of ['idle','intro','standoff','dying','dead']){const s=state();s.story.boss.state=phase;check(!bossPlan(s).firing,'nonattackable '+phase+' never fires');}
for(const phase of ['fight','stomp','sweep','lanes','ult','recover','slamCrouch','slamAir','stuck','rise','barrage','transition']){const s=state();s.story.boss.state=phase;check(bossPlan(s).firing,'source damage-allowed '+phase+' can target a real node');}
let s=state();s.story.boss.nodes.forEach(n=>{n.broken=true;n.hp=0;});check(bossPlan(s).reason==='exposed-cockpit','all four nodes broken targets cockpit');
s=state();delete s.story.boss.braced;check(bossPlan(s).reason==='missing-read-only-boss-observer','post-rise armor is not guessed from state');
s=state();s.story.boss.kneel=true;const p=bossPlan(s),camera={position:[0,20,0],yaw:0,pitch:0};
const aim=aimSolution(camera,p.legacyAimTarget,{},0);check(aim.dx===0&&aim.dy===0,'actual existing mouse helper aims at precise observed cockpit with no extra height');
const before=JSON.stringify(s);bossPlan(s);check(JSON.stringify(s)===before,'selection does not mutate observed gameplay state');
const rejectedMutations=[];
for(const [name,beforeText,afterText]of [
 ['shoot shelter marker',"story.marker?.kind==='goal'","false"],
 ['shoot cockpit instead of live leg','!boss.kneel&&!boss.braced&&live.length','false'],
 ['ignore kneeling window','!boss.kneel&&!boss.braced&&live.length','!boss.braced&&live.length'],
 ['ignore braced armor','!boss.kneel&&!boss.braced&&live.length','!boss.kneel&&live.length'],
 ['invent missing cockpit','!point(boss.cockpit)','false'],
 ['ignore behind-camera target visibility','Number(onScreen(b.view))-Number(onScreen(a.view))||',''],
 ]){
 assert.ok(source.includes(beforeText),'mutation anchor '+name);const module={exports:{}};
 vm.runInNewContext(source.replace(beforeText,afterText),{module,exports:module.exports});
 assert.throws(()=>verify(module.exports),'negative control '+name);checks++;rejectedMutations.push(name);
}
const sha=text=>crypto.createHash('sha256').update(text).digest('hex');
const report={result:'PASS',checks,rejectedMutations,helperSha256:sha(source),testSha256:sha(fs.readFileSync(__filename)),
 requiredReadOnlyFields:['story.boss.cockpit = boss:Cockpit()','story.boss.braced = boss.rules:Braced()'],optionalProjectionFields:['story.boss.targetViews.nodes[index] = {x,y,behind}','story.boss.targetViews.cockpit = {x,y,behind}'],
 integration:{file:'tools/migration/check-story-natural-web.cjs',where:'after story target selection and before generic enemy aim/navigation',steps:[
 'Use bossPlan(state) only when state.story.boss exists; cinematic-wait releases keys and fire, then waits naturally.',
 'Use plan.goal for navigation. Shelter-navigation never fires. Use plan.point for exact observed aim; existing aimSolution accepts plan.legacyAimTarget to cancel its two-metre offset.',
 'Reset aimTracking on targetKey change. Use plan.stopRange instead of generic 25m boss approach stop. Do not turn cockpit height into a navigation waypoint.',
 'Require missing-read-only-boss-observer to fail or wait explicitly. Never invent cockpit or set node HP, boss state, mission clock.'
 ]},
 boundary:'Independent CPU candidate only. Current natural web script and original mouse helper unchanged. No probe edits, browser, GPU, new S4/S5 completion, physical line-of-sight, source damage change, cinematic skipping or mobile acceptance. Projection visibility cannot prove wall occlusion; original central ray and projectile collision remain authoritative.'};
fs.writeFileSync(path.join(__dirname,'../../docs/migration/evidence/story-boss-natural-input-offline.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));

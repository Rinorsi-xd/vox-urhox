const fs=require('node:fs'),assert=require('node:assert/strict'),path=require('node:path'),crypto=require('node:crypto');
const {NaturalProgress}=require('./salvage-natural-progress.cjs');
const root=path.resolve(__dirname,'../..'),rel='docs/migration/evidence/salvage-natural-manifest-14f59378-2026-10-15T20-28-45-360Z/salvage-natural-web.json';
const bytes=fs.readFileSync(path.join(root,rel)),old=JSON.parse(bytes),samples=[];
// The old report's per-leg wall clock restarts. Isolate the failed final leg.
for(let i=old.samples.length-1;i>=0;i--){samples.unshift(old.samples[i]);if(i===0||old.samples[i].at<old.samples[i-1].at)break;}
const p=new NaturalProgress(),triggers=[];
for(const sample of samples)if(p.update(sample.pos,sample.at))triggers.push(sample.at);
assert.ok(triggers.length>0&&triggers.every(at=>at<10000),'Initial recorded stationary obstruction still requests recovery; later moving tail must not reverse');
const still=new NaturalProgress();assert.equal(still.update([0,0,0],0),false);assert.equal(still.update([0,0,0],7001),true);
assert.equal(still.update([0,0,0],8000),true);assert.equal(still.update([0,0,0],8601),false);
assert.equal(still.update([0,0,0],15601),false);assert.equal(still.update([0,0,0],15602),true);
const moving=new NaturalProgress();for(let i=0;i<60;i++)assert.equal(moving.update([i*2,0,0],i*500),false);
const counts={realSamples:samples.length,oldReverseSamples:samples.filter(s=>s.keys.includes('s')).length,newReverseSamples:triggers.length};
assert.ok(counts.oldReverseSamples>counts.newReverseSamples,'Old route includes extra false reversals beyond the initial obstruction');
const closest=samples.reduce((a,b)=>a.distance<b.distance?a:b),last=samples.at(-1);
const report={result:'PASS',sourceReport:rel,sourceReportSha256:crypto.createHash('sha256').update(bytes).digest('hex'),counts,
 closest:{at:closest.at,distance:closest.distance,hp:closest.hp},last:{at:last.at,distance:last.distance,hp:last.hp},
 routeStillFailed:true,boundary:'Read-only replay of already failed real key route, plus stationary/recovery controls. Initial 7s near-stationary obstruction remains a valid recovery; the old best-ever-distance detector subsequently falsely reversed a moving vehicle. This does not prove terrain clearance, natural extraction, settlement, or game performance. Production vehicle/maps remain unchanged.'};
const out=path.join(root,'docs/migration/evidence/salvage-natural-progress-offline.json');fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));

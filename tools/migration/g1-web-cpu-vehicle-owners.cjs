'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const folder='docs/migration/evidence/performance-trial-sections-match-1792173507902';
const result=JSON.parse(fs.readFileSync(path.join(root,folder,'result.json'),'utf8'));
assert.equal(result.shutdown,'CLOSED');assert.equal(result.errors.length,0);assert.equal(result.httpErrors.length,0);
assert.equal(result.measurementResult,'PASS');
const stored=JSON.parse(fs.readFileSync(path.join(root,folder,'drive-sections-summary.json'),'utf8'));
const records=fs.readFileSync(path.join(root,folder,'drive-sections.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
const computed=require('./analyze-drive-sections-web.cjs').summarize(records,{afterFrame:5,throughFrame:252});
assert.deepEqual(computed,stored,'Raw records match archived summary');
const names=new Map(),frames=[];
for(const record of records){record.names.forEach((n,i)=>names.set(i+1,n));for(const f of record.frames)if(f.frame>5&&f.frame<=252)frames.push(f)}
assert.equal(frames.length,247);
const direct=['suspension.Sample','contact.Step','stability.Step','hover.Step','hover.Motion','leg.Step','legHitboxes.Update','thruster.Step','wing.Step','suspension.Apply'];
const rays=['suspension.Sample','stability.Step','hover.Step','leg.Cast'];
const stats=new Map(computed.rows.map(r=>[r.name,r]));
const perFrame=[],scopes={};
for(const frame of frames){
 const rows=new Map(frame.values.map(v=>[names.get(v[0]),{calls:v[1],ms:v[2],self:v[3],max:v[4]}]));
 const get=n=>rows.get(n)||{calls:0,ms:0,self:0,max:0};
 const parent=get('vehicle.Step'),child=direct.reduce((s,n)=>s+get(n).ms,0);
 assert.equal(parent.ms,parent.self+child,'Vehicle direct subtree conservation frame '+frame.frame);
 const vehicleRayMs=rays.reduce((s,n)=>s+get(n).ms-get(n).self,0);
 assert(vehicleRayMs<=get('physics.Raycast').ms,'Vehicle ray wall <= global ray wall');
 const legSelf=[...rows].filter(([name])=>/^(leg\.|gait\.)/.test(name)).reduce((s,[,v])=>s+v.self,0);
 assert.equal(get('leg.Step').ms,legSelf+get('leg.Cast').ms-get('leg.Cast').self,'Leg subtree conservation');
 perFrame.push({frame:frame.frame,vehicleMs:parent.ms,vehicleSelfMs:parent.self,vehicleSupportRayMs:vehicleRayMs});
 for(const name of ['vehicle.Step',...direct,'physics.Raycast']){
  if(!scopes[name])scopes[name]=[];scopes[name].push(get(name));
 }
}
function percentile(v,p){const sorted=[...v].sort((a,b)=>a-b);return sorted[Math.ceil(sorted.length*p)-1]}
const distributions=Object.entries(scopes).map(([name,rows])=>({name,
 inclusiveMsPerFrame:stats.get(name).inclusiveMsPerFrame,selfMsPerFrame:stats.get(name).selfMsPerFrame,
 frameInclusiveMedianMs:percentile(rows.map(r=>r.ms),.5),frameInclusiveP95Ms:percentile(rows.map(r=>r.ms),.95),
 framesWithCallAtLeast10Ms:rows.filter(r=>r.max>=10).length,
 inclusiveMsInFramesWithCallAtLeast10Ms:rows.filter(r=>r.max>=10).reduce((s,r)=>s+r.ms,0),
 calls:stats.get(name).calls}));
const sourceHashes={};
for(const file of ['drive/Vehicle.lua','drive/RaySuspension.lua','drive/LegControl.lua','drive/HoverControl.lua','drive/ChassisStability.lua','drive/LegHitboxes.lua']){
 const bytes=fs.readFileSync(path.join(result.identity.source_directory,'scripts',file));
 const hash=crypto.createHash('sha256').update(bytes).digest('hex');assert.equal(hash,result.identity.identity.scripts[file]);sourceHashes[file]=hash;
}
const rayTotal=perFrame.reduce((s,f)=>s+f.vehicleSupportRayMs,0);
const out={status:'PASS',source:folder,frames:247,fixedSteps:stats.get('physics.Step').calls,vehicleCalls:stats.get('vehicle.Step').calls,
 directChildren:direct.map(n=>stats.get(n)),vehicle:stats.get('vehicle.Step'),
 legRows:computed.rows.filter(r=>/^(leg\.|gait\.)/.test(r.name)),
 contactRows:computed.rows.filter(r=>/^contact\./.test(r.name)),
 reconstruction:{everyFrameVehicleDirectConserves:true,everyFrameLegSubtreeConserves:true,
 vehicleSupportRayMs:rayTotal,vehicleSupportRayMsPerFrame:rayTotal/247,globalRayMs:stats.get('physics.Raycast').inclusiveMs,
 globalOutsideVehicleRayMs:stats.get('physics.Raycast').inclusiveMs-rayTotal,
 derivation:'Sum (inclusive-self) for suspension.Sample, stability.Step, hover.Step and leg.Cast, whose only wrapped immediate children in the frozen source are physics.Raycast. Names are aggregated globally; exact caller event traces were not recorded.'},
 distributions,sourceHashes,
 boundary:'Read-only reanalysis of archived valid Web scopes. Integer wall time includes wrappers, GC and preemption; no new runtime run, exact CPU attribution, optimization benefit or mobile FPS claim.'};
fs.writeFileSync(path.join(root,'docs/migration/evidence/g1-web-cpu-vehicle-owners-102.json'),JSON.stringify(out,null,2)+'\n');
console.log(JSON.stringify(out,null,2));

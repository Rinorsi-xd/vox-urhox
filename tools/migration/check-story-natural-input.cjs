const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const {holdPlan,aimSolution}=require('./story-natural-input.cjs');
const navigation=require('./check-story-natural-web.cjs');
const root=path.resolve(__dirname,'../..'),level=require('../../assets/Story/Mission/Level3.json').level;
const hold=level.steps.find(s=>s.kind==='hold'),flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
let checks=0;const check=(ok,label)=>{assert.ok(ok,label);checks++;};
const enemy=(pos,extra={})=>({team:'red',pos,...extra});
check(holdPlan({kind:'reach'},[0,0,0],[])===null,'other mission kinds retain existing navigation');
const centre=hold.pos;
for(const targets of [undefined,null,[],JSON.parse('{}')]){
 const emptyPlan=holdPlan(hold,centre,targets);
 check(emptyPlan.park&&emptyPlan.target===null,'empty Lua/JSON target list keeps defense active');
}
const distant=enemy([11.248737335205078,2.76,-145.9541778564453]);
let plan=holdPlan(hold,centre,[distant]);
check(plan.park&&!plan.target&&plan.goal===centre,'actual first S3 distant enemy does not cause departure from shield');
const threat=enemy([5,5,-210]),near=enemy([0,5,-224]);
plan=holdPlan(hold,centre,[threat,near,distant,enemy([0,5,-230],{team:'blue'})]);
check(plan.park&&plan.target===near.pos,'stationary defense selects nearest hostile inside authored drain radius');
check(!holdPlan(hold,[0,2.72,-167.31],[near]).park,'checkpoint below fortress still drives toward shield');
check(navigation.needsRoad([0,-1.58,-167.31],centre,true),'actual checkpoint return uses road navigation across height');
check(!holdPlan(hold,centre,[enemy([0,6,centre[2]+hold.drainR])]).target,'strict drain boundary is not an active threat');
check(!holdPlan(hold,[0,6,-260],[enemy([0,6,-189])]).target,'target outside conservative seventy-metre engagement limit is ignored');
check(!holdPlan(hold,[0,6,centre[2]+hold.healR*.65],[]).park,'park boundary remains strictly inside repair circle');
check(holdPlan(hold,[0,6,centre[2]+hold.healR*.65-.01],[]).park,'driver stops with a repair-circle margin');
const camera={position:[0,10,0],yaw:0,pitch:0};
let a=aimSolution(camera,[0,8,100],{},0);
check(a.dx===0&&a.dy===0,'stationary target preserves original two-metre aim height');
a=aimSolution({...camera,yaw:179},[0,8,-100],{},0);
check(Math.abs(a.dx)<8,'yaw crossing positive pi takes short route');
a=aimSolution({...camera,yaw:-179},[0,8,-100],{},0);
check(Math.abs(a.dx)<8,'yaw crossing negative pi takes short route');
let tracking={};aimSolution(camera,[0,8,100],tracking,0);
a=aimSolution(camera,[1,8,100],tracking,100);
check(Math.abs(a.lead[0]-1)<1e-9&&a.lead[1]===0,'actual target movement provides bounded horizontal lead');
a=aimSolution(camera,[100,8,100],tracking,200);
check(a.lead.every(v=>v===0),'enemy identity jump is not extrapolated as velocity');
a=aimSolution(camera,[100,8,102],tracking,900);
check(a.lead.every(v=>v===0),'stale samples are never used for velocity');
tracking={};aimSolution(camera,[0,8,100],tracking,0);
a=aimSolution(camera,[3.5,8,100],tracking,100);
check(Math.abs(a.lead[0]-3.5)<1e-9,'maximum accepted lead is three and a half metres');
check(Math.abs(aimSolution(camera,[1000,1000,-1],{},0).dx)<=300&&Math.abs(aimSolution(camera,[1000,1000,-1],{},0).dy)<=200,'mouse input retains original physical movement caps');

function trackingRun(periodMs,predict){
 let yaw=0,pitch=0,time=0,track={},errors=[];
 while(time<5000){
  const angle=.27*Math.sin(time/1600),target=[Math.sin(angle)*25,8,Math.cos(angle)*25];
  const view={position:[0,10,0],yaw,pitch};
  let command;
  if(predict)command=aimSolution(view,target,track,time);
  else command={dx:Math.max(-300,Math.min(300,(-Math.atan2(target[0],target[2])-yaw*Math.PI/180)/.0024)),dy:0};
  // Public pointer input reaches the next update; soft-lock slows it to 55%.
  yaw+=command.dx*.0024*.55*180/Math.PI;
  time+=periodMs;
  const actual=.27*Math.sin(time/1600);
  if(time>1000)errors.push(Math.abs(actual+yaw*Math.PI/180)*180/Math.PI);
 }
 return {mean:errors.reduce((s,v)=>s+v,0)/errors.length,max:Math.max(...errors),samples:errors.length};
}
const oldTracking=trackingRun(450,false),newTracking=trackingRun(120,true);
check(newTracking.mean<oldTracking.mean*.4,'faster public mouse loop reduces moving-target lag under actual soft-lock response');
check(newTracking.max<3,'new moving-target simulation remains within three degrees');

function coreControls(api){
 assert.ok(api.holdPlan(hold,centre,JSON.parse('{}')).park);
 assert.ok(!api.holdPlan(hold,[0,6,centre[2]+16],[enemy([0,6,centre[2]+hold.drainR+1])]).target);
 assert.ok(!api.holdPlan(hold,[0,6,centre[2]+30],[]).park);
 assert.ok(api.holdPlan(hold,centre,[]).park);
 const track={};api.aimSolution(camera,[0,8,100],track,0);
 const next=api.aimSolution(camera,[1,8,100],track,100);
 assert.ok(Math.abs(next.lead[0]-1)<1e-9);
 const jump=api.aimSolution(camera,[100,8,100],track,200);
 assert.ok(jump.lead.every(v=>v===0));
 assert.ok(Math.abs(api.aimSolution({...camera,yaw:179},[0,8,-100],{},0).dx)<10);
}
coreControls({holdPlan,aimSolution});checks++;
const helperFile=path.join(__dirname,'story-natural-input.cjs'),helperSource=fs.readFileSync(helperFile,'utf8');
const mutations={
 'assume empty Lua table is a JavaScript array':['(Array.isArray(targets)?targets:[])','(targets||[])'],
 'pursue outside authored defense zone':['flat(t.pos,step.pos)<step.drainR','true'],
 'park outside repair circle':['step.healR*.65','step.healR*2'],
 'omit bounded target-motion lead':['v=>v*.10','v=>v*0'],
 'predict target-switch jumps':['Math.hypot(velocity[0],velocity[2])<=35','true'],
 'take full yaw revolution':['wrap(-Math.atan2(dx,dz)-camera.yaw*Math.PI/180)','(-Math.atan2(dx,dz)-camera.yaw*Math.PI/180)'],
};
const rejectedMutations=[];
for(const [label,[before,after]]of Object.entries(mutations)){
 assert.ok(helperSource.includes(before),'mutation anchor '+label);
 const module={exports:{}};vm.runInNewContext(helperSource.replace(before,after),{module,exports:module.exports});
 assert.throws(()=>coreControls(module.exports),'negative control '+label);checks++;rejectedMutations.push(label);
}

const evidenceFile=path.join(root,'docs/migration/evidence/story-natural-s3-manifest-848f4d10-2026-10-16T04-35-05-101Z/result.json');
let replay;
if(fs.existsSync(evidenceFile)){
 const original=JSON.parse(fs.readFileSync(evidenceFile)),samples=original.samples.filter(s=>s.story.step==='hold');
 const formerTrips=(original.routes||[]).filter(r=>r.step==='hold'&&r.target&&flat(r.target,centre)>hold.drainR&&flat(r.from,centre)<hold.healR);
 check(formerTrips.length>0,'preserved current old-tool run contains actual distant pursuit departures');
 for(const route of formerTrips){
  const alternative=holdPlan(hold,route.from,[enemy(route.target)]);
  check(alternative.park&&!alternative.target,'old distant pursuit becomes parked defense without changing gameplay');
 }
 replay={originalResult:original.result,oldToolSha:original.toolSha256,holdSamples:samples.length,formerDistantDepartures:formerTrips.length,
  path:path.relative(root,evidenceFile),sha256:crypto.createHash('sha256').update(fs.readFileSync(evidenceFile)).digest('hex')};
}
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const report={result:'PASS',checks,rejectedMutations,oldTracking,newTracking,replay,helperSha256:sha(helperFile),toolSha256:sha(path.join(__dirname,'check-story-natural-web.cjs')),
 boundary:'CPU verification of actual public-input helper functions and counterfactual decisions over preserved old natural samples. No browser, new mission completion, physical line-of-sight, production damage fix, rendering or mobile performance acceptance. Old result remains old-tool evidence.'};
fs.writeFileSync(path.join(root,'docs/migration/evidence/story-natural-input-offline.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));

// Offline controls for the actual natural-route helper functions. No browser.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'../..'),file=path.join(__dirname,'check-story-natural-web.cjs');
const source=fs.readFileSync(file,'utf8'),roads=require('../../assets/Crater/Layout.json');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function load(text){
 const module={exports:{}};
 vm.runInNewContext(text,{require:createRequire(file),module,exports:module.exports,__filename:file,__dirname,process,console,Buffer,setTimeout,structuredClone},{filename:file});
 return module.exports;
}
function verify(api){
 let checks=0;
 const check=(ok,label)=>{assert.ok(ok,label);checks++;};
 const progress={};
 check(!api.navigationProgress(progress,'k1',10,0),'first goal starts forward');
 check(!api.navigationProgress(progress,'k1',4,1000),'first goal makes progress');
 check(!api.navigationProgress(progress,'kW',70,9500),'new waypoint does not inherit old small distance');
 check(progress.best===70&&progress.stuckAt===9500,'new waypoint owns progress baseline');
 check(!api.navigationProgress(progress,'kW',60,12000),'new waypoint movement keeps forward');
 check(api.navigationProgress(progress,'kW',60,20001),'genuinely stationary waypoint still reverses');
 check(!api.navigationProgress(progress,'hBr',75,20500),'new waypoint cancels active old reverse');
 check(progress.reverseUntil===0,'old reverse deadline cleared');
 for(let i=1;i<=24;i++)check(!api.navigationProgress(progress,'hBr',75-i*2,20500+i*1000),'long advancing segment stays forward');
 check(api.navigationProgress(progress,'hBr',27,53501),'stationary recovery remains after sustained progress');
 const stacked=[{id:'upper',pos:[0,28,0]}];
 check(api.advanceRoute(stacked,[0,-12,0]).length===0&&stacked.length===1,'same XZ on lower level cannot pass upper waypoint');
 check(api.advanceRoute(stacked,[6,28,0]).length===0,'horizontal acceptance is still strictly below six metres');
 check(api.advanceRoute(stacked,[0,20,0]).length===0,'vertical acceptance is still strictly below eight metres');
 check(api.advanceRoute(stacked,[0,27,0]).length===1&&stacked.length===0,'actual upper arrival advances waypoint');
 const bow=api.roadRoute([-1.24003469944,26.9994945526,-19.559715271],[120,0,117],roads);
 check(bow.map(p=>p.id).join(',')==='k2,k1,kW,hBr,h3,h4,hiN1,hiN0,dB2,dB1,bN,pB','bow follows actual connected deck, bridge, highland and bow route');
 for(let i=1;i<bow.length;i++)check(roads.nav.edges.some(([a,b])=>a===bow[i-1].id&&b===bow[i].id||b===bow[i-1].id&&a===bow[i].id),'route uses an authored navigation edge');
 check(api.roadRoute([45,-12,-22],[45,-2,-70],roads)[0].id==='iS1','lower hull position selects lower node');
 check(api.roadRoute([45,28,-22],[45,-2,-70],roads)[0].id==='k1','deck position selects deck node');
 check(Math.abs(api.routeHeightError([0,0,0],[100,20,0],[50,9,0])+1)<1e-9,'height diagnostic interpolates ramp surface');
 check(api.routeHeightError([120,28,0],[198,20,0],[151,-12,-25])<-30,'fallen lower-level sample is distinguished from current bridge segment');
 const low=[-203.258056640625,-10.367635726928711,-156.5662841796875],pirate=[-119.67034912109375,2.570065975189209,-192.10348510742188];
 check(api.needsRoad(low,pirate,true),'actual S2 CP1 enemy pursuit requires roads from the lowland');
 const escape=api.roadRoute(low,pirate,roads);
 check(escape.map(p=>p.id).join(',')==='lS1,lS0','actual S2 lowland enemy approach uses authored ascent ramp');
 check(api.needsRoad([0,-12,0],[40,1,0],true),'cross-height enemy approach uses roads before eighty metres');
 check(!api.needsRoad([0,0,0],[20,0,0],true),'near same-level enemy retains direct engagement');
 check(api.needsRoad([0,0,0],[81,0,0],false),'distant nonenemy retains existing road navigation');
 check(source.includes("const goalId=route.length?'road:'+route[0].id:enemy?'enemy':"),'road waypoints retain individual progress baselines during enemy pursuit');
 const log={};let accepted=0;const strict=(ok,label)=>assert.ok(ok,label);
 const state=(step,phase,stats,enemies=0)=>({index:step==='box'?1:step==='scouts'?6:step==='log'?7:8,step,phase,stats,enemies,time:1,target:[0,0,0]});
 const stats={kills:0,intel:0,collectors:0};api.observeLog(log,state('box','go',stats),strict);
 api.observeLog(log,state('scouts','fight',{kills:0,intel:2,collectors:2},3),strict);
 api.observeLog(log,state('log','go',{kills:3,intel:2,collectors:2}),strict);
 accepted+=api.observeLog(log,state('east','go',{kills:3,intel:3,collectors:2}),strict)?1:0;
 check(accepted===1&&log.result==='PASS','real three-kill and pickup acceptance retained');
 assert.throws(()=>api.observeLog({baseline:{kills:0},fight:{},threeEnemiesObserved:true},state('log','go',{kills:2,intel:2,collectors:2}),strict));checks++;
 assert.throws(()=>api.observeLog({baseline:{kills:0},fight:{},threeEnemiesObserved:true},state('log','go',{kills:3,intel:1,collectors:2}),strict));checks++;
 assert.throws(()=>api.observeLog({},state('east','go',{kills:3,intel:3,collectors:2}),strict));checks++;
 return {checks,bowRoute:bow};
}
const api=load(source),result=verify(api);
const mutations={
 'reuse previous waypoint baseline':['progress.goal!==goal','progress.goal===undefined'],
 'keep previous reverse deadline':['progress.reverseUntil=0;','progress.reverseUntil=progress.reverseUntil||0;'],
 'disable genuine stuck recovery':['now-progress.stuckAt>8000','false&&now-progress.stuckAt>8000'],
 'accept wrong-height waypoint':['&&Math.abs(p[1]-route[0].pos[1])<8',''],
 'omit ramp interpolation':['from[1]+(to[1]-from[1])*t','to[1]'],
 'disable enemy road navigation':['flat(from,to)>80||enemy&&flat(from,to)>25&&Math.abs(from[1]-to[1])>6','!enemy&&flat(from,to)>80'],
 'omit nearby cross-height ascent':['||enemy&&flat(from,to)>25&&Math.abs(from[1]-to[1])>6',''],
};
result.rejectedMutations=[];
for(const [label,[old,replacement]]of Object.entries(mutations)){
 assert.ok(source.includes(old),'mutation anchor '+label);
 assert.throws(()=>verify(load(source.replace(old,replacement))),'negative control '+label);result.rejectedMutations.push(label);
}
const evidence=path.join(root,'docs/migration/evidence/story-natural-s1-manifest-ea91d004-2026-10-16T00-56-24-255Z/result.json');
const original=JSON.parse(fs.readFileSync(evidence)),samples=original.samples.filter(s=>s.story.step==='bow');
let route=[],progress={},old={best:Infinity,stuckAt:original.transitions.find(t=>t.story.step==='bow').at,reverseUntil:0};
const replay=[];
for(const sample of samples){
 const p=sample.vehicle.position,t=sample.story.target;
 if(!route.length&&Math.hypot(p[0]-t[0],p[2]-t[2])>80)route=api.roadRoute(p,t,roads);
 api.advanceRoute(route,p);const goal=route[0]?.pos||t,d=Math.hypot(p[0]-goal[0],p[2]-goal[2]);
 if(d<old.best-1){old.best=d;old.stuckAt=sample.at;}
 if(sample.at-old.stuckAt>8000&&sample.at>old.reverseUntil){old.reverseUntil=sample.at+1800;old.stuckAt=sample.at;}
 const reversing=api.navigationProgress(progress,route[0]?.id||'target',d,sample.at);
 if(sample.at>=181397&&sample.at<=183180)replay.push({at:sample.at,goal:route[0]?.id,distance:d,oldReverse:sample.at<old.reverseUntil,newReverse:reversing,observedKeys:sample.keys});
}
assert.ok(replay.length>=5&&replay.every(s=>s.goal==='hBr'&&s.oldReverse&&!s.newReverse),'captured bow approach reproduces old false recovery');
assert.ok(replay.every((s,i)=>i===0||s.distance<replay[i-1].distance),'captured approach is actually making progress');
result.checks+=2;
Object.assign(result,{result:'PASS',toolSha256:sha(source),testSha256:sha(fs.readFileSync(__filename)),priorRun:{path:path.relative(root,evidence),sha256:sha(fs.readFileSync(evidence)),result:original.result},bowApproachReplay:replay,
 inputs:Object.fromEntries(['tools/migration/check-story-natural-web.cjs','tools/migration/check-story-navigation.cjs','assets/Crater/Layout.json'].map(name=>[name,sha(fs.readFileSync(path.join(root,name)))])),
 boundary:'Offline helper controls and counterfactual recovery decisions over preserved old vehicle samples only. No browser, GPU, new driving, mission completion, collision fix, rendered or mobile acceptance. Original INCOMPLETE run is unchanged.'});
fs.writeFileSync(path.join(root,'docs/migration/evidence/story-navigation-offline.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));

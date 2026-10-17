const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const defense=require('./story-hold-defense-input.cjs'),stopApi=require('./story-natural-stop.cjs');
const root=path.resolve(__dirname,'../..'),step=require('../../assets/Story/Mission/Level3.json').level.steps.find(s=>s.kind==='hold');
const nav=require('../../assets/Crater/Layout.json').nav;
const evidence='docs/migration/evidence/story-natural-s3-manifest-e1bd07fa-2026-10-16T16-29-48-246Z',jsonFile=path.join(root,evidence,'result.json'),logFile=path.join(root,evidence,'runtime.log');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),original=fs.readFileSync(jsonFile),originalSha=sha(original),r=JSON.parse(original);
let checks=0;const check=(value,label)=>{assert.ok(value,label);checks++;};
const flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]),enemy=(pos,parts=91)=>({team:'red',pos,parts});
function controls(api){
 const centre=step.pos,t1=enemy([16,5.5,-199]),t2=enemy([-20,7,-250]);
 let memory={},plan=api.defensePlan(step,centre,[t1],memory,1000);
 assert(plan.target===t1.pos&&flat(plan.goal,centre)>8&&!plan.park&&flat(plan.goal,centre)<step.healR);
 assert.equal(plan.lineOfSight,'UNKNOWN');assert(plan.focusChanged);
 const t3=enemy([17,5.5,-199]),closer=enemy([0,5,-230]);
 plan=api.defensePlan(step,centre,[closer,t3],memory,1100);assert.deepEqual(plan.target,t3.pos);assert(!plan.focusChanged);
 const firstGoal=[...plan.goal];plan=api.defensePlan(step,centre,[t3],memory,4500);assert(flat(firstGoal,plan.goal)>2&&flat(plan.goal,centre)<step.healR);
 assert.equal(api.defensePlan(step,centre,[{...t2,team:'blue'}],{},0).target,null);
 assert.equal(api.defensePlan(step,centre,[enemy([0,0,-234-step.drainR])],{},0).target,null);
 assert.equal(api.defensePlan(step,centre,[enemy([0,NaN,-220])],{},0).target,null);
 assert(api.defensePlan(step,centre,{}, {},0).park);
 assert(api.alignedForFire({yawError:.02,dy:5}));assert(!api.alignedForFire({yawError:.2,dy:5}));assert(!api.alignedForFire({yawError:.02,dy:50}));
 const options={nav,health:1},patrolMemory={};
 let patrol=api.defensePlan(step,centre,[],patrolMemory,1000,options);
 assert(patrol.goalNodeId&&flat(patrol.goal,centre)>=step.drainR+15&&!patrol.park);
 assert.deepEqual([...patrol.goal],nav.nodes[patrol.goalNodeId]);assert.equal(patrol.lineOfSight,'UNKNOWN');
 const outside=enemy([0,6,-138]);patrol=api.defensePlan(step,centre,[outside],{},1000,options);
 assert(patrol.target===outside.pos&&flat(outside.pos,centre)>step.drainR);
 const repair={};patrol=api.defensePlan(step,centre,[outside],repair,1000,{nav,health:.3});
 assert(patrol.goal===centre&&patrol.reason==='return-for-observed-damage');
 assert(api.defensePlan(step,centre,[outside],repair,2000,{nav,health:.6}).goal===centre);
 patrol=api.defensePlan(step,centre,[outside],repair,3000,{nav,health:.9});
 assert(flat(patrol.goal,centre)>=step.drainR+15&&nav.nodes[patrol.goalNodeId]);
}
controls(defense);checks+=19;
const helperFile=path.join(__dirname,'story-hold-defense-input.cjs'),source=fs.readFileSync(helperFile,'utf8'),mutations={
 'park permanently at base':['park:flat(position,goal)<3','park:true'],
 'claim projection proves line of sight':["lineOfSight:'UNKNOWN'","lineOfSight:'CLEAR'"],
 'switch target every observation':['if(memory.target&&now-memory.at<1500)','if(false)'],
 'fire despite yaw error':['Math.abs(aim.yawError)<.045','true'],
 'keep healthy defender inside drain circle':['step.drainR+15','0'],
 'repair despite full observed health':['if(health<.45)','if(true)'],
};
const rejected=[];for(const [label,[before,after]]of Object.entries(mutations)){assert(source.includes(before));const module={exports:{}};vm.runInNewContext(source.replaceAll(before,after),{module});assert.throws(()=>controls(module.exports));rejected.push(label);checks++;}
const states=fs.readFileSync(logFile,'utf8').split(/\r?\n/).filter(s=>s.includes('OUTGAME_STATE ')).map(s=>JSON.parse(s.slice(s.indexOf('OUTGAME_STATE ')+14)));
const acceptance=require('./story-hold-acceptance.cjs'),replayedAcceptance=acceptance.create(require('../../assets/Story/Mission/Level3.json').level);
for(const sample of r.samples)acceptance.observe(replayedAcceptance,sample.story,sample.at,assert);
check(replayedAcceptance.attempts.length===5,'actual four failed holds and final partial attempt remain distinct');
check(replayedAcceptance.attempts.every(a=>a.firstLeft>=118&&a.firstEnergy>0),'actual failure-dialogue snapshots never become retry starts');
const live=states.find(s=>s.story?.time>140&&s.story.time<146&&s.aimTargets?.length&&flat(s.vehicle.position,step.pos)<1);
check(!!live,'actual recorded parked state and public target positions available');
const replay=defense.defensePlan(step,live.vehicle.position,live.aimTargets,{},0);
check(!replay.park&&flat(replay.goal,step.pos)>8,'recorded parked failure now requests public movement');
check(flat(replay.goal,step.pos)<step.healR&&replay.lineOfSight==='UNKNOWN','recorded new goal stays in original repair circle without fabricated LOS');
const controller=stopApi.createStopController();check(!controller.poll({story:{id:'s3',stats:{fails:1}}}),'first actual failure remains retryable');
const stopState=states.find(s=>s.story?.id==='s3'&&s.story.stats?.fails===2);
check(controller.poll(stopState)?.observedFailures===2,'actual second failure requests early stop');
check(!controller.poll({story:{id:'s2',stats:{fails:9}}}),'other missions do not acquire S3 failure budget');
const fileStop=stopApi.createStopController({file:'operator.stop',exists:()=>true,read:()=> 'Stop this route'});
check(fileStop.poll({})?.kind==='operator-file','explicit external stop file is observed');
const signalStop=stopApi.createStopController();signalStop.request('SIGINT');check(signalStop.poll({})?.reason==='SIGINT','signal stop is preserved');
async function main(){
 const events=[],state={mode:'trial',story:{finished:false}},before=JSON.stringify(state);
 const result=await stopApi.returnThroughPublicInput({state,now:()=>1000,release:async()=>events.push('release'),press:async key=>events.push(key),returnViaUi:async timeout=>{assert.equal(timeout,30000);events.push('observed return button');return {mode:'hangar',loadingFlow:{active:false},performance:{arrayBytes:0}};}});
 check(JSON.stringify(events)===JSON.stringify(['release','Escape','observed return button'])&&result.result==='RETURNED','public stop releases input, pauses and uses observed controls within total return budget');
 check(JSON.stringify(state)===before,'stop path does not write observed gameplay state');
 await assert.rejects(()=>stopApi.returnThroughPublicInput({state,release:async()=>{},press:async()=>{},returnViaUi:async()=>({mode:'hangar',performance:{arrayBytes:1}})}));checks++;
 let clock=1000;await assert.rejects(()=>stopApi.returnThroughPublicInput({state,now:()=>clock,release:async()=>{clock+=30001;},press:async()=>{},returnViaUi:async()=>{throw Error('must not bypass spent budget');}}),/30-second/);checks++;
 clock=1000;await assert.rejects(()=>stopApi.returnThroughPublicInput({state,now:()=>clock,release:async()=>{},press:async()=>{},returnViaUi:async()=>{clock+=30001;return {mode:'hangar',loadingFlow:{active:false},performance:{arrayBytes:0}};}}),/30-second/);checks++;
 const runnerSource=fs.readFileSync(path.join(__dirname,'check-story-natural-web.cjs'),'utf8');
 const deadlineStart=runnerSource.indexOf("  if(report.result==='RUNNING'){");
 const deadlineEnd=runnerSource.indexOf('  if(completedCampaign)',deadlineStart);
 assert(deadlineStart>=0&&deadlineEnd>deadlineStart);
 const deadlineCode=runnerSource.slice(deadlineStart,deadlineEnd);
 async function deadlineControl(code){
  const calls=[],ctx={report:{result:'RUNNING'},state:{mode:'trial',story:{finished:false}},returnThroughPublicInput:stopApi.returnThroughPublicInput,
   shot:async name=>calls.push(name),keys:async()=>calls.push('release keys'),fire:async on=>{assert.equal(on,false);calls.push('release fire');},
   page:{keyboard:{press:async key=>calls.push(key)}},
   returnViaUi:async timeout=>{assert(timeout>0&&timeout<=30000);ctx.state={mode:'hangar',loadingFlow:{active:false},performance:{arrayBytes:0}};calls.push('observed return button');return ctx.state;}};
  await vm.runInNewContext('(async()=>{'+code+'})()',ctx);
  assert.equal(ctx.report.result,'INCOMPLETE');assert.equal(ctx.report.deadlineReturn.result,'RETURNED');
  assert.deepEqual(calls,['deadline','release keys','release fire','Escape','observed return button']);
 }
 await deadlineControl(deadlineCode);checks++;
 const deadlineMutations={
  'skip actual deadline return':['report.deadlineReturn=await returnThroughPublicInput','report.deadlineReturn=await (async()=>({result:"RETURNED"}))'],
  'replace observed controls with T-only':['returnViaUi});',"returnViaUi:async()=>{await page.keyboard.press('t');return state;}});"],
 };
 for(const [label,[before,after]]of Object.entries(deadlineMutations)){
  assert(deadlineCode.includes(before));const mutated=deadlineCode.replace(before,after);
  new vm.Script('(async()=>{'+mutated+'})()');
  await assert.rejects(()=>deadlineControl(mutated));rejected.push(label);checks++;
 }
 const uiStart=runnerSource.indexOf(' async function returnViaUi(timeout){'),uiEnd=runnerSource.indexOf(' async function sampleBattleObjects',uiStart);
 assert(uiStart>=0&&uiEnd>uiStart);const uiCode=runnerSource.slice(uiStart,uiEnd);
 async function uiControl(code,confirm,lostFirst=false,never=false){
  let clock=0,returns=0,confirmed=false;const clicks=[],ctx={seq:0,state:{},report:{},persist:()=>{},structuredClone,Date:{now:()=>clock},sleep:async()=>{},
   readKey:async()=>{clock+=1000;ctx.seq++;const accepted=!never&&returns>=(lostFirst?2:1);ctx.state=accepted&&(!confirm||confirmed)?{mode:'hangar',loadingFlow:{active:false},performance:{arrayBytes:0}}:{mode:'trial',width:1600,height:900,widgets:[{text:'继续',rect:[1,2,3,4]},accepted?{text:'确定',rect:[300,200,40,50]}:{text:'返回车库',rect:[40,50,100,30]}]};},
   wait:async(fn,label,timeout,ignore)=>{assert(timeout>0&&timeout<=30000);assert.equal(ignore,true);assert(fn(ctx.state));return ctx.state;},
   page:{mouse:{click:async(x,y,options)=>{assert.equal(options.delay,120);const want=ctx.state.widgets.some(w=>w.text==='确定')?[320,225]:[90,65];assert.deepEqual([x,y],want);clicks.push([x,y]);if(x===320)confirmed=true;else returns++;}}}};
  const operation=vm.runInNewContext(code+';returnViaUi(30000)',ctx);
  if(never){await assert.rejects(()=>operation,/Timeout observed/);assert.equal(returns,3);assert.equal(ctx.report.publicReturnControls.result,'TIMEOUT');return;}
  const returned=await operation;
  assert.equal(returned.mode,'hangar');assert.equal(clicks.length,(confirm?2:1)+(lostFirst?1:0));
  assert.equal(ctx.report.publicReturnControls.result,'OBSERVED_HALL');
  assert(ctx.report.publicReturnControls.actions.every(a=>a.result==='BROWSER_DISPATCHED'));
 }
 await uiControl(uiCode,false);await uiControl(uiCode,true);await uiControl(uiCode,false,true);await uiControl(uiCode,true,true);await uiControl(uiCode,false,false,true);checks+=5;
 const wrongControl=uiCode.replace("buttons.find(w=>w.text==='确定')||buttons.find(w=>w.text==='返回车库')",'rows[0]');assert.notEqual(wrongControl,uiCode);
 await assert.rejects(()=>uiControl(wrongControl,true));rejected.push('click unrelated public widget instead of actual return label');checks++;
 const noRetry=uiCode.replace('length<3','length<1');assert.notEqual(noRetry,uiCode);
 await assert.rejects(()=>uiControl(noRetry,false,true));rejected.push('treat unacknowledged first dispatch as accepted');checks++;
 const noHold=uiCode.replace('delayMs:120','delayMs:0');assert.notEqual(noHold,uiCode);
 await assert.rejects(()=>uiControl(noHold,false));rejected.push('dispatch zero-duration return click');checks++;
 check(sha(fs.readFileSync(jsonFile))===originalSha,'original failed runtime result remains unchanged');
 const report={result:'PASS',checks,rejectedMutations:rejected,originalEvidence:evidence,originalResult:r.result,originalSha256:originalSha,originalRuntimeSha256:sha(fs.readFileSync(logFile)),actualStopOpportunity:{time:stopState.story.time,fails:stopState.story.stats.fails},replayedAttempts:replayedAcceptance.attempts,replay:{actualPosition:live.vehicle.position,actualTargets:live.aimTargets,plan:replay},hashes:Object.fromEntries(['story-hold-defense-input.cjs','story-natural-stop.cjs','check-story-natural-web.cjs','check-story-hold-driver.cjs'].map(name=>[name,sha(fs.readFileSync(path.join(__dirname,name)))])),boundary:'Offline public-control decisions over actual preserved telemetry and mocked input contracts only. No new browser, natural completion, actual public return, line-of-sight, gameplay, physical-device or performance acceptance.'};
 fs.writeFileSync(path.join(root,'docs/migration/evidence/story-hold-driver-offline.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
}
main().catch(e=>{console.error(e);process.exitCode=1;});

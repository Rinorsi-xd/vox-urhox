'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const BOUNDARY='QA integer wall timing includes observer/GC/preemption costs. Unscoped wall is not assigned CPU, GPU or UI time. Inclusive parents overlap children; aggregate selfMs only. Incomplete first/last frames are excluded from means.';
function analyze(records){
 const frames=records.map(r=>r.frame),complete=frames.filter(f=>!f.partialStart&&!f.partialEnd);
 const issues=[],rows=new Map(),orders=new Map(),identities=new Set(records.map(r=>JSON.stringify(r.identity||{})));
 const fixedMode=records.some(r=>r.identity?.fixedSteps===true),fixedNames=['fixed.BeforeStep','fixed.WorldStep','fixed.AfterStep'];
 const presentationMode=records.some(r=>r.identity?.presentationPipeline===true);
 const beforeStepMode=records.some(r=>r.identity?.beforeStepPipeline===true);
 const beforeStepNames=['before.Vehicle','before.Driver','before.Weapons','before.Pick','before.Flush','before.Regenerate'];
 const beforeStepRows=[];
 const vehicleMode=records.some(r=>r.identity?.vehiclePipeline===true);
 const vehicleNames=['vehicle.Sample','vehicle.Apply','vehicle.Legs','vehicle.Hover','vehicle.Contact','vehicle.LegHitboxes'];
 const vehicleRows=[];
 const presentationNames=['presentation.CombatView','presentation.Effects','presentation.HudUpdate'];
 const envelopeNames=['envelope.AppUpdate','envelope.TrialUpdate','envelope.TrialTick'];
 const presentationRows=[];
 const fixedRows=[];
 if(identities.size>1)issues.push('Mixed probe/source identities; do not combine performance means');
 if(records.some(r=>!r.identity?.mainSha256||!r.identity?.probeSha256))issues.push('Missing probe/source identity');
 if(new Set(frames.map(f=>f.epoch)).size>1)issues.push('Mixed capture epochs');
 let gaps=0,measured=0,wall=0,residual=0;
 for(let i=0;i<frames.length;i++){
  const f=frames[i];if(i&&f.epoch===frames[i-1].epoch&&f.frame!==frames[i-1].frame+1){gaps++;issues.push('Non-consecutive engine frame '+frames[i-1].frame+' -> '+f.frame)}
  const stack=[],observed=new Map();let lastAt=0;
  for(const event of f.events){
   const [name,phase,at]=event;
   if(!Number.isInteger(at)||at<lastAt||at>f.wallMs)issues.push('Invalid event time at frame '+f.frame);
   lastAt=at;
   if(phase==='enter'){
    if(vehicleMode&&vehicleNames.includes(name)&&stack.at(-1)?.name!=='before.Vehicle')issues.push('Vehicle child outside direct before.Vehicle at frame '+f.frame+': '+name);
    if(beforeStepMode&&beforeStepNames.includes(name)&&stack.at(-1)?.name!=='fixed.BeforeStep')issues.push('BeforeStep child outside direct fixed.BeforeStep at frame '+f.frame+': '+name);
    if(fixedMode&&fixedNames.includes(name)&&stack.at(-1)?.name!==(presentationMode?'envelope.TrialTick':'main.Update'))issues.push('Fixed-step boundary outside direct '+(presentationMode?'envelope.TrialTick':'main.Update')+' at frame '+f.frame);
    if(presentationMode){
     const parents={'envelope.AppUpdate':'main.Update','envelope.TrialUpdate':'envelope.AppUpdate','envelope.TrialTick':'envelope.TrialUpdate'};
     const expected=parents[name]||(presentationNames.includes(name)?'envelope.TrialTick':null);
     if(expected&&stack.at(-1)?.name!==expected)issues.push('Presentation boundary outside direct '+expected+' at frame '+f.frame+': '+name);
    }
    stack.push({name,at,children:0});
   }
   else if(phase==='leave'){
    const entered=stack.pop();
    if(!entered||entered.name!==name){issues.push('Unbalanced events at frame '+f.frame);continue}
    const elapsed=at-entered.at,row=observed.get(name)||{calls:0,inclusiveMs:0,selfMs:0,maxMs:0};
    row.calls++;row.inclusiveMs+=elapsed;row.selfMs+=elapsed-entered.children;row.maxMs=Math.max(row.maxMs,elapsed);observed.set(name,row);
    if(stack.length)stack.at(-1).children+=elapsed;
   }else issues.push('Invalid event phase at frame '+f.frame);
  }
  if(stack.length)issues.push('Unclosed events at frame '+f.frame);
  for(const name of new Set([...observed.keys(),...Object.keys(f.scopes)])){
   const actual=observed.get(name),row=f.scopes[name];
   if(!actual||!row||['calls','inclusiveMs','selfMs','maxMs'].some(key=>actual[key]!==row[key]))issues.push('Event/scope mismatch for '+name+' at frame '+f.frame);
   if(row&&(['calls','inclusiveMs','selfMs','maxMs','errors'].some(key=>!Number.isInteger(row[key])||row[key]<0)||row.errors!==0))issues.push('Invalid or failed callback scope '+name+' at frame '+f.frame);
  }
  if(f.droppedEvents)issues.push('Truncated event sequence at frame '+f.frame);
  const self=Object.values(f.scopes).reduce((n,r)=>n+r.selfMs,0);
  if(self!==f.measuredWallMs||f.wallMs!==self+f.unscopedWallMs||f.unscopedWallMs<0)issues.push('Invalid timing accounting at frame '+f.frame);
  if(f.callsAfterFramePresented)issues.push('Callbacks after main.FramePresented at frame '+f.frame+'; frame ID still retained');
  if(f.partialStart||f.partialEnd)continue;
  for(const name of ['main.Update','main.PostUpdate','main.FramePresented','ui.Update','ui.Render']){
   if(f.scopes[name]?.calls!==1)issues.push('Expected one '+name+' at complete frame '+f.frame+'; observed '+(f.scopes[name]?.calls||0));
  }
  if(fixedMode){
   const calls=fixedNames.map(name=>f.scopes[name]?.calls||0);
   if(!calls.every(n=>n===calls[0]))issues.push('Fixed-step call count mismatch at frame '+f.frame);
   const fixedMs=fixedNames.reduce((sum,name)=>sum+(f.scopes[name]?.inclusiveMs||0),0),updateMs=f.scopes['main.Update']?.inclusiveMs||0;
   if(fixedNames.some(name=>f.scopes[name]&&(!beforeStepMode||name!=='fixed.BeforeStep')&&f.scopes[name].inclusiveMs!==f.scopes[name].selfMs)||fixedMs>updateMs)issues.push('Overlapping fixed-step accounting at frame '+f.frame);
   const enter=f.events.find(e=>e[0]==='main.Update'&&e[1]==='enter');
   fixedRows.push({frame:f.frame,steps:calls[0],frameWallMs:f.wallMs,mainUpdateMs:updateMs,fixedMs,
    otherUpdateMs:updateMs-fixedMs,outsideUpdateMs:f.wallMs-updateMs,
    mainUpdateEntryWall:enter?f.startWall+enter[2]:null});
  }
  if(presentationMode){
   if(!fixedMode||!records[i].identity?.presentationSources||Object.keys(records[i].identity.presentationSources).length!==5)issues.push('Missing presentation source identity at frame '+f.frame);
   for(const name of [...presentationNames,...envelopeNames])if(f.scopes[name]?.calls!==1)issues.push('Expected one presentation/envelope scope '+name+' at frame '+f.frame);
   const get=name=>f.scopes[name]||{inclusiveMs:0,selfMs:0};
   const main=get('main.Update'),app=get('envelope.AppUpdate'),trial=get('envelope.TrialUpdate'),tick=get('envelope.TrialTick');
   const fixedMs=fixedNames.reduce((sum,name)=>sum+get(name).inclusiveMs,0);
   const presentedMs=presentationNames.reduce((sum,name)=>sum+get(name).inclusiveMs,0);
   if(main.inclusiveMs!==main.selfMs+app.inclusiveMs||app.inclusiveMs!==app.selfMs+trial.inclusiveMs||trial.inclusiveMs!==trial.selfMs+tick.inclusiveMs||tick.inclusiveMs!==tick.selfMs+fixedMs+presentedMs)issues.push('Presentation envelope conservation mismatch at frame '+f.frame);
   presentationRows.push({frame:f.frame,frameWallMs:f.wallMs,fixedSteps:f.scopes['fixed.BeforeStep']?.calls||0,
    mainOtherMs:main.selfMs,appServicesMs:app.selfMs,trialInputMs:trial.selfMs,tickSideMs:tick.selfMs,
    combatViewMs:get('presentation.CombatView').inclusiveMs,effectsMs:get('presentation.Effects').inclusiveMs,hudMs:get('presentation.HudUpdate').inclusiveMs,
    fixedMs,updateRemainderMs:main.inclusiveMs-fixedMs});
  }
  if(beforeStepMode){
   const get=name=>f.scopes[name]||{inclusiveMs:0,selfMs:0,calls:0};
   const before=get('fixed.BeforeStep'),children=beforeStepNames.reduce((sum,name)=>sum+get(name).inclusiveMs,0);
   if(!presentationMode||Object.keys(records[i].identity?.beforeStepSources||{}).length!==5)issues.push('Missing BeforeStep source identity at frame '+f.frame);
   if(before.inclusiveMs!==before.selfMs+children)issues.push('BeforeStep child conservation mismatch at frame '+f.frame);
   if(beforeStepNames.some(name=>(!vehicleMode||name!=='before.Vehicle')&&get(name).inclusiveMs!==get(name).selfMs))issues.push('BeforeStep child overlap at frame '+f.frame);
   if(get('before.Vehicle').calls<before.calls||get('before.Weapons').calls<before.calls||get('before.Flush').calls<before.calls||get('before.Regenerate').calls<before.calls||get('before.Driver').calls!==get('before.Pick').calls)issues.push('BeforeStep child call count mismatch at frame '+f.frame);
   beforeStepRows.push({frame:f.frame,beforeMs:before.inclusiveMs,beforeSelfMs:before.selfMs,steps:before.calls,
    children:Object.fromEntries(beforeStepNames.map(name=>[name,{ms:get(name).inclusiveMs,calls:get(name).calls,maxMs:get(name).maxMs||0}]))});
  }
  if(vehicleMode){
   const get=name=>f.scopes[name]||{inclusiveMs:0,selfMs:0,calls:0};
   const vehicle=get('before.Vehicle'),children=vehicleNames.reduce((sum,name)=>sum+get(name).inclusiveMs,0);
   if(!beforeStepMode||Object.keys(records[i].identity?.vehicleSources||{}).length!==5)issues.push('Missing Vehicle source identity at frame '+f.frame);
   if(vehicle.inclusiveMs!==vehicle.selfMs+children)issues.push('Vehicle child conservation mismatch at frame '+f.frame);
   if(vehicleNames.some(name=>get(name).inclusiveMs!==get(name).selfMs))issues.push('Vehicle child overlap at frame '+f.frame);
   if(vehicleNames.some(name=>get(name).calls>vehicle.calls))issues.push('Vehicle child call count exceeds Vehicle at frame '+f.frame);
   vehicleRows.push({frame:f.frame,vehicleMs:vehicle.inclusiveMs,vehicleSelfMs:vehicle.selfMs,vehicleCalls:vehicle.calls,steps:get('fixed.BeforeStep').calls,
    children:Object.fromEntries(vehicleNames.map(name=>[name,{ms:get(name).inclusiveMs,calls:get(name).calls,maxMs:get(name).maxMs||0}]))});
  }
  measured+=f.measuredWallMs;wall+=f.wallMs;residual+=f.unscopedWallMs;
  const order=f.events.filter(e=>e[1]==='enter').map(e=>e[0]).join(' > ');orders.set(order,(orders.get(order)||0)+1);
  for(const [name,row]of Object.entries(f.scopes)){
   const total=rows.get(name)||{name,calls:0,inclusiveMs:0,selfMs:0,maxMs:0,errors:0};
   for(const key of ['calls','inclusiveMs','selfMs','errors'])total[key]+=row[key];total.maxMs=Math.max(total.maxMs,row.maxMs);rows.set(name,total);
  }
 }
 const count=complete.length,mean=n=>count?n/count:null;
 let fixedSteps;
 if(fixedMode){
  const total=fixedRows.reduce((sum,f)=>sum+f.steps,0),fixedMs=fixedRows.reduce((sum,f)=>sum+f.fixedMs,0);
  const groups=new Map();
  for(let i=0;i<fixedRows.length;i++){
   const row=fixedRows[i],previous=fixedRows[i-1],next=fixedRows[i+1];
   row.incomingUpdateIntervalMs=previous&&previous.frame+1===row.frame?row.mainUpdateEntryWall-previous.mainUpdateEntryWall:null;
   row.outgoingUpdateIntervalMs=next&&row.frame+1===next.frame?next.mainUpdateEntryWall-row.mainUpdateEntryWall:null;
   const group=groups.get(row.steps)||{steps:row.steps,frames:0,fixedMs:0,otherUpdateMs:0};
   group.frames++;group.fixedMs+=row.fixedMs;group.otherUpdateMs+=row.otherUpdateMs;groups.set(row.steps,group);
  }
  fixedSteps={boundary:'Three sibling fixed-step scopes in main.Update, not the whole simulation step. Other Update includes remaining fixed-step side work and QA observers. Outside Update includes measured UI/PostUpdate plus unscoped engine/waits. Incoming intervals precede the current update; outgoing intervals include it. More steps after a long interval are not proof of its cause. Integer wall measurements remain observer-sensitive.',
   total,meanStepsPerFrame:mean(total),mainFixedMsPerStep:total?fixedMs/total:null,mainFixedMsPerFrame:mean(fixedMs),
   meanOtherUpdateMs:mean(fixedRows.reduce((sum,f)=>sum+f.otherUpdateMs,0)),meanOutsideUpdateMs:mean(fixedRows.reduce((sum,f)=>sum+f.outsideUpdateMs,0)),
   stepGroups:[...groups.values()],frames:fixedRows};
 }
 return {boundary:BOUNDARY,frames:frames.length,completeFrames:count,gaps,reportedDropped:Math.max(0,...records.map(r=>r.dropped||0)),issues,
  ...(fixedMode?{fixedSteps}:{}),
  ...(presentationMode?{presentation:{boundary:'Six once-per-frame presentation/envelope scopes extend fixed-step QA only. Envelope self separates main/QA/storage, app services, trial input and Tick side work; three disjoint presentation roots and fixed scopes are children of Tick. Wall stalls inside a boundary do not identify GC or native source.',
   means:Object.fromEntries(['mainOtherMs','appServicesMs','trialInputMs','tickSideMs','combatViewMs','effectsMs','hudMs','fixedMs','updateRemainderMs'].map(key=>[key,mean(presentationRows.reduce((sum,row)=>sum+row[key],0))])),frames:presentationRows}}:{}),
  ...(beforeStepMode?{beforeStep:{boundary:'Six actual method children directly inside real BattleController.BeforeStep. Self retains objective/rotor/consumer/other work and observer costs. Child wall ownership is not CPU/GC attribution or an optimization result.',
   meanBeforeMs:mean(beforeStepRows.reduce((sum,row)=>sum+row.beforeMs,0)),meanSelfMs:mean(beforeStepRows.reduce((sum,row)=>sum+row.beforeSelfMs,0)),
   means:Object.fromEntries(beforeStepNames.map(name=>[name,mean(beforeStepRows.reduce((sum,row)=>sum+row.children[name].ms,0))])),frames:beforeStepRows}}:{}),
  ...(vehicleMode?{vehicle:{boundary:'Six actual methods directly inside before.Vehicle. Vehicle self retains Stability/Motion/Mech/Thruster/Wing/other work and observer costs. Early returns may skip children; LegControl is optional. This is wall ownership, not CPU or GC attribution.',
   meanVehicleMs:mean(vehicleRows.reduce((sum,row)=>sum+row.vehicleMs,0)),meanSelfMs:mean(vehicleRows.reduce((sum,row)=>sum+row.vehicleSelfMs,0)),
   means:Object.fromEntries(vehicleNames.map(name=>[name,mean(vehicleRows.reduce((sum,row)=>sum+row.children[name].ms,0))])),frames:vehicleRows}}:{}),
  meanWallMs:mean(wall),meanMeasuredWallMs:mean(measured),meanUnscopedWallMs:mean(residual),orders:[...orders].map(([order,count])=>({order,count})),
  rows:[...rows.values()].map(r=>({...r,inclusiveMsPerFrame:mean(r.inclusiveMs),selfMsPerFrame:mean(r.selfMs)})).sort((a,b)=>b.selfMs-a.selfMs)};
}
function parse(text){
 return text.split(/\r?\n/).filter(line=>line.includes('VOX_FRAME_PIPELINE ')).map(line=>JSON.parse(line.slice(line.indexOf('VOX_FRAME_PIPELINE ')+'VOX_FRAME_PIPELINE '.length)));
}
function selfTest(){
 const scope={calls:1,inclusiveMs:3,selfMs:3,maxMs:3,errors:0};
 const f={frame:1,partialStart:false,partialEnd:false,scopes:{'main.Update':scope},events:[['main.Update','enter',0],['main.Update','leave',3]],wallMs:5,measuredWallMs:3,unscopedWallMs:2};
 const report=analyze([{frame:f,dropped:0}]);assert.equal(report.meanUnscopedWallMs,2);assert.equal(report.rows[0].selfMsPerFrame,3);
 assert.ok(report.issues.some(s=>s.includes('ui.Update')));assert.equal(parse('prefix VOX_FRAME_PIPELINE '+JSON.stringify({frame:f})).length,1);
 const broken=structuredClone(f);broken.frame=3;broken.scopes['main.Update'].selfMs=8;
 assert.ok(analyze([{frame:f},{frame:broken}]).issues.some(s=>s.includes('Non-consecutive')));
 assert.ok(analyze([{frame:broken}]).issues.some(s=>s.includes('Invalid timing')));
 const forged=structuredClone(f);forged.events=[['main.Update','enter',100],['main.Update','leave',-100]];
 assert.ok(analyze([{frame:forged}]).issues.some(s=>s.includes('Invalid event time')));
 assert.ok(analyze([{frame:{...f,events:[]}}]).issues.some(s=>s.includes('Event/scope mismatch')));
 console.log('PASS: engine-frame gaps, missing UI callbacks, nested self accounting and unassigned residual boundaries');
}
module.exports={analyze,parse,selfTest};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else{assert.ok(process.argv[2],'Usage: node analyze-frame-pipeline.cjs runtime.log');console.log(JSON.stringify(analyze(parse(fs.readFileSync(process.argv[2],'utf8'))),null,2))}}

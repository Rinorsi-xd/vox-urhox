'use strict';
const assert=require('node:assert/strict');
const {reacquireScope,selfTest}=require('./scope-fx-isolated-run.cjs');
async function check(captured,allowClick=true,allowScope=true){
 const events=[];
 const state={samplePhase:'post-update',trial:{captured,firstPerson:false,scope:false,effectsFirstPerson:false,ownsWeapons:false,models:4,visible:4,weaponFx:{visible:true,batches:{Band:{count:1,enabled:true}}},samples:{hiddenViolations:0},projected:0,projectiles:0,nearOwn:0}};
 const page={mouse:{up:async b=>events.push('up:'+b.button),click:async(x,y)=>{events.push('click:'+x+','+y);if(allowClick)state.trial.captured=true},down:async b=>{events.push('down:'+b.button);if(allowScope&&state.trial.captured){Object.assign(state.trial,{firstPerson:true,scope:true,effectsFirstPerson:true,ownsWeapons:true,visible:0});state.trial.weaponFx.visible=false;state.trial.weaponFx.batches.Band.enabled=false}}},bringToFront:async()=>events.push('front'),locator:()=>({boundingBox:async()=>({x:5,y:8,width:2000,height:900})})};
 const poll=async()=>state;
 const wait=async predicate=>{assert(predicate(state),'Real capture/ADS did not arrive');return state};
 return {result:await reacquireScope(page,poll,wait,'offline-adapter'),events};
}
(async()=>{
 selfTest();
 const lost=await check(false);assert.deepEqual(lost.events,['up:left','up:right','front','click:1005,458','down:right']);
 const retained=await check(true);assert.deepEqual(retained.events,['up:left','up:right','front','down:right']);
 await assert.rejects(()=>check(false,false),/Real capture\/ADS/);
 await assert.rejects(()=>check(true,true,false),/Real capture\/ADS/);
 console.log('PASS: offline input adapters preserve strict scope assertions; real-click capture loss recovery, retained capture, refused capture and refused ADS controls. No browser/Runtime acceptance.');
})().catch(e=>{console.error(e.stack);process.exitCode=1});

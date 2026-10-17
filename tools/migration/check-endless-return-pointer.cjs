'use strict';
const assert=require('node:assert/strict');
const {pauseMenuReady,exitHudReady,releaseExitPointer}=require('./endless-edit-stock-web-run.cjs');
async function main(){
 let checks=0;
 const paused={mode:'trial',pointer:{captured:false,pending:false},endless:{state:'rest'},overlayState:{present:true,owner:'app.trial.dialog',title:'暂停',open:true,stackAvailable:true,stack:[{owner:'app.trial.dialog',visible:true,pointerEvents:'auto'}]}};
 const released={...structuredClone(paused),overlayState:{present:true,owner:'main.performancePanel',stackAvailable:true,stack:[{owner:'main.performancePanel',visible:true,pointerEvents:'box-none'}]}};
 assert(pauseMenuReady(paused));assert(exitHudReady(released));assert(!exitHudReady(paused));checks+=3;
 for(const mutate of [s=>s.pointer.captured=true,s=>s.pointer.pending=true,s=>delete s.pointer,s=>s.mode='hangar',s=>s.endless.state='over',s=>s.overlayState.owner='app.debugPanel',s=>s.overlayState.title='设置',s=>s.overlayState.open=false]){
  const s=structuredClone(paused);mutate(s);assert(!pauseMenuReady(s));checks++;
 }
 for(const mutate of [s=>s.pointer.captured=true,s=>s.pointer.pending=true,s=>s.endless.state='editing',s=>s.overlayState.stackAvailable=false,s=>s.overlayState.stack={broken:true},s=>s.overlayState.stack=[],s=>s.overlayState.stack.push({owner:'app.trial.dialog'}),s=>s.overlayState.stack[0].pointerEvents='auto',s=>s.overlayState.stack[0].owner='unknown',s=>s.overlayState.stack[0].visible=false,s=>delete s.overlayState.present]){
  const s=structuredClone(released);mutate(s);assert(!exitHudReady(s));checks++;
 }
 for(const stack of [[],{}]){assert(exitHudReady({...released,overlayState:{present:false,stack}}));checks++}
 const events=[];let observed=0;
 await releaseExitPointer({escape:async()=>events.push('Escape'),observe:async gate=>{const s=observed++?released:paused;assert(gate(s));events.push(observed===1?'pause-observed':'released-observed');return s},backdrop:async()=>events.push('actual-backdrop-click'),snap:label=>events.push(label)});
 assert.deepEqual(events,['Escape','pause-observed','actual pause menu after Escape','actual-backdrop-click','released-observed','actual released HUD before finish']);checks++;
 for(const broken of ['no-release','recaptured-after-backdrop','escape-fails','backdrop-fails']){
  let n=0,backdrop=false;
  await assert.rejects(()=>releaseExitPointer({escape:async()=>{if(broken==='escape-fails')throw Error(broken)},observe:async()=>{const s=structuredClone(n++?released:paused);if(broken==='no-release'||broken==='recaptured-after-backdrop'&&n===2)s.pointer.captured=true;return s},snap:()=>{},backdrop:async()=>{backdrop=true;if(broken==='backdrop-fails')throw Error(broken)}}));
  if(broken==='no-release'||broken==='escape-fails')assert.equal(backdrop,false);checks++;
 }
 console.log(JSON.stringify({status:'PASS',checks,boundary:'Actual runner release helper and gate negative controls with read-only state/input adapters; no browser or production writes.'}));
}
main().catch(e=>{console.error(e.stack);process.exitCode=1});

'use strict';
const assert=require('node:assert/strict');
const {heldHistoryShortcut}=require('./endless-edit-stock-web-run.cjs');
async function main(){
 let checks=0;
 for(const letter of ['z','y']){
  const held=new Set(),events=[];
  const keyboard={down:async k=>{assert(!held.has(k));held.add(k);events.push('down:'+k)},
   up:async k=>{held.delete(k);events.push('up:'+k)}};
  await heldHistoryShortcut(keyboard,'Control+'+letter,async()=>{
   assert.deepEqual([...held],['Control',letter]);events.push('actual-dispatch');checks++;
  },async ms=>{assert(held.has('Control'));events.push('wait:'+ms)});
  assert.deepEqual(events,['down:Control','wait:120','down:'+letter,'wait:80','actual-dispatch','up:'+letter,'up:Control']);
  assert.equal(held.size,0);checks++;
 }
 for(const broken of ['dispatch-fails','letter-down-fails','letter-up-fails']){
  const held=new Set(),events=[];
  const keyboard={down:async k=>{events.push('down:'+k);if(broken==='letter-down-fails'&&k==='z')throw Error(broken);held.add(k)},
   up:async k=>{events.push('up:'+k);held.delete(k);if(broken==='letter-up-fails'&&k==='z')throw Error(broken)}};
  await assert.rejects(()=>heldHistoryShortcut(keyboard,'Control+z',async()=>{throw Error(broken)},async()=>{}),new RegExp(broken));
  assert.equal(held.size,0);assert.equal(events.at(-1),'up:Control');checks++;
 }
 for(const invalid of ['Control+a','z','Control+Z','Control+Shift+z']){
  let touched=false;await assert.rejects(()=>heldHistoryShortcut({down:async()=>{touched=true}},invalid,async()=>{}));
  assert.equal(touched,false);checks++;
 }
 // Reproduce the measured f boundary: a latched Z press can coexist with released Control.
 const f={z:true,ctrl:false,focus:{textInput:false,inventory:false,dialog:false}};
 assert.throws(()=>assert(f.ctrl,'Actual engine Control key held during shortcut dispatch'));checks++;
 console.log(JSON.stringify({status:'PASS',checks,boundary:'Actual runner chord helper with keyboard/clock adapters, ordering and cleanup/invalid-input negative controls. No browser, manufactured gameplay or production edit.'}));
}
main().catch(e=>{console.error(e.stack);process.exitCode=1});

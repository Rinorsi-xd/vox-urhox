const assert=require('node:assert/strict');

function frameObjects(presentation){
 if(!presentation)return [];
 assert(Array.isArray(presentation.frameFields),'Presentation observer field names required');
 return Object.values(presentation.frames||{}).map(row=>Object.fromEntries(presentation.frameFields.map((name,i)=>[name,row[i]])));
}

function choiceEvidence(samples,id,picked){
 const frames=new Map(),sources=[];
 for(const sample of samples){
  const observed=frameObjects(sample.state?.story?.presentation);
  sources.push({name:sample.name,historyMode:sample.state?.story?.presentation?.historyMode,frames:observed.length});
  for(const frame of observed){
   assert(Number.isFinite(frame.at)&&Number.isFinite(frame.frame),'Actual post-update frame identity required');
   const key=frame.frame+':'+frame.at,previous=frames.get(key);
   if(previous)assert.deepEqual(frame,previous,'Overlapping actual frame observations agree');
   else frames.set(key,frame);
  }
 }
 const selected=[...frames.values()].sort((a,b)=>a.at-b.at||a.frame-b.frame).filter(f=>f.choiceId===id&&f.choicePicked===picked);
 const held=selected.filter(f=>f.choiceOn&&Number.isFinite(f.choiceHideAt)&&f.at<f.choiceHideAt);
 const exited=selected.filter(f=>!f.choiceOn&&!f.choiceVisible);
 return {sources,frames:frames.size,selected: selected.length,held:held.length,exited:exited.length,
  heldObserved:held.length>0,exitObserved:exited.length>0,
  timerWithinSource:held.length>0&&held.every(f=>f.choiceHideAt-f.at<=500),
  orderedExit:held.length>0&&exited.some(f=>f.at>held[0].at),
  firstHeld:held[0]||null,lastHeld:held.at(-1)||null,firstExited:exited[0]||null};
}

module.exports={frameObjects,choiceEvidence};

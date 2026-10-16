// Derive stage statistics from retained rAF rows without changing their labels.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const dir=path.resolve(process.argv[2]||'');assert(process.argv[2],'Evidence directory required');
const input=path.join(dir,'report.json'),report=JSON.parse(fs.readFileSync(input,'utf8'));
const rows=report.frames||[],groups=new Map();report.crossStageFrames=[];let previous;
for(const row of rows){
 const key=row.stage||'unlabelled';if(!groups.has(key))groups.set(key,[]);groups.get(key).push(row);
 if(previous&&previous.stage!==row.stage){(report.crossStageFrames??=[]).push({from:previous.stage,to:row.stage,...row});}
 previous=row;
}
function stats(samples){const values=samples.map(row=>row.ms).sort((a,b)=>a-b);return values.length?{count:values.length,p50:values[Math.floor((values.length-1)*.5)],p95:values[Math.floor((values.length-1)*.95)],max:values.at(-1),over100:values.filter(ms=>ms>100).length}:null;}
report.stageFrameStats=Object.fromEntries([...groups].map(([key,samples])=>[key,stats(samples)]));
report.stageFrameBoundary='Each retained rAF row belongs to its originally recorded completion stage; transition intervals remain in the destination stage and are additionally listed in crossStageFrames. No frame is discarded. Editor has no separate stage in runs before explicit editor marking; its rows remain in wave-5 and are not claimed to be combat-only.';
report.frameStats=stats(rows);report.performanceResult=report.frameStats?.over100?'FAIL':'NOT_ACCEPTED';
fs.writeFileSync(input,JSON.stringify(report,null,2));
console.log(JSON.stringify({result:report.result,stages:report.stageFrameStats,crossStageFrames:report.crossStageFrames?.length||0,frameStats:report.frameStats}));

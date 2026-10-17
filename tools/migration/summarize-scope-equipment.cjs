'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
function delta(before,after){
 const out={};for(const key of new Set([...Object.keys(before),...Object.keys(after)])){
  const row={};for(const name of new Set([...Object.keys(before[key]||{}),...Object.keys(after[key]||{})])){
   const value=(after[key]?.[name]||0)-(before[key]?.[name]||0);assert(Number.isSafeInteger(value)&&value>=0,'Monotonic counter '+key+'.'+name);if(value)row[name]=value;
  }if(Object.keys(row).length)out[key]=row;
 }return out;
}
function summarize(directory){
 const load=name=>JSON.parse(fs.readFileSync(path.join(directory,name+'.json'),'utf8'));
 const report=load('report');const phases=[];
 for(const kind of ['laser','mg','sniper','missile']){
  const a=load(kind+'-normal'),b=load(kind+'-scope-11');
  assert(a.sequence<b.sequence&&b.trial.firstPerson&&b.trial.scope&&b.trial.captured);
  phases.push({kind,fromSequence:a.sequence,toSequence:b.sequence,totals:delta(a.trial.equipmentEmit.totals,b.trial.equipmentEmit.totals),draws:delta(a.trial.equipmentEmit.draws,b.trial.equipmentEmit.draws),liveAtEnd:b.trial.equipmentEmit.live});
 }
 return{status:report.status,shutdown:report.shutdown,errors:report.errors.length,httpErrors:report.httpErrors.length,failure:report.failure,phases,boundary:'Counter differences between each saved normal state and scope-11 state. Includes transition/poll/screenshot time; repeated particle draw submissions are not distinct particles or visible pixels. OutsideOwnPersistent includes own motion events; no timing/FPS or phone claim.'};
}
module.exports={summarize,delta};if(require.main===module){const text=JSON.stringify(summarize(path.resolve(process.argv[2])),null,2)+'\n';if(process.argv[3])fs.writeFileSync(path.resolve(process.argv[3]),text,{flag:'wx'});else process.stdout.write(text)}

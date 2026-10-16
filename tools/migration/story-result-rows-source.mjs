import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const hashes={};
function Read(relative){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,relative));
 const sha=createHash('sha256').update(bytes).digest('hex');
 if(sha!==baseline.files[relative]?.sha256)throw Error('Frozen source changed: '+relative);
 hashes[relative]=sha;return bytes.toString('utf8');
}
const context=vm.createContext({});
const values={escapeHtml:String,touchCopy:{},radio(){},mechFrame(){},comms:{},FACE:String,
 storyVoice:{prepare(){return Promise.resolve(null);}},Blueprint:class{},buildDrillTank(){return {toJSON(){return {};}};}};
async function Module(relative){
 const mod=new vm.SourceTextModule(Read(relative),{context});
 await mod.link(name=>{
  const exports=name.endsWith('nonoComms.js')?['comms','FACE']:name.endsWith('blueprint.js')?['Blueprint']:
   name.endsWith('prefab.js')?['buildDrillTank']:name.endsWith('touchCopy.js')?['touchCopy']:
   name.endsWith('radio.js')?['radio']:name.endsWith('mechFrame.js')?['mechFrame']:
   name.endsWith('storyVoice.js')?['storyVoice']:['escapeHtml'];
  return new vm.SyntheticModule(exports,function(){for(const key of exports)this.setExport(key,values[key]);},{context});
 });await mod.evaluate();return mod.namespace;
}
const {StoryHud}=await Module('shared/ui/storyHud.js');
const cases=[];
for(let i=1;i<=5;i++){
 const level=(await Module(`shared/story/level${i}.js`))[`LEVEL${i}`];
 for(const health of [null,-.2,0,.004,.005,.299,.695,1])for(const tag of [null,0,1,2]){
  const stats={intel:2,collectors:1,kills:7,deaths:2,fails:3,checkpoints:2,sites:2,kneels:4,missileHits:9};
  if(health!==null){stats.shield=health;stats.truckHp=health;}
  const flags=tag===null?{}:{tag};
  const time=health===null?0:health===0?60:125.99;
  let html='';
  const el={set innerHTML(value){html=value;},classList:{add(){}},querySelector(){return {addEventListener(){}};}};
  const hud=Object.create(StoryHud.prototype);Object.assign(hud,{level,$(){return el;},h:{},comms:{queue:[]}});
  hud.result({...stats,time,grade:'S',quote:'',newBest:false,intelTotal:Object.keys(level.intel||{}).length,
   collectorTotal:level.steps.filter(s=>s.kind==='install').length,rows:level.resultRows?.(stats,{flags})});
  const rows=[...html.matchAll(/<div class="sh-row"><i>&gt;<\/i><small>(.*?)<u>(.*?)<\/u><\/small><b>(.*?)<\/b><\/div>/g)]
   .map(match=>match.slice(1));
  if(rows.length!==(i===5?4:5))throw Error('Unexpected source row composition');
  cases.push({level:i,stats,flags,time,rows});
 }
}
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,files:hashes},cases}));

import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const relative='shared/ui/storyHud.js';const bytes=fs.readFileSync(path.join(baseline.snapshot,relative));
const sha=createHash('sha256').update(bytes).digest('hex');
if(sha!==baseline.files[relative]?.sha256)throw Error('Frozen source changed');
let resolveReady,played=0,owner;
const values={escapeHtml:String,touchCopy:{},radio(){},mechFrame(){},FACE:String,
 comms:{owns(candidate){return candidate===owner;}},
 storyVoice:{prepare(){return new Promise(resolve=>{resolveReady=resolve;});},play(){played++;},stop(){}}};
const context=vm.createContext({clearTimeout(){},document:{body:{classList:{remove(){}}}}});
const mod=new vm.SourceTextModule(bytes.toString('utf8'),{context});
await mod.link(name=>{
 const keys=name.endsWith('nonoComms.js')?['comms','FACE']:name.endsWith('touchCopy.js')?['touchCopy']:
  name.endsWith('radio.js')?['radio']:name.endsWith('mechFrame.js')?['mechFrame']:
  name.endsWith('storyVoice.js')?['storyVoice']:['escapeHtml'];
 return new vm.SyntheticModule(keys,function(){for(const key of keys)this.setExport(key,values[key]);},{context});
});await mod.evaluate();
const cases=[];
for(const cardLength of [0,.6,2.2])for(const readyStep of [1,6,99])for(const focusedPause of [false,true]){
 played=0;let card=cardLength>0?{age:0,length:cardLength}:null;
 const comms={queue:['stale','stale2'],get talking(){return !!card||this.queue.length>0;},update(dt){if(card){card.age+=dt;if(card.age>=card.length)card=null;}}};
 const el={innerHTML:'',classList:{add(){},contains(){return true;}},querySelector(){return {addEventListener(){}};}};
 const hud=Object.create(mod.namespace.StoryHud.prototype);
 Object.assign(hud,{level:{no:'01',name:'TEST',en:'TEST'},comms,$(){return el;},h:{},root:{remove(){}},intelTimer:0});owner=hud;
 hud.result({time:1,grade:'S',quote:'Quote test',deaths:0,rows:[]});
 const trace=[];
 for(let i=1;i<=24;i++){
  if(i===readyStep){resolveReady('q');await Promise.resolve();await Promise.resolve();}
  const focused=!(focusedPause&&i>=5&&i<=9);
  if(focused)hud.update(.2);
  trace.push({focused,ready:i===readyStep,played,card:!!card,queue:comms.queue.length});
 }
 cases.push({cardLength,readyStep,focusedPause,trace});
}
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,files:{[relative]:sha}},cases}));

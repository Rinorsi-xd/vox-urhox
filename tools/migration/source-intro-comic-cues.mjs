import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const file='three/src/intro/intro.js';
const bytes=fs.readFileSync(path.join(baseline.snapshot,file));
const sha256=createHash('sha256').update(bytes).digest('hex');
if(sha256!==baseline.files[file].sha256)throw Error('Frozen source drift: '+file);
const node=()=>({style:{},classList:{remove(){}},querySelector:()=>node(),
 get lastChild(){return node();},get firstChild(){return node();},animate(){}});
const context=vm.createContext({IntroStory:class{},h:()=>node(),IMG:id=>id,
 titleCard:()=>({out(){}}),confetti(){},V:{}});
vm.runInContext(bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'')
 .replace(/^export /gm,'').replaceAll('import.meta.url',"'file:///frozen/intro.js'")
 +'\nglobalThis.Intro=Intro;',context);
const durations=JSON.parse(fs.readFileSync('assets/Intro/Intro.json')).durations;
const cases=[];
for(const values of [[durations.vo_n02a,durations.vo_n02b,durations.vo_n02c],[.1,.1,.1],[4,5,6]]){
 const events=[],I=Object.create(context.Intro.prototype);
 const byId=Object.fromEntries(['n02a','n02b','n02c'].map((id,i)=>['vo_'+id,values[i]]));
 Object.assign(I,{time:0,log:[],L:{panels:node(),bars:node(),slams:node()},
  audio:{sfx:(id,opt)=>events.push({type:'sfx',id,opt,t:I.time}),
   voice:id=>events.push({type:'voice',id,t:I.time}),duration:id=>byId[id]},
  wait:async seconds=>{events.push({type:'wait',seconds,t:I.time});I.time+=seconds;},
  task:()=>({stop(){}}),_in:()=>({finished:Promise.resolve()}),flash(){},shakeDom(){}});
 await I.actVirtues();
 cases.push({durations:values,events,duration:I.time});
}
process.stdout.write(JSON.stringify({baseline:baseline.commit,sourceHashes:{[file]:sha256},cases,
 boundary:'Actual frozen actVirtues, cut, _panel, words and voice execute in a Node VM. DOM/animation are explicit adapters; wait advances the controlled clock. No browser, audible output or rendered acceptance.'}));

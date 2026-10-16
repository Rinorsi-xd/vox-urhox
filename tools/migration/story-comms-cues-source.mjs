import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';

const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const relative='shared/ui/nonoComms.js';
const bytes=fs.readFileSync(path.join(baseline.snapshot,relative));
const sha=createHash('sha256').update(bytes).digest('hex');
if(sha!==baseline.files[relative]?.sha256)throw Error('Frozen source changed');
function element(){
 const children=new Map();let classes=new Set();
 return {dataset:{},style:{},textContent:'',innerHTML:'',parentNode:null,
  get className(){return [...classes].join(' ');},set className(value){classes=new Set(value.split(/\s+/));},
  classList:{contains(name){return classes.has(name);},remove(name){classes.delete(name);},toggle(name,on){if(on)classes.add(name);else classes.delete(name);}},
  appendChild(node){node.parentNode=this;},prepend(node){node.parentNode=this;},remove(){this.parentNode=null;},
  querySelector(selector){if(!children.has(selector))children.set(selector,element());return children.get(selector);},
  querySelectorAll(){return [];},animate(){},
 };
}
let cues=[];
const values={radio(name){cues.push(name);},storyVoice:{preload(){},find(){return null;},fade(){}},mechFrame(){},HUHU_FACES:{talk:'face'}};
const context=vm.createContext({URL,document:{createElement:element}});
const mod=new vm.SourceTextModule(bytes.toString('utf8'),{context,initializeImportMeta(meta){meta.url='file:///frozen/shared/ui/nonoComms.js';}});
await mod.link(name=>{
 const keys=name.endsWith('radio.js')?['radio']:name.endsWith('storyVoice.js')?['storyVoice']:name.endsWith('mechFrame.js')?['mechFrame']:['HUHU_FACES'];
 return new vm.SyntheticModule(keys,function(){for(const key of keys)this.setExport(key,values[key]);},{context});
});await mod.evaluate();
const cases=[];
const say=(who,text='test',urgent=false,append=false)=>({action:'say',lines:[[who,text]],urgent,append});
const tick=(dt=.125)=>({action:'update',dt});
for(const sample of [
 {name:'friendly-natural-close',ops:[say('nono'),tick(),tick(3),tick()]},
 {name:'logistics-natural-close',ops:[say('yun'),tick(),tick(3)]},
 {name:'pirate-natural-close',ops:[say('huhu'),tick(),tick(3)]},
 {name:'boss-natural-close',ops:[say('boss'),tick(),tick(4)]},
 {name:'same-speaker-queue',ops:[say('nono'),say('nono','next'),tick(),tick(3),tick(),tick(3)]},
 {name:'speaker-changes',ops:[say('nono'),say('huhu'),say('boss'),say('yun'),tick(),tick(3),tick(),tick(3),tick(),tick(4),tick(),tick(3)]},
 {name:'same-speaker-urgent-interrupt',ops:[say('nono'),tick(),say('nono','next',true),tick(),tick(3)]},
 {name:'different-speaker-urgent-interrupt',ops:[say('nono'),tick(),say('huhu','next',true),tick(),tick(3)]},
 {name:'explicit-hide-is-silent',ops:[say('nono'),tick(),{action:'hide'},tick(),say('nono'),tick(),tick(3)]},
 {name:'last-line-keep-open',keepOpen:true,ops:[say('nono'),tick(),tick(3),tick(5),say('nono','next'),tick(),tick(),tick(3)]},
 {name:'keep-open-speaker-change',keepOpen:true,ops:[say('nono'),tick(),tick(3),say('huhu'),tick(),tick(),tick(3)]},
 {name:'external-cinematic-is-silent',ops:[{action:'present',who:'nono'},{action:'present',who:'huhu'},{action:'hide'},say('huhu'),tick(),tick(3)]},
 {name:'empty-queue-is-silent',ops:[tick(),tick(3),{action:'hide'},tick()]},
 {name:'same-speaker-after-natural-close',ops:[say('nono'),tick(),tick(3),say('nono'),tick(),tick(3)]},
]){
 cues=[];const card=new mod.namespace.NonoComms(element(),{keepOpen:!!sample.keepOpen});const trace=[];
 for(const op of sample.ops){
  if(op.action==='say')card.say(op.lines,op.urgent,op.append);
  else if(op.action==='update')card.update(op.dt);
  else if(op.action==='hide')card.hide();
  else if(op.action==='present')card.showSpeaker(op.who);
  trace.push({cues:[...cues],talking:card.talking,queue:card.queue.length});
 }
 cases.push({...sample,trace});card.dispose();
}
const radioRelative='shared/story/radio.js';const radioBytes=fs.readFileSync(path.join(baseline.snapshot,radioRelative));
const radioSha=createHash('sha256').update(radioBytes).digest('hex');
if(radioSha!==baseline.files[radioRelative]?.sha256)throw Error('Frozen radio source changed');
const radioCalls=[];
const radioModule=new vm.SourceTextModule(radioBytes.toString('utf8'),{context});
await radioModule.link(()=>new vm.SyntheticModule(['sfx'],function(){this.setExport('sfx',{play(...args){radioCalls.push(args);}});},{context}));
await radioModule.evaluate();
const cuesByName={};
for(const name of ['open','close','intercept','pickup','install','alert','done']){
 radioModule.namespace.radio(name);cuesByName[name]=radioCalls.at(-1);
}
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,files:{[relative]:sha,[radioRelative]:radioSha}},cases,cuesByName}));

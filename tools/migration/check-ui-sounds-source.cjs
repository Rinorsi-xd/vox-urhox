const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const registry=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',baseline.commit+'.json')));
const hashes={};
function Source(name){const data=fs.readFileSync(path.join(baseline.snapshot,name));const sha=crypto.createHash('sha256').update(data).digest('hex');if(sha!==registry.files[name].sha256)throw Error('Source drift '+name);hashes[name]=sha;return data.toString('utf8');}
function Method(text,name){const start=text.indexOf('\n\t'+name+'(');if(start<0)throw Error(name);const end=text.indexOf('\n\t}',start);return text.slice(start,end+3);}
const shell=Source('shared/ui/shell.js'),tutorial=Source('shared/ui/tutorial.js');
const sounds=[],listeners={};let now=0;
const context=vm.createContext({sfx:{init(){},play(id){sounds.push(id);}},document:{addEventListener(id,fn){listeners[id]=fn;}},performance:{now:()=>now},FLOWS:{}});
vm.runInContext('globalThis.Shell=class{'+Method(shell,'_buttonSounds')+'};globalThis.Tutorial=class{'+Method(tutorial,'_advanceClick')+Method(tutorial,'_update')+'};',context);
new context.Shell()._buttonSounds();const pointer=[];
for(const spec of [{button:0,exists:true,disabled:false},{button:0,exists:true,disabled:true},{button:2,exists:true,disabled:false},{button:1,exists:true,disabled:false},{button:0,exists:false,disabled:false}]){
 sounds.length=0;listeners.pointerdown({button:spec.button,target:{closest:()=>spec.exists?{disabled:spec.disabled}:null}});pointer.push({...spec,sounds:[...sounds]});
}
const advances=[];
for(const state of [{talking:true,typed:false,queue:[]},{talking:true,typed:true,queue:['next']},{talking:true,typed:true,queue:[]},{talking:false,typed:false,queue:[]}]){
 sounds.length=0;const t=new context.Tutorial();Object.assign(t,{running:true,_visible:true,step:{next:'button'},i:0,comms:{...state,finishLine(){}},_go(){}});t._advanceClick();advances.push({state,sounds:[...sounds]});
}
const conditions=[];
for(const spec of [{busy:false,doneAt:null,observeHidden:false,got:true},{busy:false,doneAt:10,observeHidden:false,got:true},{busy:true,doneAt:null,observeHidden:true,got:true},{busy:true,doneAt:null,observeHidden:false,got:true},{busy:false,doneAt:null,observeHidden:false,got:false}]){
 sounds.length=0;now=100;const t=new context.Tutorial();Object.assign(t,{app:{},step:{until:()=>spec.got,observeHidden:spec.observeHidden},ctx:{},flow:['first','next'],i:0,_doneAt:spec.doneAt,_busy:()=>spec.busy,suspend(){},_finish(){},_claim(){},_go(){},_layout(){},root:{classList:{remove(){}}},comms:{update(){},typed:true,queue:[]},$(){return {classList:{add(){},toggle(){}}};}});t._update(.01);conditions.push({...spec,sounds:[...sounds]});
}
const pageTabs=[];
vm.runInContext('globalThis.PageShell=class{'+Method(shell,'tab')+Method(shell,'salvageTab')+'};',context);
for(const salvage of [false,true])for(const same of [false,true])for(const quiet of [false,true]){
 sounds.length=0;const s=new context.PageShell(),id=salvage?'garage':'workshop';
 s.home={tab:same?id:'hangar',setTab(v){this.tab=v;},animateIn(){}};
 s.salvage={tab:same?id:'loadout',setTab(v){this.tab=v;},animateIn(){}};s._station=()=>{};
 s[salvage?'salvageTab':'tab'](id,{quiet});pageTabs.push({salvage,same,quiet,id,sounds:[...sounds]});
}
const ui=Source('shared/ui/ui.js'),toasts=[];
const toastContext=vm.createContext({sfx:{play(id){sounds.push(id);}},el(){return {};},setTimeout(){}});
vm.runInContext('globalThis.SourceUI=class{'+Method(ui,'toast')+'};',toastContext);
for(const kind of ['info','ok','bad','warn']){
 sounds.length=0;const s=new toastContext.SourceUI();s.toasts={children:[],appendChild(t){this.children.push(t);}};
 s.toast('test',kind,2200);toasts.push({kind,sounds:[...sounds]});
}
for(const name of ['shared/audio/workshopCues.js','shared/audio/hangarCues.js','shared/audio/mixTrim.js','shared/ui/uiSound.js'])Source(name);
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Sounds.json')));if(data.baseline!==baseline.commit)throw Error('Wrong sound baseline');
for(const cue of Object.values(data.cues)){const source=fs.readFileSync(path.join(baseline.snapshot,cue.source)),actual=fs.readFileSync(path.join(root,'assets',cue.path));if(!actual.equals(source)||crypto.createHash('sha256').update(actual).digest('hex')!==cue.sha256)throw Error('Sample drift '+cue.path);}
(async()=>{
 const load=name=>import(require('node:url').pathToFileURL(path.join(baseline.snapshot,name)).href);
 const {WORKSHOP_CUES}=await load('shared/audio/workshopCues.js'),{HANGAR_CUES}=await load('shared/audio/hangarCues.js'),{MIX_TRIM}=await load('shared/audio/mixTrim.js');
 for(const [id,cue]of Object.entries(data.cues)){
  const original=WORKSHOP_CUES[id]||HANGAR_CUES[id];
  if(!original||cue.gain!==original.gain*10**((MIX_TRIM[id]||0)/20)||cue.gap!==original.gap/1000)throw Error('Original gain/gap drift '+id);
 }
 fs.writeFileSync(path.join(root,'.tmp/ui-sounds-source.json'),JSON.stringify({commit:baseline.commit,sourceHashes:hashes,pointer,advances,conditions,pageTabs,toasts},null,2)+'\n');
 console.log(JSON.stringify({result:'PASS',pointer:pointer.length,advances:advances.length,conditions:conditions.length,samples:Object.keys(data.cues).length,originalGainAndGap:true}));
})().catch(error=>{console.error(error);process.exitCode=1;});

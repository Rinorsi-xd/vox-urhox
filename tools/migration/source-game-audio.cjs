const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const hashes={},modules=new Map();let now=0,feedbackActive=false,speaking=0;
class Param{
 constructor(value=1){this.base=value;this.target=value;this.at=0;this.tau=0;}
 get value(){return this.tau?this.target+(this.base-this.target)*Math.exp(-(now/1000-this.at)/this.tau):this.base;}
 set value(value){this.base=value;this.target=value;this.tau=0;}
 setTargetAtTime(value,at,tau){this.base=this.value;this.target=value;this.at=at;this.tau=tau;}
}
const node=()=>({gain:new Param(),connect(to){return to;}});
class Context{
 constructor(){this.state='running';this.destination=node();}
 get currentTime(){return now/1000;}
 createGain(){return node();}
 createDynamicsCompressor(){return Object.assign(node(),{threshold:new Param(),ratio:new Param()});}
}
const read=file=>{const text=execFileSync('git',['-C','D:/Rino_Project/Vox','show',commit+':'+file],{encoding:'utf8',maxBuffer:8*1024*1024});hashes[file]=crypto.createHash('sha256').update(text).digest('hex');return text;};
const context=vm.createContext({URL,Math,console,performance:{now:()=>now},localStorage:{getItem(){return null;},setItem(){}},window:{AudioContext:Context},document:{}});
function synthetic(entries){return new vm.SyntheticModule(Object.keys(entries),function(){for(const [key,value]of Object.entries(entries))this.setExport(key,value);},{context});}
async function load(file){
 if(modules.has(file))return modules.get(file);
 let source=read(file);
 if(file==='shared/ui/uiSound.js')source+='\nexport { SAMPLES as auditSamples, busOf as auditBus, ensure as auditEnsure, buses as auditBuses }; export const auditFeedback = id => !!(BATTLE_FLOW_CUES[id] || MATCH_FLOW_LIVE[id]); export const auditSetFeedback = value => feedbackUntil=value; export const auditMaster = () => sampleMaster.gain.value;';
 const module=new vm.SourceTextModule(source,{context,identifier:file,initializeImportMeta(meta){meta.url='file:///D:/Rino_Project/Vox/'+file;}});modules.set(file,module);
 await module.link(spec=>load(path.posix.normalize(path.posix.join(path.posix.dirname(file),spec))));return module;
}
(async()=>{
 const samples=await load('shared/ui/uiSound.js');await samples.evaluate();
 const source=read('shared/audio/gameMusic.js');const game=new vm.SourceTextModule(source,{context});
 await game.link(spec=>synthetic(spec.includes('uiSound')?{sfx:{get feedbackActive(){return feedbackActive;},mixContext(){},play(){}}}:spec.includes('levels')?{levels:{get speaking(){return speaking;}}}:spec.includes('musicLibrary')?{MUSIC_POOLS:{}}:spec.includes('musicPlayer')?{MusicPlayer:class{}}:spec.includes('gameAmbience')?{GameAmbience:class{}}:{MusicBox:class{}}));
 await game.evaluate();const cases=[];
 const states=[['home',{}],['trial',{active:true,mapId:'test',input:{locked:true}}],['arena',{active:true,mapId:'crater',input:{locked:true}}],['story',{active:true,mapId:'engine-pit',input:{locked:true}}],['salvage',{active:true,mapId:'salvage',input:{locked:true}}],['edit',{pausedDrive:true,mapId:'crater'}],['menu',{active:true,mapId:'crater',input:{locked:false}}],['firing',{active:true,mapId:'crater',input:{locked:true},firing:true}],['briefing',{active:true,mapId:'crater',modeController:{intro:{}},input:{locked:true}}],['matching',{matchStarting:true}],['over',{active:true,mapId:'crater',input:{locked:true},modeController:{rules:{state:'over'}}}],['mvp',{active:true,mapId:'crater',input:{locked:true},modeController:{mvpShow:{cleared:false}}}]];
 for(const [name,drive]of states)for(const feedback of [false,true])for(const voice of [false,true])for(const intro of [false,true]){
  feedbackActive=feedback;speaking=voice?1:0;
  cases.push({name,drive,feedback,voice,intro,expected:game.namespace.musicState({drive,shell:{screen:'home'},introActive:intro})});
 }
 const cues=Object.fromEntries(Object.entries(samples.namespace.auditSamples).map(([id,cue])=>[id,{gain:cue.gain,bus:samples.namespace.auditBus(id),feedback:samples.namespace.auditFeedback(id),gap:cue.gap,loop:!!cue.loop,attack:cue.attack,release:cue.release}]));
 const mix=[];samples.namespace.auditEnsure();
 for(const [dt,briefing,feedback]of [[.01,true,false],[.06,true,false],[.12,true,false],[.5,true,true],[.01,false,true],[.12,false,true],[.5,false,false],[.12,false,false],[1,false,false]]){
  samples.namespace.auditSetFeedback(feedback?now+10000:0);samples.namespace.sfx.mixContext(briefing);now+=dt*1000;
  mix.push({dt,briefing,feedback,time:now/1000,buses:Object.fromEntries(Object.entries(samples.namespace.auditBuses).map(([id,bus])=>[id,bus.gain.value]))});
 }
 const masters=[];for(const volume of [.1,.325,.65,1]){samples.namespace.sfx.setVolume(volume);masters.push({volume,gain:samples.namespace.auditMaster()});}
 const audioPanels=[];
 for(const [name,active,locked,editing,modal,audioPanel,feedback,voice]of [
  ['home-normal',false,false,false,false,false,false,false],['home-audio',false,false,false,true,true,false,false],
  ['home-other-modal',false,false,false,true,false,false,false],['drive-audio-locked',true,true,false,true,true,false,false],
  ['drive-audio-unlocked',true,false,false,true,true,false,false],['editing-audio',false,false,true,true,true,false,false],
  ['home-audio-feedback',false,false,false,true,true,true,false],['home-audio-speaking',false,false,false,true,true,false,true],
  ['home-after-close',false,false,false,false,false,false,false]]){
  feedbackActive=feedback;speaking=voice?1:0;let expected;
  const host={drive:{active,pausedDrive:editing,mapId:active||editing?'crater':'test',input:{locked}},shell:{screen:'home'},ui:{modalOpen:modal},
   card:{isConnected:audioPanel},musicBox:{opened:false},ambience:{tick(){}},player:{tick(dt,state){expected=state}},
   _refreshHomeMusic(){},_addHudButton(){}};
  game.namespace.GameMusic.prototype.tick.call(host,.016,false);
  audioPanels.push({name,active,locked,editing,modal,audioPanel,feedback,voice,expected});
 }
 process.stdout.write(JSON.stringify({commit,hashes,cases,cues,mix,masters,audioPanels}));
})().catch(error=>{console.error(error);process.exitCode=1;});

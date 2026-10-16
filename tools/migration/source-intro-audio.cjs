const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const commit=baseline.commit,sourceHashes={};
const read=file=>{const bytes=fs.readFileSync(path.join(baseline.snapshot,file)),hash=crypto.createHash('sha256').update(bytes).digest('hex');if(hash!==baseline.files[file].sha256)throw Error('Frozen source drift: '+file);sourceHashes[file]=hash;return bytes.toString('utf8');};
const source=read('three/src/intro/introAudio.js'),player=read('shared/audio/musicPlayer.js');
const gainLine=player.split('\n').find(line=>line.startsWith('export const musicGain ='));
const gain=vm.runInNewContext(gainLine.replace('export const musicGain =','').replace(/;\s*$/,''));
let ctx;
class Param{
 constructor(value=1){this.base=value;this.events=[];}
 get value(){let value=this.base,at=0;for(const event of this.events){if(ctx.currentTime<event.at)return event.ramp?value+(event.value-value)*(ctx.currentTime-at)/(event.at-at):value;value=event.value;at=event.at;}return value;}
 set value(value){this.base=value;this.events=[];}
 setValueAtTime(value,at){this.events.push({value,at,ramp:false});return this;}
 linearRampToValueAtTime(value,at){this.events.push({value,at,ramp:true});return this;}
 cancelScheduledValues(at){const value=this.value;this.events=this.events.filter(event=>event.at<at);this.events.push({value,at,ramp:false});return this;}
}
const node=()=>({gain:new Param(),connect(to){return to;}});
class Context{
 constructor(){ctx=this;this.currentTime=0;this.state='running';this.destination=node();}
 createGain(){return node();}
 createDynamicsCompressor(){return Object.assign(node(),Object.fromEntries(['threshold','knee','ratio','attack','release'].map(key=>[key,new Param()])));}
 createAnalyser(){return Object.assign(node(),{getFloatTimeDomainData(array){array.fill(0);}});}
 createBufferSource(){return Object.assign(node(),{playbackRate:new Param(),start(){},stop(at){this.stopAt=at;}});}
 createBiquadFilter(){return Object.assign(node(),{frequency:new Param(),Q:new Param()});}
 suspend(){this.state='suspended';return Promise.resolve();}
 resume(){this.state='running';return Promise.resolve();}
 close(){this.state='closed';return Promise.resolve();}
}
(async()=>{
 const volumes={sfx:.65,voice:.6,music:.75},listeners={};
 const on=(key,callback)=>{listeners[key]=callback;callback(volumes[key]);return()=>{};};
 let wall=0;const timers=[];
 const document={hidden:false,addEventListener(){},removeEventListener(){}};
 const context=vm.createContext({URL,window:{AudioContext:Context},document,setTimeout:(fn,delay)=>timers.push({at:wall+delay,fn})});
 const module=new vm.SourceTextModule(source,{context,initializeImportMeta(meta){meta.url='file:///D:/Rino_Project/Vox/three/src/intro/introAudio.js';}});
 await module.link(specifier=>{
  const entries=specifier.includes('uiSound')?{sfx:{onVolume:callback=>on('sfx',callback)}}:
   specifier.includes('levels.js')?{levels:{on},DEFAULT_LEVELS:{voice:.6,music:.75}}:{musicGain:gain};
  return new vm.SyntheticModule(Object.keys(entries),function(){for(const [key,value]of Object.entries(entries))this.setExport(key,value);},{context});
 });
 await module.evaluate();const audio=new module.namespace.IntroAudio();
 audio.buf.set('vo_test',{duration:2});audio.buf.set('bgm_test',{duration:40});audio.playMusic('bgm_test',{vol:.5,fade:0});
 const trace=[];
 for(const [time,action]of [[0,'voice'],[.075,'none'],[.15,'none'],[1.999,'none'],[2,'end'],[2.1,'none'],[2.3,'none'],[2.6,'none'],[2.7,'voice'],[2.775,'none'],[2.8,'stop'],[2.9,'none'],[3.1,'none'],[3.4,'none']]){
  ctx.currentTime=time;
  if(action==='voice')audio.voice('vo_test');
  if(action==='end')for(const voice of [...audio.voices])voice.src.onended();
  if(action==='stop')audio.stopVoices();
  trace.push({time,action,gain:audio.music.g.gain.value*audio.musicBus.gain.value*audio.musicLevel.gain.value*audio.master.gain.value});
 }
 const data=JSON.parse(fs.readFileSync(path.resolve('assets/Intro/Intro.json'),'utf8'));
 const cues=[];
 for(const id of Object.keys(data.audio).filter(id=>id.startsWith('sfx_'))){
  audio.buf.set(id,{duration:1});
  for(const volume of [0,.1,.65,1])for(const relative of [.2,.5,1])for(const rate of [.7,1,1.4]){
   listeners.sfx(volume);const handle=audio.sfx(id.slice(4),{vol:relative,rate});
   cues.push({id,volume,relative,rate,gain:handle.g.gain.value*audio.sfxBus.gain.value*audio.master.gain.value});
  }
 }
 const stops=[];
 for(const [index,fade]of [.6,.2,1.5,0,null].entries()){
  ctx.currentTime=10+index*10;listeners.sfx(.65);const start=ctx.currentTime;
  const handle=audio.sfx('alarm',{vol:.32,loop:true});
  if(fade===null)handle.stop();else handle.stop(fade);
  const duration=fade??.05,samples=[];
  for(const elapsed of [0,duration*.5,duration,duration+.019,duration+.021]){
   ctx.currentTime=start+elapsed;
   samples.push({elapsed,gain:handle.g.gain.value*audio.sfxBus.gain.value*audio.master.gain.value,stopped:ctx.currentTime>=handle.src.stopAt});
  }
  stops.push({fade,samples});
 }
 ctx.currentTime=100;listeners.sfx(.65);const repeated=audio.sfx('alarm',{vol:.32,loop:true});repeated.stop(.6);
 const repeatedStops=[];
 for(const [elapsed,action,volume]of [[0,'none',.65],[.2,'stop',.65],[.25,'volume',.3],[.3,'none',.3],[.4,'none',.3],[.421,'none',.3]]){
  ctx.currentTime=100+elapsed;if(action==='stop')repeated.stop(.2);if(action==='volume')listeners.sfx(volume);
  repeatedStops.push({elapsed,action,volume,gain:repeated.g.gain.value*audio.sfxBus.gain.value*audio.master.gain.value,stopped:ctx.currentTime>=repeated.src.stopAt});
 }
 const masterTails=[];
 for(const [name,steps]of [
  ['normal',[[0,true],[.35,true],[.7,true],[1.2,true],[1.399,true],[1.4,true]]],
  ['paused',[[0,true],[.35,true],[.7,false],[1.2,false],[1.4,false]]],
  ['volume',[[0,true],[.35,true],[.7,true],[1.2,true],[1.4,true]]],
 ]){
  Object.assign(volumes,{sfx:.65,voice:.6,music:.75});wall=0;timers.length=0;document.hidden=false;
  const tail=new module.namespace.IntroAudio();const context=ctx;
  tail.buf.set('vo_test',{duration:60});tail.buf.set('bgm_test',{duration:60});tail.buf.set('sfx_alarm',{duration:60});
  tail.playMusic('bgm_test',{vol:.5,fade:0});tail.voice('vo_test');const cue=tail.sfx('alarm',{vol:.32,rate:.7,loop:true});
  tail.fadeOutAll(1.2);const closeDeadline=timers[0].at;let previous=0;const samples=[];
  for(const [elapsed,focused]of steps){
   document.hidden=!focused;tail.hidden();
   if(focused)context.currentTime+=elapsed-previous;
   previous=elapsed;wall=elapsed*1000;
   if(name==='volume'&&elapsed===.7){listeners.voice(.3);listeners.sfx(.2);listeners.music(.25);}
   for(const timer of timers)if(!timer.fired&&wall>=timer.at){timer.fired=true;timer.fn();}
   samples.push({elapsed,focused,audioTime:context.currentTime,closed:context.state==='closed',master:tail.master.gain.value/.9,
    voice:tail.voiceBus.gain.value*tail.voiceLevel.gain.value*tail.master.gain.value,
    sfx:cue.g.gain.value*tail.sfxBus.gain.value*tail.master.gain.value,
    music:tail.music.g.gain.value*tail.musicBus.gain.value*tail.musicLevel.gain.value*tail.master.gain.value});
  }
  masterTails.push({name,closeDeadline,samples});
 }
 const transitions=[];
 for(const kind of ['voice-stop','voice-overlap','music-partial','music-zero','tvcut','scribble']){
  Object.assign(volumes,{sfx:.65,voice:.6,music:.75});
  const value=new module.namespace.IntroAudio(),clock=ctx;
  value.buf.set('vo_test',{duration:2});value.buf.set('bgm_test',{duration:60});value.buf.set('sfx_tv_cut',{duration:60});value.buf.set('sfx_scribble',{duration:60});
  let handle,start=0,events=[];
  if(kind.startsWith('voice')){
   value.voice('vo_test');handle=[...value.voices][0];clock.currentTime=.3;start=.3;value.stopVoices();
   if(kind==='voice-overlap')value.voice('vo_test');
   for(const elapsed of [0,.04,.08,.099,.101]){
    clock.currentTime=start+elapsed;
    events.push({elapsed,level:handle.g.gain.value*value.voiceLevel.gain.value*value.master.gain.value,stopped:clock.currentTime>=handle.src.stopAt,
     currentLevel:[...value.voices].at(-1)?.g.gain.value*value.voiceLevel.gain.value*value.master.gain.value||0});
   }
  }else if(kind.startsWith('music')){
   value.playMusic('bgm_test',{vol:.75,fade:1.2});handle=value.music;clock.currentTime=.3;start=.3;value.stopMusic(kind==='music-zero'?0:.6);
   for(const elapsed of [0,.01,.021,.15,.3,.6,.619,.621]){
    clock.currentTime=start+elapsed;events.push({elapsed,level:handle.g.gain.value*value.musicBus.gain.value*value.musicLevel.gain.value*value.master.gain.value,stopped:clock.currentTime>=handle.src.stopAt});
   }
  }else{
   handle=value.sfx(kind==='tvcut'?'tv_cut':'scribble',{vol:kind==='tvcut'?.5:.4,loop:kind==='scribble'});
   clock.currentTime=kind==='tvcut'?.45:.3;start=clock.currentTime;handle.stop(kind==='tvcut'?.15:.1);
   for(const elapsed of [0,.05,.1,.15,.169,.171]){
    clock.currentTime=start+elapsed;events.push({elapsed,level:handle.g.gain.value*value.sfxBus.gain.value*value.master.gain.value,stopped:clock.currentTime>=handle.src.stopAt});
   }
  }
  transitions.push({kind,start,events});
 }
 const intro=read('three/src/intro/intro.js'),story=read('three/src/intro/introStory.js');
 const rateLine=intro.split('\n').find(line=>line.includes('this.heart.src.playbackRate.value ='));
 const heartbeat=[0,.25,.5,.75,1].map(k=>{const target={heart:{src:{playbackRate:{value:1}}}};new Function('k',rateLine).call(target,k);return {progress:k,rate:target.heart.src.playbackRate.value};});
 const commsConfirm=story.split('\n').find(line=>line.includes("this.audio.sfx( 'confirm', { vol: 0.6 } )"));
 if(!commsConfirm)throw Error('Missing frozen comms confirm cue');
 const storyModule=new vm.SourceTextModule(story,{context,initializeImportMeta(meta){meta.url='file:///D:/Rino_Project/Vox/three/src/intro/introStory.js';}});
 await storyModule.link(specifier=>{
  const entries=specifier.includes('introLogo')?{insignia:()=>''}:specifier.includes('holoPortrait')?{HoloPortrait:class{}}:{hudFrame:()=>{}};
  return new vm.SyntheticModule(Object.keys(entries),function(){for(const [key,value]of Object.entries(entries))this.setExport(key,value);},{context});
 });
 await storyModule.evaluate();
 const voiceClock=[];
 const cases=[
  {name:'natural-before-duration',steps:[{dt:1.9},{dt:.05,end:true}]},
  {name:'natural-after-duration',steps:[{dt:1.9},{dt:.4},{dt:0,end:true}]},
  {name:'ended-during-typing',steps:[{dt:.3,end:true},{dt:1.6}]},
  {name:'click-twice',steps:[{dt:.1,tap:true},{dt:.1,tap:true}]},
  {name:'missing',missing:true,steps:[{dt:.3},{dt:20}]},
  {name:'missing-click',missing:true,steps:[{dt:.1,tap:true}]},
  {name:'post-line-pause',wait:true,steps:[{dt:1.9},{dt:.05,end:true},{dt:.89},{dt:.02}]},
  {name:'skip-post-line-pause',wait:true,steps:[{dt:1.9},{dt:.05,end:true},{dt:.1,tap:true}]},
 ];
 for(const definition of cases){
  const value=new module.namespace.IntroAudio();if(!definition.missing)value.buf.set('vo_v01',{duration:2});
  const target=Object.create(storyModule.namespace.IntroStory.prototype),tasks=[],waits=[];let nextVisible=false;
  Object.assign(target,{time:0,log:[],audio:value,vv:{nx:{classList:{add(){nextVisible=true;},remove(){nextVisible=false;}}},tx:{innerHTML:''}}});
  target.task=fn=>new Promise(resolve=>tasks.push({fn,resolve,start:target.time}));
  target.wait=duration=>new Promise(resolve=>waits.push({until:target.time+duration,resolve}));
  let complete=false;target.vivi('v01','talk',{wait:definition.wait===true}).then(()=>{complete=true;});
  const samples=[];
  for(const step of definition.steps){
   if(step.tap)target.onAdvance?.();
   if(step.end)for(const handle of [...value.voices])handle.src.onended();
   target.time+=step.dt;
   for(const task of [...tasks])if(!task.fn(0,step.dt,target.time-task.start)){tasks.splice(tasks.indexOf(task),1);task.resolve();}
   for(const wait of [...waits])if(target.time>=wait.until){waits.splice(waits.indexOf(wait),1);wait.resolve();}
   for(let i=0;i<8;i++)await Promise.resolve();
   samples.push({...step,age:target.time,complete,nextVisible,voicePending:value.voices.size>0});
  }
  voiceClock.push({...definition,samples});
 }
 process.stdout.write(JSON.stringify({commit,sourceHashes,trace,cues,stops,repeatedStops,masterTails,transitions,heartbeat,voiceClock}));
})().catch(error=>{console.error(error);process.exitCode=1;});

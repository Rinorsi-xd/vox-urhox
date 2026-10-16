const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const hashes={},modules=new Map(),all=[];let now=0,serial=0;
class Param{
 constructor(value=1){this.base=value;this.target=value;this.at=0;this.tau=0;}
 get value(){return this.tau?this.target+(this.base-this.target)*Math.exp(-(now-this.at)/this.tau):this.base;}
 set value(value){this.base=value;this.target=value;this.tau=0;}
 setTargetAtTime(value,at,tau){this.base=this.value;this.target=value;this.at=at;this.tau=tau;}
}
const node=()=>({gain:new Param(),connect(to){return to;},disconnect(){}});
class Context{
 constructor(){this.state='running';this.destination=node();}
 get currentTime(){return now;}
 createGain(){return node();}
 createDynamicsCompressor(){return {...node(),threshold:new Param(),ratio:new Param()};}
 createStereoPanner(){return {...node(),pan:new Param(0)};}
 createBufferSource(){const source={playbackRate:new Param(),playing:false,loop:false,disconnect(){},
  connect(gain){this.gainNode=gain;const original=gain.connect;gain.connect=pan=>{this.panNode=pan;return original.call(gain,pan);};return gain;},
  start(){this.playing=true;this.order=++serial;},stop(at=now){this.stopAt=at;if(at<=now)this.end();},
  end(){if(!this.playing)return;this.playing=false;this.onended?.();}};all.push(source);return source;}
 async decodeAudioData(){return {duration:100};}
}
function read(file){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,file)),hash=crypto.createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[file]?.sha256)throw Error('Frozen source bytes drifted: '+file);
 hashes[file]=hash;return bytes.toString('utf8');
}
const math=Object.create(Math);math.random=()=>.5;
const document={hidden:false,addEventListener(){}};
const context=vm.createContext({URL,Math:math,console,performance:{now:()=>now*1000},setTimeout(){throw Error('Unexpected timer');},
 fetch:async()=>({ok:true,arrayBuffer:async()=>new ArrayBuffer(0)}),window:{AudioContext:Context,addEventListener(){}},document});
async function load(file){
 if(modules.has(file))return modules.get(file);
 let code=read(file);
 if(file==='shared/ui/uiSound.js')code+='\nexport { ensure as auditEnsure, loops as auditLoops, voices as auditVoices, SAMPLES as auditSamples }; export const auditMaster=()=>sampleMaster.gain.value;';
 const module=new vm.SourceTextModule(code,{context,identifier:file,initializeImportMeta(meta){meta.url='file:///D:/Rino_Project/Vox/'+file;}});modules.set(file,module);
 await module.link(spec=>load(path.posix.normalize(path.posix.join(path.posix.dirname(file),spec))));return module;
}
const scenarios=[];
for(const id of ['drive_idle','drive_load','track_loop','hover_loop','thruster_loop'])for(const remote of [false,true]){
 const key=(remote?'remote:':'')+id;
 scenarios.push({name:key,actions:[
  {op:'loop',key,id,amount:1,rate:1.4,pan:.8,dt:.016},{op:'loop',key,id,amount:.25,rate:.7,pan:-.6,dt:.032},
  {op:'loop',key,id,amount:.005000001,rate:2,pan:.2,dt:.08},{op:'loop',key,id,amount:.005,dt:0},
  {op:'wait',dt:.124},{op:'wait',dt:.001},{op:'loop',key,id,amount:.004999999,dt:.02},
  {op:'loop',key,id,amount:.6,rate:.2,pan:-.7,dt:0},{op:'wait',dt:.04},
  {op:'loop',key,id,amount:0,dt:.03},{op:'loop',key,id,amount:1,rate:1.5,pan:.5,dt:.02},
  {op:'wait',dt:.08},{op:'stop',dt:0},{op:'loop',key,id,amount:.8,rate:1.2,pan:.3,dt:.03},
  {op:'pause',dt:0},{op:'resume',dt:0},{op:'loop',key,id,amount:.4,rate:.8,pan:-.2,dt:.01},{op:'stop',dt:.2}
 ]});
}
const rapid=[];for(let i=0;i<22;i++)rapid.push({op:'loop',key:'drive_idle',id:'drive_idle',amount:.8,dt:0},{op:'loop',key:'drive_idle',id:'drive_idle',amount:0,dt:0});
rapid.push({op:'wait',dt:.125},{op:'loop',key:'remote:drive_load',id:'drive_load',amount:1,rate:1.3,pan:.6,dt:.04},{op:'stop',dt:0});
scenarios.push({name:'bounded-restarts-and-reuse',actions:rapid});
scenarios.push({name:'actual-update-local-remote',actions:[
 {op:'update',speed:6,throttle:1,mixed:true,remote:true,dt:.016},
 {op:'update',speed:12,throttle:0,mixed:true,remote:true,dt:.04},
 {op:'update',speed:0,throttle:0,mixed:false,remote:false,dt:.032},
 {op:'update',speed:0,throttle:0,mixed:false,remote:false,dt:.092},
 {op:'update',speed:0,throttle:0,mixed:false,remote:false,dt:.001},
 {op:'update',speed:3,throttle:1,mixed:true,remote:true,dt:.03},{op:'pause',dt:0}
]});
(async()=>{
 const module=await load('shared/ui/uiSound.js');await module.evaluate();const api=module.namespace;
 await api.sfx.init();api.auditEnsure(true);api.sfx.setVolume(.65);
 const snapshot=()=>({voices:[...api.auditVoices].filter(([s])=>s.playing).map(([s,id])=>({id,key:s.auditKey,order:s.order,gain:s.gainNode.gain.value*api.auditMaster(),rate:s.playbackRate.value,pan:s.panNode.pan.value})).sort((a,b)=>a.order-b.order),active:[...api.auditLoops.keys()].sort()});
 for(const scenario of scenarios){api.sfx.stopAll();document.hidden=false;serial=0;scenario.samples=[];
  for(const action of scenario.actions){
   if(action.op==='loop')api.sfx.setLoop(action.id,action.amount,action.rate??1,action.pan??0,action.key);
   else if(action.op==='update'){
    const vehicle={speed:action.speed,wheels:action.mixed?[{track:false},{track:true}]:[],trackWheels:action.mixed?[{}]:[],hovers:action.mixed?[{}]:[],thrusterOutputs:new Map([[1,action.mixed?.64:0]]),telemetry:{hoverForce:action.mixed?10:0}};
    api.sfx.updateDriving(vehicle,{throttle:action.throttle});
    const enemy={alive:true,pos:[10,0,0],vehicle:{...vehicle,speed:6}};
    api.sfx.updateRemoteDriving(action.remote?[enemy]:[],null,{pos:[0,0,0],right:[-1,0,0]});
   }else if(action.op==='stop'||action.op==='pause'){api.sfx.stopDriving();if(action.op==='pause')document.hidden=true;}
   else if(action.op==='resume')document.hidden=false;
   for(const [key,value]of api.auditLoops)value.source.auditKey=key;
   now+=action.dt;for(const voice of all)if(voice.playing&&voice.stopAt!==undefined&&voice.stopAt<=now+1e-12)voice.end();
   scenario.samples.push(snapshot());
  }
 }
 process.stdout.write(JSON.stringify({commit:baseline.commit,hashes,scenarios,cues:Object.fromEntries(Object.entries(api.auditSamples).map(([id,cue])=>[id,{gain:cue.gain,attack:cue.attack||.08,release:cue.release||.025}]))}));
})().catch(error=>{console.error(error);process.exitCode=1;});

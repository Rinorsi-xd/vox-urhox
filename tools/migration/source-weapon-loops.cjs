const path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const commit='b276064942ae09c0227ec28d4cfda1d5ff006455',hashes={},modules=new Map();
let now=0,serial=0;const all=[];
class Param {
 constructor(value=1){this.base=value;this.target=value;this.at=0;this.tau=0;}
 get value(){return this.tau?this.target+(this.base-this.target)*Math.exp(-(now-this.at)/this.tau):this.base;}
 set value(value){this.base=value;this.target=value;this.tau=0;}
 setTargetAtTime(value,at,tau){this.base=this.value;this.target=value;this.at=at;this.tau=tau;}
}
const node=()=>({gain:new Param(),connect(to){return to;},disconnect(){}});
class Context {
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
const read=file=>{const text=execFileSync('git',['-C','D:/Rino_Project/Vox','show',commit+':'+file],{encoding:'utf8',maxBuffer:8*1024*1024});hashes[file]=crypto.createHash('sha256').update(text).digest('hex');return text;};
const math=Object.create(Math);math.random=()=>.5;
const context=vm.createContext({URL,Math:math,console,performance:{now:()=>now*1000},setTimeout(){throw Error('Unexpected timer');},
 fetch:async()=>({ok:true,arrayBuffer:async()=>new ArrayBuffer(0)}),window:{AudioContext:Context,addEventListener(){}},document:{hidden:false,addEventListener(){}}});
async function load(file){
 if(modules.has(file))return modules.get(file);
 let text=read(file);
 if(file==='shared/ui/uiSound.js')text+='\nexport { ensure as auditEnsure, loops as auditLoops, voices as auditVoices, SAMPLES as auditSamples }; export const auditMaster=()=>sampleMaster.gain.value;';
 const module=new vm.SourceTextModule(text,{context,identifier:file,initializeImportMeta(meta){meta.url='file:///D:/Rino_Project/Vox/'+file;}});modules.set(file,module);
 await module.link(spec=>load(path.posix.normalize(path.posix.join(path.posix.dirname(file),spec))));return module;
}
const scenarios=[];
for(const id of ['mg_motor','sniper_charge','missile_flight'])scenarios.push({name:id,actions:[
 {op:'loop',id,amount:1,rate:1.4,pan:.8,dt:.016},{op:'loop',id,amount:.25,rate:.7,pan:-.6,dt:.032},
 {op:'loop',id,amount:.005000001,rate:2,pan:.2,dt:.08},{op:'loop',id,amount:.005,dt:0},
 {op:'wait',dt:.124},{op:'wait',dt:.001},{op:'loop',id,amount:.004999999,dt:.02},
 {op:'loop',id,amount:.6,rate:.2,pan:-.7,dt:0},{op:'wait',dt:.04},
 {op:'loop',id,amount:0,dt:.03},{op:'loop',id,amount:1,rate:1.5,pan:.5,dt:.02},
 {op:'wait',dt:.08},{op:'stop',dt:0},{op:'loop',id,amount:.8,rate:1.2,pan:.3,dt:.03},
 {op:'pause',dt:0},{op:'resume',dt:0},{op:'loop',id,amount:.4,rate:.8,pan:-.2,dt:.01},{op:'stop',dt:.2} ]});
scenarios.push({name:'sniper-fire',actions:[{op:'loop',id:'sniper_charge',amount:.9,rate:1.3,pan:0,dt:.08},{op:'fire',remote:false,dt:0},{op:'wait',dt:.124},{op:'wait',dt:.001},{op:'stop',dt:0},{op:'loop',id:'sniper_charge',amount:.7,rate:1.2,dt:.04},{op:'fire',remote:true,dt:.02},{op:'stop',dt:0}]});
const rapid=[];for(let i=0;i<22;i++)rapid.push({op:'loop',id:'mg_motor',amount:.8,dt:0},{op:'loop',id:'mg_motor',amount:0,dt:0});rapid.push({op:'wait',dt:.125},{op:'loop',id:'mg_motor',amount:1,rate:1.3,pan:.6,dt:.04},{op:'stop',dt:0});scenarios.push({name:'bounded-restarts',actions:rapid});
const shots=[];for(let i=0;i<5;i++)shots.push({op:'play',id:'mg_fire',dt:.2});for(const id of ['laser_fire','sniper_fire','missile_eject','missile_launch','missile_blast','hit_metal','hit_ground','weapon_dry','energy_online','missile_scan','missile_lock'])shots.push({op:'play',id,dt:.2});shots.push({op:'stop',dt:0});scenarios.push({name:'ten-one-shots',actions:shots});
scenarios.push({name:'production-update',actions:[{op:'update',spin:.8,dt:.016},{op:'update',spin:.2,dt:.04},{op:'update',spin:0,dt:0},{op:'update',spin:0,dt:.124},{op:'update',spin:0,dt:.001},{op:'update',spin:.9,dt:.03},{op:'pause',dt:0}]});
(async()=>{
 const module=await load('shared/ui/uiSound.js');await module.evaluate();const api=module.namespace;
 await api.sfx.init();api.auditEnsure(true);api.sfx.setVolume(.65);
 const snapshot=()=>({voices:[...api.auditVoices].filter(([s])=>s.playing).map(([s,id])=>({id,loop:s.loop,gain:s.gainNode.gain.value*api.auditMaster(),rate:s.playbackRate.value,pan:s.panNode.pan.value,order:s.order})).sort((a,b)=>a.order-b.order),active:[...api.auditLoops.keys()].sort()});
 for(const scenario of scenarios){api.sfx.stopAll();serial=0;scenario.samples=[];
  for(const action of scenario.actions){
   if(action.op==='loop')api.sfx.setLoop(action.id,action.amount,action.rate??1,action.pan??0);
   else if(action.op==='play')api.sfx.play(action.id,1,0);
   else if(action.op==='fire')api.sfx.consumeWeapons([{type:'shot',kind:'sniper',pos:[0,0,0],remote:action.remote}],{pos:[0,0,0],right:[1,0,0]});
   else if(action.op==='update')api.sfx.updateWeapons({groups:[{weapons:[{spin:action.spin}]}],projectiles:[],group:null,lockInfo:()=>null},{pos:[0,0,0],right:[1,0,0]},[]);
   else if(action.op==='stop'||action.op==='pause')api.sfx.stopDriving();
   now+=action.dt;for(const source of all)if(source.playing&&source.stopAt!==undefined&&source.stopAt<=now+1e-12)source.end();
   scenario.samples.push(snapshot());
  }
 }
 process.stdout.write(JSON.stringify({commit,hashes,scenarios,cues:Object.fromEntries(Object.entries(api.auditSamples).map(([id,cue])=>[id,{gain:cue.gain,attack:cue.attack||.08,release:cue.release||.025}]))}));
})().catch(error=>{console.error(error);process.exitCode=1;});

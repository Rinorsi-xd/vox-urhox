import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
if(baseline.commit!=='b276064942ae09c0227ec28d4cfda1d5ff006455')throw Error('Unexpected baseline');
const files={},noop=()=>{};
const context=vm.createContext({THREE:{Vector3:class{}},BOSS_KIND:{},radio:noop,URL,URLSearchParams,location:{search:''},PHYSICS_DT:1/60,
 sfx:new Proxy({},{get:()=>noop}),cameraListener:noop,CollisionAudio:class{beforeStep(){}afterStep(){return []}},performance:{now:()=>0}});
function load(relative,name){
 const bytes=fs.readFileSync(`${baseline.snapshot}/${relative}`),hash=crypto.createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[relative]?.sha256)throw Error(`Frozen source changed: ${relative}`);
 files[relative]=hash;
 return vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'').replaceAll('import.meta.url',"'file:///source.js'")}\nreturn ${name};})()`,context);
}
context.KINDS=load('three/src/battle/storyKinds.js','KINDS');
const Mission=load('three/src/battle/storyMission.js','StoryMission'),Drive=load('three/src/drive/testDrive.js','TestDrive');
function fixture(install){
 let prompt=null;
 const step={id:'install',kind:'install',pos:[0,2,0],r:9};
 const m=Object.create(Mission.prototype),d=Object.create(Drive.prototype);
 const p={alive:true,pos:[0,2,0],flush:noop,spawn(){this.alive=true;d.vehicle={speed:0};}};
 Object.assign(m,{level:{steps:[step,{id:'after',kind:'reach',pos:[1000,2,0],r:1}],respawn:[]},i:0,begun:true,time:10,deadAt:null,finished:false,
  install,holdG:false,stats:{deaths:0,kills:0,collectors:0},enemies:new Map(),checkpoint:{pos:[0,2,0],yaw:0},drive:d,
  hud:{update:noop,prompt(v){prompt=v},dead:noop,marker:noop,pips:noop,say:noop,progress:noop,banner:noop},
  view:new Proxy({},{get:()=>noop}),fx:{update:noop}});
 m._beats=noop;m._marker=noop;m._place=noop;m._yaw=()=>0;m._go=i=>m.i=i;m._collectorSpot=()=>[0,2,0];
 m.carSize=()=>({w:2,below:1.5,above:1.5});
 Object.assign(d,{vehicle:{speed:0},player:p,input:{controlling:false,touchInteract:false},acc:0,modeController:m,
  sim:{viewEvents:[],units:[p],step:noop},combat:{consume:noop,update:noop},track:{update:noop},camera:{}});
 d._syncPlayer=noop;d._comWorld=x=>x;d._effects=noop;d._hud=noop;
 m.update(0);
 return {m,d,p,prompt:()=>prompt};
}
const cases=[];
for(const hz of [60,30,2])for(const install of [0,1.2,2.39]){
 const f=fixture(install),trace=[],cycles=[];
 for(let cycle=0;cycle<2;cycle++){
  f.p.alive=false;f.d.vehicle=null;
  // Production H5 invokes afterStep even in the no-vehicle branch.
  let wall=0,frames=0;
  while(!f.p.alive&&frames<2000){
   Drive.prototype.update.call(f.d,1/hz,wall);wall+=1/hz;frames++;
   if(frames===1||Math.abs(wall-1)<.00001||f.p.alive)
    trace.push({cycle,wall,install:f.m.install,prompt:f.prompt()?.progress,alive:f.p.alive});
  }
  if(!f.p.alive)throw Error('Source never respawned');
  cycles.push({wall,frames,install:f.m.install,deaths:f.m.stats.deaths});
 }
 f.m.update(1/60);
 const released={install:f.m.install,prompt:f.prompt()?.progress};
 f.m.holdG=true;
 let held=0;
 while(f.m.i===0&&held<500){f.m.update(1/60);held++;}
 cases.push({hz,initial:install,trace,cycles,released,heldFrames:held,collectors:f.m.stats.collectors,complete:f.m.i===1});
}
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,files},cases,
 boundary:'SHA-verified frozen TestDrive.update, StoryMission.afterStep/update/_respawn. Physics, native render/audio, placement and next-objective presentation use adapters. Two deaths precede release/rehold. No GPU or natural-game acceptance.'}));

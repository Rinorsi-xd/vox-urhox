import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const name='three/src/drive/testDrive.js';
const text=fs.readFileSync(path.join(baseline.snapshot,name),'utf8');
const hash=createHash('sha256').update(text).digest('hex');
if(hash!==baseline.files[name]?.sha256)throw Error('Frozen camera feedback changed');
const THREE=await import(pathToFileURL(path.join(baseline.snapshot,'three/vendor/three/build/three.module.js')));
const constants=text.slice(text.indexOf('const SHAKE ='),text.indexOf('const hullOf'));
const start=text.indexOf('\n\t_effects( dt, com ) {');
const end=text.indexOf('\n\t// 顶部罗盘',start);
if(start<0||end<0)throw Error('Frozen effects section not found');
const body=text.slice(start,end).replace(/^\s*_effects\( dt, com \) \{/,'function effects(dt,com){');
const effects=Function('THREE','sfx','cameraListener',constants+'\n'+body+'\nreturn effects;')(THREE,{consumeWeapons(){},play(){}},()=>({}));
const keys=['trauma','drillImpact','shakeT','rumble','rumbleTo','rumbleK','rumbleAt','rumbleT','thump','stompY','stompV','nodY','nodV','mechSpeed'];
const scenarios=[];
for(const kind of ['quiet','mg','sniper','blast','drill','mech','external','mixed']){
 const state={camera:new THREE.PerspectiveCamera(),fx:{consume(){},update(){},stomp(){},drillSpeed:{update(){}}},sim:{fx:[],units:[]},
  input:{controlling:true},cam:{eye:null},stepFx:[],weapons:{projectiles:[]},renderer:{getSize:v=>v.set(1600,900)}};
 for(const key of keys)state[key]=0;state.rumbleK=1;state.rumbleAt=-9;
 const frames=[];
 for(let frame=0;frame<120;frame++){
  const dt=[1/60,1/120,1/30,.08][frame%4],events=[],footfalls=[];
  if((kind==='mg'||kind==='mixed')&&frame<55&&frame%2===0)events.push({type:'shot',kind:'mg',spin:frame/55,tier:3+frame%3,kick:.09,shake:.32});
  if((kind==='sniper'||kind==='mixed')&&frame%23===0)events.push({type:'shot',kind:'sniper',tier:4,kick:.65,shake:1});
  if((kind==='blast'||kind==='mixed')&&frame%31===0)events.push({type:frame%2?'explode':'blast',pos:[frame/2,2,0]});
  if(kind==='drill'&&frame%17===0)events.push({type:'drill',stage:['impact','grind','fling','start'][Math.floor(frame/17)%4]});
  if((kind==='mech'||kind==='mixed')&&frame%11===0)footfalls.push({kind:['plant','launch','land'][Math.floor(frame/11)%3],strength:.3+(frame%7)/10,pos:[2,6,3]});
  const impulse=kind==='external'&&frame%30===0?-2.2:0;state.stompV+=impulse;
  const speed=frame<70?18:-2;
  state.vehicle={speed,mechControl:kind==='mech'||kind==='mixed'?{footfalls:structuredClone(footfalls),standAvg:8.5}:null};
  const base={pos:[8,4,6],rotation:[.15+Math.sin(frame*.1)*.2,-.7+frame*.01,.2]};
  state.camera.position.fromArray(base.pos);state.camera.rotation.set(...base.rotation,'XYZ');
  const baseRight=new THREE.Vector3(1,0,0).applyQuaternion(state.camera.quaternion).toArray();
  const baseUp=new THREE.Vector3(0,1,0).applyQuaternion(state.camera.quaternion).toArray();
  const baseForward=state.camera.getWorldDirection(new THREE.Vector3()).toArray();
  state.stepFx=structuredClone(events);effects.call(state,dt,new THREE.Vector3(0,2,0));
  frames.push({dt,events,footfalls,impulse,speed,base:{...base,right:baseRight,up:baseUp,forward:baseForward},
   expected:{state:Object.fromEntries(keys.map(k=>[k,state[k]])),pos:state.camera.position.toArray(),
    right:new THREE.Vector3(1,0,0).applyQuaternion(state.camera.quaternion).toArray(),
    up:new THREE.Vector3(0,1,0).applyQuaternion(state.camera.quaternion).toArray(),forward:state.camera.getWorldDirection(new THREE.Vector3()).toArray()}});
 }
 scenarios.push({kind,frames});
}
const output=path.join(root,'.tmp/source-camera-feedback.json');
fs.writeFileSync(output,JSON.stringify({sourceCommit:baseline.commit,provenance:{[name]:hash},scenarios}));
console.log(JSON.stringify({output,scenarios:scenarios.length,frames:scenarios.reduce((n,c)=>n+c.frames.length,0)}));

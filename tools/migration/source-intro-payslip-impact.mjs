import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const sourceHashes={};
function frozen(name){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,name));
 const hash=createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[name].sha256)throw Error('Source drift: '+name);
 sourceHashes[name]=hash;return bytes.toString('utf8');
}
const intro=frozen('three/src/intro/intro.js'),story=frozen('three/src/intro/introStory.js'),fx=frozen('three/src/intro/introFx.js');
const shake=story.slice(story.indexOf('\tshakeDom('),story.indexOf('\n\t// 鼠标视差'));
const randoms=Array.from({length:22},(_,i)=>((i*37+5)%100)/100);
const cases=[];
for(const duration of [2,5.86,9]){
 let I,shakeEvent,wipeMarkup,wipeAnimation,randomIndex=0;
 const randomMath=Object.create(Math);randomMath.random=()=>randoms[randomIndex++];
 const node=()=>({style:{},remove(){},querySelector:()=>node(),animate:()=>({finished:new Promise(()=>{})}),
  get firstChild(){return {animate(frames,options){wipeAnimation={frames,options};return {finished:new Promise(()=>{})};}};}});
 const h=(tag,cls,parent,html)=>{if(cls==='wipe')wipeMarkup=html;return node();};
 const position={x:0,y:0,z:0,copy(v){this.x=v.x;this.y=v.y;this.z=v.z;}};
 const camera={position,lookAt(){},rotateZ(v){this.roll=v;},fov:44,updateProjectionMatrix(){},updateMatrixWorld(){}};
 const context=vm.createContext({V:{},Math:randomMath,performance:{now:()=>0},outpostHeight:()=>0,
  setTimeout(fn,ms){I.waits.push({at:I.time+ms/1000,res:fn});},h,mark:()=>'',LockOn:class{draw(){}remove(){}},
  IntroStory:class{}});
 vm.runInContext('IntroStory.prototype.shakeDom=function'+shake.trim().slice('shakeDom'.length),context);
 vm.runInContext(fx.slice(fx.indexOf('export function wipe('),fx.indexOf('// 标题卡')).replace('export ',''),context);
 vm.runInContext(intro.replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')
  .replaceAll('import.meta.url',"'file:///frozen/intro.js'")+'\nglobalThis.Intro=Intro;',context);
 I=Object.create(context.Intro.prototype);
 Object.assign(I,{time:0,waits:[],tasks:new Set(),props:[],mode:'crater',drive:{active:false},
  camera,cam:{on:true,pos:{x:0,y:0,z:0,set(){}},look:{set(){}},fov:44},trauma:0,
  root:{animate(frames,options){shakeEvent={at:I.time,frames,options};}},L:{panels:node(),tint:node()},
  cine:{target:null},cartUnit:null,sim:{castRay:()=>null},audio:{duration:()=>duration,sfx(){}},
  scene:{updateMatrixWorld(){}},_lights(){},_in(){},_rect:()=>({left:0,top:0,width:100,height:100}),
  _shred(){},flash(){},say:()=>new Promise(()=>{}),mark(id){this.shot=id;this.markAt=this.time;},W:1920});
 let error;I.actPayslip().catch(e=>{error=e;});
 for(let n=0;n<10&&!shakeEvent;n++){
  if(!I.waits.length)throw Error('Source has no pending impact cue');
  const at=Math.min(...I.waits.map(w=>w.at));I.update(at-I.time,at);
  await Promise.resolve();await Promise.resolve();await Promise.resolve();
  if(error)throw error;
 }
 if(!shakeEvent||randomIndex!==22)throw Error('Source impact did not produce 11 shake frames');
 const hitAt=Math.max(1.8,duration-1.3),frames=shakeEvent.frames.map(f=>[...f.translate.matchAll(/\* ([\deE+.-]+)/g)].map(m=>Number(m[1])));
 const cameraFrames=[];const at=I.time;
 for(const age of [0,.01,.08,.19,.379,.38,.5,.59,.7]){
  const next=at+age,dt=next-I.time;I.time=next;camera.roll=0;
  const before=I.trauma;I._camera(dt);
  cameraFrames.push({age,time:next,dt,position:[position.x,position.y,position.z],roll:camera.roll,traumaBefore:before,traumaAfter:I.trauma});
 }
 cases.push({duration,hitAt,markAt:I.markAt,impactAt:at,impactAge:at-I.markAt,wipeMarkup,wipeAnimation,
  shake:{frames,options:shakeEvent.options},cameraFrames});
}
process.stdout.write(JSON.stringify({baseline:baseline.commit,sourceHashes,randoms,cases,
 boundary:'Actual frozen actPayslip, wipe, task/update, shakeDom and _camera; controlled DOM/audio/terrain and deterministic random sequence. Captures hit+.09 cue, 11 linear vh keyframes, red wipe and own trauma applied before 1.4/s decay. Drive trauma is zero. No GPU or native raster.'}));

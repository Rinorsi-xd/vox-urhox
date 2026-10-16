import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const name='three/src/intro/intro.js',bytes=fs.readFileSync(path.join(baseline.snapshot,name));
const hash=createHash('sha256').update(bytes).digest('hex');
if(hash!==baseline.files[name].sha256)throw Error('Frozen intro source drift');
const source=bytes.toString('utf8');
const cases=[];
for(const kind of ['clear','three-blocks','all-blocked','near-end','at-margin','actor','fallback']){
 const rays=[],grounds=[];let calls=0;
 const ground=(x,z)=>{grounds.push([x,z]);return x*.07-z*.03;};
 const context=vm.createContext({V:{},IntroStory:class{},outpostHeight:ground,
  wipe:()=>({covered:Promise.resolve()}),performance:{now:()=>0}});
 vm.runInContext(source.replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')
  .replaceAll('import.meta.url',"'file:///frozen/intro.js'")+'\nglobalThis.Intro=Intro;',context);
 const I=Object.create(context.Intro.prototype),cart={pos:[31,4,-169],vehicle:{body:{name:'cart-body'}}};
 Object.assign(I,{time:17,waits:[],tasks:new Set(),props:[],mode:'crater',drive:{active:false},
  cine:{target:kind==='fallback'?null:cart},cartUnit:kind==='fallback'?null:cart,root:{},
  cam:{pos:{set(...v){this.value=v;}},look:{set(...v){this.value=v;}}},
  scene:{updateMatrixWorld(){}},_lights(){},_camera(){},
  mark(id){this.shot=id;this.markAt=this.time;},galaxy:{remove(){}},
  L:{get tint(){throw Error('camera-setup-complete');}},
  sim:{castRay(origin,direction,length,ignored){
   rays.push({origin:[...origin],direction:[...direction],length,ignored:ignored?.name||null});
   calls++;
   if(kind==='three-blocks')return calls<=3?{dist:1}:null;
   if(kind==='all-blocked')return {dist:1};
   if(kind==='near-end')return {dist:length-.59};
   if(kind==='at-margin')return calls===1?{dist:length-.6}:null;
   if(kind==='actor')return {dist:1,owner:{ref:{}}};
   return null;
  }}});
 let staleRuns=0;I.task(()=>{staleRuns++;});
 await I.actPayslip().then(()=>{throw Error('Missing camera setup boundary');},e=>{
  if(e.message!=='camera-setup-complete')throw e;
 });
 const frames=[];
 for(const age of [0,.25,1,2.5,5.5]){
  cart.pos=[31+age*3,4+age*.2,-169+age];
  I.cine.target={pos:[900,900,900]};
  const dt=I.markAt+age-I.time;I.update(dt,age);
  frames.push({age,position:I.cam.pos.value,look:I.cam.look.value,fov:I.cam.fov});
 }
 if(staleRuns)throw Error('actPayslip did not clear previous tasks');
 const before=JSON.stringify(I.cam.pos.value);I.clearTasks();I.update(1,7);
 if(JSON.stringify(I.cam.pos.value)!==before)throw Error('Cleared source camera kept running');
 cases.push({kind,initial:kind==='fallback'?null:[31,4,-169],grounds,rays,frames,taskStart:I.markAt});
}
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},
 sourceHashes:{[name]:hash},cases,
 boundary:'Actual frozen actPayslip through camera setup, clearCam, task, update and clearTasks. UI access stops execution after camera registration; controlled raycasts, terrain and target poses. No DOM layout, shake, GPU or natural playback.'}));

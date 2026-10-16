import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json')),sourceHashes={};
function read(file){const text=fs.readFileSync(path.join(baseline.snapshot,file),'utf8');const sha=createHash('sha256').update(text).digest('hex');if(sha!==baseline.files[file].sha256)throw Error('Frozen source mismatch '+file);sourceHashes[file]=sha;return text;}
const THREE=await import(pathToFileURL(path.join(baseline.snapshot,'three/vendor/three/build/three.module.js')));
const intro=read('three/src/intro/intro.js'),fx=read('three/src/intro/introFx.js');
const durations=JSON.parse(fs.readFileSync('assets/Intro/Intro.json')).durations,cases=[];
for(const duration of [durations.vo_n14,1,8]){
 let time=0;const timers=[],cards=[],marks=[],voices=[];const schedule=(fn,ms)=>{timers.push({at:time+ms/1000,fn});return timers.length;};
 function node(){return {style:{},classList:{add(){},remove(){}},appendChild(){},querySelector(){return node();},querySelectorAll(){return[node(),node()];},remove(){},
  animate(keys,opt){if(this.text&&opt.easing==='ease-in')Object.assign(this,{exit:time,exitDuration:opt.duration/1000,exitKeys:keys});return{finished:new Promise(resolve=>schedule(resolve,opt.duration+(opt.delay||0)))}}};}
 const context=vm.createContext({THREE,URL,Math,console,V:{},IntroStory:class{},IMG:()=>'',mark:()=>'',outpostHeight:()=>0,document:{createElement:node},setTimeout:schedule});
 const titleCode=fx.slice(fx.indexOf('const h ='),fx.indexOf('// 旧版大字')).replace(/export /g,'');
 vm.runInContext(titleCode+'\nglobalThis.realTitleCard=titleCard;globalThis.actualH=h;',context);
 context.h=context.actualH;
 context.titleCard=(parent,text,opt)=>{const card=context.realTitleCard(parent,text,opt);Object.assign(card,{text,enter:time,opt});cards.push(card);return card;};
 const actualTitle=context.titleCard;
 // The imported titleCard binding lives in a separate module in the source.
 const introContext=vm.createContext({...context,titleCard:actualTitle,h:context.actualH});
 vm.runInContext(intro.replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'').replaceAll('import.meta.url',JSON.stringify(pathToFileURL(path.join(baseline.snapshot,'three/src/intro/intro.js')).href))+'\nglobalThis.Intro=Intro;',introContext);
 const I=Object.create(introContext.Intro.prototype);let cameraTask;
 Object.assign(I,{time:0,trauma:0,log:[],mode:'crater',root:node(),L:{slams:node(),panels:node(),caps:node(),black:node()},drive:{cur:{p:{x:66,y:2,z:-174}}},cam:{pos:new THREE.Vector3(),look:new THREE.Vector3()},
  mark:id=>marks.push({id,t:time}),clearTasks(){},task(fn){cameraTask=fn;},safeCam:at=>at,_in(){},_out(){},flash(){},fade(){},
  wait:seconds=>new Promise(resolve=>schedule(resolve,seconds*1000)),audio:{duration:id=>id==='vo_n14'?duration:durations[id],voice:id=>voices.push({id,t:time}),sfx(){}}});
 let done=false,error;I.actRecruit().then(()=>done=true,e=>{done=true;error=e;});
 for(let round=0;round<1000&&!done;round++){
  for(let n=0;n<12;n++)await Promise.resolve();if(done)break;
  if(!timers.length)throw Error('Source timeline stalled');time=Math.min(...timers.map(t=>t.at));I.time=time;
  for(const timer of [...timers])if(timer.at<=time+1e-10){timers.splice(timers.indexOf(timer),1);timer.fn();}
 }
 if(error)throw error;if(!done)throw Error('Source timeline timeout');
 const n17=voices.find(e=>e.id==='vo_n17').t;
 const camera=[];for(const age of [n17-.001,n17,n17+.15,n17+durations.vo_n17+.3]){cameraTask(0,1/60,age);camera.push({age,at:I.cam.pos.toArray(),look:I.cam.look.toArray(),fov:I.cam.fov});}
 cases.push({duration,cards:cards.map(({text,enter,opt,exit,exitDuration,exitKeys})=>({text,enter,opt,exit,exitDuration,exitKeys})),marks,voices,camera});
}
process.stdout.write(JSON.stringify({baseline:baseline.commit,sourceHashes,cases}));

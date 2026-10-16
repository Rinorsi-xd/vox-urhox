import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const file='three/src/intro/intro.js';
const text=fs.readFileSync(path.join(baseline.snapshot,file),'utf8');
const hash=createHash('sha256').update(text).digest('hex');
if(hash!==baseline.files[file].sha256)throw Error('Frozen intro drift');
const THREE=await import(pathToFileURL(path.join(baseline.snapshot,'three/vendor/three/build/three.module.js')));
let active;
const delay=(fn,ms)=>{if(!active)return 0;active.waits.push({at:active.time+ms/1000,res:fn});return 0;};
const node=()=>{const children=new Map();return {style:{setProperty(){}},classList:{add(){},remove(){}},
 querySelector:q=>{if(!children.has(q))children.set(q,node());return children.get(q);},
 querySelectorAll:q=>Array.from({length:q.includes('bolt')?6:2},()=>node()),
 animate(_,opt){return {finished:new Promise(r=>delay(r,opt.duration))}},
 get firstChild(){return this.querySelector('first');},appendChild(){},addEventListener(){},focus(){},
 getBoundingClientRect:()=>({left:0,top:0,width:100,height:100}),clientWidth:100,clientHeight:100,
 getContext:()=>new Proxy({createRadialGradient:()=>({addColorStop(){}})},{get:(o,k)=>o[k]||(()=>{})}),
 remove(){},setAttribute(){},cloneNode:()=>node(),parentNode:{appendChild(){}}};};
const context=vm.createContext({THREE,V:{},IntroStory:class{},h:()=>node(),IMG:()=>'',mark:()=>'',titleCard:()=>({out(){}}),
    VehicleView:class{constructor(){this.root={};}addPart(){}},LockOn:class{draw(){}remove(){}},GalaxyMap:class{draw(){}remove(){}},
    outpostHeight:()=>0,setTimeout:delay,document:{createElement:node},localStorage:{getItem:()=>null},insignia:()=>'',hudFrame(){},devicePixelRatio:1,STAMP:'',console});
const sourceHashes={[file]:hash};
function frozen(name){const value=fs.readFileSync(path.join(baseline.snapshot,name),'utf8');const sha=createHash('sha256').update(value).digest('hex');if(sha!==baseline.files[name].sha256)throw Error('Frozen source drift: '+name);sourceHashes[name]=sha;return value;}
const fx=frozen('three/src/intro/introFx.js');
vm.runInContext(fx.slice(fx.indexOf('export function wipe('),fx.indexOf('// 标题卡')).replace('export ',''),context);
vm.runInContext(text.replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'').replaceAll('import.meta.url',JSON.stringify(pathToFileURL(path.join(baseline.snapshot,file)).href))+'\nglobalThis.Intro=Intro;',context);
const story=frozen('three/src/intro/introStory.js');
vm.runInContext('globalThis.StoryActs=class {'+story.slice(story.indexOf('\tasync actContract()'),story.indexOf('\n\tsaveStoryProfile'))+'}',context);
const sortie=frozen('three/src/intro/introSortie.js');
Object.assign(context,{swapPlayer(){},sortieCar:()=>({toJSON:()=>({})}),window:{addEventListener(){},removeEventListener(){}}});
vm.runInContext(sortie.slice(sortie.indexOf('const EASY ='),sortie.indexOf('// ── 交出操作')).replace('export ','')+'} finally {} }\nglobalThis.sortieBrief=playSortie;',context);
async function advance(I,run,max=30000){let done=false,error;active=I;run().then(()=>done=true,e=>{error=e;done=true;});const dt=1/240;
 for(let frame=0;frame<max&&!done;frame++){
  I.time+=dt;
  for(const w of [...I.waits])if(I.time+1e-10>=w.at){I.waits.splice(I.waits.indexOf(w),1);w.res();}
  for(const k of [...I.tasks]){const t=I.time-k.t0,p=k.dur?Math.min(1,t/k.dur):t;if(k.fn(p,dt,t)===false||(k.dur&&p>=1)){I.tasks.delete(k);k.res();}}
  if(I._autoSign){const sign=I._autoSign;I._autoSign=null;sign('Tester');}
  I.onAdvance?.();
  await Promise.resolve();await Promise.resolve();await Promise.resolve();
 }
 if(error)throw error;if(!done)throw Error('Source timing timeout');
}
const durations=JSON.parse(fs.readFileSync('assets/Intro/Intro.json')).durations;
const cases=[];
for(const held of [true,false])for(const n06 of [5.04,1,8])for(const n10 of [4.13,7]){
 const events=[];
 const I=Object.create(context.Intro.prototype);
 Object.assign(I,{time:0,waits:[],tasks:new Set(),log:[],props:[],holding:held,trauma:0,root:node(),
    L:Object.fromEntries(['panels','decide','black','tint','film','bars','caps','slams'].map(x=>[x,node()])),
    cam:{pos:new THREE.Vector3(),look:new THREE.Vector3()},heroBp:{parts:new Map()},scene:{add(){}},
    drive:{cur:{p:{x:66,y:1,z:-174}},vehicle:{yaw:0},weapons:{projectiles:[]},_spawn(){}},crater:{},
    cine:{script:{}},sim:{units:Array.from({length:4},()=>({pos:[66,1,-104]}))}});
 const duration=id=>id==='vo_n06'?n06:id==='vo_n10'?n10:durations[id]||2;
 const sourceSay=I.say;I.say=function(id,opt){if(opt&&Object.hasOwn(opt,'text'))events.push({t:this.time,type:'captionOverride',id,text:opt.text});return sourceSay.call(this,id,opt);};
 I.audio={duration,voice:id=>events.push({t:I.time,type:'voice',id}),stopMusic(){},playMusic(){},sfx:(id,opt)=>{events.push({t:I.time,type:'sfx',id,opt});return {src:{playbackRate:{value:1}},stop(){}};}};
 for(const name of ['_in','_out','flash','fade','cut','shakeDom','useGarage','useCrater','grade','placeUnit','selectMissiles'])I[name]=()=>{};
 I._rect=()=>({left:0,top:0,width:100,height:100});I.clearCam=at=>at;I.W=1920;I.H=1080;
 I.safeCam=at=>at;
 I.mark=id=>{events.push({t:I.time,type:'shot',id});};
 let done=false,error;
 await advance(I,async()=>{await I.actFamiliar();await I.actGalaxy();await I.actPayslip();await I.actDecide();await I.actMontage();await I.actRecruit();});
 const at=id=>events.find(e=>e.type==='shot'&&e.id===id)?.t;
 cases.push({held,n06,n10,events,decideDuration:at('decided')-at('decide'),missileDuration:at('m-salvage')-at('m-missile')});
}
const acts={};
for(const act of ['actNo','actGate','actContract','sortieBrief']){
 const events=[],I=Object.create(context.Intro.prototype);Object.assign(I,{time:0,waits:[],tasks:new Set(),trauma:0,root:node(),W:1920,H:1080,vv:{},px:{},tearFx:{pulse(){},stop(){}},L:Object.fromEntries(['panels','slams','comms'].map(k=>[k,node()]))});
 I.audio={sfx:(id,opt)=>{events.push({t:I.time,type:'sfx',id,opt});return {stop(){}};},playMusic:(id,opt)=>events.push({t:I.time,type:'music',id,opt}),stopMusic:fade=>events.push({t:I.time,type:'stopMusic',fade})};
 I.alarmSfx={stop:fade=>events.push({t:I.time,type:'stopAlarm',fade})};I.mark=id=>events.push({t:I.time,type:'shot',id});
 for(const name of ['_in','_out','flash','shakeDom','grade','_unfold','prepareStoryGate','saveStoryProfile','vivi'])I[name]=()=>{};
 if(act==='sortieBrief'){
  Object.assign(I,{props:[],sim:{units:[]},editor:{bp:{}},drive:{player:{pos:[62,1,-176]}},cine:{script:{}},cam:{pos:new THREE.Vector3(),look:new THREE.Vector3()}});
  I.L.bars=node();I.L.tint=node();for(const name of ['_clearProps','useCrater','cut','camMove'])I[name]=()=>{};I.clearCam=at=>at;
 }
 await advance(I,()=>act==='sortieBrief'?context.sortieBrief(I,{ground:()=>0}):act==='actNo'?I[act]():context.StoryActs.prototype[act].call(I));acts[act]={events,duration:I.time};
}
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},sourceHashes,cases,acts}));

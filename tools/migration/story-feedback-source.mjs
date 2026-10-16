import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const hashes={};
function read(relative){
 const bytes=fs.readFileSync(`${baseline.snapshot}/${relative}`);
 const sha=crypto.createHash('sha256').update(bytes).digest('hex');
 if(sha!==baseline.files[relative]?.sha256)throw Error(`Frozen source drift: ${relative}`);
 hashes[relative]=sha;return bytes.toString('utf8');
}
let touch=false;
const context=vm.createContext({THREE:{Vector3:class{}},radio(){},BOSS_KIND:{},URL,
 performance:{now:()=>10000},document:{body:{classList:{contains:()=>touch}}}});
function load(relative,name){
 const code=read(relative).replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'').replaceAll('import.meta.url',"'file:///source.js'");
 return vm.runInContext(`(()=>{${code}\nreturn ${name};})()`,context);
}
const Hud=load('shared/ui/storyHud.js','StoryHud');
const Kinds=load('three/src/battle/storyKinds.js','KINDS');context.KINDS=Kinds;
const Mission=load('three/src/battle/storyMission.js','StoryMission');
const cssText=read('shared/css/storyHud.css');
function declarations(selector){
 const escaped=selector.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
 const rule=cssText.match(new RegExp('(?:^|\\n)'+escaped+'\\s*\\{([^}]+)\\}'));
 if(!rule)throw Error(`Missing source CSS ${selector}`);
 return Object.fromEntries(rule[1].split(';').filter(s=>s.includes(':')).map(s=>{const colon=s.indexOf(':');return [s.slice(0,colon).trim(),s.slice(colon+1).trim()];}));
}
function hud(){
 const nodes=new Map();
 const get=selector=>{
  if(!nodes.has(selector)){
   const classes=new Set();
   nodes.set(selector,{style:{},textContent:'',classes,classList:{toggle(name,on){on?classes.add(name):classes.delete(name);}},
    querySelector(child){return get(`${selector} ${child}`);}});
  }
  return nodes.get(selector);
 };
 const h=Object.create(Hud.prototype);h.$=get;
 for(const key of ['update','retitle','marker','pips','row','banner','say','progress'])h[key]=()=>{};
 const snapshot=()=>{
  const shown=get('.sh-prompt').classes.has('on');
  return {visible:shown,...shown?{blocked:get('.sh-prompt').classes.has('blocked'),key:get('.sh-prompt kbd').style.display!=='none',
   title:get('.sh-prompt b').textContent,sub:get('.sh-prompt small').textContent,
   progress:(100-get('.sh-prompt .arc').style.strokeDashoffset)/100}: {}};
 };
 return {h,get,snapshot};
}
const cases=[],deathTraces=[];
function check(input){
 touch=input.touch;const {h,snapshot}=hud();
 const s={kind:input.kind,pos:[0,2,0],r:9,site:'A',title:'夺回采集器',trigger:30,guards:[],counter:[{}]};
 const enemies=new Map(Array.from({length:input.enemies||0},()=>[{alive:true,pos:[0,2,0]},{tag:'counter'}]));
 const m=Object.create(Mission.prototype);
 Object.assign(m,{level:{steps:[s]},i:0,begun:true,time:10,deadAt:null,stats:{},
  drive:{player:{alive:true,pos:input.inside?[0,2,0]:[100,2,0]},vehicle:{speed:input.blocked?3:0},input:{touchInteract:false,touchEnabled:touch}},hud:h,
  view:new Proxy({},{get:()=>()=>{}}),fx:{update(){}},cap:{phase:input.phase||'cap',p:input.progress||0,scrub:(input.progress||0)*1.6},
  install:(input.progress||0)*2.4,stepT:0,enemies});
 m._beats=()=>{};m._marker=()=>{};m.carSize=()=>({w:2,below:1.5,above:1.5});m.spawn=()=>{};
 if(input.kind==='capture')Kinds.capture.update(m,s,0);
 else if(input.kind==='install')m.update(0);
 cases.push({input,expected:snapshot()});
 if(input.deathTrace){
  const trace=[{at:0,alive:true,prompt:snapshot()}];m.deadAt=m.time;m.drive.player.alive=false;
  for(let i=1;i<=5;i++){m.update(.5);trace.push({at:i*500,alive:false,prompt:snapshot()});}
  deathTraces.push({input,trace});
 }
}
for(const isTouch of [false,true]){
 for(const inside of [false,true])for(const blocked of [false,true])for(const progress of [0,.4,.999])
  check({kind:'install',touch:isTouch,inside,blocked,progress});
 for(const inside of [false,true])for(const phase of ['go','cap','counter','scrub'])for(const enemies of [0,3])
  check({kind:'capture',touch:isTouch,inside,phase,enemies,progress:.4});
 check({kind:'reach',touch:isTouch,inside:true});
 check({kind:'install',touch:isTouch,inside:true,blocked:false,progress:.4,deathTrace:true});
}
const deaths=[null,3,2.999,2.5,2,1.001,1,.001,0].map(sec=>{
 const {h,get}=hud();h.dead(sec);
 return {sec,visible:get('.sh-dead').classes.has('on'),...sec===null?{}:{label:get('.sh-dead small').textContent,
  progress:Number(get('.sh-dead .sh-dbar s').style.transform.match(/scaleX\(([^)]+)\)/)[1])}};
});
const css={};for(const selector of ['.sh-prompt','.sh-prompt svg','.sh-prompt circle','.sh-prompt .arc','.sh-prompt kbd','.sh-prompt b','.sh-prompt small','.sh-prompt.blocked .arc','.sh-prompt.blocked b','.sh-dead','.sh-dkick','.sh-dbar','.sh-dbar s','.sh-dead b','.sh-dead small'])css[selector]=declarations(selector);
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,files:hashes},cases,deaths,deathTraces,css}));

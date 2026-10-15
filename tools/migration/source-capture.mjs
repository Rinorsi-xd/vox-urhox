import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const url=p=>pathToFileURL(path.join(baseline.snapshot,p)).href;
registerHooks({resolve(s,c,n){return n(s.startsWith('@shared/')?url('shared/'+s.slice(8)):s,c);},
 load(u,c,n){if(u===url('shared/story/radio.js'))return {format:'module',source:'export function radio() {}',shortCircuit:true};return n(u,c);}});
const {KINDS}=await import(url('three/src/battle/storyKinds.js'));
const {LEVEL4}=await import(url('shared/story/level4.js'));
const nav=JSON.parse(fs.readFileSync(path.join(root,'assets/Crater/Layout.json'))).nav,trace=[];
const noop=()=>{},flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
for(let index=0;index<3;index++){
 const s=LEVEL4.steps[index],player={pos:[...s.pos],alive:true},enemies=new Map();let captured=0,scrubbed=0;
 const m={drive:{player,input:{touchInteract:false}},enemies,stats:{},hud:{banner:noop,say:noop,row:noop,prompt:noop,retitle:title=>m.retitle=title},
  view:{showZone:noop,hideBeacon:noop,setZoneProgress:p=>m.progress=p,setZoneColor:noop,siteCaptured:()=>captured++,scrub:()=>scrubbed++},
  near:(p,t,r,up=6)=>flat(p,t)<r&&t[1]>p[1]-1.5-up&&t[1]<p[1]+1.5+up,
  alive:tag=>[...enemies.values()].filter(e=>!tag||e.tag===tag).length,
  spawn:(list,tag)=>{for(const e of list){let p=typeof e.at==='string'?nav.nodes[e.at]:e.at;const off=e.off||[0,0];p=[p[0]+off[0],p.length===3?p[1]:s.pos[1],(p.length===3?p[2]:p[1])+off[1]];enemies.set({alive:true,pos:p},{tag});}},
 };
 KINDS.capture.enter(m,s);
 const sample=(dt,pos,positions,interact=false)=>{
  if(positions){enemies.clear();for(const e of positions)enemies.set({alive:true,pos:e.pos},{tag:e.tag});}
  player.pos=pos;m.holdG=interact;const before=[...enemies].map(([u,e])=>({pos:u.pos,tag:e.tag}));
  const done=KINDS.capture.update(m,s,dt);
  trace.push({index:index+1,dt,pos,enemies:before,interact,expected:{...m.cap,progress:m.progress||0,sites:m.stats.sites||0,graffiti:m.stats.graffiti||0,checkpoint:m.checkpoint,captured,scrubbed,done}});
 };
 sample(.1,[s.pos[0]+s.trigger,s.pos[1],s.pos[2]],[]);
 sample(.1,s.pos,[]);
 sample(.1,s.pos,[{pos:s.pos,tag:'guard'}]);
 sample(.5,[s.pos[0]+s.r,s.pos[1],s.pos[2]],[]);
 sample(.5,[s.pos[0],s.pos[1]+20,s.pos[2]],[]);
 for(let i=0;i<12;i++)sample(.1,s.pos,[]);
 sample(.4,s.pos,[{pos:[s.pos[0]+s.r*1.8,s.pos[1],s.pos[2]],tag:'guard'}]);
 sample(.3,s.pos,[{pos:[s.pos[0]+s.r*1.8-.001,s.pos[1],s.pos[2]],tag:'guard'}]);
 sample(.5,[s.pos[0]+s.r+.01,s.pos[1],s.pos[2]],[]);
 for(let i=0;i<80;i++){sample(.1,s.pos,[]);if(m.cap.phase==='counter')break;}
 sample(.2,s.pos,[{pos:s.pos,tag:'counter'}]);
 sample(.1,s.pos,[]);
 for(let i=0;i<10;i++)sample(.1,s.pos,[],true);
 sample(.5,[s.pos[0]+9,s.pos[1],s.pos[2]],[],true);
 for(let i=0;i<25;i++){sample(.1,s.pos,[],true);if(m.cap.scrub>=1.6)break;}
}
fs.writeFileSync(path.join(root,'tools/migration/source-capture.json'),JSON.stringify({baseline:baseline.commit,nav,trace}));
console.log(JSON.stringify({source:baseline.commit,samples:trace.length}));

import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const sourceHashes={};
function read(file){const bytes=fs.readFileSync(path.join(baseline.snapshot,file));const hash=createHash('sha256').update(bytes).digest('hex');if(hash!==baseline.files[file].sha256)throw Error('Frozen source drift: '+file);sourceHashes[file]=hash;return bytes.toString('utf8').replaceAll('\r\n','\n');}
const intro=read('three/src/intro/intro.js'),story=read('three/src/intro/introStory.js'),fx=read('three/src/intro/introFx.js');
const section=(text,start,end)=>{const at=text.indexOf(start),to=text.indexOf(end,at);if(at<0||to<0)throw Error(start+' / '+end);return text.slice(at,to);};
const virtues=section(intro,'\tasync actVirtues()','\n\t// NO!');
const panel=section(intro,'\t_panel( P,','\n\t// 「觉得眼熟');
const shake=section(story,'\tshakeDom( el =','\n\n\n\t// 鼠标视差');
const cases=[];
for(const offset of [0,7.123]){
 let now=offset,seed=(Math.floor(offset*1000+.5)+7726)>>>0;const events=[],layers=[];
 const fakeMath=Object.create(Math);fakeMath.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 const element=name=>({name,style:{},classList:{remove(){}},
  animate(frames,options){events.push({name,frames,options});return {finished:Promise.resolve()};},
  querySelector(selector){const el={name:selector,style:{}};layers.push(el);return el;},
  set innerHTML(value){this.html=value;this.firstChild=element('page');this.lastChild=element('cl');}});
 const ctx=vm.createContext({Math:fakeMath,IMG:n=>n,confetti(){},lerp:(a,b,k)=>a+(b-a)*k,h:(_,name)=>element(name)});
 vm.runInContext(`globalThis.Actor=class{${virtues}\n${panel}\n${shake}}`,ctx);
 const actor=new ctx.Actor();Object.assign(actor,{time:offset,L:{panels:element('panels'),bars:element('bars'),slams:element('slams')},
  _in(el,frames,duration,easing){if(duration===300)seed=(Math.floor(this.time*1000+.5)+7726)>>>0;return el.animate(frames,{duration,easing});},
  mark(name){events.push({mark:name,at:this.time});},cut(){},audio:{sfx(){}},
  words(){return {out(){}};},voice(){return 1;},task(fn){this.animateLayers=fn;return {stop(){}};},
  wait:async function(seconds){this.time+=seconds;}});
 await actor.actVirtues();
 const marks=events.filter(e=>e.mark),samples=[];
 for(const age of [0,.05,.3,1,3.99,4,8]){
  actor.time=marks[2].at+age;actor.animateLayers();
  samples.push({time:actor.time,layers:layers.filter(e=>e.style.transform).map(e=>({name:e.name,transform:e.style.transform}))});
 }
 const noAt=actor.time+.5;seed=(Math.floor(noAt*1000+.5)+7726)>>>0;actor.shakeDom(actor.L.panels,2.2,520);
 cases.push({offset,events,marks,samples,noAt});
}
const burstCode=section(intro,'\t_burst( el,','\n\t// 实机出战');
const titleCode=section(fx,'export function titleCard(','\n// 旧版大字').replace('export function','function');
const bursts=[],titleExits=[];
for(const box of [{x:1200,y:70,w:310,h:320},{x:1700,y:110,w:400,h:250},{x:850,y:40,w:250,h:400}]){
 let seed=11726;const particles=[];const math=Object.create(Math);
 math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 const ctx=vm.createContext({Math:math});vm.runInContext(`globalThis.Actor=class{${burstCode}}`,ctx);
 const actor=new ctx.Actor();actor._rect=()=>({left:box.x,top:box.y,width:box.w,height:box.h});actor.L={panels:{appendChild(){}}};
 const element={style:{},cloneNode(){return {style:{},animate(frames,options){particles.push({style:this.style,frames,options});}};}};
 actor._burst(element,6,6);bursts.push({box,seed:11726,particles,hidden:element.style.visibility});
}
const ctx=vm.createContext({Math,h(){return {style:{},animate(frames,options){titleExits.push({frames,options});return {finished:Promise.resolve()};},remove(){}};}});
vm.runInContext(titleCode+';globalThis.card=titleCard({}, "繁荣！");card.out(150);',ctx);
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},sourceHashes,cases,bursts,titleExit:titleExits.at(-1)}));

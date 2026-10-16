import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const file='three/src/battle/storyEpilogue.js',bytes=fs.readFileSync(`${baseline.snapshot}/${file}`);
const sha=crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(sha,baseline.files[file].sha256);
const source=bytes.toString('utf8'),events=[],timers=new Map();let wall=0,serial=0;
class Element{
 constructor(){this.children=[];this.className='';this.style={};this.selected=new Map();this.classes=new Set();
  this.classList={add:k=>{this.classes.add(k);events.push({at:wall,element:this.className,action:'add',class:k});},remove:k=>{this.classes.delete(k);events.push({at:wall,element:this.className,action:'remove',class:k});}};
 }
 appendChild(e){this.children.push(e);return e;}
 append(...all){all.forEach(e=>this.appendChild(e));}
 insertBefore(e){return this.appendChild(e);}
 remove(){events.push({at:wall,element:this.className,action:'dispose'});}
 addEventListener(){}
 querySelector(selector){if(selector==='.chr')return null;if(!this.selected.has(selector)){const e=new Element();e.className=selector;this.selected.set(selector,e);}return this.selected.get(selector);}
 animate(){}
}
const body=new Element(),card={root:new Element(),hide(){},say(){},update(){},skipLine(){},queue:[]};
const context=vm.createContext({URL,document:{body,createElement:()=>new Element()},performance:{now:()=>wall},
 setTimeout(fn,ms){const id=++serial;timers.set(id,{at:wall+ms,fn});return id;},clearTimeout:id=>timers.delete(id),
 requestAnimationFrame(fn){fn();return ++serial;},cancelAnimationFrame(){},addEventListener(){},removeEventListener(){},radio(){},
 comms:{use:()=>card,release(){}},CHAIRMAN:'chairman',HUHU_FACES:{smug:'huhu',angry:'huhuAngry'}});
vm.runInContext(source.replace(/^import .*;\r?$/gm,'').replaceAll('import.meta.url',JSON.stringify(pathToFileURL(`${baseline.snapshot}/${file}`).href)).replace('export function playEpilogue','function playEpilogue')+'\nglobalThis.play=playEpilogue;globalThis.css=CSS;',context);
const panel=JSON.parse(fs.readFileSync('assets/Story/Boss/Epilogue.json')).data.scenes.find(s=>s.panel?.deal).panel;
const controller=context.play({scenes:[{page:true,panel:{...panel,hold:100}}]},()=>{});
controller.advance();
function advanceTo(at){for(;;){const due=[...timers.entries()].filter(([,t])=>t.at<=at).sort((a,b)=>a[1].at-b[1].at);if(!due.length)break;const [id,t]=due[0];timers.delete(id);wall=t.at;t.fn();}wall=at;}
advanceTo(1599);assert(!events.some(e=>e.element==='.deal i'&&e.class==='on'));
advanceTo(1600);assert(events.some(e=>e.at===1600&&e.element==='.deal i'&&e.class==='on'));
controller.advance();controller.advance();
assert(events.some(e=>e.element==='.ep-stamp'&&e.action==='add'&&e.class==='on'));
advanceTo(5000);
const root=body.children.find(e=>e.className==='fx-epi sh-scope');
assert(root.selected.get('.ep-stamp').classes.has('on'),'Source finish retains the rejection stamp');
assert(!root.classes.has('on'),'Source whole overlay fades out');
assert(!events.some(e=>e.element==='fx-epi sh-scope'&&e.action==='dispose'));
advanceTo(5800);assert(events.some(e=>e.at===5800&&e.element==='fx-epi sh-scope'&&e.action==='dispose'));
const declaration=selector=>{const at=context.css.indexOf(selector+'{');assert(at>=0);return context.css.slice(at+selector.length+1,context.css.indexOf('}',at));};
const approval=declaration('.fx-epi .deal i'),on=declaration('.fx-epi .deal i.on'),overlay=declaration('.fx-epi');
assert(approval.includes('scale(2.4)')&&approval.includes('opacity:0')&&approval.includes('transform .22s cubic-bezier(.2,1.6,.4,1),opacity .15s'));
assert(on.includes('scale(1)')&&on.includes('opacity:.9'));
assert(overlay.includes('transition:opacity .8s'));
console.log(JSON.stringify({source:{commit:baseline.commit,files:{[file]:sha}},approval:{delay:1.6,scale:[2.4,1],scaleDuration:.22,scaleEase:[.2,1.6,.4,1],opacity:[0,.9],opacityDuration:.15,opacityEase:[.25,.1,.25,1]},outro:{duration:.8,ease:[.25,.1,.25,1],retainStamp:true},events,boundary:'Complete frozen playEpilogue executes with DOM/timer adapters; source CSS declarations verified. CSS compositor and GPU pixels are not executed.'}));

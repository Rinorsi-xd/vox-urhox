import fs from 'node:fs';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const path='three/src/intro/introStory.js';
const source=fs.readFileSync(`${baseline.snapshot}/${path}`,'utf8');
const hash=createHash('sha256').update(source).digest('hex');
if(hash!==baseline.files[path].sha256)throw Error('Frozen gate source drift');
const method=source.slice(source.indexOf('\tasync actGate() {'),source.indexOf('\n\tsaveStoryProfile('));
const impacts=source.slice(source.indexOf('\tflash('),source.indexOf('\n\t_parallax()'));
const randoms=[];const sourceMath=Object.create(Math);
sourceMath.random=()=>{const value=((randoms.length*37+17)%101)/101;randoms.push(value);return value;};
let time=0,queue=[],trace=[];
const wait=seconds=>new Promise(resolve=>queue.push({at:time+seconds,resolve}));
const canvas={clientWidth:1920,clientHeight:1080,getContext:()=>({})};
const nodes=new Map();
function node(key){
 if(nodes.has(key))return nodes.get(key);
 const item={style:{},classList:{add(value){trace.push({time,kind:'class',key,value});}},
  animate(frames,options){trace.push({time,kind:'animate',key,frames,options,background:this.style.background,randoms:key==='root'?randoms.slice(-22):undefined});return {finished:wait(options.duration/1000)};},
  querySelector(selector){return selector==='.g-steam'?canvas:node(`${key} ${selector}`);},
  querySelectorAll(selector){return selector==='.g-leaf'?[node('left'),node('right')]:selector==='.g-half'?[node('left-half'),node('right-half')]:Array.from({length:6},(_,i)=>node(`${key} ${selector} ${i}`));},
  remove(){trace.push({time,kind:'remove'});}};
 nodes.set(key,item);return item;
}
const context=vm.createContext({localStorage:{getItem:()=>null},h:(_,kind)=>node(kind==='stamp'?'stamp':'gate'),insignia:()=>'',hudFrame(){},Math:sourceMath,JSON,
 STAMP:'stamp.png',tear:{pulse(){}},setTimeout(callback,ms){queue.push({at:time+ms/1000,resolve:callback});}});
vm.runInContext(`globalThis.Story=class {${impacts}${method}}`,context);
const I=new context.Story();Object.assign(I,{root:node('root'),name:'Tester',vv:{},
 mark(value){trace.push({time,kind:'mark',value});},audio:{sfx(value){trace.push({time,kind:'sfx',value});},stopMusic(){}},
 _out(value,ms){trace.push({time,kind:'out',key:value,ms});},_unfold(value,options){trace.push({time,kind:'unfold',options});},
 task(){return {stop(){trace.push({time,kind:'steam-stop'});}};},prepareStoryGate(){trace.push({time,kind:'camera'});},wait});
let complete=false;I.actGate().then(()=>{complete=true;});
for(let i=0;i<1000&&!complete;i++){
 for(let j=0;j<8;j++)await Promise.resolve();
 if(queue.length){queue.sort((a,b)=>a.at-b.at);const next=queue.shift();time=next.at;next.resolve();}
}
if(!complete)throw Error('Gate source task failed to settle');
const gateTrace=trace,gateFinished=time;
const start=source.indexOf("\t\tthis.vv.face = 'stamp';",source.indexOf('async actContract()'));
const tail=source.slice(start),end=tail.search(/\r?\n\t}\r?\n/);
if(start<0||end<0)throw Error('Frozen contract tail missing');
vm.runInContext(`globalThis.Contract=class {${impacts}async finish(){${tail.slice(0,end)}}}`,context);
time=0;queue=[];trace=[];complete=false;
const C=new context.Contract();Object.assign(C,{vv:{},L:{comms:{},flash:node('flash')},root:node('root'),wait,
 audio:{sfx(value){trace.push({time,kind:'sfx',value});}},
 _in(value,frames,duration,easing){trace.push({time,kind:'in',frames,duration,easing});},
 _out(value,ms){trace.push({time,kind:'out',ms});},
 vivi(value){trace.push({time,kind:'voice',value});}});
context.C={};C.finish().then(()=>{complete=true;});
for(let i=0;i<100&&!complete;i++){
 for(let j=0;j<8;j++)await Promise.resolve();
 if(queue.length){queue.sort((a,b)=>a.at-b.at);const next=queue.shift();time=next.at;next.resolve();}
}
if(!complete)throw Error('Contract source task failed to settle');
process.stdout.write(JSON.stringify({sourceHashes:{[path]:hash},trace:gateTrace,finished:gateFinished,contractTrace:trace},(_,value)=>value&&value.style?undefined:value));

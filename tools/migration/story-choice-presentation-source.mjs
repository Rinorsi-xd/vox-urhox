import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source={branch:baseline.branch,commit:baseline.commit,files:{}};
function read(relative){const bytes=fs.readFileSync(path.join(baseline.snapshot,relative));const sha=createHash('sha256').update(bytes).digest('hex');if(sha!==baseline.files[relative]?.sha256)throw Error('Frozen source changed '+relative);source.files[relative]=sha;return bytes.toString('utf8');}
const code=read('shared/ui/storyHud.js'),css=read('shared/css/storyHud.css');
const choiceCss=css.match(/\.sh-choice\s*\{([^}]+)\}/)?.[1];
if(!/transition:\s*opacity\s*\.2s,\s*transform\s*\.3s\s*cubic-bezier\(\.16,\s*1,\s*\.3,\s*1\)/.test(choiceCss)||!css.includes('.sh-choice button.picked { background: var(--sa); color: #04121f; }'))throw Error('Frozen choice CSS changed');
const ease=(x,c)=>{if(x<=0)return 0;if(x>=1)return 1;const f=(t,a,b)=>3*(1-t)**2*t*a+3*(1-t)*t*t*b+t*t*t;let a=0,b=1;for(let n=0;n<60;n++){const t=(a+b)/2;if(f(t,c[0],c[2])<x)a=t;else b=t;}return f((a+b)/2,c[1],c[3]);};
const open=(id='a',prompt='决定怎么回答')=>({op:'open',id,prompt});
const sample=at=>({op:'sample',at});
const boundaries=[0,1,100,199,200,299,300].map(sample);
const cases=[
 {name:'enter',ops:[open(),...boundaries]},
 {name:'keyboard-selection',ops:[open(),sample(300),{op:'pick',index:2},...[300,499,799,800,899,999,1000,1099,1100].map(sample)]},
 {name:'pointer-repeat-no-second-reply',ops:[open(),sample(300),{op:'click',index:1},{op:'click',index:3},sample(799),{op:'pick',index:2},sample(1100)]},
 {name:'automatic-default',ops:[open(),sample(14000),{op:'pick',index:1},sample(14499),sample(14500),sample(14800)]},
 {name:'cancel-before-choice',ops:[open(),sample(100),{op:'cancel'},sample(150),sample(200),sample(300),sample(400)]},
 {name:'next-objective-cancels-confirmation',ops:[open(),sample(300),{op:'pick',index:3},sample(350),{op:'cancel'},sample(550),sample(650),sample(800)]},
 {name:'cancel-reopen-with-stale-source-hide-timer',ops:[open(),sample(300),{op:'pick',index:1},sample(350),{op:'cancel'},sample(400),open('b',''),sample(600),sample(799),sample(800),sample(1000),sample(1100)]},
 {name:'death-does-not-freeze-confirmation',ops:[open(),sample(300),{op:'pick',index:2},{op:'dead'},sample(800),sample(1100)]},
 {name:'no-choice',ops:[sample(0),sample(8000)]},
];
for(const test of cases){
 let now=0,timers=[],buttons=[],on=false,alpha=null,slide=null,replyCount=0,cues=[];
 const value=t=>!t?0:t.from+(t.target-t.from)*ease(t.duration?Math.min(1,Math.max(0,(now-t.at-t.delay)/t.duration)):1,t.curve);
 const setOn=next=>{if(next===on)return;const make=(t,duration,curve)=>{const from=value(t);return {from,target:next?1:0,at:now,duration:duration*Math.abs((next?1:0)-from),delay:0,curve};};alpha=make(alpha,200,[.25,.1,.25,1]);slide=make(slide,300,[.16,1,.3,1]);on=next;};
 let id,prompt;
 const el={classList:{add:()=>setOn(true),remove:()=>setOn(false)},querySelectorAll:()=>buttons,
  set innerHTML(html){buttons=[...html.matchAll(/<button data-i="(\d+)">/g)].map(m=>({dataset:{i:m[1]},picked:false,classList:{toggle(_name,active){buttons[+m[1]].picked=active;}},addEventListener(_name,fn){this.onclick=fn;}}));}};
 const context=vm.createContext({setTimeout(fn,delay){timers.push({fn,at:now+delay});},document:{body:{classList:{contains:()=>false}}},navigator:{maxTouchPoints:0},matchMedia:()=>({matches:false})});
 const module=new vm.SourceTextModule(code,{context});await module.link(name=>{
  const names=name.endsWith('/ui.js')?['escapeHtml']:name.endsWith('radio.js')?['radio']:name.endsWith('touchCopy.js')?['touchCopy']:name.endsWith('mechFrame.js')?['mechFrame']:name.endsWith('nonoComms.js')?['comms','FACE']:['storyVoice'];
  return new vm.SyntheticModule(names,function(){for(const key of names)this.setExport(key,key==='escapeHtml'?s=>s:key==='radio'?cue=>cues.push(cue):()=>{});},{context});
 });await module.evaluate();
 const hud=Object.create(module.namespace.StoryHud.prototype);hud.$=()=>el;test.trace=[];
 for(const op of test.ops){
  if(op.at!==undefined){while(true){timers.sort((a,b)=>a.at-b.at);if(!timers[0]||timers[0].at>op.at)break;const next=timers.shift();now=next.at;next.fn();}now=op.at;}
  if(op.op==='open'){id=op.id;prompt=op.prompt;hud.choice({prompt,options:['继续','先看看','拒绝']},()=>replyCount++);}
  else if(op.op==='pick')hud.pick(op.index-1);
  else if(op.op==='click')buttons[op.index-1].onclick({currentTarget:buttons[op.index-1]});
  else if(op.op==='cancel')hud.cancelChoice();
  test.trace.push({at:now,hasChoice:id!==undefined,id,prompt,on,choosing:hud.choosing,picked:buttons.findIndex(b=>b.picked)+1,alpha:value(alpha),x:-16*(1-value(slide)),replyCount,cues:[...cues]});
 }
}
console.log(JSON.stringify({source,cases}));

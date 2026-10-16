import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';

const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source={branch:baseline.branch,commit:baseline.commit,files:{}};
function read(relative){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,relative));
 const hash=createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[relative]?.sha256)throw Error(`Frozen source changed: ${relative}`);
 source.files[relative]=hash;return bytes.toString('utf8');
}
const css=read('shared/css/storyHud.css');
if(!css.includes('.sh-ocur.done .sh-otitle { color: #3ddc84; }'))throw Error('Actual done CSS changed');
const code=read('shared/ui/storyHud.js');const touchCode=read('shared/ui/touchCopy.js');
const ease=(x,curve)=>{
 if(x<=0)return 0;if(x>=1)return 1;
 const [x1,y1,x2,y2]=curve;const at=(t,a,b)=>3*(1-t)**2*t*a+3*(1-t)*t*t*b+t*t*t;
 let lo=0,hi=1;for(let i=0;i<60;i++){const t=(lo+hi)/2;if(at(t,x1,x2)<x)lo=t;else hi=t;}
 return at((lo+hi)/2,y1,y2);
};
const samples=[0,1,199,200,419,420,649,650,651,850,1069,1070];
const cases=[
 {name:'first-objective',ops:[{op:'objective',title:'前往信标',hint:'WASD 开车 · 鼠标看路',index:1},...samples.map(at=>({op:'sample',at}))]},
 {name:'next-objective',ops:[{op:'objective',title:'旧目标',index:1},{op:'sample',at:500},{op:'objective',title:'新目标',hint:'停进圈里按住 G',index:2},...samples.map(dt=>({op:'sample',at:500+dt}))]},
 {name:'touch-original-copy',touch:true,ops:[{op:'objective',title:'触屏目标',hint:'WASD 开车 · 鼠标看路 · 停进圈里按住 G',index:1},{op:'sample',at:420}]},
 {name:'retitle-during-completion-hold',ops:[{op:'objective',title:'旧',index:1},{op:'sample',at:500},{op:'objective',title:'新',hint:'新提示',index:2},{op:'retitle',title:'击退拦截运输车的海盗'},...samples.map(dt=>({op:'sample',at:500+dt}))]},
 {name:'repeated-dynamic-retitle',ops:[{op:'objective',title:'清理海盗',index:1},{op:'sample',at:420},{op:'retitle',title:'海盗 1 / 3'},{op:'sample',at:450},{op:'retitle',title:'海盗 2 / 3'},{op:'sample',at:600},{op:'retitle',title:'海盗 3 / 3'}]},
 {name:'rapid-original-timers',ops:[{op:'objective',title:'一',index:1},{op:'sample',at:500},{op:'objective',title:'二',hint:'二提示',index:2},{op:'sample',at:600},{op:'objective',title:'三',hint:'三提示',index:3},... [649,650,1149,1150,1151,1249,1250,1251,1670].map(at=>({op:'sample',at}))]},
 {name:'final-objective-retained',ops:[{op:'objective',title:'撤离',hint:'抵达出口',index:6},{op:'sample',at:500},{op:'done'},... [500,699,700,4500,12000].map(at=>({op:'sample',at}))]},
 {name:'complete-before-pending-swap-source-order',ops:[{op:'objective',title:'旧',index:1},{op:'sample',at:500},{op:'objective',title:'末',index:2},{op:'done'},{op:'sample',at:1149},{op:'sample',at:1150},{op:'sample',at:1570}]},
 {name:'dead-countdown-does-not-freeze-ui',ops:[{op:'objective',title:'旧',index:1},{op:'sample',at:500},{op:'objective',title:'新',index:2},{op:'dead'},... [700,1149,1150,1570,3500].map(at=>({op:'sample',at}))]},
 {name:'no-objective-before-begin',ops:[{op:'sample',at:0},{op:'sample',at:8000}]},
];
for(const test of cases){
 let now=0,timers=[],sequence=0,animation=null,done=false,fill=0,fillAt=null;
 const background=()=>fillAt===null?(done?1:0):fill+((done?1:0)-fill)*ease(Math.min(1,(now-fillAt)/200),[.25,.1,.25,1]);
 const toggle=value=>{if(done===value)return;fill=background();fillAt=now;done=value;};
 const children=new Map();
 const get=selector=>{
  if(!children.has(selector))children.set(selector,{textContent:'',innerHTML:'',classList:{add:()=>toggle(true),remove:()=>toggle(false)},animate:(frames,options)=>{animation={frames,options,at:now};}});
  return children.get(selector);
 };
 const context=vm.createContext({setTimeout(fn,delay){timers.push({fn,at:now+delay,seq:sequence++});},document:{body:{classList:{contains:()=>!!test.touch}}},matchMedia:()=>({matches:false}),navigator:{maxTouchPoints:0}});
 const touch=new vm.SourceTextModule(touchCode,{context});await touch.link(()=>{});await touch.evaluate();
 const module=new vm.SourceTextModule(code,{context});
 await module.link(name=>{
  if(name.endsWith('touchCopy.js'))return touch;
  const names=name.endsWith('/ui.js')?['escapeHtml']:name.endsWith('radio.js')?['radio']:name.endsWith('mechFrame.js')?['mechFrame']:name.endsWith('nonoComms.js')?['comms','FACE']:['storyVoice'];
  return new vm.SyntheticModule(names,function(){for(const key of names)this.setExport(key,()=>{});},{context});
 });await module.evaluate();
 const hud=Object.create(module.namespace.StoryHud.prototype);hud.$=get;test.trace=[];
 for(const op of test.ops){
  if(op.at!==undefined){
   while(true){timers.sort((a,b)=>a.at-b.at||a.seq-b.seq);if(!timers.length||timers[0].at>op.at)break;const next=timers.shift();now=next.at;next.fn();}
   now=op.at;
  }
  if(op.op==='objective')hud.objective({title:op.title,hint:op.hint},op.index-1,6);
  else if(op.op==='retitle')hud.retitle(op.title);
  else if(op.op==='done')hud.objectiveDone();
  const title=get('.sh-otitle').textContent;
  const t=animation?Math.min(1,(now-animation.at)/animation.options.duration):1;
  const p=animation?ease(t,[.16,1,.3,1]):1;
  const number=get('.sh-ostep').innerHTML.match(/<em>(\d+)<\/em> \/ (\d+)/);
  test.trace.push({at:now,visible:!!title,title,hint:get('.sh-ohint').textContent,index:number?+number[1]:0,total:number?+number[2]:0,done,alpha:p,x:-18*(1-p),brightness:1+1.2*(1-p),fill:background()});
 }
}
console.log(JSON.stringify({source,css:{done:'#3ddc84',normalBorder:'#ff6a13',doneGlow:14,normalGlow:10,backgroundTransition:200},cases}));

const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{createHash}=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const file='shared/controls/cameraRig.js',source=fs.readFileSync(path.join(baseline.snapshot,file),'utf8');
const hash=createHash('sha256').update(source).digest('hex');
if(hash!==baseline.files[file].sha256)throw Error('Frozen mouse input changed');
const start=source.indexOf('export class Input {'),end=source.indexOf('export function isTyping(',start);
if(start<0||end<0)throw Error('Frozen Input class not found');
const scenarios=[
 {name:'empty-frames',frames:[[],[],[[10,20]],[],[]]},
 {name:'single-warp',frames:[[[4,2]],[[5,1],[900,-800],[6,3]],[[8,2]]]},
 {name:'real-consecutive-fast-flick',frames:[[[800,0],[800,0],[900,100]],[],[[850,0]]]},
 {name:'same-frame-normal-total-over-threshold',frames:[Array.from({length:15},()=>[30,10]),[[35,15]]]},
 {name:'threshold-exact-120',frames:[[[120,0]],[[121,0]],[[130,0]]]},
 {name:'repeated-warp-after-small-movement',frames:[[[1000,0]],[[1,0]],[[1000,0]],[[1,0]]]},
 {name:'negative-and-vertical',frames:[[[0,-1000],[0,-1000]],[[0,-12],[-1800,0],[-10,-10]]]},
 {name:'lock-reset',frames:[[[600,0],[600,0]],{reset:true,moves:[[600,0],[600,0]]},[[10,0]]]},
];
let state=492783;
const random=()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;};
for(let i=0;i<24;i++){
 const frames=[];
 for(let j=0;j<120;j++){
  const moves=[];
  for(let k=0,n=Math.floor(random()*9);k<n;k++){
   const magnitude=random()<.13?1600:100;
   moves.push([Math.round((random()-.5)*magnitude),Math.round((random()-.5)*magnitude)]);
  }
  frames.push(j===60?{reset:true,moves}:moves);
 }
 scenarios.push({name:`seeded-${i}`,frames});
}
for(const scenario of scenarios){
 const handlers={};const target=id=>({addEventListener:(type,fn)=>handlers[id+':'+type]=fn});
 const dom=target('dom'),document=target('document');document.pointerLockElement=dom;
 const context=vm.createContext({window:target('window'),document});
 vm.runInContext(source.slice(start,end).replace('export class Input','class Input')+';globalThis.Input=Input;',context);
 const input=new context.Input(dom);input.locked=true;
 scenario.frames=scenario.frames.map(frame=>{
  const moves=frame.moves||frame;
  if(frame.reset)handlers['document:pointerlockchange']();
  for(const [dx,dy] of moves)handlers['document:mousemove']({movementX:dx,movementY:dy});
  return {moves,reset:!!frame.reset,raw:moves.reduce((s,m)=>[s[0]+m[0],s[1]+m[1]],[0,0]),
   expected:{delta:input.consumeMouse(),avg:input._avgMove||0,lastSpike:!!input._lastSpike}};
 });
}
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},source:{file,hash},scenarios}));

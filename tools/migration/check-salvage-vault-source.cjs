// Execute the frozen method unchanged; rendering and sound calls are recorded.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'),'utf8'));
const name='three/src/salvage/salvageRun.js',bytes=fs.readFileSync(path.join(baseline.snapshot,name));
const sha=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha!==baseline.files[name].sha256)throw new Error('Frozen source changed');
const rarity=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Outgame.json'),'utf8')).rarity;
const context=vm.createContext({URLSearchParams,location:{search:''},performance:{now:()=>0},CARGO_SLOTS:20,RARITY:rarity,
 THREE:{Color:class{constructor(c){this.c=c;}getHex(){return parseInt(this.c.slice(1),16);}}},
 sfx:{play(){}},CONTAINERS:{}});
vm.runInContext(bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.Run=SalvageRun;',context);
const cases=[];
for(const rarities of [[],[0],[1,0],[2,1],[3,1],[4,0,2],[2,5,1]])for(const initialTrauma of [0,.8]){
 const trace=[],run=Object.create(context.Run.prototype);
 const o={id:'vault',kind:'crate',ctype:'vault',tier:3,g:[2,3,4]};
 const s={o,type:'vault',title:'test',en:'SALVAGE',items:rarities.map(r=>({id:'scrap',r,t:100,state:'hidden'})),i:0,p:0,wait:0,value:0,crack:0,done:false,opened:true};
 Object.assign(run,{drive:{player:{pos:[0,0,0]},input:{},trauma:initialTrauma},speed:0,hold:false,search:s,heat:0,
  _heat(n){trace.push(['heat',n]);this.heat=Math.min(100,this.heat+n);},_noise(at,r){trace.push(['noise',at,r]);},
  _hunt(n,at){trace.push(['hunt',n,at]);},hud:{nameCard(...a){trace.push(['card',...a]);},flash(...a){trace.push(['flash',...a]);},search(){},feed(){}},
  fx:{loot(at,color,n){trace.push(['beam',at,color,n]);}},opened:new Set(),openedCount:0,W:{},time:0,
  _session(){return s;}});
 const frames=[];
 const steps=[{dt:1,speed:3,hold:true},{dt:.5,speed:0,hold:false},{dt:2,speed:0,hold:true},
  {dt:1,speed:0,hold:false,reopen:true},{dt:1,speed:2,hold:true},{dt:5.75,speed:0,hold:true},
  {dt:.25,speed:0,hold:true},{dt:.01,speed:0,hold:true,reopen:true},{dt:.01,speed:0,hold:false}];
 for(const step of steps){
  if(step.reopen)run._openSearch(o);
  run.speed=step.speed;run.hold=step.hold;run.time+=step.dt;
  const result=run._searchStep(step.dt,run.drive.player.pos);
  frames.push({step,crack:s.crack,heat:run.heat,trauma:run.drive.trauma,trace:structuredClone(trace),prompt:result.prompt});
 }
 cases.push({rarities,initialTrauma,frames});
}
// Actual update entry point derives speed from position; never inject speed.
const run=Object.create(context.Run.prototype),o={id:'vault',kind:'crate',ctype:'vault',tier:3,g:[0,0,0]};
const search={o,type:'vault',items:[{id:'scrap',r:0,t:100,state:'hidden'}],i:0,p:0,wait:0,value:0,crack:0,done:false,opened:true};
Object.assign(run,{begun:true,finished:false,landed:false,time:0,deadAt:null,extracts:[],ex:null,heat:0,hold:true,search,
 drive:{player:{pos:[0,0,0],incomingDamageMultiplier:1},input:{}},
 fx:{update(){},target(){}},cine:{update(){}},hud:{search(){},nameCard(){},flash(){},feed(){}},
 _hud(prompt){this.lastPrompt=prompt;},_weigh(){},_airdrop(){},_encounters(){},_director(){},_noise(){},_hunt(){},_target(){return null;}});
const entry=[];
const moves=[
 {name:'unlanded-no-sample',pos:[9,5,9],dt:1,landed:false},
 {name:'first-landed-sample',pos:[0,0,0],dt:.1,landed:true},
 {name:'sideways-forward-speed-zero',pos:[3,0,0],dt:1},
 {name:'reverse-positive-distance',pos:[3,0,-3],dt:1},
 {name:'exact-two-blocked',pos:[5,0,-3],dt:1},
 {name:'only-y-motion',pos:[5,2,-3],dt:.1},
 {name:'zero-dt-displacement',pos:[5.003,2,-3],dt:0},
 {name:'zero-dt-stationary',pos:[5.003,2,-3],dt:0},
 {name:'sub-millisecond-divisor',pos:[5.006,2,-3],dt:.0001},
 {name:'pause-does-not-sample',pos:[6,2,-3],dt:4,paused:true},
 {name:'resume-retains-last-sample',pos:[6,2,-3],dt:.1},
 {name:'rebuilt-same-position-keeps-sample',pos:[6,2,-3],dt:.1,rebuild:true},
 {name:'reset-displacement-blocked',pos:[9,2,-3],dt:.1,rebuild:true},
 {name:'after-reset-stationary',pos:[9,2,-3],dt:.1},
 {name:'finished-does-not-sample',pos:[12,2,-3],dt:1,finished:true}
];
for(const step of moves){
 run.drive.player.pos.splice(0,3,...step.pos);if(step.landed!==undefined)run.landed=step.landed;
 if(step.finished)run.finished=true;
 if(!step.paused)run.update(step.dt);
 entry.push({step,speed:run.speed??0,lastPos:run.lastPos??null,crack:search.crack,prompt:run.lastPrompt??null});
}
const out=path.join(root,'.tmp/source-salvage-vault-fixtures.json');
fs.writeFileSync(out,JSON.stringify({commit,sourceHashes:{[name]:sha},cases,entry},null,2)+'\n');
console.log(JSON.stringify({result:'PASS',cases:cases.length,frames:cases.reduce((n,c)=>n+c.frames.length,0),entry:entry.length,out}));

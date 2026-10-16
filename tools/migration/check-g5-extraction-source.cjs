// Frozen production methods run unchanged; engine/DOM/audio edges are adapters.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'),'utf8'));
const names=['three/src/salvage/salvageRun.js','three/src/salvage/salvageCine.js','three/src/battle/endlessLoot.js',
 'shared/ui/endlessHud.js','shared/css/style.css','shared/css/story.css','three/src/battle/endlessSession.js'];
const source={},sourceHashes={};
for(const name of names){const b=fs.readFileSync(path.join(baseline.snapshot,name));const sha=crypto.createHash('sha256').update(b).digest('hex');if(sha!==baseline.files[name].sha256)throw Error('Source drift '+name);source[name]=b.toString('utf8');sourceHashes[name]=sha;}
class Vec{
 constructor(x=0,y=0,z=0){Object.assign(this,{x,y,z});}
 clone(){return new Vec(this.x,this.y,this.z);}
 copy(v){this.x=v.x;this.y=v.y;this.z=v.z;return this;}
 add(v){this.x+=v.x;this.y+=v.y;this.z+=v.z;return this;}
 lerpVectors(a,b,t){this.x=a.x+(b.x-a.x)*t;this.y=a.y+(b.y-a.y)*t;this.z=a.z+(b.z-a.z)*t;return this;}
}
const context=vm.createContext({THREE:{Vector3:Vec},URLSearchParams,location:{search:''},performance:{now:()=>0},CARGO_SLOTS:20,ITEMS:{},PARTS:{laser:{name:'激光炮'}},shieldContains:()=>false});
function Load(name,expose){vm.runInContext('{\n'+source[name].replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\n'+expose+'\n}',context);}
Load(names[0],'globalThis.Run=SalvageRun;');Load(names[1],'globalThis.Cine=SalvageCine;');Load(names[2],'globalThis.Loot=EndlessLoot;');
Load(names[6],'globalThis.Session=EndlessSession;');
const cases=[];
for(const wait of [2.5,3,4.25,6,20])for(const loud of [false,true]){
 const trace=[],run=Object.create(context.Run.prototype),cine=Object.create(context.Cine.prototype);
 const exit={id:'A',name:'测试撤离点',g:[10,2,30],radius:12,wait,loud,x:-10,beam:{material:{color:{setHex(){} }}},ring:{material:{color:{copy(){} }}}};
 const ship={visible:false,position:new Vec(),rotation:{set(){}},userData:{fl:[]}};
 Object.assign(cine,{_ship:()=>ship});
 Object.assign(run,{begun:true,finished:false,landed:true,time:0,deadAt:null,extracts:[exit],ex:null,heat:0,cargo:new Map(),
  drive:{player:{pos:[10,2,30],incomingDamageMultiplier:1},input:{}},
  fx:{update(){},target(){}},cine:{update(){},approach(E,w){cine.approach(E,w);trace.push(['approach',E,w,cine.ex.wait]);},leave(){},extract(E,label){trace.push(['extract',E,label]);}},
  hud:{feed(...a){trace.push(['feed',...a]);},nameCard(...a){trace.push(['card',...a]);},search(){}},
  _hud(){},_weigh(){},_airdrop(){},_encounters(){},_director(){},_target(){return null;},
  _heat(){},_noise(at,r){trace.push(['noise',at,r]);},_hunt(n,at){trace.push(['hunt',n,at]);}});
 const steps=[{inside:true,dt:.25},{inside:true,dt:wait-2.25},{inside:false,dt:.1},
  {inside:true,dt:.1},{inside:false,dt:.1},{inside:true,dt:.1},{inside:true,dt:1.9}];
 const frames=[];
 for(const step of steps){run.drive.player.pos=step.inside?[10,2,30]:[100,2,30];run.update(step.dt);frames.push({step,left:run.ex?.left??null,called:!!exit.called,extracting:!!run.extracting,trace:structuredClone(trace)});}
 cases.push({wait,loud,frames});
}
const shots=[];
for(const wait of [0,2,3,4.25,6,20])for(const t of [0,.1,1,2.9,3,4,6,9]){
 const cine=Object.create(context.Cine.prototype),ship={visible:false,position:new Vec(),rotation:{set(x,y,z){this.x=x;this.y=y;this.z=z;}},userData:{fl:[]}};
 Object.assign(cine,{_ship:()=>ship,run:{fx:{_puff(){}}}});cine.approach([10,2,30],wait);cine._approachStep(t);
 shots.push({wait,t,clamped:cine.ex.wait,ship:[ship.position.x,ship.position.y,ship.position.z],rotation:[ship.rotation.x,ship.rotation.y,ship.rotation.z],dust:!!cine.ex.dust});
}
const notices=[],loot=Object.create(context.Loot.prototype);
Object.assign(loot,{session:{drive:{ui:{toast(...args){notices.push(args);}}}}});
const events=[{type:'credits',amount:300,total:300},{type:'pickup',partType:'laser',count:2},{type:'credits',amount:12,total:312},{type:'credits',amount:0,total:312}];
for(const event of events)loot.onEvent(event);
const gates=[];
for(const respawnAt of [null,0,9,10,10.001,11,14.7])for(const state of ['rest','combat'])for(const entry of ['nextWave','enterEdit']){
 const trace=[],s=Object.create(context.Session.prototype);
 Object.assign(s,{run:{respawnAt,time:10,state,beginNextWave(){trace.push(['next']);return false;},beginEdit(){trace.push(['edit']);return false;}},drive:{player:{pos:[0,0,0]},ui:{toast(...a){trace.push(['toast',...a]);}}}});
 const result=s[entry]();gates.push({respawnAt,state,entry,result:!!result,trace});
}
// These declarations establish the source layering; no target relocation is allowed.
if(!/#endless-hud[^}]*z-index:\s*80/.test(source[names[3]])||!/#toasts\s*\{[^}]*z-index:\s*860/.test(source[names[5]]))throw Error('Source layering changed');
const out=path.join(root,'.tmp/source-g5-extraction-fixtures.json');
fs.writeFileSync(out,JSON.stringify({commit,sourceHashes,cases,shots,events,notices,gates,layering:{endless:80,toasts:860}},null,2)+'\n');
console.log(JSON.stringify({result:'PASS',cases:cases.length,frames:cases.reduce((n,c)=>n+c.frames.length,0),shots:shots.length,gates:gates.length,out}));

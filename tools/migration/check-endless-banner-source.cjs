// Execute frozen session events and HUD methods; DOM/audio/native edges are doubles.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'),'utf8'));
const names=['three/src/battle/endlessSession.js','shared/ui/endlessHud.js','shared/battle/endlessConfig.js','shared/config.js'];
const source={},hashes={};
for(const name of names){const bytes=fs.readFileSync(path.join(baseline.snapshot,name));hashes[name]=crypto.createHash('sha256').update(bytes).digest('hex');if(hashes[name]!==baseline.files[name].sha256)throw new Error('Source drift '+name);source[name]=bytes.toString('utf8');}
const context=vm.createContext({document:{pointerLockElement:false},performance:{now:()=>0},shieldContains:()=>false});
function Load(name,expose){vm.runInContext(source[name].replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\n'+expose,context);}
Load(names[3],'globalThis.tiers=TIERS;');
Load(names[2],'globalThis.cfg=ENDLESS;');
Load(names[0],'globalThis.Session=EndlessSession;');
Load(names[1],'globalThis.Hud=EndlessHud;');
const batches=[];
function Scenario(name,events,tierLimits=false){
 const c=vm.createContext({document:{pointerLockElement:true,exitPointerLock(){this.exits++;},exits:0},performance:{now:()=>1000},ENDLESS:{...context.cfg,tierLimits},TIERS:context.tiers});
 vm.runInContext(source[names[0]].replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.Session=EndlessSession;',c);
 const notices=[];const session=Object.create(c.Session.prototype);
 Object.defineProperty(session,'paused',{value:true});
 Object.assign(session,{drive:{},run:{drainEvents:()=>events,supplies:[1]},rewardsEnabled:true,
  view:{raise(){},shieldHit(){},shieldDown(){}},hud:{announce:text=>notices.push(text)},persist(){}});
 session.events();batches.push({name,events,tierLimits,notices,exits:c.document.exits});
}
for(const limits of [false,true])for(let tier=2;tier<=5;tier++){
 Scenario(`boss-${limits}-${tier}`,[{type:'tierUp',tier},{type:'shieldRaise'},{type:'waveClear',wave:(tier-1)*5},{type:'save'}],limits);
 Scenario(`tier-only-${limits}-${tier}`,[{type:'tierUp',tier}],limits);
 Scenario(`reversed-${limits}-${tier}`,[{type:'waveClear',wave:5},{type:'tierUp',tier}],limits);
}
for(const wave of [1,4,5,10,15,20,24,25])for(const boss of [false,true])Scenario(`start-${wave}-${boss}`,[{type:'waveStart',wave,boss}]);
Scenario('warnings',[{type:'charge'},{type:'shieldDown'},{type:'waveClear',wave:7}]);
Scenario('ordinary-clear',[{type:'shieldRaise'},{type:'waveClear',wave:6},{type:'save'}]);
Scenario('last-tier-wins',[{type:'tierUp',tier:2},{type:'tierUp',tier:3},{type:'waveClear',wave:10}]);
// Keep real source banner state across wall-time, pause and respawn overrides.
const clock=[];let now=1000;
context.performance.now=()=>now;
const hud=Object.create(context.Hud.prototype);const keys={};
Object.assign(hud,{banner:{textContent:''},status:{},score:{},shield:{},root:{querySelector:()=>keys}});
const run={state:'combat',wave:1,tier:1,waveTime:0,alive:new Set(),queue:[],lives:3,score:0,shield:{hp:1,max:1},time:0};
function Announce(text,ms){hud.announce(text,ms);clock.push({kind:'announce',now,text,ms:ms??3500,expected:hud.banner.textContent});}
function Frame(at,respawn,state='combat'){now=at;run.state=state;hud.lastState=state;hud.update(run,{respawn});clock.push({kind:'frame',now,respawn,state,expected:hud.banner.textContent});}
Announce('第 5 波完成 · 敌人升到 T2');Frame(4499,0,'rest');Frame(4500,0,'rest');Frame(4501,0,'rest');
now=5000;Announce('敌人冲锋！');Frame(7000,4.1);Frame(8501,2.1);Frame(9000,.001);Frame(9001,0);
now=10000;Announce('保护期',1200);Frame(11000,0,'editing');Frame(11200,0);Frame(11201,0);
now=12000;Announce('前一个');now=13000;Announce('后一个');Frame(15501,0);Frame(16500,0);Frame(16501,0);
const out=path.join(root,'.tmp/source-endless-banner-fixtures.json');
fs.writeFileSync(out,JSON.stringify({sourceCommit:commit,hashes,tiers:context.tiers,config:context.cfg,batches,clock},null,2)+'\n');
console.log(JSON.stringify({result:'PASS',batches:batches.length,clock:clock.length,out}));

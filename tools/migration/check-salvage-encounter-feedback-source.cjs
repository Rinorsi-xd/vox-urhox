const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
(async()=>{
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'),'utf8'));
const name='three/src/salvage/salvageRun.js',bytes=fs.readFileSync(path.join(baseline.snapshot,name));
const sha=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha!==baseline.files[name].sha256)throw Error('Frozen source drift');
let soundTrace;
const context=vm.createContext({URLSearchParams,location:{search:''},CARGO_SLOTS:20,DROPS:{rat:[]},sfx:{play(...a){soundTrace.push(['sound',...a]);}},CRATE_LOOT:[[],[],[],[]],Kit:class{build(){return {position:{set(){}},scale:{setScalar(){}}};}},lootCrate(){},makeRand(){}});
vm.runInContext(bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.Run=SalvageRun;',context);
function make(trace){soundTrace=trace;return Object.assign(Object.create(context.Run.prototype),{
 W:{W:{M:{}}},drive:{player:{pos:[10,2,30],alive:true},scene3:{add(){}},sim:{units:[]}},
 fx:{loot(...a){trace.push(['loot',...a]);},explode(...a){trace.push(['explode',...a]);}},
 hud:{feed(...a){trace.push(['feed',...a]);},nameCard(...a){trace.push(['card',...a]);},flash(...a){trace.push(['flash',...a]);}},
 cine:{elite(){trace.push(['elite']);},death(){trace.push(['death']);}},
 _surface(x,z){return [x,3,z];},extras:[],kills:0,time:360.6,rand:()=>.505,
 _yaw:()=>.4,_crateMesh(){return {};},_noise(...a){trace.push(['noise',...a]);},_heat(n){trace.push(['heat',n]);},units:new Map(),deadAt:null,finished:false,
});}
const alerts=[];
for(const kind of ['camp','nest','patrol','ambush','elite','elite-without-leader'])for(const why of ['', '发现了你','被打了','听到动静','同伴被打爆']){
 const trace=[],run=make(trace),alive={alive:true,elite:kind==='elite',name:'精英车'},dead={alive:false};
 run.units.set(alive,{def:{name:'精英车',title:'重装',gang:'铁帮'}});
 const e={name:'测试据点',kind:kind==='elite-without-leader'?'elite':kind,units:[alive,dead]};run._alert(e,why);run._alert(e,'重复');
 alerts.push({kind:e.kind,hasElite:alive.elite,why,trace});
}
const clears=[];
for(const kind of ['camp','patrol'])for(const reward of [0,1,2,3,4]){
 const trace=[],run=make(trace);run._cleared({id:'X',name:'测试据点',kind,reward,g:[1,2,3],lastPos:[4,5,6]});
 clears.push({kind,reward,trace,cache:run.extras[0].g});
}
const drops=[];
for(const seed of [.005,.505,.999]){
 const trace=[],run=make(trace);run.rand=()=>seed;run.airdrops=[360,600];run._airdrop();
 drops.push({seed,trace,id:run.extras[0].id});
}
const kills=[];
for(const elite of [false,true])for(const why of ['', '动不了了','武器全被打掉']){
 const trace=[],run=make(trace),u={alive:false,elite,name:'敌车',pos:[1,2,3],spec:{bounds:{radius:4}}};
 run.units.set(u,{def:{name:u.name},why,type:'rat'});run.afterStep();
 kills.push({elite,why,trace});
}
const deathTrace=[],run=make(deathTrace);run.drive.player.alive=false;run.afterStep();
const {pathToFileURL,fileURLToPath}=require('node:url');
const file=p=>path.join(baseline.snapshot,p),url=p=>pathToFileURL(file(p)).href;
const {BATTLE_FLOW_CUES,BATTLE_FLOW_BASE}=await import(url('shared/audio/battleFlowCues.js'));
const {REWARD_CUES,REWARD_BASE}=await import(url('shared/audio/rewardCues.js'));
const {MIX_TRIM}=await import(url('shared/audio/mixTrim.js'));
const sourceHashes={[name]:sha};
for(const p of ['shared/audio/battleFlowCues.js','shared/audio/rewardCues.js','shared/audio/mixTrim.js','shared/ui/uiSound.js']){
 const hash=crypto.createHash('sha256').update(fs.readFileSync(file(p))).digest('hex');
 if(hash!==baseline.files[p].sha256)throw Error('Frozen audio source drift '+p);sourceHashes[p]=hash;
}
const sounds={};for(const id of ['urgent_warning','supply_open','wave_start']){
 const cue=BATTLE_FLOW_CUES[id]||REWARD_CUES[id],base=cue.base||(BATTLE_FLOW_CUES[id]?BATTLE_FLOW_BASE:REWARD_BASE);
 sounds[id]={gain:cue.gain*10**((MIX_TRIM[id]||0)/20),gap:cue.gap/1000,
  sha256:crypto.createHash('sha256').update(fs.readFileSync(fileURLToPath(new URL(`${id}_${cue.variant}.wav`,base)))).digest('hex')};
}
const out=path.join(root,'.tmp/source-salvage-encounter-feedback.json');
fs.writeFileSync(out,JSON.stringify({commit,sourceHashes,alerts,clears,drops,kills,deathTrace,sounds},null,2)+'\n');
console.log(JSON.stringify({out,cases:alerts.length+clears.length+drops.length+kills.length+1}));
})().catch(error=>{console.error(error);process.exitCode=1;});

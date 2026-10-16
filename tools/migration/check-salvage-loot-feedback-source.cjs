const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const {pathToFileURL}=require('node:url');
const root=path.resolve(__dirname,'../..'),commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
(async()=>{
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'),'utf8'));
const sourceHashes={};
function read(name){const bytes=fs.readFileSync(path.join(baseline.snapshot,name));const sha=crypto.createHash('sha256').update(bytes).digest('hex');if(sha!==baseline.files[name].sha256)throw Error('Frozen source drift '+name);sourceHashes[name]=sha;return bytes.toString('utf8');}
for(const name of ['shared/salvage/items.js','shared/salvage/salvageLoot.js','shared/salvage/salvageGameplay.js'])read(name);
const load=name=>import(pathToFileURL(path.join(baseline.snapshot,name)).href);
const {ITEMS,RARITY,sellPrice}=await load('shared/salvage/items.js');
const {WRECKS,rollLoot}=await load('shared/salvage/salvageGameplay.js');
const {roomFor}=await load('shared/salvage/salvageLoot.js');
let now=0,timers=[];
const context=vm.createContext({URLSearchParams,location:{search:''},CARGO_SLOTS:20,ITEMS,RARITY,sellPrice,WRECKS,rollLoot,roomFor,THREE:{Color:class{constructor(c){this.c=c;}getHex(){return parseInt(this.c.slice(1),16);}}},setTimeout(fn,delay){timers.push({at:now+delay,fn});}});
vm.runInContext(read('three/src/salvage/salvageRun.js').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.Run=SalvageRun;',context);
function make(cargo,trauma){return Object.assign(Object.create(context.Run.prototype),{cargo:new Map(Object.entries(cargo)),drive:{player:{pos:[0,0,0]},trauma},hud:{feed(...a){this.feeds.push(a);},feeds:[],reveal(){},jackpot(){},flash(){},nameCard(){},fly(){}},fx:{loot(){}},opened:new Set(),openedCount:0,rand:()=>.5,_press(){},_heat(){},_noise(){},_hunt(){}});}
const rare=[];
for(const r of [0,3,4,5])for(const trauma of [0,.8])for(const full of [false,true])for(const poi of [null,'坠舰断口']){
 now=1000;timers=[];const id=Object.keys(ITEMS).find(k=>ITEMS[k].rarity===r),cargo=full?{scrap:400}:{};
 const run=make(cargo,trauma),it={id,n:1,r},s={o:{g:[0,0,0],poi:poi||undefined},value:0};run._reveal(s,it);
 const frames=[{now,feeds:[...run.hud.feeds]}];
 for(const at of [2199,2200,2400]){now=at;for(const timer of timers.filter(t=>!t.done&&t.at<=now)){timer.done=true;timer.fn();}frames.push({now,feeds:[...run.hud.feeds]});}
 rare.push({r,trauma,full,poi,id,afterTrauma:run.drive.trauma,cargo:Object.fromEntries(run.cargo),frames});
}
const wrecks=[];
for(const model of Object.keys(WRECKS))for(const seed of [0,.5,.999999])for(const fill of [0,359,379,-1]){
 const cargo=fill===-1?{scrap:360,alloy:19}:fill?{scrap:fill}:{},run=make(cargo,0);run.rand=()=>seed;
 const o={id:'W',kind:'wreck',model,name:'断坝',g:[0,0,0]};run._open(o);
 wrecks.push({model,seed,fill,cargo:Object.fromEntries(run.cargo),feeds:run.hud.feeds});
}
const out=path.join(root,'.tmp/source-salvage-loot-feedback.json');fs.writeFileSync(out,JSON.stringify({commit,sourceHashes,rare,wrecks},null,2)+'\n');console.log(JSON.stringify({out,cases:rare.length+wrecks.length}));
})().catch(error=>{console.error(error);process.exitCode=1;});

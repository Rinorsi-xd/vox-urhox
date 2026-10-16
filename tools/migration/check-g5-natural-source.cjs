// Execute unchanged frozen methods with controlled native/DOM edges.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json')));
const sourceHashes={};
function read(name){const raw=fs.readFileSync(path.join(baseline.snapshot,name)),hash=crypto.createHash('sha256').update(raw).digest('hex');if(hash!==baseline.files[name].sha256)throw Error('Source drift '+name);sourceHashes[name]=hash;return raw.toString('utf8');}
const context=vm.createContext({URL,URLSearchParams,location:{search:''},PART_LIST:[{id:'cube',name:'方块',budget:1,cat:'structure'}],PARTS:{},STARTER_CARS:[],CARGO_SLOTS:20,OPS:[],OP_KEY:'op',REGIONS:[],PLAN_LOOT:[],PLAN_EX:[],PLAN_SPAWNS:[],icon:()=>'',touchCopy:s=>s,escapeHtml:s=>String(s),sfx:{play(){}},THREE:{},performance:{now:()=>0}});
function load(name,expose){vm.runInContext('{\n'+read(name).replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'').replaceAll('import.meta.url',JSON.stringify('file:///frozen/source.js'))+'\n'+expose+'\n}',context);}
load('shared/salvage/items.js','Object.assign(globalThis,{ITEMS,ITEM_CATS,RARITY,sellPrice,partItemId});');
load('shared/salvage/stash.js','Object.assign(globalThis,{Stash:SalvageStash,STASH_CELLS,stackMax,partsNeeded});');
load('shared/ui/salvageHub.js','globalThis.Hub=SalvageHub;');
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Outgame.json'))),rules=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/SalvageRules.json'))),runData=JSON.parse(fs.readFileSync(path.join(root,'assets/Salvage/RunData.json')));
const sales=[];
const configs=[
 {name:'mixed',items:[['ration',3],['repair',7],['ore',2],['part:cube',10],['scrap',30],['blackbox',1]],usage:{'part:cube':8}},
 {name:'reverse-acquisition',items:[['starcore',2],['ore',4],['ration',5],['repair',2]],usage:{}},
 {name:'no-cargo',items:[['repair',2],['part:cube',4],['scrap',30]],usage:{'part:cube':4}},
 {name:'all-installed',items:[['ore',3],['ration',2],['repair',4]],usage:{ore:3,ration:2}},
 {name:'partial-reserved',items:[['ore',5],['ration',4],['repair',4]],usage:{ore:2,ration:1}},
 {name:'catalogue',items:rules.itemOrder.filter(id=>context.ITEMS[id]&&context.ITEMS[id].cat==='cargo').map((id,i)=>[id,i+1]),usage:{}}
];
for(const config of configs){
 const notes=[],sounds=[],sold=[];let saves=0,handler;
 const stash=Object.create(context.Stash.prototype);Object.assign(stash,{credits:1234,items:new Map(config.items),usage:()=>config.usage,save(){saves++;}});
 const sell=stash.sell;stash.sell=function(id,n){sold.push([id,n]);return sell.call(this,id,n);};
 const hub=Object.create(context.Hub.prototype),box={querySelector(q){return q==='[data-dump]'&&box.innerHTML.includes('data-dump')?{addEventListener(_,fn){handler=fn;}}:null;}};
 context.sfx.play=s=>sounds.push(s);Object.assign(hub,{stash,mode:'sell',offer:null,h:{toast:(text,kind)=>notes.push([text,kind])},$:()=>box});
 hub._deal();const quote=stash.loose().filter(([id])=>context.ITEMS[id].cat==='cargo').reduce((sum,[id,n])=>sum+context.sellPrice(id)*n,0),visible=!!handler;
 if(handler)handler();
 sales.push({config,visible,quote,items:Object.fromEntries(stash.items),credits:stash.credits,sold,notes,sounds,saves});
}
// These are host objects only; _alive/_addUnit/_spawnEncounter/_encounters are source.
let unitSerial=0;
context.CarUnit=class{constructor(_,source,options){this.serial=++unitSerial;this.alive=!context.failUnit;this.pos=[...options.spawn.pos];this.spawnAt=options.spawn;this.hitAt=0;this.cur={};this.spec={};this.name=options.name;this.vehicle={place(){}};}savePose(){}};
context.EnemyDriver=class{};context.centeredSpawn=(_,at)=>at;
context.scavenger=(kind,seed)=>runData.enemies[kind][(seed-1)%4];
context.CRATE_LOOT=runData.crateLoot; // Source indexes tier directly; adapter below restores JS zero index.
context.CRATE_LOOT=Object.fromEntries(runData.crateLoot.map((rows,i)=>[i,rows]));
context.makeRand=()=>()=>.5;context.lootCrate=()=>{};
context.Kit=class{build(){return {position:{set(){}},scale:{setScalar(){}}};}};
load('three/src/salvage/salvageRun.js','globalThis.Run=SalvageRun;');
const encounters=[];
const encounterConfigs=[
 {name:'partial-budget',alive:12,dead:0,kind:'camp'},
 {name:'one-slot',alive:13,dead:0,kind:'camp'},
 {name:'full-budget',alive:14,dead:0,kind:'camp'},
 {name:'dead-does-not-consume-budget',alive:12,dead:4,kind:'camp'},
 {name:'no-surface',alive:0,dead:0,kind:'camp',noSurface:true},
 {name:'failed-unit',alive:0,dead:0,kind:'camp',failUnit:true},
 {name:'fallback-squad',alive:0,dead:0,kind:'camp',emptyLeft:true},
 {name:'ambush-partial',alive:13,dead:0,kind:'ambush'},
 {name:'ambush-full',alive:14,dead:0,kind:'ambush'},
 {name:'nest-partial',alive:12,dead:0,kind:'nest'},
 {name:'patrol-partial',alive:12,dead:0,kind:'patrol'},
 {name:'exact-spawn-distance',alive:0,dead:0,kind:'camp',distance:380},
 {name:'inside-spawn-distance',alive:0,dead:0,kind:'camp',distance:379.999}
];
for(const config of encounterConfigs){
 const trace=[],units=new Map(),surfaceCalls=[];unitSerial=0;context.failUnit=!!config.failUnit;
 for(let i=0;i<config.alive+config.dead;i++)units.set({alive:i<config.alive},{type:'rat'});
 const kinds=['rat','dozer','rat'],e={id:'case',name:'测试遭遇',kind:config.kind,g:[0,0,0],squad:kinds,left:config.emptyLeft?[]:[...kinds],units:[],state:'dormant',triggerR:300,ring:[20,50],posts:[[10,20],[30,40]],route:[[0,0,0],[10,0,10],[20,0,20],[30,0,30],[40,0,40]],reward:1};
 const run=Object.create(context.Run.prototype);Object.assign(run,{units,encounters:[e],rand:()=>.5,time:10,op:{enemyHp:1},extras:[],W:{W:{M:{}}},
 drive:{player:{pos:[config.distance??200,0,0]},sim:{units:[]},layout:{nav:{}},scene3:{add(){}}},
 _surface(x,z,nest){surfaceCalls.push([x,z,!!nest]);return config.noSurface?null:[x,0,z];},_env:()=>({}),
 cine:{elite(){trace.push(['elite']);}},fx:{loot(...args){trace.push(['loot',...args.slice(0,3)]);}},
 hud:{feed(...args){trace.push(['feed',...args]);},nameCard(a,b,t){trace.push(['card',a,b,t/1000]);},flash(...args){trace.push(['flash',...args]);},threat(){} }});
 const frames=[];
 for(let i=0;i<2;i++){run._encounters();frames.push({state:e.state,left:[...e.left],alerted:!!e.alerted,spawned:e.units.map(u=>({kind:units.get(u).type,pos:u.pos,yaw:u.spawnAt.yaw,wp:units.get(u).wp+1})),alive:run._alive(),surfaceCalls:structuredClone(surfaceCalls),trace:structuredClone(trace),cache:run.extras.map(c=>({id:c.id,tier:c.tier,g:c.g,loot:c.loot}))});}
 encounters.push({config,frames});
}
load('three/src/battle/endlessSession.js','globalThis.Endless=EndlessSession;');
const keys=[];
for(const code of ['Enter','NumpadEnter'])for(const repeat of [false,true]){let next=0,prevent=0;const e=Object.create(context.Endless.prototype);e.nextWave=()=>next++;e.key({code,repeat,preventDefault(){prevent++;}});keys.push({code,repeat,next,prevent});}
process.stdout.write(JSON.stringify({commit,sourceHashes,sales,encounters,keys,cargoOrder:rules.itemOrder.filter(id=>context.ITEMS[id]?.cat==='cargo'),cargoPrices:Object.fromEntries(rules.itemOrder.filter(id=>context.ITEMS[id]?.cat==='cargo').map(id=>[id,context.sellPrice(id)]))}));

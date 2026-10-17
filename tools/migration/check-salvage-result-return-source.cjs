const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'))),sourceHashes={};
function read(name){const raw=fs.readFileSync(path.join(baseline.snapshot,name)),hash=crypto.createHash('sha256').update(raw).digest('hex');if(hash!==baseline.files[name].sha256)throw Error('Frozen drift '+name);sourceHashes[name]=hash;return raw.toString('utf8');}
const context=vm.createContext({URLSearchParams,location:{search:''},CARGO_SLOTS:20,STARTER_CARS:[],PART_LIST:[],Map,THREE:{},removeEventListener(){}});
for(const [name,expose] of [['shared/salvage/items.js','Object.assign(globalThis,{ITEMS,partItemId,sellPrice});'],['shared/salvage/stash.js','Object.assign(globalThis,{Stash:SalvageStash,partsNeeded});'],['three/src/salvage/salvageRun.js','globalThis.Run=SalvageRun;']]){
 vm.runInContext('{\n'+read(name).replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\n'+expose+'\n}',context);
}
const catalogue=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Outgame.json')));
// Adapt the PART_LIST import using the migration catalogue; non-part ITEMS remain actual source.
for(const [id,item] of Object.entries(catalogue.items))if(id.startsWith('part:'))context.ITEMS[id]={...item};
const cases=[],controls=[];
for(const name of ['drop','extract','death'])for(const code of ['Escape','KeyT','Space','KeyA']){
 let skips=0;
 const run=Object.assign(Object.create(context.Run.prototype),{cine:{cur:{name},blocking:true,skip(){skips++;}},search:null});
 controls.push({name,code,consumed:run.key({code}),skips});
}
for(const kind of ['success','death','timeout','abandon']){
 const trace=[],timers=[];let writes=0,closed=0;
 context.setTimeout=(fn,delay)=>{timers.push({fn,delay});trace.push(['schedule',delay]);};
 context.showSalvageResult=(ui,result)=>{if(ui.active())throw Error('Result over live drive');trace.push(['result']);ui.result=result;};
 const stock={scrap:3,cell:4,'part:cube':4,'part:laser1':2};
 const stash=Object.assign(Object.create(context.Stash.prototype),{credits:8000,items:new Map(Object.entries(stock)),stats:{raids:1,lost:0,extracted:0},usage:()=>({}),save(){writes++;trace.push(['save']);}});
 const run=Object.assign(Object.create(context.Run.prototype),{begun:true,finished:false,cargo:new Map([['scrap',7],['cell',2]]),time:23,kills:2,openedCount:3,stash,
  hud:{el:{hidden:false},dispose(){trace.push(['hudDispose']);}},units:new Map(),extras:[],beams:{removeFromParent(){},traverse(){}},fx:{dispose(){}},cine:{dispose(){}},W:{}});
 const ui={active:()=>drive.active},drive={active:true,modeController:run,ui,editor:{bp:{parts:[['core'],['cube'],['laser1']]}},hud:{root:{style:{},querySelectorAll:()=>[]}},sim:{viewEvents:[],units:[]},
  exit(){if(!this.active)return;trace.push(['exit']);this.active=false;run.dispose();this.modeController=null;trace.push(['hall']);}};
 run.drive=drive;
 if(kind==='success')run._extracted({name:'出口',needs:'cell'});
 else if(kind==='abandon')drive.exit();
 else run._fail(kind==='death'?'战车被击毁':'时间到了');
 if(kind!=='abandon'&&(ui.result||!run.finished||!run.hud.el.hidden||timers[0]?.delay!==250))throw Error('Finish ordering');
 if(kind==='abandon'&&timers[0]?.delay!==200)throw Error('Abandon timing');
 for(const timer of timers)timer.fn();
 if(trace.findIndex(x=>x[0]==='hall')>=trace.findIndex(x=>x[0]==='result'))throw Error('Hall before result contract');
 const result=ui.result;
 cases.push({kind,trace,delay:timers[0].delay,writes,stock:Object.fromEntries(stash.items),stats:stash.stats,result:{ok:result.ok,title:result.title,cargo:Object.fromEntries(result.items),value:result.value,lost:result.lost||0,time:result.time,kills:result.kills,opened:result.opened,lostText:result.lostText||''}});
}
console.log(JSON.stringify({commit,sourceHashes,cases,controls}));

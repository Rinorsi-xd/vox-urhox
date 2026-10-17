const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'))),hashes={};
function read(name){const raw=fs.readFileSync(path.join(baseline.snapshot,name));const hash=crypto.createHash('sha256').update(raw).digest('hex');if(hash!==baseline.files[name].sha256)throw Error('Source drift '+name);hashes[name]=hash;return raw.toString('utf8');}
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/Endless/Rules.json')));
const context=vm.createContext({URLSearchParams,location:{search:''},performance:{now:()=>123},structuredClone,
 ENDLESS:data.config,seededRandom:()=>()=>.5,asBlueprint:source=>({toJSON:()=>structuredClone(source)}),
 isLimited:()=>true,PARTS:{laser1:{cat:'weapon'}},shieldContains:()=>true});
function load(name,expose){vm.runInContext('{\n'+read(name).replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\n'+expose+'\n}',context);}
load('shared/battle/endless.js','globalThis.Run=EndlessRun;');
load('three/src/battle/endlessSession.js','globalThis.Session=EndlessSession;');
const cases=[];
for(const state of ['rest','combat','countdown','editing','over'])for(const supplies of [0,1,3])for(const locked of [false,true]){
 const saved={version:1,seed:1,wave:5,tier:2,lives:2,blueprint:{name:'saved',parts:[]},inventory:{laser1:2},supplies:Array.from({length:supplies},()=>({kind:'repair',id:'repair'})),time:71};
 const run=new context.Run({saved});run.state=state;
 let releases=0;context.document={pointerLockElement:locked?{}:null,exitPointerLock(){releases++;this.pointerLockElement=null;}};
 const session=Object.create(context.Session.prototype);Object.assign(session,{run,lastUpdate:0,aiMs:0,drive:{player:{alive:true,pos:[0,0,0]}},shield:{},debug:{update(){}},view:{update(){}},hud:{update(){}},loot:{update(){}}});
 session.update();session.update();
 const before=structuredClone(run.save());if(state==='rest'&&supplies)run.chooseSupply(0);
 cases.push({state,supplies,locked,releases,lockedAfter:!!context.document.pointerLockElement,before,after:run.save()});
}
process.stdout.write(JSON.stringify({commit,sourceHashes:hashes,cases}));

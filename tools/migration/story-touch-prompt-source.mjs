import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const hashes={},context={THREE:{Vector3:class{}},BOSS_KIND:{},URL,performance:{now:()=>10000},document:{body:{classList:{contains:()=>true}}}};vm.createContext(context);
function Load(relative,name){
 const bytes=fs.readFileSync(`${baseline.snapshot}/${relative}`),sha=crypto.createHash('sha256').update(bytes).digest('hex');
 if(sha!==baseline.files[relative].sha256)throw Error(`Source drift: ${relative}`);hashes[relative]=sha;
 const code=bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'').replaceAll('import.meta.url',"'file:///source.js'");
 return vm.runInContext(`(()=>{${code}\nreturn ${name};})()`,context);
}
const Hud=Load('shared/ui/storyHud.js','StoryHud'),Kinds=Load('three/src/battle/storyKinds.js','KINDS');context.KINDS=Kinds;
const Mission=Load('three/src/battle/storyMission.js','StoryMission'),Touch=Load('shared/controls/touchControls.js','TouchControls');
const cases=[];
function Check(kind,inside,blocked=false,phase=null,extra={}){
 const spec={name:`${kind}-${inside}-${blocked}-${phase??''}-${cases.length}`,kind,inside,blocked,phase,...extra};
 const elements=new Map();const hud=Object.create(Hud.prototype);hud.$=selector=>{if(!elements.has(selector))elements.set(selector,{classList:{toggle(){}},style:{}});return elements.get(selector);};
 hud.update=()=>{};hud.retitle=()=>{};hud.marker=()=>{};hud.pips=()=>{};
 const step={kind,pos:[0,2,0],r:9,site:'A',title:'test'};
 const m=Object.create(Mission.prototype);Object.assign(m,{level:{steps:[step]},i:0,begun:true,time:10,deadAt:null,drive:{player:{alive:true,pos:inside?[0,2,0]:[100,2,0]},vehicle:{speed:blocked?3:0},input:{touchInteract:false}},hud,
 view:{update(){},beaconFade(){},setZoneProgress(){}},fx:{update(){}},cap:{phase:phase||'cap',p:0,scrub:0},install:0,stepT:0,enemies:new Map()});
 m.carSize=()=>({w:2,below:1.5,above:1.5});m._beats=()=>{};m._marker=()=>{};
 if(kind==='install'||kind==='capture')m.update(.016);
 if(extra.finished)hud.prompt(null);
 if(extra.dead)hud.prompt(null);
 const controller=extra.salvagePrompt||extra.swap?{touchPrompt:extra.salvagePrompt?{}:null,touchSwap:extra.swap}:m;
 const t=Object.create(Touch.prototype);Object.assign(t,{drive:{modeController:controller,vehicle:{body:{rotation:()=>({x:extra.flip?1:0,y:0,z:0})}}},flipT:extra.flip?2:0,
 rdyEl:{firstElementChild:{style:{}}},wswap:{},wKey:'',input:{}});
 t._tickDrive();const held=t.hold('interact',true);const released=t.hold('interact',false);
 cases.push({...spec,promptOn:hud.promptOn===true,role:t.ctxRole,held:held===true,released:released===true,afterRelease:t.input.touchInteract===true});
}
for(const inside of [false,true])for(const blocked of [false,true])Check('install',inside,blocked);
for(const inside of [false,true])for(const phase of ['cap','scrub'])Check('capture',inside,false,phase);
Check('hold',true);Check('reach',true);Check('install',true,false,null,{finished:true});Check('install',true,false,null,{dead:true});
Check('reach',false,false,null,{salvagePrompt:true});Check('reach',false,false,null,{swap:true,salvagePrompt:true});
Check('install',true,false,null,{flip:true});Check('install',true,true,null,{flip:true});
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,files:hashes},cases}));

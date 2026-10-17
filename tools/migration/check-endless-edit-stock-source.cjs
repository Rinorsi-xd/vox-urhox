'use strict';
// Complete frozen consumers run against adapted editor/DOM services.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'),'utf8'));
const hashes={};function read(name){const bytes=fs.readFileSync(path.join(baseline.snapshot,name));hashes[name]=crypto.createHash('sha256').update(bytes).digest('hex');assert.equal(hashes[name],baseline.files[name].sha256);return bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')}
const parts=Object.fromEntries(JSON.parse(fs.readFileSync(path.join(root,'assets/Parts/Catalog.json'),'utf8')).parts.map(p=>[p.id,p]));
class Blueprint{
 constructor(){this.parts=new Map()}
 load(data){this.parts=new Map(data.parts.map((p,i)=>[i,{type:p[0]}]));return this}
}
const context=vm.createContext({PARTS:parts,PART_LIST:Object.values(parts),RETIRED_TYPES:{},Blueprint,ENDLESS:{tierLimits:false},ENEMY_ROLES:{},
 TIERS:[1,2,3,4,5].map(id=>({id})),clearTimeout(){},document:{pointerLockElement:null,querySelectorAll(){return []},createElement(){return {style:{},querySelector(){return {}},set innerHTML(value){}}},body:{appendChild(){}},addEventListener(){}},window:{addEventListener(){}},
 buildVehicleSpec:()=>({ok:true,weapons:[{}],motion:{topSpeed:1}})});
vm.runInContext(read('shared/battle/endlessInventory.js')+'\nglobalThis.Inv={isLimited,remainingInventory};',context);
vm.runInContext(read('shared/build/editor.js')+'\nglobalThis.EditorClass=Editor;',context);
vm.runInContext(read('three/src/battle/endlessEdit.js')+'\nglobalThis.EditClass=EndlessEdit;',context);
const ids=['laser1','drive1',Object.values(parts).find(p=>p.cat==='function').id,'cube','heavy','rod'];
const cases=[];
for(const id of ids)for(const stock of [{owned:0,used:0},{owned:1,used:1},{owned:2,used:1},{owned:1,used:2}])for(const action of ['pick','assign']){
 const blueprint={v:1,name:'stock',parts:Array.from({length:stock.used},(_,i)=>[id,i*20,0,0,0,0])};
 const editor=Object.create(context.EditorClass.prototype),messages=[];
 Object.assign(editor,{bp:new Blueprint(),rig:{},pipeline:{quality:'high'},ui:{inventory:null,toast(text,kind){messages.push({text,kind:kind||false})}},_saveSettings(){},_modeChanged(){},focusCar(){}});
 const edit=new context.EditClass(editor);edit.rebuild=()=>{};edit.refresh=()=>{};
 edit.enter({blueprint,tier:1,owned:{[id]:stock.owned}});
 editor.hotbar=['cube','slope','heavy','corner',false,false,false,false,false,false].map(x=>x||null);editor.slot=1;editor.tool='build';editor.spin=7;
 editor.preview={marker:true};editor.hold={marker:true};editor.down={marker:true};
 editor.ui.setHotbar=()=>{};messages.length=0;
 const before=JSON.stringify(editor.hotbar),beforeSlot=editor.slot;
 if(action==='pick')editor.pickPart(id,true);else editor.assignSlot(7,id);
 cases.push({id,...stock,action,blueprint,selectable:editor.endlessMode.canSelect(id),hotbar:editor.hotbar.map(x=>x??false),active:editor.slot+1,
  blocked:before===JSON.stringify(editor.hotbar)&&beforeSlot===editor.slot&&messages[0]?.text==='本局仓库没有这个零件',messages});
}
process.stdout.write(JSON.stringify({commit,hashes,cases})+'\n');

// Execute frozen shop/reset callbacks; DOM and transaction boundaries are adapters.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'),'utf8'));
const name='three/src/battle/endlessEdit.js',bytes=fs.readFileSync(path.join(baseline.snapshot,name));
const sha=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha!==baseline.files[name].sha256)throw new Error('Frozen source changed');
const parts=Object.fromEntries(Array.from({length:8},(_,i)=>['part'+(i+1),{id:'part'+(i+1),name:'Part '+(i+1),cat:'weapon'}]));
function section(){return {style:{},buttons:[],nodes:{},remove(){this.removed=true;},
 set innerHTML(value){this.markup=value;this.buttons=[...value.matchAll(/data-buy="([^"]+)"/g)].map(m=>({dataset:{buy:m[1]}}));},
 querySelector(key){return this.nodes[key]??= {};},querySelectorAll(key){if(key!=='[data-buy]')throw new Error(key);return this.buttons;}};}
const document={pointerLockElement:null,createElement:section,body:{appendChild(){}}};
const context=vm.createContext({PARTS:parts,ENDLESS:{tierLimits:false},shopParts:()=>Object.values(parts),
 partTier:()=>1,partPrice:()=>10,escapeHtml:String,validateDeparture:()=>({ok:true,errors:[]}),document});
vm.runInContext(bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.Edit=EndlessEdit;',context);
const cases=[];
for(const config of [
 {name:'gapped',hotbar:['cube','part1',null,'part2',null,null,null,null,null,null],slot:1,credits:100,actions:['part3','part3','fail:part4','reset']},
 {name:'full',hotbar:Array.from({length:10},(_,i)=>'occupied'+(i+1)),slot:9,credits:100,actions:['part4','reset']},
 {name:'already-present',hotbar:['part3',null,null,null,null,null,null,null,null,null],slot:0,credits:100,actions:['part3','part1','reset']},
 {name:'poor',hotbar:Array(10).fill(null),slot:3,credits:0,actions:['fail:part2','reset']}
]){
 let credits=config.credits,calls=0,loaded=null,rebuilds=0;
 const editor={hotbar:[...config.hotbar],slot:config.slot,undoStack:[1],redoStack:[2],selection:new Set([7]),
  clipboard:[{type:'part1'}],pasting:true,color:'#ffffff',bp:{name:'changed',load(value){loaded=value;}},
  ui:{setHotbar(){},toast(){},setName(){},setColor(){}},view:{rebuild(){rebuilds++;}},ghost:{hideAll(){}},
  _diagnose(){},_selectionChanged(){},_modeChanged(){}};
 const transient=['hit','preview','focusIds','boxing','down','hold','stretch','rotorAim','turretPreview'];
 for(const key of transient)editor[key]={};
 const edit=new context.Edit(editor,{credits:()=>credits,onBuy(type){calls++;if(type===failure)return {ok:false,reason:'controlled failure'};credits-=10;return {ok:true,price:10};}});
 let failure=null;edit.snapshot={};edit.entry={name:'entry',parts:[]};edit.owned={};edit.bar=section();edit.toggleShop(true);
 const shopStyle=edit.shop.style.cssText,markup=edit.shop.markup;
 const frames=[];
 for(const action of config.actions){
  if(action==='reset')edit.reset();
  else{failure=action.startsWith('fail:')?action.slice(5):null;const type=failure||action;
   const button=edit.shop.querySelectorAll('[data-buy]').find(b=>b.dataset.buy===type);if(!button)throw new Error(type);button.onclick();}
  frames.push({action,hotbar:editor.hotbar.map(x=>x??false),active:editor.slot+1,credits,stock:{...edit.owned},calls,
   reset:action==='reset'?{loaded,undo:editor.undoStack.length,redo:editor.redoStack.length,selection:editor.selection.size,
    clipboard:editor.clipboard===null,pasting:editor.pasting,transient:transient.map(key=>editor[key]===null),rebuilds,dirty:editor.dirty}:null});
 }
 if(!shopStyle.includes('width:min(980px,calc(100% - 48px))')||!markup.includes('minmax(210px,1fr));gap:6px'))throw new Error('Source shop layout changed');
 cases.push({config:{...config,hotbar:config.hotbar.map(x=>x??false),active:config.slot+1},frames});
}
process.stdout.write(JSON.stringify({commit,sourceHashes:{[name]:sha},cases})+'\n');

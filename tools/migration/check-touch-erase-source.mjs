import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),sourceHashes={};
function read(name){const data=fs.readFileSync(path.join(baseline.snapshot,name));const hash=createHash('sha256').update(data).digest('hex');if(hash!==baseline.files[name]?.sha256)throw Error('Source drift '+name);sourceHashes[name]=hash;return data.toString('utf8');}
const load=name=>{read(name);return import(pathToFileURL(path.join(baseline.snapshot,name)).href);};
globalThis.window={};globalThis.location={search:'?rawModels'};globalThis.innerWidth=800;globalThis.innerHeight=360;
const {Editor}=await load('shared/build/editor.js'),{Blueprint}=await load('shared/build/blueprint.js');
const {TouchControls}=await load('shared/controls/touchControls.js'),{buildBounds}=await load('shared/config.js'),{sfx}=await load('shared/ui/uiSound.js');
const nil=new Proxy({},{get:()=>()=>{}});
const editorText=read('shared/build/editor.js');
const start=editorText.indexOf('\t\tif ( this.hold && ! this.pasting && performance.now() >= this.hold.next )');
const repeatText=editorText.slice(start,editorText.indexOf('\n\t\t}',start)+4);
let now=0;Object.defineProperty(globalThis,'performance',{value:{now:()=>now},configurable:true});
const sourceRepeat=vm.runInNewContext('(function(){'+repeatText+'})',{performance:globalThis.performance,SWEEP_RATE:.03,HOLD_RATE:.1});
const parts=[{type:'cube',pos:[0,4,0],rot:0},{type:'cube',pos:[2,4,0],rot:0},{type:'cube',pos:[4,4,0],rot:0}];
const hit=id=>id?{partId:id,cell:[(id-1)*2,4,0],place:[(id-1)*2,5,0],normal:[0,1,0]}:null;
const specs=[
 {name:'orbit-release',mode:'orbit',steps:[['down',1],['up']]},
 {name:'orbit-remembered-target',mode:'orbit',steps:[['down',1],['aim',2],['up']]},
 {name:'orbit-held-no-repeat',mode:'orbit',steps:[['down',1],['tick',.5,2],['tick',.5,3],['up']]},
 {name:'orbit-empty-press',mode:'orbit',steps:[['down',null],['aim',2],['up']]},
 {name:'orbit-paint',mode:'orbit',tool:'paint',steps:[['down',1],['up']]},
 {name:'orbit-selection',mode:'orbit',select:true,steps:[['down',1],['aim',2],['up']]},
 {name:'fp-press',mode:'fp',steps:[['down',1],['up']]},
 {name:'fp-repeat',mode:'fp',steps:[['down',1],['tick',.299,2],['tick',.002,2],['tick',.099,3],['tick',.002,3],['up']]},
 {name:'fp-paint',mode:'fp',tool:'paint',steps:[['down',1],['tick',.5,2],['up']]},
 {name:'fp-selection',mode:'fp',select:true,steps:[['down',1],['tick',.029,2],['tick',.002,2],['tick',.031,3],['up']]},
 {name:'fp-paste-repeat-gate',mode:'fp',pasting:true,steps:[['down',1],['tick',.5,2],['up']]},
 {name:'fp-no-hit',mode:'fp',steps:[['down',null],['tick',.301,2],['up']]},
 {name:'tap-not-held',mode:'orbit',build:'tap',steps:[['down',1],['up']]},
];
const cases=[];
for(const spec of specs){now=0;let sounds=[];sfx.play=id=>sounds.push(id);const bp=new Blueprint();for(const p of parts)bp.add(p);
 const e=Object.create(Editor.prototype);Object.assign(e,{bp,bounds:buildBounds(),view:nil,ui:{toast(){},closePopovers(){},toggleInventory(){}},selection:new Set(spec.select?[1,2,3]:[]),selectionCorners:[],undoStack:[],redoStack:[],mirror:false,tool:spec.select?'select':spec.tool||'build',pasting:spec.pasting||false,input:{controlling:true,touchEnabled:true,down:()=>false},rig:{mode:spec.mode,beginDrag(){},endDrag(){}},update(){}});
 e._changed=()=>{};e._modeChanged=()=>{};
 const tc={mode:'edit',prefs:{build:spec.build||'aim'},input:e.input,editor:e};
 const states=[];for(const [op,value,target] of spec.steps){
  if(op==='down'){e.hit=hit(value);tc.returnValue=TouchControls.prototype.hold.call(tc,'erase',true);}
  else if(op==='aim')e.hit=hit(value);
  else if(op==='tick'){now+=value*1000;e.hit=hit(target);sourceRepeat.call(e);}
  else if(op==='up')tc.returnValue=TouchControls.prototype.hold.call(tc,'erase',false);
  states.push({ids:[...bp.parts.keys()],selection:[...e.selection].sort((a,b)=>a-b),transactions:e.undoStack.length,sounds:[...sounds],held:tc.returnValue});
 }
 cases.push({...spec,parts,states});
}
const mobile=read('shared/controls/mobileEditor.js'),touchCss=read('shared/css/touch-controls.css'),mobileCss=read('shared/css/mobile-editor.css'),shell=read('shared/ui/shell.js');
const sourceLimits={copyDoesNotPaste:!editorText.slice(editorText.indexOf('\n\tselectionAction('),editorText.indexOf('\n\t_selectionChanged(')).includes('startPaste'),modernHasNoPaste:!mobile.includes("'paste'")&&!mobile.includes("'me-paste'"),oldMenuHidden:mobileCss.includes('#touch-controls[data-mode="edit"] .tc-top { display: none; }'),settingsOnlyHidesActions:touchCss.includes('.tc-panel > .tc-options:first-child > :not([data-touch="menu"]) { display:none !important; }'),settingsOnlyEnabled:read('shared/controls/touchControls.js').includes('this.menu = this.settingsOnly = true'),pauseOpensSettings:shell.includes('this.touch?.openSettings()')};
for(const [name,value] of Object.entries(sourceLimits))if(!value)throw Error(name);
read('shared/controls/cameraRig.js');
const escapeCases=[];
for(const captured of [false,true])for(const pending of [false,true])for(const state of ['paste','selection','paint','idle','stretch','dialog','inventory']){
 const bp=new Blueprint();for(const p of parts)bp.add(p);let pauses=0,closes=0;
 const ui={modalOpen:state==='dialog',inventoryOpen:state==='inventory',closeModal(){closes++;this.modalOpen=false;},toggleInventory(on){if(!on)closes++;this.inventoryOpen=on;}};
 const e=Object.create(Editor.prototype);Object.assign(e,{bp,bounds:buildBounds(),view:nil,ghost:nil,ui,selection:new Set(state==='selection'?[1,2]:[]),selectionCorners:[],undoStack:[],redoStack:[],mirror:false,tool:state==='paint'?'paint':'build',pasting:state==='paste',stretch:state==='stretch'?{phase:'rect'}:null,input:{locked:false,touchEnabled:true,touchActive:true},onEscape(){pauses++;}});
 e._changed=()=>{};e._modeChanged=()=>{};e._key({code:'Escape',preventDefault(){}});
 escapeCases.push({captured,pending,state,pasting:e.pasting,selection:[...e.selection],tool:e.tool,stretch:!!e.stretch,pauses,closes});
}
fs.writeFileSync(path.join(root,'.tmp/touch-erase-source.json'),JSON.stringify({commit:baseline.commit,sourceHashes,cases,sourceLimits,escapeCases},null,2)+'\n');
console.log(JSON.stringify({result:'PASS',cases:cases.length,escapeCases:escapeCases.length,sourceLimits}));

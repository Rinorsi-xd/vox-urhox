import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),hashes={};
function read(p){const b=fs.readFileSync(path.join(baseline.snapshot,p));const h=createHash('sha256').update(b).digest('hex');if(baseline.files[p]?.sha256!==h)throw Error('Source drift '+p);hashes[p]=h;return b.toString('utf8');}
const load=p=>{read(p);return import(pathToFileURL(path.join(baseline.snapshot,p)).href);};
globalThis.window={addEventListener(){}};
globalThis.document={addEventListener(){},pointerLockElement:null,activeElement:null};
globalThis.location={search:'?rawModels'};
const {Editor}=await load('shared/build/editor.js'),{Blueprint}=await load('shared/build/blueprint.js');
const {buildBounds}=await load('shared/config.js'),{sfx}=await load('shared/ui/uiSound.js');sfx.play=()=>{};
const noop=new Proxy({},{get:()=>()=>{}});
function make(){
 const bp=new Blueprint();for(const [x,type,g] of [[0,'cube',9],[1,'cube',9],[2,'slope',0]])bp.add({type,pos:[x,4,0],rot:0,color:0x336699,g});
 const e=Object.create(Editor.prototype),handlers={};
 Object.assign(e,{bp,view:noop,ghost:noop,ui:new Proxy({modalOpen:false,showHelpOpen:false,inventoryOpen:false},{get:(o,k)=>k in o?o[k]:()=>{}}),bounds:buildBounds(),mirror:false,selection:new Set([1,2,3]),undoStack:[],redoStack:[],hotbar:['cube','slope'],slot:0,tool:'build',color:0xd0182a,paintChannel:'shell',_wheelAcc:23,
 dom:{addEventListener(n,f){handlers[n]=f;}},input:{touchEnabled:false,down:()=>false},rig:{mode:'orbit',dist:20,zoom(d){this.dist=Math.max(2,Math.min(80,this.dist*1.0012**d));},beginDrag(){},endDrag(){}},
 _changed(){},_modeChanged(){},_selectionChanged(){},_saveSettings(){},_runBlocked(){return false;}});
 e._bind();e._wheelAcc=23;return {e,handlers};
}
const wheels=[];
for(const mode of ['orbit','fp'])for(const phase of ['selection','height','rect'])for(const modifiers of ['none','shift','ctrl','alt'])for(const pixels of [-100,-1,0,1,100]){
 const {e,handlers}=make();e.rig.mode=mode;e.stretch={phase,h:8,adj:3};
 handlers.wheel({deltaY:pixels,deltaX:0,preventDefault(){},shiftKey:modifiers==='shift',ctrlKey:modifiers==='ctrl',altKey:modifiers==='alt'});
 wheels.push({mode,phase,modifiers,pixels,h:e.stretch.h,adj:e.stretch.adj,acc:e._wheelAcc,dist:e.rig.dist});
}
const keys=[];
for(const code of ['KeyZ','KeyY'])for(const shift of [false,true]){
 const {e}=make();e.undoStack=[[{op:'add',data:{id:3,type:'slope',pos:[2,4,0],rot:0,color:0x336699,g:0}}]];
 e.stretch={phase:'selection',h:2};
 e._key({code,ctrlKey:true,shiftKey:shift,target:{tagName:'DIV'},preventDefault(){}});
 keys.push({code,shift,parts:[...e.bp.parts.keys()],undo:e.undoStack.length,redo:e.redoStack.length,stretch:!!e.stretch});
}
const pointers=[];
for(const spec of [
 {name:'right-original-target',button:2,press:1,release:3},
 {name:'right-empty-press',button:2,press:null,release:3},
 {name:'right-select-group',button:2,tool:'select',press:1,release:3},
 {name:'right-select-empty',button:2,tool:'select',press:null,release:3},
 {name:'middle-original-target',button:1,press:3,release:1},
 {name:'middle-paint-picks-part',button:1,tool:'paint',press:3,release:1},
 {name:'middle-empty-press',button:1,press:null,release:3},
 {name:'right-small-diagonal',button:2,press:1,release:3,dx:5,dy:5},
 {name:'right-drag',button:2,press:1,release:3,dx:8,dy:1},
 {name:'right-return-to-origin',button:2,press:1,release:3,excursion:true},
 {name:'right-paint-no-delete',button:2,tool:'paint',press:1,release:3}
]){
 const {e}=make();e.tool=spec.tool||'build';e.hit=spec.press?{partId:spec.press}:null;
 e._pointerDown({button:spec.button,clientX:10,clientY:10,shiftKey:false});
 e.hit=spec.release?{partId:spec.release}:null;
 e._pointerUp({button:spec.button,clientX:10+(spec.dx||0),clientY:10+(spec.dy||0)});
 pointers.push({...spec,parts:[...e.bp.parts.keys()],selection:[...e.selection].sort(),tool:e.tool,type:e.hotbar[e.slot],color:e.color});
}
const output={commit:baseline.commit,sourceHashes:hashes,wheels,keys,pointers};
fs.writeFileSync(path.join(root,'.tmp/build-input-source.json'),JSON.stringify(output,null,2)+'\n');
console.log(JSON.stringify({result:'PASS',wheels:wheels.length,keys:keys.length,pointers:pointers.length}));

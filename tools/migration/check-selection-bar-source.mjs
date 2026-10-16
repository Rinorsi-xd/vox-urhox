import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),sourceHashes={};
function read(p){const bytes=fs.readFileSync(path.join(baseline.snapshot,p)),hash=createHash('sha256').update(bytes).digest('hex');if(hash!==baseline.files[p]?.sha256)throw Error('Source drift '+p);sourceHashes[p]=hash;return bytes.toString('utf8');}
const load=p=>{read(p);return import(pathToFileURL(path.join(baseline.snapshot,p)).href);};
globalThis.window={};globalThis.location={search:'?rawModels'};
const {Editor}=await load('shared/build/editor.js'),{Blueprint}=await load('shared/build/blueprint.js');
const {buildBounds}=await load('shared/config.js'),{sfx}=await load('shared/ui/uiSound.js');
read('shared/parts/paint.js');
const {WEAPON_GLB}=await load('shared/parts/weaponData.js'),{registerWeaponGLB}=await load('shared/parts/weaponModels.js');
const gunAsset='shared/assets/weapons/'+WEAPON_GLB.mg3.file;read(gunAsset);
const gunBytes=fs.readFileSync(path.join(baseline.snapshot,gunAsset));registerWeaponGLB('mg3',gunBytes.buffer.slice(gunBytes.byteOffset,gunBytes.byteOffset+gunBytes.byteLength));
const nil=new Proxy({},{get:()=>()=>{}});let sounds=[],messages=[];
sfx.play=id=>sounds.push(id);
const cube=(x,color)=>({type:'cube',pos:[x,4,0],rot:0,...(color==null?{}:{color})});
const gun=(x,color,shellColor)=>({type:'mg3',pos:[x,4,0],rot:0,...(color==null?{}:{color}),...(shellColor==null?{}:{shellColor})});
function make(initial){const bp=new Blueprint();for(const d of initial)bp.add(d);const e=Object.create(Editor.prototype);Object.assign(e,{bp,bounds:buildBounds(),view:nil,ui:{toast:text=>messages.push(text)},selection:new Set(),selectionCorners:[],undoStack:[],redoStack:[],mirror:false,autoColor:false,color:0xd0182a,paintChannel:'shell',tool:'build'});e._changed=()=>{};e._modeChanged=()=>{};return e;}
function rows(e){return [...e.bp.parts.values()].map(p=>({id:p.id,type:p.type,color:p.color,shellColor:p.shellColor??null}));}
const cases=[];
const specs=[
 {name:'empty',parts:[cube(0)],selection:[]},
 {name:'unselected-mirror',parts:[cube(3),cube(-3)],selection:[1],mirror:true},
 {name:'one-shell',parts:[cube(0,0x112233)],selection:[1]},
 {name:'same-color',parts:[cube(0,0xd0182a)],selection:[1]},
 {name:'missing-id',parts:[cube(0)],selection:[99]},
 {name:'mixed-shell',parts:[cube(0,0x112233),gun(10,0x112233,0x556677)],selection:[1,2]},
 {name:'mixed-accent',parts:[cube(0,0x112233),gun(10,0x112233,0x556677)],selection:[1,2],channel:'accent'},
 {name:'shell-auto',parts:[cube(0,0x112233),gun(10,0x112233,0x556677)],selection:[1,2],auto:true},
 {name:'accent-auto',parts:[cube(0,0x112233),gun(10,0x112233,0x556677)],selection:[1,2],channel:'accent',auto:true},
 {name:'null-original-fields',parts:[cube(0),gun(10)],selection:[1,2],auto:true},
 {name:'partial-same',parts:[cube(0,0xd0182a),cube(1,0x112233)],selection:[2,1]},
 {name:'paint-tool-independent',parts:[cube(0,0x112233)],selection:[1],tool:'erase'},
];
for(const spec of specs){sounds=[];messages=[];const e=make(spec.parts);e.selection=new Set(spec.selection);e.mirror=spec.mirror||false;e.autoColor=spec.auto||false;e.paintChannel=spec.channel||'shell';e.tool=spec.tool||'build';const before=rows(e);e.paintSelection();const after=rows(e),paintSounds=[...sounds],paintMessages=[...messages],undoCount=e.undoStack.length;let undone=after,redone=after;if(undoCount){e.undo();undone=rows(e);e.redo();redone=rows(e);}cases.push({...spec,before,after,undone,redone,sounds:paintSounds,messages:paintMessages,undoCount,selection:[...e.selection]});}
function method(text,name){const start=text.indexOf('\n\t'+name+'(');if(start<0)throw Error(name);return text.slice(start,text.indexOf('\n\t}',start)+3);}
const editorText=read('shared/build/editor.js'),uiText=read('shared/ui/ui.js');
const actions=[];for(const action of ['move','copy','join','stretch','paint','delete','clear']){const calls=[];const e=make([]);for(const name of ['copy','toggleForm','setTool','paintSelection','deleteSelection','clearSelection'])e[name]=(...args)=>calls.push([name,...args]);e.ui.toast=text=>calls.push(['toast',text]);e.selectionAction(action);actions.push({action,calls});}
const bars=[];let current;
const context=vm.createContext({$:()=>({classList:{toggle:(name,on)=>{current.show=on;}},querySelector:selector=>selector.includes('count')?{set textContent(v){current.count=v;}}:{style:{setProperty:(name,value)=>{current.brush=value;}}}}),document:{body:{classList:{toggle:(name,on)=>{current.hasSelection=on;}}}},hex:v=>'#'+v.toString(16).padStart(6,'0')});
const sync=vm.runInContext('({'+method(uiText,'_selBar')+'})._selBar',context);
for(const count of [0,1,19,1200])for(const pasting of [false,true])for(const auto of [false,true]){current={count,pasting,auto};sync({selection:count,pasting,autoColor:auto,color:0x123456});bars.push(current);}
const match=uiText.match(/sel\.innerHTML = `[\s\S]*?\]\s*\.map/)[0];
const entries=[...match.matchAll(/\[ '([^']+)', '([^']+)', '([^']+)', '([^']*)' \]/g)].map(m=>({action:m[1],icon:m[2],text:m[3],key:m[4]}));if(entries.length!==7)throw Error('Original selection entries');
for(const p of ['shared/css/style.css','shared/css/new-ui-tokens.css','shared/css/new-ui-utility.css','shared/css/new-ui-controls.css','shared/css/new-ui-responsive.css','shared/css/mobile-editor.css'])read(p);
fs.writeFileSync(path.join(root,'.tmp/selection-bar-source.json'),JSON.stringify({commit:baseline.commit,sourceHashes,cases,actions,bars,entries},null,2)+'\n');
console.log(JSON.stringify({result:'PASS',cases:cases.length,actions:actions.length,visibility:bars.length,entries:entries.length}));

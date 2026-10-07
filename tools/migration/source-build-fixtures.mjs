// Read-only execution of source editor rules. DOM/audio/persistence are adapters;
// placement, command history, subcell rays and blueprint operations are original.
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {deflateRawSync,constants} from 'node:zlib';
const source='D:/Rino_Project/Vox',root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const mod=p=>import(pathToFileURL(path.join(source,p)).href);
globalThis.window={};
const {Editor}=await mod('shared/build/editor.js');
const {Blueprint}=await mod('shared/build/blueprint.js');
const {PARTS}=await mod('shared/parts/defs.js');
const R=await mod('shared/core/rotations.js');
const {buildBounds}=await mod('shared/config.js');
const {raycastGrid}=await mod('shared/build/raycast.js');
const {paintField}=await mod('shared/parts/paint.js');
const {sfx}=await mod('shared/ui/uiSound.js');sfx.play=()=>{};
globalThis.fetch=async file=>{
 const target=path.resolve(file instanceof URL || String(file).startsWith('file:')?fileURLToPath(file):file);if(!target.replaceAll('\\','/').startsWith(source+'/'))throw Error('Non-source fetch');
 const bytes=fs.readFileSync(target);return {ok:true,arrayBuffer:async()=>bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength)};
};
for(const [name,folder] of [['Weapon','weapons'],['Wheel','wheels'],['Track','tracks'],['Thruster','thrusters'],['Hover','hovers'],['Leg','legs']]){
 const api=await mod(`shared/parts/${name.toLowerCase()}Models.js`);await api[`load${name}Models`](pathToFileURL(source+`/shared/assets/${folder}/`).href);
}
const nilView=new Proxy({},{get:()=>()=>{}});
function editor(bp){
 const e=Object.create(Editor.prototype);
 Object.assign(e,{bp,view:nilView,ui:nilView,rig:{forward:{x:.3,y:0,z:.95}},bounds:buildBounds(),mirror:true,spin:0,
  selection:new Set(),undoStack:[],redoStack:[],color:0xd0182a,paintChannel:'shell',tool:'build',clipboard:null,pasteSpin:0,hotbar:['cube'],slot:0});
 e._changed=()=>{};e._modeChanged=()=>{};e._saveSettings=()=>{};
 return e;
}
const e=editor(new Blueprint()),placements=[],mirrors=[],rotations=[],paint=[];
for(const type of Object.keys(PARTS)){
 paint.push({type,shell:paintField({type},'shell'),accent:paintField({type},'accent')});
 for(const normal of R.DIRS)for(const spin of [-1,0,1,2,3]){
  e.spin=spin;const pos=[normal[0]<0?-3:3,6,-2];
  placements.push({type,normal,spin,pos,expected:e._placeFor(type,{normal},pos)});
 }
 for(let rot=0;rot<24;rot++)for(const pos of [[0,5,0],[3,5,-2]])mirrors.push({type,rot,pos,expected:e._mirrorOf(type,pos,rot)});
}
for(let rot=0;rot<24;rot++)for(const axis of R.DIRS)for(const step of [-2,-1,0,1,2])rotations.push({rot,axis,step,expected:R.rotateAroundAxis(rot,axis,step)});
let seed=17831;const random=()=>((seed=seed*48271%2147483647)/2147483647);
const rays=[];
for(const type of Object.keys(PARTS)){
 const bp=new Blueprint();bp.add({type,pos:[0,4,0],rot:R.IDENTITY});bp.add({type:'cube',pos:[0,4,-5],rot:R.IDENTITY});
 const samples=[];
 for(let i=0;i<12;i++){
  const origin=[(random()-.5)*6,random()*5,4+(random()-.5)*2],target=[(random()-.5)*1.5,2+random(),-1];
  const delta=target.map((v,k)=>v-origin[k]),length=Math.hypot(...delta),direction=delta.map(v=>v/length);
  const asVec=a=>({x:a[0],y:a[1],z:a[2]});
  samples.push({origin,direction,expected:raycastGrid(asVec(origin),asVec(direction),bp,40,false)});
 }
 rays.push({type,data:bp.toJSON(),samples});
}
const bp=new Blueprint();bp.add({type:'core',pos:[0,4,0],rot:R.IDENTITY});
const ed=editor(bp),steps=[];const initial=structuredClone(bp.toJSON());
function record(op,args){
 switch(op){
 case 'place':{
  const [type,pos,rot]=args;ed.preview={type,pos,rot,res:bp.check(type,pos,rot,ed.bounds),normal:[0,1,0]};
  const m=ed._mirrorOf(type,pos,rot);if(m)ed.preview.mirror=m;ed.place();break;}
 case 'select': ed.selection=new Set(args);break;
 case 'move':ed.moveSelection(args);break;
 case 'lift':ed.liftCar(args);break;
 case 'copy':ed.copy();break;
 case 'paste':ed.pasteSpin=args.spin;{const paste=ed._pasteItems(args.pos);ed.preview={paste,ok:paste.every(it=>it.res.ok)};ed.commitPaste();}break;
 case 'paint':ed.tool='paint';ed.hit={partId:args.id};ed.color=args.color;ed.paintChannel=args.channel;ed.paintTarget();break;
 case 'remove':ed.removeTarget({partId:args});break;
 case 'delete':ed.deleteSelection();break;
 case 'undo':ed.undo();break;
 case 'redo':ed.redo();break;
 }
 steps.push({op,args,data:structuredClone(bp.toJSON()),parts:Array.from(bp.parts.values()).map(p=>({id:p.id,type:p.type,pos:p.pos,rot:p.rot,color:p.color,shellColor:p.shellColor})),selection:[...ed.selection].sort((a,b)=>a-b),undo:ed.undoStack.length,redo:ed.redoStack.length});
}
for(let z=-2;z<=2;z++)for(let x=-2;x<=2;x++)record('place',['cube',[x,5,z],R.IDENTITY]);
record('select',[2,3,4]);record('move',[0,1,0]);record('undo');record('redo');record('select',[2,3,4]);record('copy');record('paste',{pos:[8,7,0],spin:1});record('undo');record('redo');
record('paint',{id:2,color:0x2f8cff,channel:'shell'});record('undo');record('redo');
record('select',[2,3]);record('delete');record('undo');record('redo');record('undo');
record('lift',2);record('undo');record('redo');record('remove',1);record('undo');
record('paint',{id:2,color:0xffcc22,channel:'accent'}); // Single-color parts reject this channel.
for(let i=0;i<310;i++)record('paint',{id:2,color:i%2?0xffcc22:0xd0182a,channel:'shell'});
record('undo');record('paint',{id:2,color:0x2f8cff,channel:'accent'});record('redo');
const paths=['shared/build/editor.js','shared/build/blueprint.js','shared/build/raycast.js','shared/ui/inventory.js','shared/parts/defs.js','shared/parts/hoverMount.js','shared/parts/legMount.js'];
const provenance=paths.map(p=>({path:p,sha256:createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex')}));
const codes=[];const storage=await mod('shared/storage.js');
for(const count of [0,1,7,142,1024]){
 const data={v:1,sizeVersion:1,name:'赤焰 GT · 蓝图验证',parts:Array.from({length:count},(_,i)=>['cube',i%30,4,Math.floor(i/30),R.IDENTITY,(i*378013)%0xffffff,i%2?0xcbd1d7:null])};
 const bytes=Buffer.from(JSON.stringify(data));
 for(const options of [{level:0},{strategy:constants.Z_FIXED},{level:6}]){
  const code='FKZC1:z'+deflateRawSync(bytes,options).toString('base64url');
  codes.push({code,data:await storage.decodeBlueprint(code)});
 }
 codes.push({code:'FKZC1:j'+bytes.toString('base64url'),data});
}
const {rules}=await import('./source-blueprint-rules.mjs');
const {inventory}=await import('./source-inventory-fixtures.mjs');
fs.writeFileSync(path.join(root,'tools/migration/source-build-fixtures.json'),JSON.stringify({provenance,placements,mirrors,rotations,paint,rays,codes,rules,inventory,commands:{initial,steps}},(k,v)=>typeof v==='number'&&!Number.isFinite(v)?String(v):v));
console.log(JSON.stringify({placements:placements.length,mirrors:mirrors.length,rotations:rotations.length,rays:rays.reduce((n,r)=>n+r.samples.length,0),commands:steps.length}));

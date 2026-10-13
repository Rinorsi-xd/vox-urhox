import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const load=name=>import(pathToFileURL(path.join(baseline.snapshot,'shared',name)));
const {Editor}=await load('build/editor.js'),{Blueprint}=await load('build/blueprint.js');
const {PARTS}=await load('parts/defs.js'),{IDENTITY,ROTATIONS}=await load('core/rotations.js');
const {exactShapeGeo}=await load('parts/shapes.js'),{faceMask}=await load('parts/solid.js');
const {getInstancedLayers}=await load('parts/models.js');
const {buildBounds}=await load('config.js');
const {sfx}=await load('ui/uiSound.js');sfx.play=()=>{};
const THREE=await import(pathToFileURL(path.join(baseline.snapshot,'three/vendor/three/build/three.module.js')));
const source=fs.readFileSync(path.join(baseline.snapshot,'three/src/build/vehicleView.js'),'utf8');
const classCode=source.slice(source.indexOf('class JoinedMesh {'),source.indexOf('class InstancedBatch {'));
const slots=['paint','heavyPaint','glassPaint','neonPaint'];
const JOINED=Object.fromEntries(slots.map(s=>[s,new THREE.MeshBasicMaterial({vertexColors:true})]));
const Joined=vm.runInNewContext(classCode+'; JoinedMesh',{THREE,PARTS,ROTATIONS,exactShapeGeo,faceMask,getInstancedLayers,JOINED,_jc:new THREE.Color()});
const noop=new Proxy({},{get:()=>()=>{}});
const canonical=bp=>[...bp.parts.values()].map(p=>({id:p.id,type:p.type,pos:p.pos,rot:p.rot,color:p.color,shellColor:p.shellColor??null,g:p.g||0})).sort((a,b)=>a.id-b.id);
function bpOf(specs){const bp=new Blueprint();for(const s of specs)bp.add(s);return bp;}
function editor(bp,mirror=false){const e=Object.create(Editor.prototype);Object.assign(e,{bp,mirror,bounds:buildBounds(),view:noop,ui:noop,ghost:noop,
 selection:new Set(),selectionCorners:[],undoStack:[],redoStack:[],joinNew:false,autoColor:true,paintChannel:'shell',color:0xd0182a,
 _changed(){},_modeChanged(){},_previewPaint(){}});return e;}
const selections=[],removals=[],placements=[];
for(let i=0;i<64;i++){
 const specs=[{type:'core',pos:[0,4,0],rot:IDENTITY}];
 for(let j=0;j<8;j++)specs.push({type:['cube','heavy','slope','panel'][i%4],pos:[j<5?j-2:j+5,5,j%3===0?1:0],rot:IDENTITY,g:i%3===0?2:i%3===1&&j%2?3:0});
 const bp=bpOf(specs),e=editor(bp,i%2===0);e.selection=new Set(i%11===0?[1]:[2,3,4,7]);
 const c={specs:canonical(bp),mirror:e.mirror,ids:[...e.selection]};
 e.toggleForm();c.after=canonical(bp);c.selected=[...e.selection].sort((a,b)=>a-b);c.history=e.undoStack.length;
 e.undo();c.undo=canonical(bp);e.redo();c.redo=canonical(bp);e.toggleForm();c.second=canonical(bp);selections.push(c);
}
for(let i=0;i<48;i++){
 const bp=new Blueprint();bp.add({type:'core',pos:[0,3,0],rot:IDENTITY});
 for(let x=-4;x<=4;x++)bp.add({type:x%2&&i%3===0?'heavy':'cube',pos:[x,5,0],rot:IDENTITY,g:7});
 if(i%4===0)bp.add({type:'cube',pos:[0,6,0],rot:IDENTITY,g:7});
 const e=editor(bp,i%2===0),id=2+i%8,c={specs:canonical(bp),mirror:e.mirror,id};
 e.removeTarget({partId:id});c.after=canonical(bp);e.undo();c.undo=canonical(bp);e.redo();c.redo=canonical(bp);removals.push(c);
}
for(let i=0;i<48;i++){
 const bp=new Blueprint();bp.add({type:'core',pos:[0,4,0],rot:IDENTITY});
 for(let x=-3;x<=3;x++)bp.add({type:i%3===0&&x<0?'heavy':'cube',pos:[x,5,0],rot:IDENTITY,g:x<0?2:5});
 const e=editor(bp,i%2===0);e.joinNew=i%4!==0;const type=i%3===0?'heavy':'cube';
 const pv={type,pos:[1,6,0],rot:IDENTITY,res:{ok:true},normal:[0,1,0],mirror:e.mirror?{pos:[-1,6,0],rot:IDENTITY}:null};
 const c={specs:canonical(bp),mirror:e.mirror,joinNew:e.joinNew,pv};e.preview=pv;e.place();c.after=canonical(bp);
 e.undo();c.undo=canonical(bp);e.redo();c.redo=canonical(bp);placements.push(c);
}
const shapeTypes=[...new Map(Object.entries(PARTS).filter(([,d])=>d.shape&&!d.panel&&d.mat==='light').map(([t,d])=>[d.shape,t])).values()];
const surfaces=[];
for(let i=0;i<shapeTypes.length*4+72;i++){
 const type=shapeTypes[i%shapeTypes.length],rot=i%24,bp=new Blueprint();
 bp.add({type,pos:[0,5,0],rot,color:0xe84a2a,g:1});
 if(i>=shapeTypes.length*4){
  const materials=['cube','heavy','glass','neonCube'];const q=materials[i%4];
  bp.add({type:q,pos:[i%3===0?1:0,i%3===1?6:5,i%3===2?1:0],rot:IDENTITY,color:0x32c5dd,g:i%2?1:2});
  if(i%7===0)bp.add({type:'slope',pos:[1,5,0],rot:i%24,color:0x54993c,g:3});
 }
 const mesh=new Joined(new THREE.Group());for(const p of bp.parts.values())mesh.add(p);mesh.update();
 const out={};for(const [slot,m] of mesh.meshes)out[slot]={position:Array.from(m.geometry.attributes.position.array),normal:Array.from(m.geometry.attributes.normal.array),color:Array.from(m.geometry.attributes.color.array)};
 const edges={};for(const line of mesh.outlines.children)edges[line.userData.group]=Array.from(line.geometry.attributes.position.array);
 surfaces.push({specs:canonical(bp),surfaces:out,edges});mesh.clear();
}
const decalSource=fs.readFileSync(path.join(baseline.snapshot,'three/src/build/liveryView.js'),'utf8');
const decalCode=decalSource.slice(decalSource.indexOf('export function decalFrame'),decalSource.indexOf('function decalMaterial')).replaceAll('export function','function');
const decalPrelude=`const SKIP_SLOT=/glow|Glow|beam|holo|neon|flag|flame|lamp|Fx|fx/, LIFT=.012,FACING=.22,FOLD=-.3;
const _m=new THREE.Matrix4(),_inv=new THREE.Matrix4(),_n3=new THREE.Matrix3();
const _a=new THREE.Vector3(),_b=new THREE.Vector3(),_c=new THREE.Vector3(),_e1=new THREE.Vector3(),_e2=new THREE.Vector3(),_fn=new THREE.Vector3();`;
const decals=[];
for(let i=0;i<24;i++){
 const bp=new Blueprint();for(let x=0;x<3;x++)bp.add({type:i%3===0?'slope':'cube',pos:[x,5,0],rot:i%24,color:0x32c5dd,g:1});
 const mesh=new Joined(new THREE.Group());for(const p of bp.parts.values())mesh.add(p);mesh.update();
 const model=Object.fromEntries([...mesh.meshes].map(([slot,m])=>[slot,{position:m.geometry.attributes.position.array,normal:m.geometry.attributes.normal.array}]));
 // Feed the source projector the displayed source JoinedMesh surface. The H5
 // projector otherwise still reads ordinary beveled models for joined blocks.
 const project=vm.runInNewContext(decalPrelude+decalCode+';projectDecal',{THREE,PARTS,NO_SHADOW_SLOTS:new Set(),getModel:()=>model,partMatrix:()=>new THREE.Matrix4()});
 const decal={p:[1,6,0],n:i%2?[0,1,0]:[0,0,-1],r:i*.07,w:3.2,f:i%2};const sticker={aspect:1.2};
 const g=project(decal,sticker,[{}]);
 decals.push({specs:canonical(bp),decal,sticker,positions:g?Array.from(g.attributes.position.array):[],uv:g?Array.from(g.attributes.uv.array):[]});
 g?.dispose();mesh.clear();
}
fs.writeFileSync(path.join(root,'tools/migration/source-build-groups-fixtures.json'),JSON.stringify({commit:baseline.commit,selections,removals,placements,surfaces,decals}));
console.log(JSON.stringify({selections:selections.length,removals:removals.length,placements:placements.length,surfaces:surfaces.length}));

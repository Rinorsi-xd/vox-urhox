import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const baseline=JSON.parse(fs.readFileSync(new URL('../../docs/migration/outgame-baseline.json',import.meta.url)));
const load=name=>import(pathToFileURL(path.join(baseline.snapshot,'shared',name)));
const {Editor}=await load('build/editor.js');
const {Blueprint}=await load('build/blueprint.js');
const {extrusionPlan}=await load('build/selectionTools.js');
const {IDENTITY,DIRS}=await load('core/rotations.js');
const {CELL,buildBounds}=await load('config.js');
const {sfx}=await load('ui/uiSound.js');sfx.play=()=>{};
const noop=new Proxy({},{get:()=>()=>{}});
function editor(bp,mirror){const e=Object.create(Editor.prototype);Object.assign(e,{bp,mirror,bounds:buildBounds(),view:noop,ghost:noop,ui:noop,
 selection:new Set(),undoStack:[],redoStack:[],joinNew:false,autoColor:true,paintChannel:'shell',color:0xd0182a,tool:'stretch',
 _changed(){},_modeChanged(){},_previewPaint(){}});return e;}
function canonical(bp){return [...bp.parts.values()].map(p=>({id:p.id,type:p.type,pos:p.pos,rot:p.rot,color:p.color,shellColor:p.shellColor??null,g:p.g||0})).sort((a,b)=>a.id-b.id);}
const rays=[];
for(let i=0;i<144;i++){
 const n=DIRS[i%6],a=n.findIndex(v=>v!==0),anchor=[i%7-3,4+i%3,Math.floor(i/7)%7-3],cur=[anchor[0]+i%4,anchor[1],anchor[2]-i%5];
 const s={anchor,cur,n,a,hd:a===1?n:[0,1,0],h:1+i%4};
 const origin=[Math.sin(i)*20,8+i%9,Math.cos(i)*20],direction=[Math.sin(i*.3),-.1-i%4*.2,Math.cos(i*.3)];
 if(i%11===0)direction[1]=0;if(i%13===0)direction[1]=.5;if(i%17===0)direction.splice(0,3,0,-1,0);
 const e=editor(new Blueprint(),false);e.rig={ray:()=>({origin:{x:origin[0],y:origin[1],z:origin[2]},direction:{x:direction[0],y:direction[1],z:direction[2]}})};
 rays.push({s,origin,direction,cell:e._planeCell(s),height:e._heightAlong(s),cells:e._stretchCells(s)});
}
const extrusions=[];
const types=['cube','slope','corner','heavy','glass','frame','neon'].filter(t=>true);
const {PARTS}=await load('parts/defs.js');
for(let i=0;i<96;i++){
 const bp=new Blueprint();const type=types[i%types.length] in PARTS?types[i%types.length]:'cube';
 for(const [j,pos] of [[0,[3,5,0]],[1,[3,6,0]],[2,[3,5,2]],[3,[-3,5,0]]])bp.add({type,pos,rot:IDENTITY,color:j%2?0x32c5dd:0xe84a2a,g:i%9===0?j+2:0});
 if(i%8===0)bp.add({type:'cube',pos:[4,5,0],rot:IDENTITY});
 if(i%10===0)bp.add({type:'core',pos:[8,5,0],rot:IDENTITY});
 const ids=[1,2,3];if(i%10===0)ids.push(bp.size);
 const e=editor(bp,i%2===0),n=DIRS[i%6],h=i%12===0?48:1+i%4,seeds=ids.map(id=>bp.parts.get(id));
 const plan=extrusionPlan(e,seeds,n,h);
 const c={specs:canonical(bp),ids,n,h,mirror:e.mirror,plan};
 if(!plan.bad){e.stretch={phase:'selection',seeds,n,h};e.selection=new Set(ids);e.commitSelectionStretch();c.after=canonical(bp);c.selection=[...e.selection].sort((a,b)=>a-b);}
 extrusions.push(c);
}
const rectangles=[];
for(let i=0;i<36;i++){
 const bp=new Blueprint();bp.add({type:'core',pos:[0,4,0],rot:IDENTITY});
 if(i%3===0)bp.add({type:'cube',pos:[-4,5,0],rot:IDENTITY});
 const n=DIRS[i%6],a=n.findIndex(v=>v!==0),s={phase:'height',type:i%2?'slope':'cube',rot:IDENTITY,n,a,anchor:[3,5,0],cur:[3+i%3,5,i%4],h:1+i%3,hd:a===1?n:[0,1,0]};
 const e=editor(bp,i%2===0);s.cells=e._stretchCells(s);s.mirrorCells=[];const own=new Set(s.cells.map(c=>c.join()));
 if(e.mirror)for(const c of s.cells){const m=e._mirrorOf(s.type,c,s.rot);if(m&&!own.has(m.pos.join()))s.mirrorCells.push(m);}
 s.bad=s.cells.map(c=>bp.check(s.type,c,s.rot,e.bounds,null,false)).find(r=>!r.ok)?.reason??null;
 const before=canonical(bp);e.stretch=s;if(!s.bad)e.commitStretch();
 rectangles.push({specs:before,mirror:e.mirror,s,after:canonical(bp),history:e.undoStack.length});
}
fs.writeFileSync(new URL('./source-build-stretch.json',import.meta.url),JSON.stringify({commit:baseline.commit,cell:CELL,rays,extrusions,rectangles}));
console.log(`Frozen H5 stretch: ${rays.length} rays, ${extrusions.length} selection plans, ${rectangles.length} rectangle transactions`);

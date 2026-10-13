import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const baseline=JSON.parse(fs.readFileSync(new URL('../../docs/migration/outgame-baseline.json',import.meta.url)));
const load=name=>import(pathToFileURL(path.join(baseline.snapshot,'shared',name)));
const {Blueprint}=await load('build/blueprint.js');
const {Editor}=await load('build/editor.js');
const {cornerParts}=await load('build/selectionTools.js');
const {PARTS}=await load('parts/defs.js');
const {IDENTITY}=await load('core/rotations.js');
const bp=new Blueprint();
const types=['cube','drive3','steer3','track3','mg3'].filter(t=>PARTS[t]);
const specs=[];
for(let i=0;i<42;i++){
 const spec={type:types[i%types.length],pos:[(i%7-3)*7,4+Math.floor(i/21)*5,(Math.floor(i/7)%3-1)*9],rot:IDENTITY};
 const p=bp.add(spec);specs.push({...spec,id:p.id});
}
const volumes=[];
for(let i=0;i<120;i++){
 const p=[...bp.parts.values()][i%42],q=[...bp.parts.values()][(i*13+5)%42];
 const a=p._cells[i%p._cells.length],b=q._cells[(i*3)%q._cells.length];
 volumes.push({a,b,ids:cornerParts(bp,a,b).map(p=>p.id).sort((a,b)=>a-b)});
}
// Invoke the frozen editor's real methods without constructing its browser UI.
const editor=Object.create(Editor.prototype);
Object.assign(editor,{bp,selection:new Set(),selectionCorners:[],mirror:true,view:{setSelection(){}},_modeChanged(){},ui:{toast(){}}});
const operations=[];
function act(action,id,on){
 const p=bp.parts.get(id);editor.hit=p?{partId:id,cell:p._cells.at(-1)}:null;
 let result;
 if(action==='toggle')result=editor.toggleSelectTarget();
 if(action==='sweep')editor.sweepSelect(on);
 if(action==='corner')editor.selectCorner();
 if(action==='clear'){editor.selection.clear();editor._selectionChanged();}
 operations.push({action,id,on,hit:editor.hit,result:result??null,ids:[...editor.selection].sort((a,b)=>a-b)});
}
for(let i=0;i<16;i++){
 act('clear');act('toggle',1+i);act('toggle',42-i);act('corner');
 act('sweep',1+i,false);act('sweep',42-i,false);act('sweep',1+i,true);act('toggle',1+i);
}
fs.writeFileSync(new URL('./source-build-selection.json',import.meta.url),JSON.stringify({commit:baseline.commit||baseline.source?.commit,specs,volumes,operations}));
console.log(`Original H5 selection: ${volumes.length} occupied-cell volumes, ${operations.length} command transitions`);

import {Inventory} from 'file:///D:/Rino_Project/Vox/shared/ui/inventory.js';
import {Editor} from 'file:///D:/Rino_Project/Vox/shared/build/editor.js';
import {CATEGORIES,BLOCK_MATS,PART_LIST} from 'file:///D:/Rino_Project/Vox/shared/parts/defs.js';
const inv=Object.create(Inventory.prototype),lists=[];
for(const cat of ['all',...CATEGORIES.map(c=>c.id)])for(const mat of BLOCK_MATS.map(m=>m.id))for(const query of ['', 'T3', '转向', '玻璃', 'mg', '不存在的零件']){
 Object.assign(inv,{cat,mat,query});lists.push({cat,mat,query,expected:inv._list().map(d=>d.id)});
}
const e=Object.create(Editor.prototype);
Object.assign(e,{hotbar:['cube','slope','corner','heavy','glass','drive3','steer3','mg3','laser3','light'],slot:0,ui:{setHotbar(){},toast(){}},_saveSettings(){},_modeChanged(){}});
const steps=[];
function op(name,args){e[name](...args);steps.push({name,args,active:e.slot+1,hotbar:e.hotbar.map(t=>t??false)});}
for(let i=0;i<100;i++){
 op('assignSlot',[i%10,PART_LIST[(i*37)%PART_LIST.length].id]);
 if(i%3===0)op('clearSlot',[(i+3)%10]);
 if(i%4===0)op('pickPart',[PART_LIST[(i*13)%PART_LIST.length].id]);
 if(i%7===0)op('selectSlot',[(i+6)%10]);
}
export const inventory={lists,steps};

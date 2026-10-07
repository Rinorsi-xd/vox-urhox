// Execute the original rules; only serialization normalizes unordered sets.
import {buildRaceCar,buildTank} from 'file:///D:/Rino_Project/Vox/shared/build/prefab.js';
import {Blueprint,partCells} from 'file:///D:/Rino_Project/Vox/shared/build/blueprint.js';
import {PARTS} from 'file:///D:/Rino_Project/Vox/shared/parts/defs.js';
import {ROTATIONS,IDENTITY,applyRot} from 'file:///D:/Rino_Project/Vox/shared/core/rotations.js';
import {TIERS} from 'file:///D:/Rino_Project/Vox/shared/config.js';
import {legStanceCells} from 'file:///D:/Rino_Project/Vox/shared/parts/legMount.js';
const sort=s=>[...s].sort((a,b)=>a-b);
const row=(type,x=0,y=4,z=0,rot=IDENTITY)=>[type,x,y,z,rot,0xd0182a,0xe6e2d8];
const cases=[];
function add(name,parts){cases.push({name,data:{v:1,name,parts}});}
add('empty',[]);
add('legacy single row',[row('wheelS',-4),row('wheel',4),row('wheelL',10)]);
add('legacy front row',[row('wheelS',-4,4,-5),row('wheel',4,4,8),row('wheelL',10,4,8)]);
add('legacy wheel overlap',[row('cube'),row('wheelS'),row('wheel',8),row('wheel',8)]);
add('legacy hover structure first',[row('hover'),row('cube'),row('hover',12)]);
add('legacy panel retained',[row('cube'),row('panelSlope'),row('heavyPanelSlope',3),row('glassPanelSlope',6),row('neonPanelSlope',9)]);
add('modern overlap preserved',[row('cube'),row('cube'),row('hover2',10),row('hover2',10)]);
add('unknown type and rotation',[row('removedWeapon'),row('cube',0,4,0,99)]);
add('bounds',[row('core'),row('cube',-31),row('cube',0,-1),row('cube',31,41,41)]);
add('weak chain',[row('core'),...Array.from({length:30},(_,i)=>row('cube',0,4,i+1))]);
add('forked chains',[row('core'),...[-1,1].flatMap(sign=>Array.from({length:14},(_,i)=>row('cube',sign*(i+1),4)))]);
for(const build of [buildRaceCar,buildTank])cases.push({name:build.name,data:build(new Blueprint()).toJSON()});
for(const [type,d] of Object.entries(PARTS)){
 add('part '+type,[row('core',-12),row(type)]);
 if(d.leg||d.hover||type.startsWith('hover'))for(let rot=0;rot<24;rot++)add(type+' rotation '+rot,[row('core',-12),row(type,0,4,0,rot)]);
}
for(const type of ['leg3','leg4','leg5'])for(const spacing of [1,2,3])add('crowd '+type+'/'+spacing,[row('core',-12),row(type),row(type,0,4,spacing)]);
let seed=1327;const random=()=>((seed=seed*48271%2147483647)/2147483647);
const types=Object.keys(PARTS);
for(let i=0;i<65;i++){
 const rows=[row('core')];
 for(let k=0;k<10+i*3;k++)rows.push(row(types[Math.floor(random()*types.length)],Math.floor(random()*9)-4,Math.floor(random()*10),Math.floor(random()*9)-4,Math.floor(random()*24)));
 add('mixed '+i,rows);
}
for(const c of cases){
 const bp=new Blueprint().load(c.data);
 c.loaded=bp.toJSON();c.dropped=bp.dropped;c.warnings=bp.migrationWarnings;
 c.diagnostics=TIERS.map(t=>{
  const d=bp.diagnose(t);
  return {list:d.list.map(w=>({...w,ids:sort(w.ids)})),outside:sort(d.outside),stats:d.stats,
   reached:sort(d.conn.reached),floating:sort(d.conn.floating),coreId:d.conn.coreId};
 });
}
const overlaps=[];
for(const type of ['leg3','leg4','leg5'])for(let rot=0;rot<24;rot++){
 const pos=[0,6,0],stance=legStanceCells(type,pos,rot);
 const min=[0,1,2].map(k=>Math.min(...stance.map(c=>c[k]))-1),max=[0,1,2].map(k=>Math.max(...stance.map(c=>c[k]))+1);
 const samples=[...stance];
 for(let i=0;i<30;i++)samples.push(min.map((v,k)=>v+Math.floor(random()*(max[k]-v+1))));
 const bp=new Blueprint();bp.add({type,pos,rot});
 for(const p of samples){
  const reverse=new Blueprint();reverse.add({type:'cube',pos:p,rot:IDENTITY});
  overlaps.push({type,rot,pos:p,forward:bp.overlaps('cube',p,IDENTITY),reverse:reverse.overlaps(type,pos,rot),ignored:bp.overlaps('cube',p,IDENTITY,partCells('cube',p,IDENTITY),new Set([1]))});
 }
}
export const rules={cases,overlaps};
console.log(JSON.stringify({blueprintCases:cases.length,diagnostics:cases.length*TIERS.length,stanceOverlaps:overlaps.length}));

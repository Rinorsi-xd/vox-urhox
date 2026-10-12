// Execute the current H5 rules, never repair native assets from acceptance code.
import fs from 'node:fs';
import {Blueprint,partCells,partClearance} from 'file:///D:/Rino_Project/Vox/shared/build/blueprint.js';
import {buildRaceCar} from 'file:///D:/Rino_Project/Vox/shared/build/prefab.js';
import {PART_LIST} from 'file:///D:/Rino_Project/Vox/shared/parts/defs.js';
import {applyRot,IDENTITY} from 'file:///D:/Rino_Project/Vox/shared/core/rotations.js';
import {buildBounds} from 'file:///D:/Rino_Project/Vox/shared/config.js';
const bp=buildRaceCar(new Blueprint());
// The normal application raises the vehicle to four cells above the build floor.
const lift=4-Math.min(...[...bp.parts.values()].flatMap(p=>p._cells.map(c=>c[1])));
const raised=bp.toJSON();for(const row of raised.parts)row[2]+=lift;bp.load(raised);
const initial=bp.toJSON(),placements=[];
const panels=PART_LIST.filter(d=>d.panel&&!['panel','panelArc'].includes(d.shape));
for(const d of panels){
 let placed=false;
 // Try actual socket-to-socket attachment, above the original wheeled vehicle.
 const cells=[...bp.parts.values()].flatMap(p=>p._cells).sort((a,b)=>b[1]-a[1]||Math.hypot(a[0],a[2])-Math.hypot(b[0],b[2]));
 outer:for(const rotation of [IDENTITY,...Array.from({length:24},(_,i)=>i).filter(i=>i!==IDENTITY)])for(const socket of d.sockets)for(const cell of cells){
  const c=applyRot(rotation,socket.c),n=applyRot(rotation,socket.d),pos=cell.map((v,k)=>v-c[k]-n[k]);
  if(pos[1]<5)continue;
  const res=bp.check(d.id,pos,rotation,buildBounds());
  if(!res.ok)continue;
  const part=bp.add({type:d.id,pos,rot:rotation});placements.push({type:d.id,pos,rot:rotation,id:part.id,res});placed=true;break outer;
 }
 if(!placed)throw Error('No connected placement: '+d.id);
}
if(placements.length!==24||bp.connectivity().floating.size)throw Error('Panel fixture is incomplete/disconnected');
const clearance=[];
for(const d of PART_LIST.filter(p=>p.clear))for(let rot=0;rot<24;rot++){
 const pos=[0,8,0],cells=partClearance(d.id,pos,rot);if(!cells.length)continue;
 const at=cells[Math.floor(cells.length/2)],a=new Blueprint(),b=new Blueprint();
 a.add({type:d.id,pos,rot});b.add({type:'cube',pos:at,rot:IDENTITY});
 clearance.push({type:d.id,pos,rot,at,
  forward:a.check('cube',at,IDENTITY,null,null,false),
  reverse:b.check(d.id,pos,rot,null,null,false),
  ignored:a.check('cube',at,IDENTITY,null,new Set([1]),false),
  same:a.turretConflict(d.id,pos,rot,partCells(d.id,pos,rot)),
 });
}
const out=new URL('./source-panel-fixtures.json',import.meta.url);
fs.writeFileSync(out,JSON.stringify({initial,placements,final:bp.toJSON(),clearance}));
console.log(JSON.stringify({panels:placements.length,clearanceCases:clearance.length,vehicleParts:bp.size}));

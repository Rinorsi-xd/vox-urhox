import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {pathToFileURL} from 'node:url';
const base='.tmp/outgame-source-2026-10-14T10-09-50-505Z',file=path.resolve(base,'shared/combat/aimAssist.js');const {assistAim}=await import(pathToFileURL(file));const cases=[];
for(const speed of [0,12,90])for(const offset of [0,1,4,12])for(const wide of [1,1.8,2.2,3.96])for(const mode of ['normal','direct','wall','friend','dead','outside','sniper']){
 const origin=[0,2,0],dir=[0,0,1],pos=[0,1,0];const self={pos,team:'blue',vehicle:{body:{}}};const units=[self];
 for(let i=0;i<2;i++){const p=[offset+i*1.2,1,mode==='outside'?310:50+i*5],parts=new Map([[1,{id:1,_cells:[[0,0,0],[0,1,0]]}],[2,{id:2,_cells:[[2,1,0],[-1,1,0]]}],[3,{id:3,_cells:[[0,2,1]]}]]);const angle=i*.3,q={x:0,y:Math.sin(angle/2),z:0,w:Math.cos(angle/2)};
 units.push({id:i,pos:p,alive:mode!=='dead',team:mode==='friend'?'blue':'red',bp:{parts},vehicle:{spec:{bounds:{min:[-2,-1,-3],max:[2,3,3]}},body:{translation:()=>({x:p[0],y:p[1],z:p[2]}),rotation:()=>q,linvel:()=>({x:speed,y:0,z:0})}}});}
 const stats=mode==='sniper'?{range:600}:{range:200,assist:{angle:.06*wide,slow:.45}};
 const hit=mode==='direct'?{point:[offset,1,50],dist:50,owner:{ref:units[1]}}:mode==='wall'?{point:[0,2,20],dist:20,owner:{}}:null;
 const castRay=(p,d,l)=>({point:p.map((x,k)=>x+d[k]*(l-1)),owner:{ref:units[1]}});
 const out=assistAim({origin,dir,hit,self,units,castRay,stats});
 cases.push({speed,offset,wide,mode,origin,dir,hit:hit?{point:hit.point,dist:hit.dist,ref:hit.owner.ref?.id??null}:null,units:units.slice(1).map(u=>({id:u.id,pos:u.pos,alive:u.alive,team:u.team,q:u.vehicle.body.rotation(),parts:[...u.bp.parts.values()]})),stats:mode==='sniper'?{range:600}:{range:200,assist:{angle:.06,slow:.45}},out:out?{point:out.point,ref:out.ref.id,partId:out.partId,slow:out.slow}:null});
}
const data={source:{path:'shared/combat/aimAssist.js',sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')},cases};fs.writeFileSync('tools/migration/source-aim-fixtures.json',JSON.stringify(data));console.log(JSON.stringify({cases:cases.length,source:data.source}));

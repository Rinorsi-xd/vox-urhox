import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const source='D:/Rino_Project/Vox';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const load=p=>import(pathToFileURL(path.join(source,p)));
const {CarUnit}=await load('shared/combat/carUnit.js');
const {Blueprint}=await load('shared/build/blueprint.js');
const {PARTS}=await load('shared/parts/defs.js');
const {rotIndex}=await load('shared/core/rotations.js');
const rot=rotIndex([0,1,0],[0,0,1]);
const identity={x:0,y:0,z:0,w:1};
const cases=[];
function run(name,parts,actions){
 const bp=new Blueprint();for(const [type,pos] of parts)bp.add({type,pos,rot,color:0xd0182a});
 const json=bp.toJSON(),env={time:0,fx:[],viewEvents:[],damage:0,kills:0,rebuilds:0,pieces:[],
  recordDamage(u,a){this.damage+=a;},recordKill(){this.kills++;}};
 env.debris={spawn(parts,pose,velocity,kick){env.pieces.push({ids:parts.map(p=>p.id).sort((a,b)=>a-b),kick});}};
 const u=Object.create(CarUnit.prototype);
 Object.assign(u,{env,source:json,name,spawnAt:{pos:[10,2,-4],yaw:0},vehicle:null});
 u._build=function(spec){
  env.rebuilds++;this.spec=spec;
  let state={p:{x:10,y:2,z:-4},q:identity,lv:{x:1,y:2,z:3},av:{x:0,y:0,z:0},steer:0};
  this.vehicle={colliders:[],body:{translation:()=>state.p,rotation:()=>state.q,worldCom:()=>state.p,velocityAtPoint:()=>state.lv},
   place(){},dispose(){},step(){},getState:()=>state,setState(s){state=s;}};
 };
 const old=Math.random;Math.random=()=>.5;
 const samples=[];
 const snapshot=()=>({ids:[...u.bp.parts.keys()].sort((a,b)=>a-b),hp:Object.fromEntries(u.hp),budget:u.budget,integrity:u.integrity,
  alive:u.alive,kill:u.kill??false,damage:env.damage,kills:env.kills,rebuilds:env.rebuilds,
  pieces:structuredClone(env.pieces),events:env.viewEvents.map(e=>({type:e.type,id:e.id??false})),
  fx:env.fx.map(e=>({type:e.type,pos:e.pos,color:e.color,cells:e.cells,dir:e.dir}))});
 try{
  u.spawn();samples.push(snapshot());
  for(const a of actions){
   if(a.kind==='hit')u.hitRay({point:a.point,owner:{partId:a.id??null}},a.damage,a.dir,a.pierce??0);
   else if(a.kind==='damage')u._damage(a.id,a.amount,a.point??[10,2,-4]);
   else if(a.kind==='explode')u.explode(a.point,a.radius,a.damage);
   else if(a.kind==='flush')u.flush();
   else if(a.kind==='step'){env.time+=a.dt;u.step(a.dt);}
   samples.push(snapshot());
  }
 }finally{Math.random=old;}
 cases.push({name,source:json,actions,samples});
}
const line=Array.from({length:7},(_,i)=>[i===0?'core':'cube',[i,0,0]]);
run('bridge-detach',line,[{kind:'damage',id:3,amount:10000},{kind:'flush'}]);
run('core-wreck-respawn',line,[{kind:'damage',id:1,amount:10000},{kind:'flush'},{kind:'step',dt:4.99},{kind:'step',dt:.02}]);
run('budget-wreck',line,[...Array.from({length:6},(_,i)=>({kind:'damage',id:i+2,amount:10000})),{kind:'flush'}]);
run('penetration',line,[{kind:'hit',point:[13.24,2.25,-4],dir:[-1,0,0],damage:40,pierce:.3},{kind:'flush'}]);
run('hole-followup',line,[{kind:'hit',point:[13.24,2.25,-4],dir:[-1,0,0],damage:10000},{kind:'hit',point:[13.24,2.25,-4],dir:[-1,0,0],damage:20},{kind:'flush'}]);
run('splash-exposed-only',line,[{kind:'explode',point:[13.7,2.25,-4],radius:4,damage:60},{kind:'flush'}]);
run('damage-clamp',line,[{kind:'damage',id:2,amount:-4},{kind:'damage',id:2,amount:10000},{kind:'damage',id:2,amount:10000},{kind:'flush'}]);
const maskSamples=[];
for(const type of ['cube','slope','corner','glassSlope'].filter(t=>PARTS[t]))for(let r=0;r<24;r++){
 const bp=new Blueprint();bp.add({type,pos:[1,2,-1],rot:r});
 const unit=Object.create(CarUnit.prototype);unit.bp=bp;
 const samples=[];
 for(const p of bp.parts.values())for(const cell of p._cells)for(let x=0;x<4;x++)for(let y=0;y<4;y++)for(let z=0;z<4;z++){
  const pos=[(cell[0]-.5+(x+.5)/4)*.5,(cell[1]+(y+.5)/4)*.5,(cell[2]-.5+(z+.5)/4)*.5];
  samples.push({pos,id:unit._partAt(pos)??false});
 }
 maskSamples.push({source:bp.toJSON(),samples});
}
const files=['shared/combat/carUnit.js','shared/combat/debris.js'];
const provenance=Object.fromEntries(files.map(p=>[p,createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex')]));
// Query actual source Rapier colliders, including non-contact wheel/track sensors.
const R=await load('shared/vendor/rapier/rapier.mjs');await R.init();
const {Vehicle}=await load('shared/drive/vehicle.js');
const {buildVehicleSpec}=await load('shared/drive/vehicleSpec.js');
const {buildRaceCar,buildTank}=await load('shared/build/prefab.js');
const rayCases=[];let seed=91823;
const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
const rotate=(q,v)=>{
 const t=[2*(q.y*v[2]-q.z*v[1]),2*(q.z*v[0]-q.x*v[2]),2*(q.x*v[1]-q.y*v[0])];
 return [v[0]+q.w*t[0]+q.y*t[2]-q.z*t[1],v[1]+q.w*t[1]+q.z*t[0]-q.x*t[2],v[2]+q.w*t[2]+q.x*t[1]-q.y*t[0]];
};
for(const build of [buildRaceCar,buildTank])for(const yaw of [0,.72,-1.4]){
 const bp=build(new Blueprint()),spec=buildVehicleSpec(bp),world=new R.World({x:0,y:0,z:0});
 const vehicle=new Vehicle(R,world,spec),q={x:0,y:Math.sin(yaw/2),z:0,w:Math.cos(yaw/2)},pos=[5,3,-7];
 vehicle.body.setTranslation({x:pos[0],y:pos[1],z:pos[2]},true);vehicle.body.setRotation(q,true);world.step();
 const samples=[];
 for(let i=0;i<180;i++){
  const axis=i%3,sign=i%2===0?1:-1,local=spec.bounds.min.map((v,k)=>v+(spec.bounds.max[k]-v)*random());
  local[axis]=(sign>0?spec.bounds.min[axis]-3:spec.bounds.max[axis]+3);
  const dirLocal=[0,0,0];dirLocal[axis]=sign;
  const origin=rotate(q,local).map((v,k)=>v+pos[k]),dir=rotate(q,dirLocal),length=30;
  const ray=new R.Ray({x:origin[0],y:origin[1],z:origin[2]},{x:dir[0],y:dir[1],z:dir[2]});
  const h=world.castRayAndGetNormal(ray,length,true);
  let hit=false;
  if(h){
   const allowed=[];
   for(const c of vehicle.colliders){
    const ch=world.getCollider(c.handle).castRayAndGetNormal(ray,length,true);
    if(ch&&Math.abs(ch.timeOfImpact-h.timeOfImpact)<.0001)allowed.push(c.partId??false);
   }
   hit={dist:h.timeOfImpact,allowed};
  }
  samples.push({origin,dir,length,hit});
 }
 rayCases.push({source:bp.toJSON(),pos,q,samples});vehicle.dispose();world.free();
}
fs.writeFileSync(path.join(root,'tools/migration/source-damage-fixtures.json'),JSON.stringify({provenance,cases,maskSamples,rayCases}));
console.log(`Damage: ${cases.length} replays, ${maskSamples.length} mask sets, ${rayCases.reduce((n,c)=>n+c.samples.length,0)} source Rapier rays`);

import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=process.cwd(),baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const source=baseline.snapshot;
for(const p of ['shared/combat/drill.js','shared/combat/weapons.js','shared/parts/drillData.js']){
 if(createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex')!==baseline.files[p].sha256)throw Error(`Source changed: ${p}`);
}
const load=p=>import(pathToFileURL(path.join(source,p)));
const {DRILL_GLB}=await load('shared/parts/drillData.js'),{CELL}=await load('shared/config.js');
const {WeaponSystem}=await load('shared/combat/weapons.js');
const cutters={};
for(const [type,g] of Object.entries(DRILL_GLB)){
 const layers=new Map();for(const c of g.cells){if(c[2]<Math.floor(g.spin[2]))continue;
  const layer=layers.get(c[2])||{min:[...c],max:[...c]};for(let i=0;i<3;i++){layer.min[i]=Math.min(layer.min[i],c[i]);layer.max[i]=Math.max(layer.max[i],c[i]);}layers.set(c[2],layer);
 }
 cutters[type]=[...layers.values()].map(({min,max})=>({offset:min.map((v,i)=>((v+max[i])/2-g.muzzle[i])*CELL),half:min.map((v,i)=>(max[i]-v+1)*CELL/2)}));
}
const write=(p,v)=>fs.writeFileSync(p,JSON.stringify(v));
write('assets/Combat/Drills.json',{baseline:baseline.commit,cutters});
const q={x:0,y:0,z:0,w:1},z={x:0,y:0,z:0};
const mount=(type,i)=>({type,partId:i+1,muzzle:[i*.5,1,2],dir:[0,0,1],quat:q});
const cases=[];
for(const type of ['tianyuanDrill','fuyuanDrill']){
 for(const contact of ['miss','target','wall','debris','late','intermittent'])cases.push({name:`${type}-${contact}`,type,contact,mass:contact==='intermittent'?8000:100,segments:[{frames:90,fire:true},{frames:240,fire:false}]});
 cases.push({name:`${type}-short-tap`,type,contact:'miss',segments:[{frames:3,fire:true},{frames:100,fire:false}]},
  {name:`${type}-low-energy`,type,contact:'target',energy:2,segments:[{frames:180,fire:true},{frames:180,fire:false}]},
  {name:`${type}-switch`,type,contact:'target',segments:[{frames:50,fire:true},{frames:80,fire:true,select:3},{frames:10,fire:false,select:1},{frames:90,fire:true},{frames:240,fire:false}]},
  {name:`${type}-cancel`,type,contact:'target',segments:[{frames:90,fire:true},{frames:10,fire:false},{frames:1,fire:false,live:false},{frames:60,fire:false}]},
  {name:`${type}-refit`,type,contact:'target',segments:[{frames:90,fire:true},{frames:10,fire:false},{frames:1,fire:false,refit:true},{frames:60,fire:false}]},
  {name:`${type}-shared-cooldown`,type,contact:'target',segments:[{frames:90,fire:true},{frames:110,fire:false},{frames:90,fire:true,select:2},{frames:240,fire:false}]});
}
cases.push({name:'tianyuan-hold-auto-release',type:'tianyuanDrill',contact:'target',energy:24,segments:[{frames:700,fire:true},{frames:100,fire:false}]});
const fields=['cool','charge','windup','spinAngle','drillPhase','shotAt'];
const out={baseline:baseline.commit,cases:[]};
for(const c of cases){
 const other=c.type==='tianyuanDrill'?'fuyuanDrill':'tianyuanDrill';
 const spec={weapons:[mount(c.type,0),mount(other,1),{...mount('laser1',2),pivot:[1,1,0],off:[0,0,2]}]};
 const ws=new WeaponSystem(spec);ws.energy=c.energy??100;
 let p={...z},lv={...z},av={...z},rot={...q},kinematic=false,ccd=false,valid=true;
 const body={translation:()=>p,rotation:()=>rot,linvel:()=>lv,angvel:()=>av,mass:()=>c.mass||100,isValid:()=>valid,bodyType:()=>kinematic,isCcdEnabled:()=>ccd,
  setTranslation:v=>p={...v},setRotation:v=>rot={...v},setLinvel:v=>lv={...v},setAngvel:v=>av={...v},setBodyType:v=>kinematic=v,
  enableCcd:v=>ccd=v,setNextKinematicTranslation:v=>p={...v},setNextKinematicRotation:v=>rot={...v},resetForces:()=>{},resetTorques:()=>{},
  applyImpulse:v=>{for(const k of ['x','y','z'])lv[k]+=v[k]/body.mass();},applyImpulseAtPoint:()=>{}};
 const hits=[],target={},col={translation:()=>({x:0,y:1,z:6})};let count=0,frame=0;
 const env={R:{RigidBodyType:{KinematicPositionBased:true}},stats:{shots:0},castRay:()=>null,
  hit:(h,damage,dir,impulse,pierce)=>hits.push({damage,point:h.point,dir,impulse,pierce}),
  sweepDrill:(tip,dir,dist,excluded,cs)=>{
   if(excluded!==body)throw Error('self exclusion lost');count++;
   if(c.contact==='miss'||c.contact==='late'&&count<73||c.contact==='intermittent'&&count%5<3)return null;
   return {dist:.12,point:tip.map((v,i)=>v+dir[i]*.12),normal:[0,0,-1],collider:col,owner:{type:c.contact==='wall'?'obstacle':c.contact==='debris'?'debris':'car',ref:target}};
  }};
 const samples=[];
 for(const seg of c.segments){if(seg.select)ws.select(seg.select-1);if(seg.refit)ws.rebuild(spec);
  for(let i=0;i<seg.frames;i++){
   hits.length=0;ws.step(1/60,{firing:seg.fire,live:seg.live,aim:[0,1,100],pos:[p.x,p.y,p.z],quat:rot,vel:[lv.x,lv.y,lv.z],body},env);
   if(!kinematic)for(const k of ['x','y','z'])p[k]+=lv[k]/60;
   frame++;if(frame%5&& !ws.fx.length)continue;
   const a=ws.drill.active;
   samples.push(structuredClone({frame,energy:ws.energy,offline:ws.offline,sinceUse:ws.sinceUse,current:ws.current+1,shots:env.stats.shots,p,lv,av,q:rot,kinematic,ccd,
    active:a?{phase:a.phase,charge:a.charge,elapsed:a.elapsed,cutTime:a.cutTime,cuts:a.cuts,speed:a.speed,engaged:a.engaged,grinding:a.grinding}:null,
    held:ws.drill.held?.id??null,hint:ws.drill.hint,readiness:ws.groups.map(g=>ws.readiness(g)),weapons:ws.groups.flatMap(g=>g.weapons.map(w=>Object.fromEntries(fields.filter(k=>w[k]!==undefined).map(k=>[k,w[k]])))),hits,fx:ws.fx.map(e=>e.barrel===undefined?e:{...e,barrel:e.barrel+1})}));
  }
 }
 out.cases.push({...c,spec,samples});
}
write('tools/migration/source-drill-fixtures.json',out);
console.log(JSON.stringify({cases:out.cases.length,samples:out.cases.reduce((n,c)=>n+c.samples.length,0),cutters:Object.fromEntries(Object.entries(cutters).map(([k,v])=>[k,v.length]))}));

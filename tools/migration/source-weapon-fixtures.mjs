import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const source=path.resolve(process.argv[2]||baseline.snapshot);
const load=p=>import(pathToFileURL(path.join(source,p)));
const {PART_LIST}=await load('shared/parts/defs.js');
const {WeaponSystem,weaponStats,ENERGY,KINDS,FULL}=await load('shared/combat/weapons.js');
const {buildVehicleSpec}=await load('shared/drive/vehicleSpec.js');
const {Blueprint}=await load('shared/build/blueprint.js');
const prefabs=await load('shared/build/prefab.js');
for(const p of ['shared/combat/weapons.js','shared/combat/drill.js','shared/parts/drillData.js']){
 const hash=createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex');
 if(hash!==baseline.files[p]?.sha256)throw Error(`Frozen source hash mismatch: ${p}`);
}
const supported=p=>/^(mg|laser|sniper|missile)|Drill$/.test(p.id)&&weaponStats(p.id);
const stats=Object.fromEntries(PART_LIST.filter(supported).map(p=>[p.id,weaponStats(p.id)]));
function writeAtomic(relative,value){
 const output=path.join(root,relative);fs.mkdirSync(path.dirname(output),{recursive:true});
 fs.writeFileSync(output+'.tmp',JSON.stringify(value));fs.renameSync(output+'.tmp',output);
}
writeAtomic('assets/Combat/Weapons.json',{source:'shared/combat/weapons.js',baseline:baseline.commit,sha256:createHash('sha256').update(fs.readFileSync(path.join(source,'shared/combat/weapons.js'))).digest('hex'),energy:ENERGY,kinds:KINDS,full:FULL,stats});
const identity={x:0,y:0,z:0,w:1};
const mount=(type,i=0)=>({partId:i+1,type,muzzle:[i*.4,1,1],dir:[0,0,1],pivot:[i*.4,1,0],off:[0,0,1],quat:identity});
const state={firing:true,aim:[0,1,100],pos:[0,0,0],quat:identity,vel:[0,0,0]};
const cases=[];
for(const type of Object.keys(stats).filter(t=>!stats[t].homing&&!stats[t].drill)) cases.push({name:type,spec:{weapons:[mount(type)]},segments:[{frames:240,state},{frames:60,state:{...state,firing:false}}],plane:95});
const missileMount=(type,i=0)=>({...mount(type,i),offs:Array.from({length:stats[type].tubes},(_,j)=>[(j%2?1:-1)*.3,Math.floor(j/2)*.2,1])});
const missileState={...state,eye:[0,1,0],aim:[0,1,160]};
for(const type of Object.keys(stats).filter(t=>stats[t].homing)) for(const energy of [100,18]) cases.push({name:`${type}-energy-${energy}`,energy,spec:{weapons:[missileMount(type)]},targets:[{id:'enemy',pos:[0,1,160],alive:true}],segments:[{frames:1200,state:missileState}],plane:150});
cases.push(
 {name:'missile-moving-dead-target',spec:{weapons:[missileMount('missile5')]},targets:[{id:'enemy',pos:[0,1,160],alive:true}],segments:[{frames:230,state:missileState},{frames:110,state:missileState,velocity:[.6,0,0]},{frames:600,state:{...missileState,firing:false},targetAlive:false}],plane:null},
 {name:'missile-lock-boundaries',spec:{weapons:[missileMount('missile3'),mount('mg3',1)]},targets:[{id:'enemy',pos:[0,1,99.99],alive:true}],segments:[{frames:30,state:missileState},{frames:125,state:missileState,targetPos:[0,1,100]},{frames:20,state:{...missileState,firing:false,aim:[100,1,160]}},{frames:60,state:missileState,targetPos:[0,1,350]},{frames:60,state:missileState,targetPos:[0,1,350.01]},{frames:90,state:missileState,targetPos:[0,1,160],select:2},{frames:130,state:missileState,select:1}],plane:null},
 {name:'missile-switch-target-salvo',spec:{weapons:[missileMount('missile4'),missileMount('missile3',1),mount('laser3',2)]},targets:[{id:'enemy',pos:[0,1,160],alive:true}],segments:[{frames:80,state:missileState},{frames:100,state:missileState,replaceTarget:{id:'other',pos:[0,1,180],alive:true}},{frames:650,state:{...missileState,salvo:true},select:2}],plane:170}
);
cases.push(
 {name:'overfull-stagger',spec:{weapons:[mount('laser5'),mount('laser5',1),mount('laser4',2)]},segments:[{frames:240,state}],plane:130},
 {name:'offline-hold-recover',energy:0.01,spec:{weapons:[mount('mg5')]},segments:[{frames:600,state},{frames:120,state:{...state,firing:false}}],plane:40},
 {name:'sniper-offline',energy:5,spec:{weapons:[mount('sniper5')]},segments:[{frames:600,state}],plane:200},
 {name:'aim-limits',spec:{weapons:[mount('laser3')]},segments:[{frames:50,state:{...state,aim:[0,1,-50]}},{frames:50,state:{...state,aim:[5,100,1]}},{frames:180,state:{...state,aim:[20,15,60]}},{frames:50,state:{...state,aim:[0,-50,10]}}],plane:45},
 {name:'switch-groups',spec:{weapons:[mount('mg3'),mount('laser2',1),mount('sniper2',2)]},segments:[{frames:200,state,select:1},{frames:200,state,select:3},{frames:200,state,select:2},{frames:30,state:{...state,firing:false}},{frames:120,state}],plane:70},
 {name:'rotated-multibarrel',spec:{weapons:[{...mount('laser5'),quat:{x:0,y:Math.sin(.25),z:0,w:Math.cos(.25)},offs:[[-.4,0,1],[.4,0,1]]}]},segments:[{frames:220,state:{...state,pos:[2,4,-3],quat:{x:Math.sin(.1),y:0,z:0,w:Math.cos(.1)},aim:[40,8,80]}}],plane:75},
 {name:'fixed-muzzle-miss',spec:{weapons:[{partId:1,type:'mg4',muzzle:[0,1,1],dir:[0,0,1]}]},segments:[{frames:180,state}],plane:null},
 {name:'empty-loadout',spec:{weapons:[]},segments:[{frames:60,state}],plane:40}
);
const fields=['id','cool','yaw','pitch','prevYaw','prevPitch','err','limited','spin','spinRate','spinAngle','charge','windup','barrel','shotAt','dryAt','rate','interval'];
const missileFields=['open','lock','lockIn','lockLost','mphase','readyAt','reloadT','reload','volley','volleyAt','fired','tubes','lofting','aimPitch'];
const projectileFields=['pos','vel','life','dist','bright','seed','age','path','end','aim','arrived','trail'];
const fixtures={baseline:baseline.commit,coverage:'mg/laser/sniper/missile simulation, lock, salvo, moving targets, damage and mount geometry; drill behavior has separate fixtures',weaponTypes:Object.keys(stats),cases:[],mounts:[],prefabs:{}};
const compact=o=>Object.fromEntries(Object.entries(o).filter(([,v])=>v!==null&&v!==undefined));
const mountGeometry=w=>{const {range,...geometry}=w;return geometry;};
for(const type of Object.keys(stats)) for(let rot=0;rot<24;rot++){
 const p={id:1,type,pos:[2,3,-4],rot,_cells:[[2,3,-4]]};
 const bp=new Blueprint();bp.add(p);bp.connectivity=()=>({coreId:1,reached:new Set([1])});
 const spec=buildVehicleSpec(bp);
 fixtures.mounts.push({part:p,expected:mountGeometry(spec.weapons[0])});
}
for(const name of ['buildRaceCar','buildTank'])fixtures.prefabs[name]=buildVehicleSpec(prefabs[name](new Blueprint())).weapons.map(mountGeometry);
const originalRandom=Math.random;
try{for(const c of cases){
 let seed=12345;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 const ws=new WeaponSystem(c.spec);if(c.energy!==undefined)ws.energy=c.energy;
 const hits=[],impulses=[],blasts=[];let targets=structuredClone(c.targets||[]);const body={applyImpulseAtPoint:(impulse,point,wake)=>impulses.push({impulse,point,wake})};
 const env={stats:{shots:0},castRay:(origin,dir,length,excluded)=>{
   if(excluded!==body)throw Error('body exclusion lost');
   if(c.plane===null||Math.abs(dir[2])<1e-12)return null;
   const dist=(c.plane-origin[2])/dir[2];if(dist<0||dist>length)return null;
   return {dist,point:origin.map((v,i)=>v+dir[i]*dist),normal:[0,0,-1],owner:{type:'target'}};
 },hit:(hit,damage,dir,impulse,pierce)=>hits.push({damage,dir,impulse,pierce,dist:hit.dist}),lockables:()=>targets.filter(t=>t.alive!==false),explode:(point,radius,damage,excluded)=>{if(excluded!==body)throw Error('blast body exclusion lost');blasts.push({point,radius,damage});}};
 const samples=[];let frame=0;
 for(const segment of c.segments){
   if(segment.select)ws.select(segment.select-1);
   if(segment.targetPos)targets[0].pos=[...segment.targetPos];
   if(segment.targetAlive!==undefined)targets[0].alive=segment.targetAlive;
   if(segment.replaceTarget)targets=[structuredClone(segment.replaceTarget)];
   for(let n=0;n<segment.frames;n++){
     if(segment.velocity)targets[0].pos=targets[0].pos.map((v,i)=>v+segment.velocity[i]/60);
     hits.length=impulses.length=blasts.length=0;ws.step(1/60,{...segment.state,body},env);frame++;
     if(frame%15!==0&&!ws.fx.length)continue;
     const weapons=ws.groups.flatMap(g=>g.weapons.map(w=>compact({...Object.fromEntries([...fields,...(w.stats.homing?missileFields:[])].map(k=>[k,k==='barrel'?w[k]+1:w[k]])),...(w.stats.homing?{lockTarget:w.lockRef?.id,volleyTarget:w.volleyTarget?.id,plan:ws.volleyPlan(w)}:{})})));
     const fx=ws.fx.map(e=>{const a={...e};if(a.barrel!==undefined)a.barrel++;if(a.normal===null)delete a.normal;return a;});
     samples.push(structuredClone({frame,shots:env.stats.shots,energy:ws.energy,offline:ws.offline,sinceUse:ws.sinceUse,blocked:ws.blocked,turning:ws.turning,current:ws.current+1,weapons,fx,hits,impulses,blasts,
       projectiles:ws.projectiles.map(p=>compact({...Object.fromEntries(projectileFields.map(k=>[k,p[k]])),target:p.target?.id})),readiness:ws.groups.map(g=>ws.readiness(g)),lockInfo:ws.lockInfo()?compact({...ws.lockInfo(),ref:ws.lockInfo().ref?.id}):undefined}));
   }
 }
 fixtures.cases.push({...c,samples});
}}finally{Math.random=originalRandom;}
writeAtomic('tools/migration/source-weapon-fixtures.json',fixtures);
console.log(JSON.stringify({types:fixtures.weaponTypes.length,cases:fixtures.cases.length,samples:fixtures.cases.reduce((s,c)=>s+c.samples.length,0)}));

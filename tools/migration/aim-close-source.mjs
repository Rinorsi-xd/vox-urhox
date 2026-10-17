import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL, fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const load=p=>import(pathToFileURL(path.join(baseline.snapshot,p)));
for(const name of ['shared/combat/weapons.js','shared/combat/aimAssist.js']) {
  const hash=createHash('sha256').update(fs.readFileSync(path.join(baseline.snapshot,name))).digest('hex');
  if(hash!==baseline.files[name].sha256)throw Error(`Frozen source mismatch: ${name}`);
}
const {WeaponSystem}=await load('shared/combat/weapons.js');
const {Blueprint}=await load('shared/build/blueprint.js');
const {buildVehicleSpec}=await load('shared/drive/vehicleSpec.js');
const {ROTATIONS}=await load('shared/core/rotations.js');
const {assistAim}=await load('shared/combat/aimAssist.js');
const upright=ROTATIONS.findIndex(r=>r.m.every((v,i)=>v===(i%4===0?1:0)));
if(upright<0)throw Error('Identity mounting rotation not found');
const q={x:0,y:0,z:0,w:1};
const cases=[];
for(const type of ['mg3','laser3','sniper3'])for(const height of [0,3,8])for(const distance of [.5,1,2,3,5,10,20]) {
  const bp=new Blueprint();
  bp.add({id:1,type,pos:[0,height,0],rot:upright,_cells:[[0,height,0]]});
  bp.connectivity=()=>({coreId:1,reached:new Set([1])});
  const {range,...mount}=buildVehicleSpec(bp).weapons[0];
  const spec={weapons:[mount]};
  const ws=new WeaponSystem(spec);const w=ws.groups[0].weapons[0];
  const state={pos:[0,0,0],quat:q,aim:[0,.25,distance]};
  ws._aim(w,1,state);
  const m=ws.muzzle(w,state);
  const norm=a=>{const l=Math.hypot(...a);return a.map(v=>v/l);};
  const dir=norm(state.aim.map((v,i)=>v-m.pos[i]));
  cases.push({name:`${type}-height${height}-foot${distance}`,spec,state,
    expected:{yaw:w.yaw,pitch:w.pitch,aimPitch:w.aimPitch,limited:w.limited,aligned:ws.aligned(w),muzzle:m.pos,barrel:m.dir,shotDir:dir,
      backwards:dir.reduce((v,x,i)=>v+x*m.dir[i],0)<0}});
}
const scope=[];
const random=Math.random;
try {
  for(const type of ['mg3','mg4','mg5'])for(const aimed of [false,true])for(const bloom of [0,.5,1])for(const seed0 of [1,12345,987654321]) {
    let seed=seed0;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
    const spec={weapons:[{partId:1,type,pivot:[0,1,0],muzzle:[0,1,1],off:[0,0,1],dir:[0,0,1],quat:q}]};
    const ws=new WeaponSystem(spec);const w=ws.groups[0].weapons[0];
    ws.aimed=aimed;w.bloom=bloom;w.spin=1;w.spinRate=w.rate;
    const state={pos:[0,0,0],quat:q,aim:[0,1,100]};
    ws._aim(w,1,state);
    const shots=[];
    for(let n=0;n<12;n++){ws.energy=100;ws._fire(w,state,{stats:{shots:0}});shots.push({bloom:w.bloom,vel:ws.projectiles.at(-1).vel});}
    scope.push({type,aimed,bloom,seed:seed0,spec,state,expected:shots});
  }
}finally {Math.random=random;}
const assist=[];
for(const z of [.5,1,2,5,20])for(const blocked of [false,true])for(const direct of [false,true]) {
  const origin=[0,2,-2],delta=[0,-1.75,z+2],length=Math.hypot(...delta),dir=delta.map(x=>x/length);
  const enemy={id:'enemy',team:'red',alive:true,pos:[0,0,z],vehicle:{body:{translation:()=>({x:0,y:0,z}),rotation:()=>q,linvel:()=>({x:0,y:0,z:0})}},
    bp:{parts:new Map([[7,{id:7,_cells:[[0,0,0]]}]])}};
  const self={id:'player',team:'blue',alive:true,pos:[0,0,0],vehicle:{body:{}}};
  const hit=direct?{dist:length,point:[0,.25,z],owner:{ref:enemy}}:null;
  const castRay=()=>blocked?{dist:1,point:[0,1,-1],owner:{type:'ground'}}:{dist:length,point:[0,.25,z],owner:{ref:enemy}};
  const stats={assist:{angle:.1,slow:.6},range:200};
  const result=assistAim({origin,dir,hit,self,units:[self,enemy],castRay,stats});
  assist.push({z,blocked,direct,origin,dir,hit:hit&&{dist:hit.dist,point:hit.point},stats,
    expected:result?{point:result.point,ref:result.ref.id,partId:result.partId,slow:result.slow}:null});
}
const testDriveBytes=fs.readFileSync(path.join(baseline.snapshot,'three/src/drive/testDrive.js'));
if(createHash('sha256').update(testDriveBytes).digest('hex')!==baseline.files['three/src/drive/testDrive.js'].sha256)throw Error('Frozen TestDrive mismatch');
const testDrive=testDriveBytes.toString('utf8').replaceAll('\r\n','\n');
const markerStart=testDrive.indexOf('_aimMarker( w, h ) {')+'_aimMarker( w, h ) {'.length;
const markerEnd=testDrive.lastIndexOf('\n\t}\n\n}');
if(markerStart<22||markerEnd<markerStart)throw Error('Aim marker extraction failed');
const markerFn=new Function('_v','return function(w,h){'+testDrive.slice(markerStart,markerEnd)+'}')( {z:0,set(){return this;},project(){this.x=this.y=0;return this;}} );
const markers=[];
for(const soft of [false,true])for(const sameTarget of [false,true])for(const status of ['aligned','limited','turning']) {
 const ref={id:'enemy'},other={id:'wall'};
 const hit={dist:5,owner:{ref:sameTarget?ref:other}};
 const wpn={pointing:{limited:status==='limited'},muzzle:()=>({pos:[0,0,0],dir:[0,0,1]}),aligned:()=>status==='aligned'};
 const session={weapons:wpn,vehicle:{body:{}},visual:{root:{position:{toArray:()=>[0,0,0]},quaternion:q}},aim:[0,0,20],aimRef:ref,
   sim:{castRay:()=>hit},hud:{setAimMarker(){}},camera:{}};
 const expected=markerFn.call(session,1920,1080);
 markers.push({soft,sameTarget,status,expected});
}
const pullStart=testDrive.indexOf('const c = this.camera.position, a = this.assist.point');
const pullEnd=testDrive.indexOf('\n\t\t}',pullStart);
const pullFn=new Function('dt',testDrive.slice(pullStart,pullEnd));
const look=[];
for(const camera of [[3,5,-6],[-8,2,12]])for(const point of [[8,.25,3],[-10,4,-12],[0,2,10]])for(const yaw of [0,3.13,-3.13]) {
 const pitch=.2,dt=1/60;
 const s={camera:{position:{x:camera[0],y:camera[1],z:camera[2]}},assist:{point},cam:{yaw,pitch}};
 pullFn.call(s,dt);
 look.push({camera,point,yaw,pitch,dt,expected:s.cam});
}
process.stdout.write(JSON.stringify({baseline:baseline.commit,upright,cases,scope,assist,markers,look}));

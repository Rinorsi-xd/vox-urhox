import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),hashes={};
function read(name){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,name)),hash=createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[name]?.sha256)throw Error('Frozen source drift '+name);
 hashes[name]=hash;return bytes.toString('utf8');
}
const text=read('three/src/drive/testDrive.js');
read('shared/combat/carUnit.js');read('shared/drive/trackSim.js');read('shared/parts/defs.js');
const THREE=await import(pathToFileURL(path.join(baseline.snapshot,'three/vendor/three/build/three.module.js')));
const {CarUnit}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/combat/carUnit.js')));
const {PARTS}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/parts/defs.js')));
const start=text.indexOf('\n\t_viewAngle( p ) {'),end=text.indexOf('\n\t}',start)+4;
if(start<0||end<4)throw Error('Actual _viewAngle missing');
const angle=Function('_v','return '+text.slice(start,end).trim().replace('_viewAngle( p )','function( p )'))(new THREE.Vector3());
const branchStart=text.indexOf('\t\t\t\tif ( e.target === this.player ) {',text.indexOf('\n\t_hud( dt, cmd ) {'));
const branchEnd=text.indexOf('\n\t\t\t\tif ( e.killed ) this.fx.consume',branchStart);
if(branchStart<0||branchEnd<0)throw Error('Actual player damage branch missing');
const consume=Function('sim','for (const e of sim.events) {\n'+text.slice(branchStart,branchEnd)+'\n}');
const scenarios=[];
const eventSets=[
 [{time:1,amount:1},{time:1.05,amount:80},{time:1.099999,amount:300},{time:1.1,amount:8},{time:1.2,amount:100}],
 [{time:1,amount:0},{time:1.02,amount:0},{time:1.2,amount:1500},{time:1.21,amount:0,killed:true}],
 [{time:0,amount:20},{time:.099,amount:40},{time:.1,amount:120},{time:.15,amount:30},{time:.2,amount:40}],
 [{time:2,amount:100,source:false},{time:2.01,amount:5,point:false},{time:2.2,amount:5,other:true},{time:2.3,amount:0,killed:true}]
];
let index=0;
for(const hp of [null,0,.5,900,30000])for(const yaw of [0,.7,-2.2])for(const pitch of [0,.8,-1.2])for(const roll of [0,.65])for(const set of eventSets){
 const camera=new THREE.PerspectiveCamera();camera.position.set(7,12,-9);camera.rotation.set(pitch,yaw,roll,'YXZ');
 const forward=camera.getWorldDirection(new THREE.Vector3()).toArray();
 const right=new THREE.Vector3(1,0,0).applyQuaternion(camera.quaternion).toArray();
 const up=new THREE.Vector3(0,1,0).applyQuaternion(camera.quaternion).toArray();
 const state={camera,player:{},trauma:index%3*.22,_viewAngle:angle};if(hp!==null)state.player._origHp=hp;
 let hits=[],explosions=[];state.feedback={hit:(angle,strength)=>hits.push({angle,strength})};state.fx={consume:list=>explosions.push(...list)};
 const events=[];
 for(let eidx=0;eidx<set.length;eidx++){
  const config=set[eidx],point=[-8+eidx*9,[-50,0,40,100][eidx%4],22-eidx*11],origin=[22-eidx*8,70-eidx*31,-20+eidx*16];
  const event={target:config.other?{}:state.player,amount:config.amount,point:config.point===false?null:point,killed:!!config.killed,source:config.source===false?null:{pos:origin}};
  hits=[];explosions=[];consume.call(state,{events:[event],time:config.time});
  events.push({...config,point:event.point,source:event.source?.pos||null,expected:{trauma:state.trauma,hurtShakeAt:state._hurtShakeAt??null,hits,explosions:explosions.length}});
 }
 scenarios.push({name:'damage-'+index++,hp,initialTrauma:(index-1)%3*.22,camera:{position:camera.position.toArray(),forward,right,up},events});
}
const restores=[];
for(const alive of [false,true])for(const count of [0,1,3])for(const missing of [false,true])for(const connected of [false,true])for(const initial of [null,0,700]){
 const part={id:1,type:'cube',pos:[0,0,0],rot:0,_cells:[[0,0,0]]},parts=new Map(missing?[]:[[1,part]]);
 const s=Object.create(CarUnit.prototype);
 Object.assign(s,{alive,repairOrder:[1],originalParts:new Map([[1,part]]),hp:new Map(),hpMultiplier:2,partHpScale:.3,rawHpMax:PARTS.cube.hp*2,
  bodyHp:10,bodyHpMax:100,struct:0,structMax:30,env:{viewEvents:[],fx:[]},_fillShield(){},
  bp:{parts,graph(){return {}},connectivity(){return {reached:new Set(connected?[7]:[])}},add(p){parts.set(p.id,p);return p},remove(id){parts.delete(id)},neighbors(){return new Set(connected?[7]:[])}}});
 if(initial!==null)s._origHp=initial;
 const restored=s.restoreMissing(count);
 restores.push({alive,count,missing,connected,initial,rawHpMax:PARTS.cube.hp,partScale:.6,
  expected:{hp:s._origHp??null,restored:restored.length,parts:parts.size}});
}
const spawns=[];
for(const initial of [null,0,700]){
 const s=Object.create(CarUnit.prototype);Object.assign(s,{source:{parts:[]},hpMultiplier:1,env:{viewEvents:[]},_disposeVehicle(){}});
 if(initial!==null)s._origHp=initial;
 s.spawn();s.spawn();spawns.push({initial,expected:s._origHp??null});
}
const output={commit:baseline.commit,sourceHashes:hashes,scenarios,restores,spawns};
fs.writeFileSync(path.join(root,'.tmp/player-damage-source.json'),JSON.stringify(output,null,2)+'\n');
console.log(JSON.stringify({result:'PASS',scenarios:scenarios.length,events:scenarios.reduce((n,s)=>n+s.events.length,0),restores:restores.length}));

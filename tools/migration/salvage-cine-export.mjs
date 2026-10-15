import * as T from 'three';
import {SalvageCine} from '/three/src/salvage/salvageCine.js';
import {makeMaterials} from '/three/src/review/salvageTerrain/hsKit.js';
import {SalvageFx} from '/three/src/salvage/salvageFx.js';
function setup(){
 const run={drive:{scene3:new T.Scene(),player:{spec:{bounds:{min:[-1,0,-2],max:[1,2,2]}},pos:[0,0,0]},camera:new T.PerspectiveCamera(),vehicle:{}},W:{W:{M:makeMaterials()}},hud:{bars(){},caption(){},skip(){},flash(){}},fx:{_puff(){},_ring(){}},_yaw:()=>.7,_value:()=>1200};
 return {run,cine:new SalvageCine(run)};
}
function pose(n){return {position:n.position.toArray(),quaternion:n.quaternion.toArray(),scale:n.scale.toArray()};}
function shot(r){return {pos:r.pos.toArray(),tgt:r.tgt.toArray(),fov:r.fov,w:r.w};}
export async function build(){
 const {cine}=setup();cine.drop({pos:[0,0,0],yaw:Math.PI/2},'fixture');
 const c=cine.cur,nodes={ship:c.ship};
 c.ship.userData.fl.forEach((n,i)=>nodes['shipFlame'+(i+1)]=n);
 nodes.holder=c.holder;nodes.frame=c.frame;
 c.frame.userData.panels.forEach((n,i)=>{nodes['hinge'+(i+1)]=n;nodes['door'+(i+1)]=n.children[0];});
 c.fl.forEach((n,i)=>nodes['frameFlame'+(i+1)]=n);
 c.ship.position.set(0,0,0);c.ship.rotation.set(0,0,0);c.holder.position.set(0,0,0);c.holder.rotation.set(0,0,0);
 const motion=Object.entries(nodes).map(([id,n])=>{n.userData.migrationMotion=id;n.visible=true;return {id,parent:n.parent.userData.migrationMotion||null,...pose(n)};});
 const samples=[];const random=Math.random;Math.random=()=>.5;
 try{
  for(const yaw of [0,.7,Math.PI/2])for(const t of [0,1.5,3.4,4.6,5.6,6.6,7.2,7.3,8.4,9.6]){
   const {cine:x,run}=setup();x.drop({pos:[12,4,-31],yaw},'fixture');x._dropStep(x.cur,0);x.cur.t=t;const r=x._dropStep(x.cur,0);
   samples.push({name:'drop',yaw,t,...shot(r),ship:pose(x.ship),holder:pose(x.cur.holder),door:pose(x.cur.frame.userData.panels[0].children[0]),hold:run.holdCar?.pos||null,throttle:run.script?.command().throttle??null});
  }
  for(const name of ['extract','death','elite'])for(const t of [0,.3,.6,1.2,2.7,3.1,5.3,6.2]){
   const {cine:x,run}=setup();run.drive.player.pos=[2,3,4];
   if(name==='extract')x.extract([12,4,-31],'fixture',()=>{});
   else if(name==='death')x.death([12,4,-31]);else x.elite({pos:[50,8,70]});
   x.cur.t=t;const r=x['_'+name+'Step'](x.cur);
   samples.push({name,t,...shot(r),...(name==='extract'?{ship:pose(x.ship),hold:run.holdCar.pos}:{})});
  }
  for(const wait of [1,4,12])for(const t of [0,1.5,3,6]){
   const {cine:x}=setup();x.approach([12,4,-31],wait);x.ex.t=t;x._approachStep(0);
   samples.push({name:'approach',wait,t,ship:pose(x.ship),dust:!!x.ex.dust});
  }
 }finally{Math.random=random;}
 let seed=711;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 let smokeTextures;try{const fx=new SalvageFx(new T.Scene());smokeTextures=fx.smoke.slice(0,2).map(q=>q.m.map.image.toDataURL('image/png'));}finally{Math.random=random;}
 return {group:cine.root,lights:[],motion,cineSamples:samples,smokeTextures};
}

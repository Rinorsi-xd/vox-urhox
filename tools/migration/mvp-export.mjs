import * as T from 'three';
import {MvpShow} from '/three/src/battle/mvpShow.js';
export async function build(){
 const show=Object.create(MvpShow.prototype);
 Object.assign(show,{S:1,carH:1.5,o:{name:' '},scene:new T.Scene(),pivot:new T.Group()});
 show._place([0,0,0]);show._stage();show._banner();
 show.spiral.name='MvpSpiral';show.flagMat.name='MvpBanner';
 const moving={stage:show.g,pod:show.pod,column:show.column,flag:show.flag};
 show.cannons.forEach((c,i)=>{moving['cannon'+i]=c.g;moving['tilt'+i]=c.tilt;});
 show.tassels.forEach((node,i)=>{moving['tassel'+i]=node;});
 for(const [id,n] of Object.entries(moving)){n.userData.migrationMotion=id;n.visible=true;}
 const motion=Object.entries(moving).map(([id,n])=>({id,parent:n.parent?.userData.migrationMotion||null,position:n.position.toArray(),quaternion:n.quaternion.toArray(),scale:n.scale.toArray()}));
 const mvpSamples=[];
 for(const S of [1.8,3.2,5])for(const h of [.6,2,12]){
  show.S=S;show.carH=h;show.podH=S*.9;
  for(const t of [0,.5,1,2.1,2.4,2.55,3.5,4.9,5.1,6.3,6.9,7.1,14,20]){
   const camera=new T.PerspectiveCamera();show.o.camera=camera;
   show._camera(t,show.podY(t),show.podY(5.1));
   mvpSamples.push({S,h,t,y:show.podY(t),rot:show.podRot(t),camera:camera.position.toArray(),look:camera.getWorldDirection(new T.Vector3()).toArray()});
  }
 }
 return {group:show.g,lights:[],motion,mvpSamples};
}

import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const name='three/src/drive/aimLines.js',file=path.join(baseline.snapshot,name);
const bytes=fs.readFileSync(file),sha256=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha256!==baseline.files[name].sha256)throw Error('Frozen aim lines drift');
const THREE=await import(pathToFileURL(path.join(baseline.snapshot,'three/vendor/three/build/three.module.js')));
const gradients=[],rects=[];
const context=vm.createContext({THREE,Math,innerWidth:1920,innerHeight:1080,
 document:{createElement:()=>({getContext:()=>({
  createRadialGradient:()=>{const stops=[];gradients.push(stops);return {addColorStop:(...a)=>stops.push(a)}},
  createLinearGradient:()=>{const stops=[];gradients.push(stops);return {addColorStop:(...a)=>stops.push(a)}},
  fillRect:(...a)=>rects.push(a)
 })})}});
vm.runInContext(bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+
 '\nglobalThis.AimLines=AimLines;glowTexture();',context);
const cases=[];
for(const enemy of [false,true])for(const k of [.5,.75,1])for(const wind of [0,.5,1])for(const time of [0,.123,9])for(const distance of [5,100,999]){
 const item={line:{},lmat:{color:new THREE.Color(),resolution:new THREE.Vector2()},lgeo:{attributes:{instanceStart:{data:{array:new Float32Array(6)}}}},
  dot:{position:new THREE.Vector3(),scale:new THREE.Vector3()},mat:{color:new THREE.Color()},
  glow:{position:new THREE.Vector3(),scale:new THREE.Vector3()},gmat:{color:new THREE.Color()}};
 const pos=[3,2,distance],camera=new THREE.Vector3(),hit={point:[3,2,distance+50]};
 context.AimLines.prototype._draw(item,pos,[0,0,1],hit,50,enemy,k,wind,camera,time);
 cases.push({pos,camera:[0,0,0],enemy,k,wind,time,expected:{color:item.lmat.color.toArray(),width:item.lmat.linewidth,
  opacity:item.lmat.opacity,glowSize:item.glow.scale.x,glowOpacity:item.gmat.opacity,dotRadius:item.dot.scale.x}});
}
console.log(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},source:{[name]:sha256},gradients,rects,cases}));

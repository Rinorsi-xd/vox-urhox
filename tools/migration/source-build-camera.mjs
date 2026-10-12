import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const baseline=JSON.parse(fs.readFileSync(new URL('../../docs/migration/outgame-baseline.json',import.meta.url)));
const {CameraRig}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/controls/cameraRig.js')));
const input={locked:true,controlling:true,touchMove:{x:0,y:0},keys:new Set(),buttons:new Set(),mouse:[0,0],consumeMouse(){return this.mouse;},down(k){return this.keys.has(k);}};
const rig=new CameraRig(input,{fov:48,onPose(){}});
rig.roomLimit={x:28.5,z0:-32.5,z1:34.5,y0:.3,y1:30};rig.setMode('fp');
const array=v=>[v.x,v.y,v.z];
const initial={pos:array(rig.fp.pos),forward:array(rig.forward),limit:rig.roomLimit};
const cases=[];
const patterns=[[],['KeyW'],['KeyW','KeyD','Space'],['KeyS','KeyA','ShiftLeft'],['KeyW','KeyZ'],['KeyW','KeyZ','ControlLeft'],['KeyE'],['KeyQ'],['ShiftLeft','KeyR'],['ShiftLeft','ControlLeft'],['KeyD','KeyZ']];
for(let i=0;i<330;i++){
  const keys=patterns[Math.floor(i/30)%patterns.length];input.keys=new Set(keys);input.buttons=new Set(i%7===0?[0]:[]);
  const dx=i%13===0?350:3,dy=i%53===0?1800:i%61===0?-1800:-2,dt=[1/60,1/30,.1][i%3];input.mouse=[dx,dy];
  rig.update(dt);
  cases.push({keys,button:input.buttons.has(0),dx,dy,dt,pos:array(rig.fp.pos),vel:array(rig.fp.vel),forward:array(rig.forward)});
}
fs.writeFileSync(new URL('./source-build-camera.json',import.meta.url),JSON.stringify({initial,cases}));
console.log(`Original H5 CameraRig: ${cases.length} movement/rotation/shortcut frames`);

import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const url=p=>pathToFileURL(path.join(baseline.snapshot,p)).href;
const entry=url('three/src/battle/storyView.js');
registerHooks({resolve(s,c,n){return n(s==='three'?url('three/vendor/three/build/three.module.js'):s,c);},load(u,c,n){
  const result=n(u,c);if(u!==entry)return result;
  return {...result,source:String(result.source).replace(/const glowSprite = .*?;(?=\r?\n)/,
    'const glowSprite=(color,size,opacity)=>{const s=new THREE.Sprite(new THREE.SpriteMaterial({color,opacity}));s.scale.setScalar(size);return s;};')+'\nexport {collectorModel,IntelCube};'};
}});
const THREE=await import(url('three/vendor/three/build/three.module.js'));
const {StoryView,collectorModel,IntelCube}=await import(entry);
const cases=[];const nativeRandom=Math.random;
for(const instant of [false,true]){
  const scene=new THREE.Scene(),time={value:0},collector=collectorModel(time);
  collector.userData.born=instant?-10:0;collector.userData.landed=instant;let seed=15,landings=0;
  const host={time,drive:{fx:{stomp(){landings++;}},stompV:0},beacon:{update(){}},intel:new Map(),collectors:[collector],alarm:{children:[]}};
  Math.random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/2**32);
  for(let frame=1;frame<=48;frame++){
    StoryView.prototype.update.call(host,1/24);const u=collector.userData;
    cases.push({instant,frame,t:time.value,body:u.body.position.y,flame:u.flame.visible,halo:u.halo.visible,
      scale:u.halo.scale.x,up:u.up.material.uniforms.uAlpha.value,lamp:u.lamp.material.color.toArray(),glow:u.glow.material.opacity,
      drill:u.drill.position.y,landings,stompV:host.drive.stompV});
  }
  Math.random=nativeRandom;
}
const script=fs.readFileSync(fileURLToPath(entry));
if(createHash('sha256').update(script).digest('hex')!==baseline.files['three/src/battle/storyView.js'].sha256)throw Error('Frozen StoryView changed');
const alarmHost=new StoryView({scene3:new THREE.Scene()}),alarms=[];
for(let frame=1;frame<=180;frame++){
  if(frame===91)alarmHost.alarmOff();
  const dt=[1/60,1/24,.1,.25][(frame-1)%4];alarmHost.update(dt);
  alarms.push({frame,dt,on:alarmHost.alarmOn!==false,time:alarmHost.time.value,
    lights:alarmHost.alarm.children.filter(o=>o.isPointLight).map(o=>({pos:o.position.toArray(),range:o.distance,decay:o.decay,intensity:o.intensity,color:o.color.toArray()})),
    lamps:alarmHost.alarm.children.filter(o=>o.isMesh).map(o=>({pos:o.position.toArray(),yaw:o.rotation.y}))});
}
fs.writeFileSync(path.join(root,'tools/migration/source-story-fx-fixtures.json'),JSON.stringify({commit:baseline.commit,
  sourceSha256:createHash('sha256').update(script).digest('hex'),cases,alarms}));
console.log(JSON.stringify({cases:cases.length,alarmFrames:alarms.length,commit:baseline.commit}));

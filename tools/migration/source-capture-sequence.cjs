'use strict';
const fs=require('node:fs'),vm=require('node:vm'),crypto=require('node:crypto');
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const hashes={},events=[];let frame=0;
const emit=(type,...args)=>events.push({frame,type,args});
const c=vm.createContext({THREE:{Vector3:class{}},BOSS_KIND:{},radio:cue=>emit('radio',cue),setTimeout(){},clearTimeout(){},performance:{now:()=>0}});
for(const [file,name]of [['three/src/battle/storyKinds.js','KINDS'],['three/src/battle/storyMission.js','StoryMission'],['shared/story/level4.js','LEVEL4']]){
 const bytes=fs.readFileSync(baseline.snapshot+'/'+file),sha=crypto.createHash('sha256').update(bytes).digest('hex');
 if(sha!==baseline.files[file].sha256)throw Error('Frozen source mismatch: '+file);hashes[file]=sha;
 vm.runInContext('(()=>{'+bytes.toString().replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.'+name+'='+name+';})()',c);
}
const frames=[],snapshots=[];const noop=()=>{};
for(const s of c.LEVEL4.steps.filter(s=>s.kind==='capture')){
 const m=Object.create(c.StoryMission.prototype),enemies=new Map();
 Object.assign(m,{stats:{sites:0,graffiti:0},drive:{player:{pos:[...s.pos]},input:{},vehicle:{}},enemies,
  level:{steps:[s],no:c.LEVEL4.no,name:c.LEVEL4.name},i:0,time:0,cap:null,holdG:false,carSize:()=>({w:2,below:1.5,above:1.5}),
  _target:()=>s.pos,_yaw:()=>0,clearEnemies:()=>{emit('clearEnemies');enemies.clear()},
  hud:{cancelChoice:noop,objective:noop,say:(lines=[],urgent=false)=>emit('say',lines,urgent),
   banner:(...args)=>emit('banner',...args),row:noop,prompt:noop,retitle:t=>m.retitle=t,
   marker:noop,pips:noop,clock:noop,objectiveDone:()=>emit('objectiveDone')},
  view:{hideZone:noop,showZone:noop,showBeacon:noop,hideBeacon:()=>emit('hideBeacon'),setZoneProgress:noop,
   setZoneColor:noop,siteCaptured:id=>emit('siteCaptured',id),scrub:id=>emit('scrub',id)},
  spawn:(specs,tag)=>{emit('spawn',specs,tag);for(const e of specs)enemies.set({alive:true,pos:[...s.pos]},{tag})},
  alive:tag=>[...enemies].filter(([u,e])=>u.alive&&e.tag===tag).length});
 m._go(0);m.asked=true;
 function tick(label,pos,dt,interact=false,clear=false){
  frame++;if(clear)enemies.clear();m.drive.player.pos=pos;m.holdG=interact;
  const input={frame,site:s.id,label,pos,dt,interact,clear};frames.push(input);
  const done=c.KINDS.capture.update(m,s,dt);
  snapshots.push({frame,phase:m.cap.phase,p:m.cap.p,scrub:m.cap.scrub,progress:m.progress||0,
   sites:m.stats.sites,graffiti:m.stats.graffiti,checkpoint:m.checkpoint||null,done});
  if(done)m._done();return done;
 }
 tick('outside-trigger',[s.pos[0]+s.trigger+1,s.pos[1],s.pos[2]],.1);
 tick('guard-encounter',[s.pos[0]+s.trigger/2,s.pos[1],s.pos[2]],.1);
 tick('contested',[...s.pos],.3);
 tick('partial-capture',[...s.pos],.6,false,true);
 tick('capture-decay',[s.pos[0]+s.r+3,s.pos[1],s.pos[2]],.2);
 while(m.cap.phase==='cap')tick('capture',[...s.pos],.2);
 tick('counter-still-alive',[...s.pos],.2);
 tick('counter-defeated',[...s.pos],.2,false,true);
 tick('partial-scrub',[...s.pos],.4,true);
 tick('scrub-decay',[...s.pos],.2);
 tick('scrub-outside',[s.pos[0]+12,s.pos[1],s.pos[2]],.2,true);
 let done=false;while(!done)done=tick('scrub',[...s.pos],.2,true);
}
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},hashes,level:c.LEVEL4,frames,snapshots,events}));

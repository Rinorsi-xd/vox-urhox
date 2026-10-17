'use strict';
const fs=require('node:fs'),vm=require('node:vm'),crypto=require('node:crypto');
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const hashes={},events=[];let current=0;
const emit=(type,...args)=>events.push({case:current,type,args});
const deterministicMath=Object.create(Math);deterministicMath.random=()=>0;
const c=vm.createContext({BOSS_KIND:{},radio:cue=>emit('radio',cue),Math:deterministicMath});
for(const [file,name]of [['three/src/battle/storyKinds.js','KINDS'],['shared/story/level2.js','LEVEL2']]){
 const bytes=fs.readFileSync(baseline.snapshot+'/'+file),sha=crypto.createHash('sha256').update(bytes).digest('hex');
 if(sha!==baseline.files[file].sha256)throw Error('Frozen source mismatch: '+file);hashes[file]=sha;
 vm.runInContext('(()=>{'+bytes.toString().replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.'+name+'='+name+';})()',c);
}
const nav=JSON.parse(fs.readFileSync('assets/Crater/Layout.json','utf8')).nav;
const step=c.LEVEL2.steps.find(s=>s.kind==='escort'),cases=[];
const ground=(x,z,hint=30)=>hint;
for(const cp of [0,1])for(const hp of [.1,.5,1])for(const alive of [true,false])for(const cross of [false,true]){
 current++;
 const m={drive:{layout:{nav},player:{alive,pos:[0,0,0]}},ground,time:5,stats:{},progress:0,
  hud:{row(){},banner:(...args)=>emit('banner',...args),say:(lines=[],urgent=false)=>emit('say',lines,urgent),retitle:t=>m.retitle=t,talking:false},
  view:{addTruck:()=>({hit(){},setPose(){}})},enemies:new Map(),fail:()=>{throw Error('Unexpected failure')}};
 c.KINDS.escort.prepare(m,step);const t=m.truck;
 t.cp=cp;t.hp=hp;t.d=m.truckPath.total*step.checkpoints[cp]-.01;t.v=cross?step.speed:0;
 m.drive.player.pos=[...t.pos];if(!cross)m.drive.player.pos[0]+=step.leash+1;
 const input={id:current,cp,hp,alive,cross,dt:cross?1/30:0};
 c.KINDS.escort.update(m,step,input.dt,!alive);
 cases.push({...input,expected:{cp:t.cp,cpD:t.cpD,cpHp:t.cpHp,d:t.d,v:t.v,hp:t.hp,pos:t.pos,yaw:t.yaw,
  stats:m.stats,checkpoint:m.checkpoint||null,progress:m.progress,retitle:m.retitle}});
}
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},hashes,nav,level:c.LEVEL2,cases,events}));

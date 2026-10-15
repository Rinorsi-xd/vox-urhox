import fs from 'node:fs';import vm from 'node:vm';import crypto from 'node:crypto';
const root='.tmp/outgame-source-2026-10-14T10-09-50-505Z/';
const read=p=>fs.readFileSync(root+p,'utf8');
const mission=read('three/src/battle/storyMission.js'),kinds=read('three/src/battle/storyKinds.js'),boss=read('three/src/battle/storyBoss.js');
const flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
const bstart=boss.indexOf('\ttarget( m ) { return m.boss'),bend=boss.indexOf('\n\t// 打完以后残骸',bstart);
const BOSS_KIND=vm.runInNewContext('({lift:24,'+boss.slice(bstart,bend)+'})',{flat});
const KINDS=vm.runInNewContext(kinds.replace(/^import .*;\r?\n/gm,'').replace('export const KINDS','const KINDS')+';KINDS',{BOSS_KIND,Math});
const method=(name,end)=>{const start=mission.indexOf('\t'+name+'(');return mission.slice(start,mission.indexOf(end,start)).trim();};
const funcs=vm.runInNewContext('({'+method('nearestEnemy','\n\talive(')+','+method('_target','\n\t// ── 刷敌人')+','+method('_marker','\n\t// 世界坐标')+'})',{flat,KIND:{pickup:'intel',install:'install',reach:'goal',clear:'goal'},LABEL:{pickup:'情报',install:'采集器',reach:'目标',clear:'目标'}});
const cases=[];
for(const kind of ['pickup','reach','install','clear','talk','escort','hold','capture','boss'])for(const distance of [0,50,200])for(const phase of ['go','fight','cap','counter','scrub'])for(const enemies of [0,2]){
 const step={kind,id:kind==='reach'?'home':'test',pos:[0,0,0],r:20,healR:20,site:'A',intel:'note'};
 const player=[distance,0,0],units=Array.from({length:enemies},(_,i)=>({pos:[i===0?100:2,0,0],alive:true}));
 const m={...funcs,step,kind:KINDS[kind],phase,cap:{phase},hold:{},truck:{blocked:phase==='fight',far:distance===200,pos:[90,0,0]},level:{intel:{note:{pos:[3,0,0]}}},drive:{player:{pos:player}},enemies:new Map(units.map((u,i)=>[u,{name:i===0?'海盗 · 远车':'海盗 · 近车'}])),bossFlow:{stage:phase==='fight'?'fight':'intro'},boss:{shelterSpot:()=>phase==='fight'&&distance===200?[20,0,20]:null,unit:{pos:[0,0,0]}},alive:()=>units.length};
 let marker=null,pips=[],projections=[];m.hud={marker:v=>marker=v,pips:v=>pips=v};m._project=(p,lift)=>{projections.push({p,lift});return {x:300,y:300,off:false,angle:0};};
 const target=m._target();m._marker();
 const targetProjection=marker?projections[0]:null;
 cases.push({kind,distance,phase,enemies,target:target??null,marker:marker?{label:marker.label,kind:marker.kind,lift:targetProjection.lift,enemy:targetProjection.lift===3.5,close:marker.hidden,pips:pips.length}:null});
}
const projected=[];const projection=method('_project','\n\t_complete(').replace(/^_project\(/,'function project(');
for(const [w,h]of [[1920,1080],[2048,922],[1280,720],[2560,1080]])for(const nx of [-4,-1,0,.25,1,4])for(const ny of [-3,0,.4,3])for(const behind of [false,true]){
 const _v={x:nx,y:ny,z:behind?2:0,set(){return this;},project(){return this;}};
 const fn=vm.runInNewContext('('+projection+')',{_v,innerWidth:w,innerHeight:h,Math});projected.push({nx,ny,behind,w,h,out:fn.call({drive:{camera:{}}},[0,0,0],0)});
}
const source=['three/src/battle/storyMission.js','three/src/battle/storyKinds.js','three/src/battle/storyBoss.js'].map(path=>({path,sha256:crypto.createHash('sha256').update(read(path)).digest('hex')}));
fs.writeFileSync('tools/migration/source-story-marker-fixtures.json',JSON.stringify({source,cases,projected}));console.log(JSON.stringify({cases:cases.length,projected:projected.length}));

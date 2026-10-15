import fs from 'node:fs';import path from 'node:path';import vm from 'node:vm';import crypto from 'node:crypto';
const filename=path.resolve('.tmp/outgame-source-2026-10-14T10-09-50-505Z/three/src/battle/storyMission.js');const code=fs.readFileSync(filename,'utf8');
const start=code.indexOf('\t_doomed( u, e ) {'),end=code.indexOf('\n\tafterStep(',start);if(start<0||end<start)throw Error('Frozen _doomed method missing');
const method=code.slice(start,end).trim().replace(/^_doomed\( u, e \)/,'function doom(u,e)');
const doom=vm.runInNewContext(`(()=>{const HULL=.55,HULL_BOSS=.35;${method};return doom;})()`);const cases=[];
for(const armed of [false,true])for(const load of [0,10])for(const speed of [0,10])for(const hull of [false,true])for(const hp of [.34,.54,.6])for(const flee of [false,.5])for(const boss of [false,true]){
 let action=null;const spec={weapons:armed?[{}]:[],motion:{load,topSpeed:speed}};const u={spec,hullEnabled:hull,health:hp,pos:[0,1,0],bp:{coreParts:()=>[{id:1}]},maxPartHp:()=>100,_damage(){action='destroy';},flush(){}};
 const ctx={view:{spawnFlash(){}},removeEnemy(){action='flee';},kind:null,drive:{sim:{viewEvents:[]}}};const result=doom.call(ctx,u,{flee,boss});cases.push({spec,hull,hp,flee,boss,action,result});
}
const out={source:{path:'three/src/battle/storyMission.js',sha256:crypto.createHash('sha256').update(code).digest('hex')},cases};fs.writeFileSync('tools/migration/source-story-enemy-fixtures.json',JSON.stringify(out));console.log(JSON.stringify({cases:cases.length,source:out.source}));

import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const sourceHashes={};
function source(file){const s=fs.readFileSync(path.join(baseline.snapshot,file),'utf8');const hash=createHash('sha256').update(s).digest('hex');if(hash!==baseline.files[file].sha256)throw Error('Frozen source drift');sourceHashes[file]=hash;return s;}
const sortie=source('three/src/intro/introSortie.js'),intro=source('three/src/intro/intro.js');
const ctx=vm.createContext({buildVehicleSpec:bp=>bp.spec,Blueprint:class{constructor(){this.fallback=true}},buildRaceCar(){},document:{body:{classList:{remove(){}}}},console});
vm.runInContext(sortie.slice(sortie.indexOf('function sortieCar('),sortie.indexOf('// 换一辆玩家车'))+
 sortie.slice(sortie.indexOf('function swapPlayer('),sortie.indexOf('// 一辆车当场炸掉'))+
 sortie.slice(sortie.indexOf('function endPlay('))+'\nglobalThis.api={sortieCar,endPlay};',ctx);
const selection=[];
for(const ok of [false,true])for(let flags=0;flags<64;flags++){
 const names=['weapons','wings','wheels','legs','hovers','mechLegs'];const spec={ok};names.forEach((k,i)=>spec[k]=flags&(1<<i)?[{}]:[]);
 const bp={spec};selection.push({ok,flags,original:ctx.api.sortieCar(bp)===bp});
}
const ground=(x,z)=>x*.01-z*.02;
ctx.ground=ground;
const placement=intro.slice(intro.indexOf('\tplaceUnit( u, x, z, yaw )'),intro.indexOf('\n\t// 摆演员'));
const handoffLine=sortie.slice(sortie.indexOf('if ( easy ) { easy.incomingDamageMultiplier = 8;'),sortie.indexOf('// 它直接冲玩家来'));
vm.runInContext(sortie.match(/^const EASY_AT =.*;/m)[0]+'\nglobalThis.Placement=class {'+placement+'};globalThis.handoff=function(I,easy,d){'+handoffLine+'}',ctx);
const handoffEasy={alive:true,vehicle:{place(pos,yaw){this.pos=pos;this.yaw=yaw;}}},handoffPlayer={};
ctx.handoff(new ctx.Placement(),handoffEasy,{player:handoffPlayer});
const handoff={pos:handoffEasy.vehicle.pos,yaw:handoffEasy.vehicle.yaw,mult:handoffEasy.incomingDamageMultiplier,targetPlayer:handoffEasy.introTarget===handoffPlayer};
const cleanups=[];
for(const mode of ['normal','skip-brief','skip-countdown','skip-playing']){
 const units=Array.from({length:8},(_,i)=>({alive:mode==='normal'?![1,4,7].includes(i):true,isCart:i===7,incomingDamageMultiplier:i===4?8:2,introTarget:{},externalControl:true,spawn(){this.alive=true;this.spawned=(this.spawned||0)+1;}}));
 const oldPlayer={alive:false},hero={id:'hero'},trace=[];
 const d={player:oldPlayer,firing:true,scope:true,_syncPlayer(){trace.push('sync');},_spawn(at){this.spawn=at;},hud:{show(...args){trace.push(['hud',...args]);}},car:{name:'hero'},spec:{motion:{}},weapons:{groups:[]},ui:{thumbs:[]}};
 const sim={units,setPlayer(json,opt){trace.push(['setPlayer',json,opt]);return hero;}};
 const I={playing:true,root:{classList:{remove(){}},querySelector(){return {remove(){}};}},drive:d,sim,cine:{script:null,target:oldPlayer},cineScript:{id:'script'},cartUnit:units[7],heroBp:{toJSON:()=>({id:'hero-blueprint'})},cam:{on:false}};
 ctx.api.endPlay(I,{ground});
 cleanups.push({mode,playing:I.playing,firing:d.firing,scope:d.scope,hero:d.player===hero,spawn:d.spawn,cam:I.cam.on,script:I.cine.script===I.cineScript,cartTarget:I.cine.target===I.cartUnit,units:units.map(u=>({alive:u.alive,mult:u.incomingDamageMultiplier,target:u.introTarget,spawned:u.spawned||0,external:u.externalControl}))});
}
// Execute the exact original cinematic beforeStep body against controlled actors.
const before= intro.slice(intro.indexOf('\t\t\tbeforeStep: ( dt ) => {'),intro.indexOf('\n\t\t\tafterStep: () => {}')).replace(/^\s*beforeStep: /,'').replace(/,\s*$/,'');
vm.runInContext('globalThis.makeBefore=function(){return '+before+';}',ctx);
const ai=[];
for(const stage of [0,1,2,3])for(const targetAlive of [true,false])for(const easy of [true,false]){
 const calls=[];const cart={alive:targetAlive,pos:[30,1,-170]},player={alive:targetAlive,pos:[62,1,-176]};
 const u={alive:true,externalControl:true,introTarget:easy&&stage>=1?player:null,vehicle:{},weapons:{},driver:{step(dt,info){calls.push(info.target.unit===player?'player':'cart');return {command:{throttle:1},aim:[1,2,3],trigger:false};}},step(){},fire:()=>[]};
 const I={sim:{units:[u],fx:[]},cine:{target:stage>=3?player:cart}};ctx.PARK={throttle:0,steer:0,handbrake:true};ctx.makeBefore.call(I)(1/60);ai.push({stage,targetAlive,easy,calls});
}
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},sourceHashes,selection,cleanups,ai,handoff}));

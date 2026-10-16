import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const file='three/src/intro/intro.js',bytes=fs.readFileSync(path.join(baseline.snapshot,file));
const sha=createHash('sha256').update(bytes).digest('hex');
if(sha!==baseline.files[file].sha256)throw Error('Frozen montage source drift');
const source=bytes.toString('utf8');
const begin=source.indexOf('beforeStep: ( dt ) => {'),end=source.indexOf('\n\t\t\tafterStep:',begin);
if(begin<0||end<begin)throw Error('Original beforeStep missing');
const step=source.slice(begin,end).trim().replace(/,$/,'');
const cases=[];
for(const target of ['cart','player',null]){
 const calls=[],cart={alive:true,pos:[30,3,-170]},player={alive:true,pos:[66,4,-174]};
 const units=Array.from({length:3},(_,i)=>({alive:true,externalControl:true,vehicle:{},
  step(dt,cmd){calls.push({i,kind:'step',cmd});},
  fire(dt,cmd){calls.push({i,kind:'fire',cmd});return[];},
  driver:{step(dt,{target}){calls.push({i,kind:'driver',target:target.pos});return{command:{throttle:1,steer:.2},trigger:true,aim:target.pos};}}
 }));
 const I={cine:{target:target==='cart'?cart:target==='player'?player:null},sim:{units,fx:[]}};
 const context=vm.createContext({I,PARK:{throttle:0,steer:0,handbrake:true,boost:false}});
 vm.runInContext('I.beforeStep=(function(){return ({'+step+'}).beforeStep}).call(I)',context);I.beforeStep(1/60);
 cases.push({target,calls});
}
const montageStart=source.indexOf("this.mark( 'm-drive' );"),montageEnd=source.indexOf("this.mark( 'm-missile' );",montageStart);
const setup=source.slice(montageStart,montageEnd);
const nullLine=setup.split('\n').find(line=>line.includes('this.cine.target = null'));
const aimLine=setup.split('\n').find(line=>line.trim().startsWith('S.aim ='));
if(!nullLine||!aimLine)throw Error('Original montage target/aim setup missing');
const point=[64,5,-104],I={cine:{target:'old'}},S={};
const context=vm.createContext({I,S,target:{pos:point},X:66});
vm.runInContext(nullLine.replace('this.','I.')+'\n'+aimLine,context);
if(I.cine.target!==null)throw Error('Original montage must park drivers');
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},
 sourceHashes:{[file]:sha},cases,aim:S.aim(),point,
 boundary:'Executes the frozen enemy beforeStep and montage target/aim statements using controlled actor adapters. No GPU, native physics or natural playback.'}));

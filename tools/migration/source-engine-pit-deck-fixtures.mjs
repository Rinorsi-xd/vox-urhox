import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const url=p=>pathToFileURL(path.join(baseline.snapshot,p)).href;
registerHooks({resolve(s,c,n){return n(s==='three'?url('three/vendor/three/build/three.module.js'):s,c);}});
const {buildSmoke}=await import(url('three/src/terrain/airFx.js'));
const manifest=JSON.parse(fs.readFileSync(path.join(root,'tools/migration/engine-pit-source/Manifest.json')));
const data=manifest.layout.enginePit.deck;
const script=fs.readFileSync(new URL(url('three/src/battle/enginePitWorld.js')),'utf8');
const frameText=script.slice(script.indexOf('const frame ='),script.indexOf('const FE ='));
const frame=new Function(frameText+'return frame;')();const DECK={c:[data.center[0],data.center[2]],w:data.half[0]*2,d:data.half[1]*2};
const containsText=script.match(/contains: \( x, z, margin = 0 \) => \{[^\n]+\}/)[0].slice('contains: '.length);
const contains=new Function('FD','DECK','return '+containsText)(frame(DECK.c,data.yaw),DECK);
const containsCases=[];for(const u of [-31,-28,-27.999,0,27.999,28,31])for(const v of [-31,-28,-27.999,0,27.999,28,31])for(const margin of [-3,0,3]){
    const [x,z]=frame(DECK.c,data.yaw).world(u,v);containsCases.push({x,z,margin,expected:contains(x,z,margin)});
}
const origins=Array.from({length:8},(_,k)=>{const a=k*Math.PI/4;const [x,z]=frame(DECK.c,data.yaw).world(Math.cos(a)*22,Math.sin(a)*22);return {pos:[x,data.top-1,z],rate:0,size:6,dark:.1};});
const random=Math.random;let seed=15;Math.random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/2**32);
const smoke=buildSmoke(origins),randomSeedAtFirstUpdate=seed,smokeCases=[];let dustT=.9;
for(let i=1;i<=60;i++){
    const dt=1/30;if(dustT>0){dustT-=dt;for(const o of origins)o.rate=dustT>0?9:0;}smoke.userData.update(dt,i*dt);
    const g=smoke.geometry,n=g.instanceCount;smokeCases.push({frame:i,rate:origins[0].rate,count:n,puff:Array.from(g.attributes.aPuff.array.slice(0,n*4)),look:Array.from(g.attributes.aLook.array.slice(0,n*4))});
}
Math.random=random;
fs.writeFileSync(path.join(root,'tools/migration/source-engine-pit-deck-fixtures.json'),JSON.stringify({commit:baseline.commit,
    sourceSha256:createHash('sha256').update(script).digest('hex'),airFxSha256:createHash('sha256').update(fs.readFileSync(new URL(url('three/src/terrain/airFx.js')))).digest('hex'),randomSeedAtFirstUpdate,containsCases,smokeCases}));
console.log(JSON.stringify({contains:containsCases.length,smoke:smokeCases.length,commit:baseline.commit}));

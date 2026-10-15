import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
for(const file of ['shared/salvage/stash.js','shared/salvage/items.js']){
 const hash=crypto.createHash('sha256').update(fs.readFileSync(path.join(baseline.snapshot,file))).digest('hex');
 if(hash!==baseline.files[file].sha256)throw Error('Frozen source drift '+file);
}
globalThis.localStorage={getItem:()=>null,setItem:()=>{}};
const {SalvageStash,partsNeeded}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/salvage/stash.js')));
const {ITEMS}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/salvage/items.js')));
const cases=[];
for(const credits of [0,20,100,8000])for(const list of [{},{scrap:3},{'part:laser1':2},{'part:drive1':1,scrap:5},Object.fromEntries(Object.keys(ITEMS).filter(x=>x.startsWith('part:')).slice(0,7).map(x=>[x,4]))]){
 const s=new SalvageStash();s.credits=credits;s.items=new Map([['scrap',3],['part:drive1',4]]);
 const before={credits:s.credits,items:Object.fromEntries(s.items)};const result=s.buyAll(list);
 cases.push({before,list,result,credits:s.credits,items:Object.fromEntries(s.items)});
}
const shorts=[];
for(const n of [0,1,4,7]){
 const s=new SalvageStash();s.items=new Map([['part:drive1',4],['part:laser1',1]]);const usage={'part:drive1':n,'part:laser1':n};s.usage=()=>usage;
 shorts.push({owned:Object.fromEntries(s.items),usage,result:s.shortfall()});
}
const needs=[[],[['core',[0,0,0],0],['cube',[1,0,0],0],['cube',[2,0,0],0],['laser1',[0,1,0],0]]].map(parts=>({parts,result:partsNeeded({parts})}));
fs.writeFileSync(path.join(root,'tools/migration/source-stash.json'),JSON.stringify({commit:baseline.commit,cases,shorts,needs}));
console.log('Source stash: '+cases.length+' buyAll, '+shorts.length+' shortages, '+needs.length+' blueprint counts');

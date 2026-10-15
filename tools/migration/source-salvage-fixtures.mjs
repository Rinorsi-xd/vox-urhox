import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=await import(pathToFileURL(path.join(baseline.snapshot,'shared/salvage/salvageLoot.js')));
const cases=[];
for(const kind of Object.keys(source.CONTAINERS))for(const op of source.OPS)for(let seed=1;seed<=20;seed++){
 let word=seed;const values=[];
 const rand=()=>{word=(Math.imul(word,1664525)+1013904223)>>>0;const v=word/4294967296;values.push(v);return v;};
 const state={red:0};const result=source.rollContainer(kind,rand,state,{bonus:op.bonus,red:op.red});
 cases.push({kind,op,values,result,red:state.red});
}
const slots=[];
for(const cargo of [[],[['scrap',41]], [['reactor',5],['scrap',19],['repair',6]], [['starcore',8]]])for(const id of ['scrap','reactor','repair','starcore'])for(const n of [1,5,21]){
 const m=new Map(cargo);slots.push({cargo:Object.fromEntries(m),id,n,used:source.slotsUsed(m),mass:source.cargoMass(m),room:source.roomFor(m,id,n,20)});
}
fs.writeFileSync(path.join(root,'tools/migration/source-salvage-fixtures.json'),JSON.stringify({baseline:baseline.commit,cases,slots}));
console.log('Frozen source fixtures: '+cases.length+' rolls, '+slots.length+' cargo cases');

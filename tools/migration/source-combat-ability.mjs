import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const root=path.resolve(baseline.snapshot),provenance={};
for(const file of ['shared/combat/carUnit.js','shared/parts/defs.js']){
 const hash=createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
 if(hash!==baseline.files[file]?.sha256)throw Error('Frozen source changed '+file);
 provenance[file]=hash;
}
const code=fs.readFileSync(path.join(root,'shared/combat/carUnit.js'),'utf8');
const match=code.match(/else if \( (.*) \) this\.kill \|\|= '失去战斗力';/);
if(!match)throw Error('Frozen lost-combat condition missing');
const {PARTS}=await import(pathToFileURL(path.join(root,'shared/parts/defs.js')));
const condition=vm.runInNewContext('(function(){return '+match[1]+';})',{PARTS});
const cases=[];
for(const type of ['empty',...Object.keys(PARTS)])for(const originallyArmed of [false,true]){
 const parts=type==='empty'?[]:[{type}];
 const original=originallyArmed?[{type:'laser1'}]:[{type:'cube'}];
 const expected=condition.call({bp:{parts:new Map(parts.map((p,i)=>[i,p]))},originalParts:new Map(original.map((p,i)=>[i,p]))});
 cases.push({type,originallyArmed,expected});
}
fs.writeFileSync('tools/migration/source-combat-ability.json',JSON.stringify({commit:baseline.commit,provenance,cases}));
console.log(JSON.stringify({cases:cases.length,commit:baseline.commit}));

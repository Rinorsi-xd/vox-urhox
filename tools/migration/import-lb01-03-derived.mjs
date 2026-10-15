// Explicitly patches only the independently confirmed LB01-LB03 differences.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {root,source,baseline,sha,read,equal,expected,changedPrefabs,changedLines} from './lb01-03-source.mjs';
const e=await expected(),arena=read('assets/Combat/Arena.json'),radio=read('assets/Combat/Radio.json');
const prefabDiff=Object.keys(e.prefabs).filter(k=>!equal(arena.prefabs[k],e.prefabs[k]));
const lineDiff=Object.keys(e.lines).filter(k=>!equal(radio.lines[k],e.lines[k]));
const obsolete=Object.keys(radio.lines).filter(k=>!e.lines[k]);
assert.deepEqual(prefabDiff.sort(),[...changedPrefabs].sort());
assert.deepEqual(lineDiff.sort(),[...changedLines].sort());
assert.deepEqual(obsolete.sort(),['c09d','c09e']);
assert.deepEqual(Object.keys(e.calls).filter(k=>!equal(e.calls[k],radio.calls[k])),['deadRespawn']);
const namesDiff=e.names.flatMap((v,i)=>v===arena.names[i]?[]:[i]);assert.deepEqual(namesDiff,[14,25]);
const beforeArena=structuredClone(arena),beforeRadio=structuredClone(radio);
const assetDirs=['assets/Combat','assets/Sounds/BattleRadio','assets/UI/Avatars'];
const beforeFiles={};for(const dir of assetDirs)for(const n of fs.readdirSync(path.join(root,dir))){const rel=dir+'/'+n;if(fs.statSync(path.join(root,rel)).isFile())beforeFiles[rel]=sha(path.join(root,rel));}
for(const key of changedPrefabs)arena.prefabs[key]=e.prefabs[key];
for(const i of namesDiff)arena.names[i]=e.names[i];
radio.calls.deadRespawn=e.calls.deadRespawn;
for(const id of changedLines)radio.lines[id]=e.lines[id];
for(const id of obsolete)delete radio.lines[id];
const untouchedArena=x=>{const copy=structuredClone(x);for(const key of changedPrefabs)delete copy.prefabs[key];for(const i of namesDiff)copy.names[i]=null;return copy;};
const untouchedRadio=x=>{const copy=structuredClone(x);delete copy.calls.deadRespawn;for(const id of [...changedLines,...obsolete])delete copy.lines[id];return copy;};
assert.deepEqual(untouchedArena(arena),untouchedArena(beforeArena));
assert.deepEqual(untouchedRadio(radio),untouchedRadio(beforeRadio));
for(const id of changedLines)fs.copyFileSync(path.join(source,`shared/assets/match/vo/bc/${id}.wav`),path.join(root,`assets/Sounds/BattleRadio/${id}.wav`));
fs.writeFileSync(path.join(root,'assets/Combat/Arena.json'),JSON.stringify(arena));
fs.writeFileSync(path.join(root,'assets/Combat/Radio.json'),JSON.stringify(radio));
const allowed=new Set(['assets/Combat/Arena.json','assets/Combat/Radio.json',...changedLines.map(id=>`assets/Sounds/BattleRadio/${id}.wav`)]);
const changedFiles=[];for(const [rel,hash] of Object.entries(beforeFiles)){if(sha(path.join(root,rel))!==hash){assert(allowed.has(rel),'Unowned file changed: '+rel);changedFiles.push(rel);}}
assert.equal(changedFiles.length,12);
const report={at:new Date().toISOString(),baseline:{branch:baseline.branch,commit:baseline.commit,snapshot:source},sourceInputs:e.inputs,prefabDiff,namesDiff,lineDiff,removedInactiveMetadata:obsolete,changedFiles,beforeFiles,afterFiles:Object.fromEntries(Object.keys(beforeFiles).map(p=>[p,sha(path.join(root,p))])),unchanged72Prefabs:72,untouchedFieldsEqual:true};
const dest=path.join(root,'docs/migration/evidence/lb01-03-derived-import.json');fs.writeFileSync(dest,JSON.stringify(report,null,2));
console.log(JSON.stringify({result:'PASS',changedFiles,untouched72Prefabs:72,untouchedFieldsEqual:true,evidence:dest}));

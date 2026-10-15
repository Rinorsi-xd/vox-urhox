import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
export const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
export const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
export const source=baseline.snapshot;
export const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
export const read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
export const stable=value=>Array.isArray(value)?value.map(stable):value&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(k=>[k,stable(value[k])])):value;
export const equal=(a,b)=>JSON.stringify(stable(a))===JSON.stringify(stable(b));
export const changedPrefabs=['blue','red'].flatMap(team=>[3,4].flatMap(tier=>[0,1].map(v=>`${team}:${tier}:hover:${v}`)));
export const changedLines=['c01','c01c','c01b','c04','c04b','c05b','c05','c05c','c11','e04'];
export async function expected(){
 const url=p=>pathToFileURL(path.join(source,p)).href,inputs={};
 const capture=p=>{const rel=path.relative(source,p).replaceAll('\\','/');const hash=sha(p);if(!baseline.files[rel]||baseline.files[rel].sha256!==hash)throw Error('Frozen source hash mismatch: '+rel);inputs[rel]=hash;};
 registerHooks({resolve(s,c,n){
  if(c.parentURL===url('three/src/battle/matchVoice.js')&&s==='./radio.js')return {url:'data:text/javascript,export class Radio {}',shortCircuit:true};
  return n(s==='three'?url('three/vendor/three/build/three.module.js'):s,c);
 },load(u,c,n){
  const result=n(u,c);if(u.startsWith(pathToFileURL(source).href+'/'))capture(fileURLToPath(u));
  if(u===url('shared/battle/matchmaker.js'))return {...result,source:result.source.toString()+'\nexport { NAMES };'};
  if(u===url('three/src/battle/matchVoice.js'))return {...result,source:result.source.toString()+'\nexport { LINES, specOf };'};
  return result;
 }});
 const {createEnemyBlueprint}=await import(url('shared/build/enemyPrefabs.js'));
 const {NAMES}=await import(url('shared/battle/matchmaker.js'));
 const {LINES,specOf}=await import(url('three/src/battle/matchVoice.js'));
 const prefabs={};for(const team of ['blue','red'])for(let tier=1;tier<=5;tier++)for(const role of ['assault','heavy','hover','sniper'])for(let variant=0;variant<=1;variant++)prefabs[`${team}:${tier}:${role}:${variant}`]=createEnemyBlueprint(role,tier,variant,{player:team==='blue'}).toJSON();
 const list=path.join(source,'shared/assets/match/vo/bc/lines.json');capture(list);
 const metadata=JSON.parse(fs.readFileSync(list,'utf8')),calls={},lines={};
 for(const [key,ids] of Object.entries(LINES)){calls[key]={ids,...specOf(key)};for(const id of ids)lines[id]={...metadata[id],path:`Sounds/BattleRadio/${id}.wav`};}
 return {prefabs,names:NAMES,calls,lines,inputs};
}

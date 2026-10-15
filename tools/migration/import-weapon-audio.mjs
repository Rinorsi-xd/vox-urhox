import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=baseline.snapshot,load=p=>import(pathToFileURL(path.join(source,p)).href);
const {WEAPON_CUES,WEAPON_BASE}=await load('shared/audio/weaponCues.js');
const {HEAVY_CUES,HEAVY_BASE}=await load('shared/audio/heavyWeaponCues.js');
const {COMPLETION_CUES,COMPLETION_BASE}=await load('shared/audio/completionCues.js');
const {MIX_TRIM}=await load('shared/audio/mixTrim.js');
const sha=b=>createHash('sha256').update(b).digest('hex'),cues={};
fs.mkdirSync(path.join(root,'assets/Sounds/Weapons'),{recursive:true});
for(const [table,base,jitter] of [[WEAPON_CUES,WEAPON_BASE,true],[HEAVY_CUES,HEAVY_BASE,false],[Object.fromEntries(Object.entries(COMPLETION_CUES).filter(([id])=>id.startsWith('missile_')||id==='energy_online')),COMPLETION_BASE,true]]){
 for(const [id,cue] of Object.entries(table)){
  const original=fileURLToPath(new URL(`${cue.file||id}_${cue.variant}.wav`,cue.base||base));
  const data=fs.readFileSync(original),relative=`Sounds/Weapons/${id}_${cue.variant}.wav`;
  if(data.toString('ascii',0,4)!=='RIFF'||data.toString('ascii',8,12)!=='WAVE')throw Error('Not WAV: '+original);
  fs.writeFileSync(path.join(root,'assets',relative),data);
  cues[id]={path:relative,gain:cue.gain*10**((MIX_TRIM[id]||0)/20),gap:cue.gap/1000,loop:cue.loop||false,jitter,
   attack:cue.attack||.08,release:cue.release||.1,source:path.relative(source,original).replaceAll('\\','/'),sha256:sha(data),bytes:data.length};
 }
}
fs.writeFileSync(path.join(root,'assets/Combat/WeaponSounds.json'),JSON.stringify({baseline:baseline.commit,cues}));
console.log(JSON.stringify({cues:Object.keys(cues).length,bytes:Object.values(cues).reduce((s,c)=>s+c.bytes,0),baseline:baseline.commit}));

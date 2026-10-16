import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash,randomBytes} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const load=p=>import(pathToFileURL(path.join(baseline.snapshot,p)).href);
const {WORKSHOP_CUES,WORKSHOP_BASE}=await load('shared/audio/workshopCues.js');
const {HANGAR_CUES,HANGAR_BASE}=await load('shared/audio/hangarCues.js');
const {MIX_TRIM}=await load('shared/audio/mixTrim.js');
const cues={};
const meta=p=>{if(!fs.existsSync(p+'.meta'))fs.writeFileSync(p+'.meta',JSON.stringify({uuid:randomBytes(18).toString('base64url')},null,2)+'\n');};
fs.mkdirSync(path.join(root,'assets/Sounds/UI'),{recursive:true});
const selected=[...['press','open','place','remove','paint'].map(id=>[id,WORKSHOP_CUES[id],WORKSHOP_BASE]),
 ...['whoosh','confirm','error','stamp'].map(id=>[id,HANGAR_CUES[id],HANGAR_BASE])];
for(const [id,cue,defaultBase] of selected){
 const source=fileURLToPath(new URL(`${cue.file||id}_${cue.variant}.wav`,cue.base||defaultBase));
 const data=fs.readFileSync(source),relative=`Sounds/UI/${id}_${cue.variant}.wav`;
 if(data.toString('ascii',0,4)!=='RIFF'||data.toString('ascii',8,12)!=='WAVE')throw Error('Invalid WAV: '+source);
 const dest=path.join(root,'assets',relative);fs.writeFileSync(dest,data);meta(dest);
 cues[id]={path:relative,gain:cue.gain*10**((MIX_TRIM[id]||0)/20),gap:cue.gap/1000,
  source:path.relative(baseline.snapshot,source).replaceAll('\\','/'),sha256:createHash('sha256').update(data).digest('hex'),bytes:data.length};
}
const dest=path.join(root,'assets/UI/Sounds.json');
fs.writeFileSync(dest,JSON.stringify({baseline:baseline.commit,cues},null,2)+'\n');meta(dest);
console.log(JSON.stringify({cues:Object.keys(cues).length,bytes:Object.values(cues).reduce((n,c)=>n+c.bytes,0),baseline:baseline.commit}));

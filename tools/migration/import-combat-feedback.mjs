import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash,randomBytes} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const load=p=>import(pathToFileURL(path.join(baseline.snapshot,p)).href);
const {DAMAGE_CUES,DAMAGE_BASE}=await load('shared/audio/damageCues.js');
const {RECOVERY_CUES,RECOVERY_BASE}=await load('shared/audio/recoveryCues.js');
const {COMBAT_FEEDBACK_LIVE}=await load('shared/audio/combatFeedbackCues.js');
const {MATCH_FLOW_LIVE}=await load('shared/audio/matchFlowCues.js');
const {MIX_TRIM}=await load('shared/audio/mixTrim.js');
const cues={},meta=p=>{if(!fs.existsSync(p+'.meta'))fs.writeFileSync(p+'.meta',JSON.stringify({uuid:randomBytes(18).toString('base64url')},null,2)+'\n');};
fs.mkdirSync(path.join(root,'assets/Sounds/CombatFeedback'),{recursive:true});
const live={...DAMAGE_CUES,...RECOVERY_CUES,...COMBAT_FEEDBACK_LIVE,
 kill_confirm:MATCH_FLOW_LIVE.kill_confirm,kill_confirm__b:MATCH_FLOW_LIVE.kill_confirm__b};
for(const [id,cue] of Object.entries(live)){
 const base=cue.base||(DAMAGE_CUES[id]?DAMAGE_BASE:RECOVERY_BASE);
 const source=fileURLToPath(new URL(`${cue.file||id}_${cue.variant}.wav`,base));
 const data=fs.readFileSync(source),relative=`Sounds/CombatFeedback/${id}_${cue.variant}.wav`;
 if(data.toString('ascii',0,4)!=='RIFF'||data.toString('ascii',8,12)!=='WAVE')throw Error('Invalid WAV: '+source);
 const dest=path.join(root,'assets',relative);fs.writeFileSync(dest,data);meta(dest);
 cues[id]={path:relative,gain:cue.gain*10**((MIX_TRIM[id]||0)/20),gap:cue.gap/1000,loop:!!cue.loop,
  spatial:!!cue.spatial,pool:cue.pool,jitter:!!DAMAGE_CUES[id],source:path.relative(baseline.snapshot,source).replaceAll('\\','/'),
  sha256:createHash('sha256').update(data).digest('hex'),bytes:data.length};
}
const dest=path.join(root,'assets/Combat/FeedbackSounds.json');fs.writeFileSync(dest,JSON.stringify({baseline:baseline.commit,cues}));meta(dest);
console.log(JSON.stringify({cues:Object.keys(cues).length,bytes:Object.values(cues).reduce((n,c)=>n+c.bytes,0),baseline:baseline.commit}));

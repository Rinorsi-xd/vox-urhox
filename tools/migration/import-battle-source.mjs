import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const source=baseline.snapshot,url=p=>pathToFileURL(path.join(source,p)).href;
registerHooks({resolve(s,c,n){
 if(c.parentURL===url('three/src/battle/matchVoice.js')&&s==='./radio.js')return {url:'data:text/javascript,export class Radio {}',shortCircuit:true};
 return n(s==='three'?url('three/vendor/three/build/three.module.js'):s,c);
},load(u,c,n){
 const result=n(u,c);if(u===url('shared/battle/matchmaker.js'))return {...result,source:result.source.toString()+'\nexport { NAMES, LINEUP };'};
 if(u===url('three/src/battle/matchVoice.js'))return {...result,source:result.source.toString()+'\nexport { LINES, specOf };'};return result;
}});
const {createEnemyBlueprint}=await import(url('shared/build/enemyPrefabs.js'));
const {MATCH_MODES,CONQUEST,ESCORT}=await import(url('shared/battle/match.js'));
const {HULL,STRUCT}=await import(url('shared/combat/tuning.js'));
const {AI_TUNING,AI_COMBAT}=await import(url('shared/ai/driver.js'));
const {findMatch,NAMES,LINEUP}=await import(url('shared/battle/matchmaker.js'));
const {PARTS}=await import(url('shared/parts/defs.js'));
const {MATCH_FLOW_LIVE,MATCH_FOUND_VOICE}=await import(url('shared/audio/matchFlowCues.js'));
const {BATTLE_FLOW_CUES,BATTLE_FLOW_BASE}=await import(url('shared/audio/battleFlowCues.js'));
const {MIX_TRIM}=await import(url('shared/audio/mixTrim.js'));
const data={source:{branch:baseline.branch,commit:baseline.commit},modes:MATCH_MODES,conquest:CONQUEST,escort:ESCORT,names:NAMES,lineup:LINEUP,hull:HULL,structure:STRUCT,ai:AI_TUNING,combat:AI_COMBAT,prefabs:{},roster:findMatch({size:3,tier:1,seed:90862445})};
for(const team of ['blue','red'])for(let tier=1;tier<=5;tier++)for(const role of ['assault','heavy','hover','sniper'])for(let variant=0;variant<=1;variant++){
 data.prefabs[`${team}:${tier}:${role}:${variant}`]=createEnemyBlueprint(role,tier,variant,{player:team==='blue'}).toJSON();
}
const dest=path.join(root,'assets/Combat');fs.mkdirSync(dest,{recursive:true});
const payload=createEnemyBlueprint('boss',3,0);
for(const p of [...payload.parts.values()]){
 if(PARTS[p.type]?.cat==='weapon'){payload.remove(p.id);continue;}
 if(p.color===0xd0182a)p.color=0xffb000;
 if(p.color===0xff6a13)p.color=0xffd060;
}
data.payload=payload.toJSON();
fs.writeFileSync(path.join(dest,'Arena.json'),JSON.stringify(data));
const avatars=path.join(root,'assets/UI/Avatars');fs.mkdirSync(avatars,{recursive:true});
for(const name of fs.readdirSync(path.join(source,'shared/assets/ui/avatars')))if(name.endsWith('.jpg'))fs.copyFileSync(path.join(source,'shared/assets/ui/avatars',name),path.join(avatars,name));
const vo=path.join(root,'assets/Sounds/Match');fs.mkdirSync(vo,{recursive:true});
for(let i=1;i<=13;i++){const name='m'+String(i).padStart(2,'0')+'.wav';fs.copyFileSync(path.join(source,'shared/assets/match/vo',name),path.join(vo,name));}
const cues={};const flowDir=path.join(root,'assets/Sounds/BattleFlow');fs.mkdirSync(flowDir,{recursive:true});
for(const [id,cue] of Object.entries({...BATTLE_FLOW_CUES,...MATCH_FLOW_LIVE})){
 if(['match_found','wave_start','boss_warning'].includes(id))continue;
 const file=`${cue.file||id}_${cue.variant}.wav`,base=cue.base||BATTLE_FLOW_BASE;
 fs.copyFileSync(fileURLToPath(new URL(file,base)),path.join(flowDir,file));
 cues[id]={path:'Sounds/BattleFlow/'+file,gain:cue.gain*10**((MIX_TRIM[id]||0)/20)*.65,gap:(cue.gap||0)/1000,loop:!!cue.loop,...(cue.pool?{pool:cue.pool}:{})};
}
for(const id of MATCH_FOUND_VOICE){fs.copyFileSync(path.join(source,'shared/assets/match/vo/bc',id+'.wav'),path.join(vo,id+'.wav'));}
fs.writeFileSync(path.join(dest,'FlowSounds.json'),JSON.stringify({source:data.source,cues,foundVoice:MATCH_FOUND_VOICE}));
const {LINES,specOf}=await import(url('three/src/battle/matchVoice.js'));
const voiceLines=JSON.parse(fs.readFileSync(path.join(source,'shared/assets/match/vo/bc/lines.json'),'utf8'));
const calls={};const used=new Set();
for(const [key,ids] of Object.entries(LINES)){calls[key]={ids,...specOf(key)};for(const id of ids)used.add(id);}
const lines={};const radioDir=path.join(root,'assets/Sounds/BattleRadio');fs.mkdirSync(radioDir,{recursive:true});
for(const id of used){if(!voiceLines[id])throw Error('Missing source radio line '+id);
 fs.copyFileSync(path.join(source,'shared/assets/match/vo/bc',id+'.wav'),path.join(radioDir,id+'.wav'));
 lines[id]={...voiceLines[id],path:'Sounds/BattleRadio/'+id+'.wav'};
}
fs.writeFileSync(path.join(dest,'Radio.json'),JSON.stringify({source:data.source,calls,lines}));
console.log(JSON.stringify({source:data.source,prefabs:Object.keys(data.prefabs).length,avatars:fs.readdirSync(avatars).filter(n=>n.endsWith('.jpg')).length,bytes:fs.statSync(path.join(dest,'Arena.json')).size}));

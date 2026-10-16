import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash,randomBytes} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const load=p=>import(pathToFileURL(path.join(baseline.snapshot,p)).href);
const {COMPLETION_CUES,COMPLETION_BASE}=await load('shared/audio/completionCues.js');
const {ambienceState}=await load('shared/audio/gameAmbience.js');
const {MIX_TRIM}=await load('shared/audio/mixTrim.js');
const hash=b=>createHash('sha256').update(b).digest('hex');
const meta=p=>{if(!fs.existsSync(p+'.meta'))fs.writeFileSync(p+'.meta',JSON.stringify({uuid:randomBytes(18).toString('base64url')},null,2)+'\n');};
const cues={};fs.mkdirSync(path.join(root,'assets/Sounds/Ambience'),{recursive:true});
for(const id of ['amb_hangar','amb_warehouse','amb_crater','amb_mine']){
 const cue=COMPLETION_CUES[id];
 const original=fileURLToPath(new URL(`${id}_${cue.variant}.wav`,COMPLETION_BASE));
 const data=fs.readFileSync(original),relative=`Sounds/Ambience/${id}_${cue.variant}.wav`;
 const source=path.relative(baseline.snapshot,original).replaceAll('\\','/');
 if(hash(data)!==baseline.files[source]?.sha256)throw Error('Frozen source mismatch: '+source);
 if(data.toString('ascii',0,4)!=='RIFF'||data.toString('ascii',8,12)!=='WAVE')throw Error('Invalid WAV: '+source);
 const dest=path.join(root,'assets',relative);fs.writeFileSync(dest,data);meta(dest);
 cues[id]={path:relative,gain:cue.gain*10**((MIX_TRIM[id]||0)/20),loop:cue.loop,attack:cue.attack,release:cue.release,bus:cue.bus,source,sha256:hash(data),bytes:data.length};
}
const json=path.join(root,'assets/Combat/AmbienceSounds.json');fs.writeFileSync(json,JSON.stringify({baseline:baseline.commit,cues}));meta(json);
meta(path.join(root,'scripts/audio/GameAmbience.lua'));
const cases=[];
for(const active of [false,true])for(const pausedDrive of [false,true])for(const mapId of ['test','crater','salvage'])for(const screen of ['home','salvage'])for(const locked of [false,true])for(const mask of ['none','disabled','introActive','busy','matching','shellBusy','transition','intro','paused','script']){
 const state={drive:{active,pausedDrive,mapId,input:{locked},modeController:{}},shell:{screen}};
 if(mask==='disabled'||mask==='introActive')state[mask]=true;
 if(mask==='busy')state.drive.busy=true;
 if(mask==='matching')state.drive.matchStarting=true;
 if(mask==='shellBusy')state.shell.busy=true;
 if(mask==='transition')state.shell.transition={playing:true};
 if(['intro','paused','script'].includes(mask))state.drive.modeController[mask]=true;
 cases.push({state,chosen:ambienceState(state)});
}
fs.writeFileSync(path.join(root,'tools/migration/source-ambience-audio.json'),JSON.stringify({baseline:baseline.commit,cases}));
console.log(JSON.stringify({samples:Object.keys(cues).length,bytes:Object.values(cues).reduce((s,c)=>s+c.bytes,0),cases:cases.length,baseline:baseline.commit}));

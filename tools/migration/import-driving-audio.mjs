import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash,randomBytes} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const load=p=>import(pathToFileURL(path.join(baseline.snapshot,p)).href);
const {DRIVING_CUES,DRIVING_BASE}=await load('shared/audio/drivingCues.js');
const {mixDriving}=await load('shared/audio/drivingMix.js');
const {MIX_TRIM}=await load('shared/audio/mixTrim.js');
const hash=b=>createHash('sha256').update(b).digest('hex');
const meta=p=>{if(!fs.existsSync(p+'.meta'))fs.writeFileSync(p+'.meta',JSON.stringify({uuid:randomBytes(18).toString('base64url')},null,2)+'\n');};
const cues={};fs.mkdirSync(path.join(root,'assets/Sounds/Driving'),{recursive:true});
for(const [id,cue] of Object.entries(DRIVING_CUES)){
 const original=fileURLToPath(new URL(`${cue.file||id}_${cue.variant}.wav`,cue.base||DRIVING_BASE));
 const data=fs.readFileSync(original),relative=`Sounds/Driving/${id}_${cue.variant}.wav`;
 if(data.toString('ascii',0,4)!=='RIFF'||data.toString('ascii',8,12)!=='WAVE')throw Error('Invalid WAV: '+original);
 const dest=path.join(root,'assets',relative);fs.writeFileSync(dest,data);meta(dest);
 cues[id]={path:relative,gain:cue.gain*10**((MIX_TRIM[id]||0)/20),gap:cue.gap/1000,loop:cue.loop||false,
  attack:cue.attack||.08,release:cue.release||.025,source:path.relative(baseline.snapshot,original).replaceAll('\\','/'),sha256:hash(data),bytes:data.length};
}
const json=path.join(root,'assets/Combat/DrivingSounds.json');fs.writeFileSync(json,JSON.stringify({baseline:baseline.commit,cues}));meta(json);
for(const module of ['DrivingMix','DrivingEvents','DrivingAudio'])meta(path.join(root,'scripts/audio',module+'.lua'));
const cases=[];
for(const kind of ['wheel','track','hover','jet','mixed','empty'])for(const speed of [0,.1,.2,6,12,30,-6])for(const cutLift of [false,true]){
 const wheels=kind==='wheel'||kind==='mixed'?[{track:false}]:[];
 const trackWheels=kind==='track'||kind==='mixed'?[{}]:[];
 const hovers=kind==='hover'||kind==='mixed'?[{}]:[];
 const thrust=kind==='jet'||kind==='mixed'?.64:0;
 const command={throttle:speed===0?0:.5,cutLift};const vehicle={speed,wheels,trackWheels,hovers,thrusterOutputs:new Map([[1,thrust]]),telemetry:{hoverForce:cutLift?0:100}};
 const loops={};mixDriving({setLoop:(id,amount,pitch)=>loops[id]={amount,pitch}},vehicle,command);
 cases.push({kind,speed,thrust,command,loops});
}
fs.writeFileSync(path.join(root,'tools/migration/source-driving-audio.json'),JSON.stringify({baseline:baseline.commit,cases}));
console.log(JSON.stringify({samples:Object.keys(cues).length,bytes:Object.values(cues).reduce((s,c)=>s+c.bytes,0),cases:cases.length,baseline:baseline.commit}));

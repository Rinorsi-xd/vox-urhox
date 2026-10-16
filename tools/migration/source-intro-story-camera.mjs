import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const name='three/src/intro/intro.js',bytes=fs.readFileSync(path.join(baseline.snapshot,name));
const hash=createHash('sha256').update(bytes).digest('hex');
if(hash!==baseline.files[name].sha256)throw Error('Frozen intro source drift');
const ctx=vm.createContext({V:{},IntroStory:class{},performance:{now:()=>0}});
vm.runInContext(bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')
 .replaceAll('import.meta.url',"'file:///frozen/intro.js'")+'\nglobalThis.Intro=Intro;',ctx);
const I=Object.create(ctx.Intro.prototype);
const no=()=>{};const alarm={classList:{add:no,remove:no}};
Object.assign(I,{time:17,log:[],tasks:new Set(),waits:[],props:[],mode:'adapter',drive:{active:false},
 view:{root:{}},L:{alarm,black:{style:{}}},audio:{sfx:no},
 _tv:no,_clearProps:no,useGarage:no,grade:no,alarmLights:no,_lights:no,_camera:no,
 scene:{updateMatrixWorld:no},cam:{pos:{set(...v){this.value=v;}},look:{set(...v){this.value=v;}}}});
I.prepareStoryScene();
const frames=[];
for(const [shot,age,startGate=false] of [
 ['comms',0],['comms',.5],['contract',.5],['contract',10],['stamp',10],['stamp',10.2],
 ['gate',11],['gate',14.93],['gate',14.94,true],['gate',15.24],['gate',16.14],['gate',17.34],['gate',17.6],
]){
 I.time=17+age;I.mark(shot);if(startGate)I.prepareStoryGate();I.update(0,age);
 frames.push({shot,age,startGate,position:I.cam.pos.value,look:I.cam.look.value,fov:I.cam.fov,tasks:I.tasks.size});
}
const gate=JSON.parse(execFileSync(process.execPath,['tools/migration/source-intro-gate.mjs'],{encoding:'utf8'}));
const gateCameraAt=gate.trace.find(row=>row.kind==='camera').time;
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},
 sourceHashes:{[name]:hash,...gate.sourceHashes},frames,gateCameraAt,gateTrace:gate.trace,
 boundary:'Complete frozen Intro.prepareStoryScene/prepareStoryGate/task/mark/update/camMove, plus actual frozen IntroStory.actGate via existing source oracle. Native/DOM factories adapted; no GPU, camera shake or audible playback.'}));

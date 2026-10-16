// Native-free reference: execute the frozen production key and progress methods.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const hashes={};
function Read(relative){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,relative));
 const hash=createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[relative]?.sha256)throw Error('Frozen source changed: '+relative);
 hashes[relative]=hash;return bytes.toString('utf8');
}
let storage={};
const context=vm.createContext({localStorage:{getItem:key=>storage[key]??null,setItem:(key,value)=>{storage[key]=value;}}});
const progress=new vm.SourceTextModule(Read('shared/story/progress.js'),{context});
await progress.link(()=>{throw Error('Unexpected progress dependency');});await progress.evaluate();
const cases=[];
for(const oldGrade of [null,'S','A','B'])for(const grade of ['S','A','B'])for(const time of [350,400,450]){
 const old=oldGrade?{grade:oldGrade,time:400,clears:2}:null;
 storage=old?{'vox.story.progress':JSON.stringify({s1:old})}:{};
 const result=progress.namespace.recordClear('s1',grade,time);
 cases.push({old,grade,time,newBest:result.newBest,best:result.best});
}
const exports={
 'three':{Vector3:class{}},'@shared/combat/carUnit.js':{CarUnit:class{}},'@shared/ai/driver.js':{EnemyDriver:class{}},
 '@shared/ai/drillRaider.js':{DrillRaiderDriver:class{}},'@shared/build/enemyPrefabs.js':{enemyPrefab(){}},
 '@shared/battle/endlessSpawn.js':{centeredSpawn(){}},'@shared/ui/storyHud.js':{StoryHud:class{}},
 '@shared/story/radio.js':{radio(){}},'@shared/story/progress.js':{recordClear:progress.namespace.recordClear},
 './storyView.js':{StoryView:class{}},'./storyEpilogue.js':{playEpilogue(){}},'../salvage/salvageFx.js':{SalvageFx:class{}},
 './storyKinds.js':{KINDS:{}},'../intro/nonoHolo.js':{nonoPortrait(){}},'../intro/huhuHolo.js':{huhuPortrait(){}},'@shared/config.js':{CELL:1}
};
const mission=new vm.SourceTextModule(Read('three/src/battle/storyMission.js'),{context});
await mission.link(name=>{
 const values=exports[name];if(!values)throw Error('Unexpected mission dependency '+name);
 return new vm.SyntheticModule(Object.keys(values),function(){for(const [key,value]of Object.entries(values))this.setExport(key,value);},{context});
});await mission.evaluate();
let skipCalls=0;
const actor=Object.create(mission.namespace.StoryMission.prototype);
Object.assign(actor,{level:{steps:[{kind:'reach'}]},i:0,hud:{comms:{skipLine(){skipCalls++;}}}});
actor.key({code:'Enter',repeat:false,preventDefault(){}});
const enterCalls=skipCalls;
actor.key({code:'Enter',repeat:true,preventDefault(){}});
if(enterCalls!==1||skipCalls!==1)throw Error('Source Enter contract changed');
console.log(JSON.stringify({source:{branch:baseline.branch,commit:baseline.commit,files:hashes},enterCalls,repeatCalls:skipCalls-enterCalls,cases}));

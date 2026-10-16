import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const hashes={};
function Read(relative){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,relative));const sha=createHash('sha256').update(bytes).digest('hex');
 if(sha!==baseline.files[relative]?.sha256)throw Error('Frozen source changed: '+relative);
 hashes[relative]=sha;return bytes.toString('utf8');
}
export async function Collect(){
 const context=vm.createContext({document:{pointerLockElement:null},localStorage:{getItem(){return null;}}});
 const exports={
  'three':{Vector3:class{}},'@shared/combat/carUnit.js':{CarUnit:class{}},'@shared/ai/driver.js':{EnemyDriver:class{}},
  '@shared/ai/drillRaider.js':{DrillRaiderDriver:class{}},'@shared/build/enemyPrefabs.js':{enemyPrefab(){}},
  '@shared/battle/endlessSpawn.js':{centeredSpawn(){}},'@shared/ui/storyHud.js':{StoryHud:class{}},
  '@shared/story/radio.js':{radio(){}},'@shared/story/progress.js':{recordClear(){return {newBest:false};}},
  './storyView.js':{StoryView:class{}},'./storyEpilogue.js':{playEpilogue(){}},'../salvage/salvageFx.js':{SalvageFx:class{}},
  './storyKinds.js':{KINDS:{}},'../intro/nonoHolo.js':{nonoPortrait(){}},'../intro/huhuHolo.js':{huhuPortrait(){}},'@shared/config.js':{CELL:1},
  '../build/blueprint.js':{Blueprint:class{}},'../build/prefab.js':{buildDrillTank(){return {toJSON(){return {};}};}}
 };
 async function Module(relative){
  const mod=new vm.SourceTextModule(Read(relative),{context});
  await mod.link(name=>{const values=exports[name];if(!values)throw Error('Unknown source import '+name);
   return new vm.SyntheticModule(Object.keys(values),function(){for(const [key,value]of Object.entries(values))this.setExport(key,value);},{context});
  });await mod.evaluate();return mod.namespace;
 }
 const {StoryMission}=await Module('three/src/battle/storyMission.js');
 const index=JSON.parse(Read('shared/assets/story/vo/lines.json'));
 const norm=s=>String(s).replace(/^【[^】]*】/,'').replace(/[^\p{Script=Han}A-Za-z0-9]/gu,'');
 const byText=new Map(Object.entries(index).flatMap(([id,v])=>v.text.map(text=>[norm(text),id])));
 const quotes=[];
 for(let i=1;i<=5;i++){
  const level=(await Module(`shared/story/level${i}.js`))[`LEVEL${i}`];
  for(const grade of ['S','A','B']){
   const [parS,parA]=level.par||[420,600];let result;
   const actor=Object.create(StoryMission.prototype);
   Object.assign(actor,{level,time:grade==='S'?0:grade==='A'?(parS+parA)/2:parA+1,
    stats:{deaths:0,fails:0,kills:0},flags:{},hud:{result(value){result=value;}}});
   actor._result();
   if(result.grade!==grade)throw Error('Unexpected source grade');
   const id=byText.get(norm(result.quote));
   if(id)Read(`shared/assets/story/vo/${id}.mp3`);
   quotes.push({level:level.id,grade,text:result.quote,id:id||null});
  }
 }
 return {source:{branch:baseline.branch,commit:baseline.commit,files:hashes},snapshot:baseline.snapshot,index,quotes};
}

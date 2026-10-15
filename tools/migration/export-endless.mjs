import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=path.resolve(baseline.snapshot);
const url=p=>pathToFileURL(path.join(source,p)).href;
const {ENDLESS,ENEMY_ROLES}=await import(url('shared/battle/endlessConfig.js'));
const {ENEMY_PREFABS,STARTER_CARS,enemyPrefab}=await import(url('shared/build/enemyPrefabs.js'));
const {planWave,wavePoints,enemyTier,unlockedTier}=await import(url('shared/battle/endless.js'));
const {BATTLE_FLOW_CUES,BATTLE_FLOW_BASE}=await import(url('shared/audio/battleFlowCues.js'));
const {REWARD_CUES,REWARD_BASE}=await import(url('shared/audio/rewardCues.js'));
const {MIX_TRIM}=await import(url('shared/audio/mixTrim.js'));
const {seededRandom}=await import(url('shared/ai/driver.js'));
const {supplyChoices,initialInventory,rollDrops}=await import(url('shared/battle/endlessInventory.js'));
const provenance={};
for(const p of ['shared/battle/endlessConfig.js','shared/battle/endless.js','shared/battle/endlessInventory.js','shared/battle/endlessSpawn.js','shared/build/enemyPrefabs.js','shared/ai/driver.js','shared/ui/endlessHud.js','three/src/battle/endlessSession.js','three/src/battle/endlessEdit.js','three/src/battle/endlessLoot.js','three/src/battle/endlessView.js']){
 const hash=createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex');
 if(baseline.files[p]?.sha256!==hash)throw Error('Source hash mismatch '+p);
 provenance[p]=hash;
}
const prefabs={};
for(const row of ENEMY_PREFABS)for(const variant of [0,1])prefabs[`${row.role}:${row.tier}:${variant}`]=enemyPrefab(row.role,row.tier,variant).source;
prefabs['huhu-fuyuan']=enemyPrefab('assault',1,0,'huhu-fuyuan').source;
const data={baseline:{branch:baseline.branch,commit:baseline.commit},provenance,config:ENDLESS,roles:ENEMY_ROLES,prefabs,starters:STARTER_CARS};
fs.mkdirSync(path.join(root,'assets/Endless'),{recursive:true});
fs.writeFileSync(path.join(root,'assets/Endless/Rules.json'),JSON.stringify(data));
const cues={};
for(const id of ['countdown_tick','wave_start','boss_warning','urgent_warning','game_over','loot_drop','loot_pickup','wave_clear','supply_open','supply_choose']){
 const cue=BATTLE_FLOW_CUES[id]||REWARD_CUES[id];const base=cue.base||(BATTLE_FLOW_CUES[id]?BATTLE_FLOW_BASE:REWARD_BASE);
 const original=fileURLToPath(new URL(`${id}_${cue.variant}.wav`,base));const dest=`Endless/Audio/${id}_${cue.variant}.wav`;
 fs.mkdirSync(path.dirname(path.join(root,'assets',dest)),{recursive:true});fs.copyFileSync(original,path.join(root,'assets',dest));
 cues[id]={path:dest,gain:cue.gain*10**((MIX_TRIM[id]||0)/20),gap:cue.gap/1000,sha256:createHash('sha256').update(fs.readFileSync(original)).digest('hex')};
}
fs.writeFileSync(path.join(root,'assets/Endless/Sounds.json'),JSON.stringify({baseline:data.baseline,cues}));
const waves=[];for(const seed of [1,19282,'competition','1234'])for(let wave=1;wave<=40;wave++)waves.push({seed,wave,points:wavePoints(wave),tier:enemyTier(wave),unlocked:unlockedTier(wave),plan:planWave(seed,wave)});
const supplies=[];for(const seed of [1,19282,'competition'])for(const wave of [1,2,3,5,10,15,20,30])for(let starter=0;starter<3;starter++){
 const tier=unlockedTier(wave),blueprint=STARTER_CARS[starter].source,inventory=initialInventory(blueprint),randomSeed=`${seed}:supplies:${wave}`;
 supplies.push({seed:randomSeed,wave,tier,starter:starter+1,drought:wave%4,choices:supplyChoices({tier,wave,blueprint,inventory,weaponDrought:wave%4,random:seededRandom(randomSeed)})});
}
const drops=[];for(const seed of [1,19282,'competition'])for(const role of Object.keys(ENEMY_ROLES))for(const elite of [false,true]){
 const parts=[{id:1,type:'laser1',hp:10},{id:2,type:'laser2',hp:10},{id:3,type:'drive1',hp:20},{id:4,type:'steer1',hp:0}];
 drops.push({seed,role,elite,parts,drops:rollDrops({role,elite},parts,seededRandom(seed))});
}
fs.writeFileSync(path.join(root,'tools/migration/source-endless-fixtures.json'),JSON.stringify({baseline:data.baseline,provenance,waves,supplies,drops}));
console.log(JSON.stringify({prefabs:Object.keys(prefabs).length,starters:STARTER_CARS.length,waves:waves.length,supplies:supplies.length,drops:drops.length}));

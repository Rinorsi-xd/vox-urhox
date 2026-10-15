import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const checked={};
const hash=b=>createHash('sha256').update(b).digest('hex');
function read(relative){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,relative));
 const actual=hash(bytes);if(actual!==baseline.files[relative]?.sha256)throw Error('Frozen hash mismatch: '+relative);
 checked[relative]=actual;return bytes;
}
function literal(file,name){
 const text=read(file).toString('utf8');
 const match=text.match(new RegExp('(?:export )?const '+name+' = (\\{[\\s\\S]*?\\n\\});'));
 if(!match)throw Error('Missing original literal '+name);
 return vm.runInNewContext('('+match[1]+')',{URL}, {timeout:1000});
}
// Evaluate only authored object literals; no browser/audio code executes here.
const names=literal('shared/story/radio.js','CUES');
const trim=literal('shared/audio/mixTrim.js','MIX_TRIM');
const groups=[
 ['shared/audio/battleFlowCues.js','BATTLE_FLOW_CUES','shared/assets/audio/battle-flow-09-r3/'],
 ['shared/audio/rewardCues.js','REWARD_CUES','shared/assets/audio/rewards-07/'],
 ['shared/audio/completionCues.js','COMPLETION_CUES','shared/assets/audio/completion-10-11/']
];
const samples={};
for(const [file,name,base]of groups){
 read(file);const cues=(await import(pathToFileURL(path.join(baseline.snapshot,file)).href))[name];
 for(const [id,cue]of Object.entries(cues))samples[id]={...cue,base:cue.base?path.relative(baseline.snapshot,fileURLToPath(cue.base)).replaceAll('\\','/'):base};
}
read('shared/ui/uiSound.js');read('three/src/battle/storyBoss.js');read('three/src/battle/storyEpilogue.js');
const cues={};const destination=path.join(root,'assets/Story/Radio');fs.mkdirSync(destination,{recursive:true});
for(const [name,[id,strength]]of Object.entries(names)){
 const cue=samples[id];if(!cue)throw Error('Missing original cue '+id);
 const relative=path.posix.join(cue.base,cue.file||id+'_'+cue.variant+'.wav');const bytes=read(relative);
 const file=id+'_'+cue.variant+'.wav';fs.writeFileSync(path.join(destination,file),bytes);
 cues[name]={id,path:'Story/Radio/'+file,strength,gain:cue.gain*10**((trim[id]||0)/20),gap:cue.gap/1000,bus:cue.bus||(id==='missile_close'?'weapons':'feedback'),trimDb:trim[id]||0,source:relative,sha256:hash(bytes)};
}
const data={source:{branch:baseline.branch,commit:baseline.commit,files:checked},master:{volume:.6,scale:.65/.6},cues};
fs.writeFileSync(path.join(destination,'Radio.json'),JSON.stringify(data,null,2)+'\n');
console.log(JSON.stringify({commit:baseline.commit,checked:Object.keys(checked).length,cues:Object.keys(cues).length,bytes:Object.values(cues).reduce((sum,c)=>sum+fs.statSync(path.join(root,'assets',c.path)).size,0)},null,2));

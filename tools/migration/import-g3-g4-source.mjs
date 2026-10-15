import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=baseline.snapshot;
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const checked=new Map();
function read(relative) {
 const bytes=fs.readFileSync(path.join(source,relative));
 if(hash(bytes)!==baseline.files[relative]?.sha256) throw Error('Frozen source hash mismatch: '+relative);
 checked.set(relative,hash(bytes));return bytes.toString('utf8');
}
registerHooks({resolve(s,c,n){
 if(s.startsWith('@shared/')) return n(pathToFileURL(path.join(source,'shared',s.slice(8))).href,c);
 return n(s,c);
},load(u,c,n){
 if(u.startsWith(pathToFileURL(source).href+'/')) read(path.relative(source,fileURLToPath(u)).replaceAll('\\','/'));
 return n(u,c);
}});
const {LEVEL5}=await import(pathToFileURL(path.join(source,'shared/story/level5.js')).href);
const {FOX}=await import(pathToFileURL(path.join(source,'shared/build/foxData.js')).href);
const bossText=read('three/src/battle/storyBoss.js');
const literal=bossText.match(/export const FOX_BOSS = (\{[\s\S]*?\n\});/)[1];
const boss=vm.runInNewContext('('+literal+')',Object.create(null),{timeout:1000});
const level=JSON.parse(JSON.stringify(LEVEL5));
level.setup={points:true};level.resultPolicy='boss';
const out={source:{branch:baseline.branch,commit:baseline.commit,files:Object.fromEntries(checked)},level,boss,fox:FOX};
const dest=path.join(root,'assets/Story/Mission/Level5.json');
fs.writeFileSync(dest+'.import-tmp',JSON.stringify(out));fs.renameSync(dest+'.import-tmp',dest);
const images={};
fs.mkdirSync(path.join(root,'assets/Story/Boss'),{recursive:true});
for(const name of ['ep_office_bg','ep_photo_bg','ep_mess_bg','chairman','chairman_cut']) {
 const relative='shared/assets/story/boss/'+name+'.webp';read(relative);
 const target=path.join(root,'assets/Story/Boss',name+'.webp');fs.copyFileSync(path.join(source,relative),target);
 const python=process.env.VOX_IMAGE_PYTHON||'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe';
 const png=target.replace(/\.webp$/,'.png');
 execFileSync(python,['-c','from PIL import Image; import sys; Image.open(sys.argv[1]).save(sys.argv[2])',target,png],{windowsHide:true});
 images[name]={path:'Story/Boss/'+name+'.png',sha256:checked.get(relative),derivedSha256:hash(fs.readFileSync(png))};
}
const epilogue={source:{branch:baseline.branch,commit:baseline.commit,
 files:{'shared/story/level5.js':checked.get('shared/story/level5.js'),'three/src/battle/storyEpilogue.js':hash(read('three/src/battle/storyEpilogue.js'))}},
 data:level.epilogue,images};
for(const scene of epilogue.data.scenes){const p=scene.panel;if(!p)continue;
 if(p.poly)p.polyPoints=p.poly.match(/[\d.]+%?\s+[\d.]+%?/g).map(v=>v.match(/[\d.]+/g).map(Number));
 const from=(p.from||'0 -40vh').match(/(-?[\d.]+)(?:vw|vh)?\s+(-?[\d.]+)(vw|vh)?/);p.fromParts=[+from[1],+from[2],p.from.includes('vw')?'vw':'vh'];
 if(p.labelAt)p.labelRight=+(p.labelAt.match(/right:([\d.]+)%/)||[])[1]||null;
 if(p.sfx){const at=p.sfx[2];p.sfxParts={right:+(at.match(/right:([\d.]+)%/)||[])[1]||0,bottom:+(at.match(/bottom:([\d.]+)%/)||[])[1]||0};}
}
const epiFile=path.join(root,'assets/Story/Boss/Epilogue.json');fs.writeFileSync(epiFile+'.import-tmp',JSON.stringify(epilogue));fs.renameSync(epiFile+'.import-tmp',epiFile);
console.log(JSON.stringify({commit:baseline.commit,steps:level.steps.length,foxParts:FOX.parts.length,epilogueScenes:level.epilogue.scenes.length,images:Object.keys(images).length}));

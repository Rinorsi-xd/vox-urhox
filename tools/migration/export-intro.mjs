import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const ledger=[];
function read(relative){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,relative));
 const hash=createHash('sha256').update(bytes).digest('hex');
 if(baseline.files[relative]?.sha256!==hash)throw Error('Frozen intro source hash mismatch: '+relative);
 ledger.push({source:relative,sha256:hash,bytes:bytes.length});return bytes;
}
function literal(text,name){
 const match=text.match(new RegExp('(?:export )?const '+name+' = (\\{[\\s\\S]*?\\n\\});'));
 if(!match)throw Error('Missing original '+name);return vm.runInNewContext('('+match[1]+')',{}, {timeout:1000});
}
const story=read('three/src/intro/introStory.js').toString();
const intro=read('three/src/intro/intro.js').toString();
const lines=literal(story,'STORY_LINES'),caps=literal(intro,'CAP');
const durations=JSON.parse(read('shared/assets/intro/audio/vo_durations.json'));
const audio={},images={};
const target=path.join(root,'assets/Intro');fs.mkdirSync(target,{recursive:true});
function copy(relative,output){
 const bytes=read(relative);const file=path.join(target,output);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);
 ledger.at(-1).target='assets/Intro/'+output;
}
for(const f of fs.readdirSync(path.join(baseline.snapshot,'shared/assets/intro/audio'))){
 if(!/\.(mp3|wav)$/.test(f))continue;
 copy('shared/assets/intro/audio/'+f,'Audio/'+f);audio[f.replace(/\.[^.]+$/,'')]='Intro/Audio/'+f;
}
for(const name of ['city','order','family','dove','workshop','machinist_idle','machinist_hero','nono_smile','nono_talk','nono_deadpan','nono_stamp']){
 copy('shared/assets/intro/raw/'+name+'.png','Images/'+name+'.png');images[name]='Intro/Images/'+name+'.png';
}
for(const name of ['company-emblem','division-insignia','company-stamp']){
 copy('shared/assets/ui/brand/'+name+'.png','Images/'+name+'.png');images[name]='Intro/Images/'+name+'.png';
}
for(const file of fs.readdirSync(path.join(baseline.snapshot,'three/src/intro'))){
 if(file.endsWith('.js')&&!ledger.some(x=>x.source==='three/src/intro/'+file))read('three/src/intro/'+file);
}
read('shared/css/intro.css');read('shared/ui/hudFrame.js');
const visited=new Set();
function trace(relative){
 if(visited.has(relative))return;visited.add(relative);
 const text=read(relative).toString();
 for(const match of text.matchAll(/(?:from\s*|import\s*)['"]([^'"]+)['"]/g)){
  if(match[1].startsWith('.'))trace(path.posix.normalize(path.posix.join(path.posix.dirname(relative),match[1])));
 }
}
trace('three/src/intro/introCast.js');
const cast=await import(pathToFileURL(path.join(baseline.snapshot,'three/src/intro/introCast.js')).href);
const enemy=await import(pathToFileURL(path.join(baseline.snapshot,'shared/build/enemyPrefabs.js')).href);
const actors={hero:cast.heroBlueprint().toJSON(),cart:cast.cartBlueprint().toJSON(),invaders:cast.INVADERS.map(r=>({...r,blueprint:cast.invaderBlueprint(r).toJSON()})),hovers:[3,4,5].map(t=>enemy.createEnemyBlueprint('hover',t,0,{player:true}).toJSON())};
const fx=read('three/src/intro/introFx.js').toString();
const galaxyCode=fx.slice(fx.indexOf('export class GalaxyMap'),fx.indexOf('// 锁定准星')).replace('export class','class');
const randomCode=fx.slice(fx.indexOf('function mulberry'));
const galaxy=vm.runInNewContext(galaxyCode+'\n'+randomCode+'\nnew GalaxyMap(null)',{
 h:()=>({querySelector:selector=>selector==='canvas'?{getContext:()=>({})}:{},getBoundingClientRect:()=>({width:1920,height:1080})}),devicePixelRatio:1,
},{timeout:1000});
const plain=html=>html.replace(/<br\s*\/?\s*>/g,'\n').replace(/<[^>]+>/g,'').replace(/&gt;/g,'>').replace(/&amp;/g,'&');
const terms=story.match(/<div class="terms">([\s\S]*?)<span class="egg" hidden>/)[1];
const kv=story.match(/<div class="kv">([\s\S]*?)<\/div>/)[1];
const data={schema:1,branch:baseline.branch,commit:baseline.commit,lines,caps,durations,audio,images,actors,galaxy:{stars:galaxy.stars,hits:galaxy.hits,names:galaxy.names},
 terms:plain(terms).trim(),employeeFields:[...kv.matchAll(/<span>([\s\S]*?)<\/span>/g)].map(x=>plain(x[1])),
 choices:['我能拒绝吗？','上一任怎么了？','……开工吧。'],
 contractEgg:'※ 你已读完全部条款。这是本月第 1 次有人这么做。\n※ 奖励：无。（如果你刚才没有真的读，本条同样适用。）',
 provenance:ledger};
const text=JSON.stringify(data,null,2)+'\n';fs.writeFileSync(path.join(target,'Intro.json'),text);
console.log(JSON.stringify({result:'PASS',commit:baseline.commit,files:ledger.length,audio:Object.keys(audio).length,images:Object.keys(images).length,bytes:ledger.filter(x=>x.target).reduce((n,x)=>n+x.bytes,0)}));

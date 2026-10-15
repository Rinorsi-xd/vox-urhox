import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const name='three/src/battle/storyBoss.js',source=fs.readFileSync(path.join(baseline.snapshot,name)),sha=createHash('sha256').update(source).digest('hex');
if(sha!==baseline.files[name].sha256)throw Error('Frozen Boss source changed');
const css=source.toString().match(/const BAR_CSS = `([\s\S]*?)`;/)[1];
const rule=selector=>css.split('\n').find(line=>line.startsWith(selector+'{'));
const seconds=(text,key)=>Number(text.match(new RegExp(key+' ([.\\d]+)s'))[1]);
const main=seconds(rule('#storyHud .fx-boss .fb-bar s'),'transition:transform');
const trailMatch=rule('#storyHud .fx-boss .fb-bar u').match(/transition:transform ([.\d]+)s ([.\d]+)s/);
const letter=rule('#storyHud .fx-letter'),letterDuration=seconds(letter,'transition:height');
const curve=letter.match(/cubic-bezier\(([^)]+)\)/)[1].split(',').map(Number);
const coord=(t,a,b)=>3*(1-t)**2*t*a+3*(1-t)*t*t*b+t*t*t;
function ease(x,curve=[.25,.1,.25,1]){if(x<=0)return 0;if(x>=1)return 1;let lo=0,hi=1;for(let i=0;i<40;i++){const mid=(lo+hi)/2;if(coord(mid,curve[0],curve[2])<x)lo=mid;else hi=mid;}return coord((lo+hi)/2,curve[1],curve[3]);}
const samples=[];
for(const time of [0,.025,.05,.1,.15,.2,.25,.3,.4,.5,.6,.75,.9,1,1.05,1.2])samples.push({time,
 main:1-.6*ease(time/main),trail:1-.6*ease((time-Number(trailMatch[2]))/Number(trailMatch[1])),
 letter:ease(time/letterDuration,curve),bar:ease(time/.4),kneel:ease(time/.2),prompt:ease((time-.6)/.4),
 boom:(1-ease(time/.9,[0,0,.58,1]))**2});
fs.writeFileSync(path.join(root,'tools/migration/source-boss-hud-fixtures.json'),JSON.stringify({commit:baseline.commit,source:name,sha,
 cssRules:[rule('#storyHud .fx-boss'),rule('#storyHud .fx-boss .fb-bar s'),rule('#storyHud .fx-boss .fb-bar u'),letter,rule('#storyHud .fx-letter.b::after'),rule('#storyHud .fx-ult.boom')],samples}));
console.log(JSON.stringify({samples:samples.length,main,trail:Number(trailMatch[1]),trailDelay:Number(trailMatch[2]),letterDuration,commit:baseline.commit}));

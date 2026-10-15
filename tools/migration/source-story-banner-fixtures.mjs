import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const files=['three/src/battle/storyMission.js','three/src/battle/storyKinds.js','three/src/battle/storyBoss.js','shared/css/storyHud.css'];
const source={};
for(const name of files){const bytes=fs.readFileSync(path.join(baseline.snapshot,name));const sha=createHash('sha256').update(bytes).digest('hex');
  if(sha!==baseline.files[name].sha256)throw Error('Frozen source changed: '+name);source[name]={text:bytes.toString(),sha};}
const l={no:'01',name:'坠舰陨坑',en:'CRASH SITE'};
const s={enemies:[1,2,3],guards:[1,2],site:'B'};
const T={cp:2,hp:.763};const m={stats:{sites:2}};
const ctx={stats:{collectors:1},colTotal:3,level:l,_ultBroken:false};
const cases=[];
for(const name of files.slice(0,3))for(const line of source[name].text.split(/\r?\n/)){
  const match=line.match(/(?:this\.hud|m\.hud|this\.m\.hud)\.banner\( (.*?) \);/);if(!match)continue;
  if(match[1].startsWith('...'))continue;
  const run=new Function('l','s','T','m','title','sub','ctx','return function(){return ['+match[1]+']}.call(ctx)');
  for(const collectors of line.includes('this.stats.collectors - 1')?[1,2,3]:[1]){
    ctx.stats.collectors=collectors;
    const args=run(l,s,T,m,'测试失败','座舱露出来了',ctx);
    cases.push({source:name,line:line.trim(),collectors,args});
  }
}
const css=source[files[3]].text;
const slam=css.match(/shSlam \.5s cubic-bezier\(([^)]+)\)/)[1].split(',').map(Number);
const coord=(t,a,b)=>3*(1-t)**2*t*a+3*(1-t)*t*t*b+t*t*t;
function ease(x,curve){if(x<=0)return 0;if(x>=1)return 1;let lo=0,hi=1;for(let i=0;i<40;i++){const mid=(lo+hi)/2;if(coord(mid,curve[0],curve[2])<x)lo=mid;else hi=mid;}return coord((lo+hi)/2,curve[1],curve[3]);}
const frames=[0,.04,.08,.125,.25,.4,.5,.68,2.4,2.5,2.65].map(age=>({age,alpha:age>2.4?1-ease(Math.min(1,(age-2.4)/.25),[.25,.1,.25,1]):ease(Math.min(1,age/.25),[.25,.1,.25,1]),slam:ease(Math.min(1,age/.5),slam),wipe:ease(Math.max(0,Math.min(1,(age-.08)/.6)),slam)}));
fs.writeFileSync(path.join(root,'tools/migration/source-story-banner-fixtures.json'),JSON.stringify({commit:baseline.commit,sources:Object.fromEntries(files.map(n=>[n,source[n].sha])),cases,frames}));
console.log(JSON.stringify({cases:cases.length,frames:frames.length,commit:baseline.commit}));

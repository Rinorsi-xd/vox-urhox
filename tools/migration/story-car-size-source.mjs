import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';
import {execFileSync} from 'node:child_process';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const relative='three/src/battle/storyMission.js';
const bytes=fs.readFileSync(`${baseline.snapshot}/${relative}`);
const sha256=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha256!==baseline.files[relative].sha256)throw Error('Frozen mission drift');
const config=execFileSync('git',['-C','D:/Rino_Project/Vox','show',`${baseline.commit}:shared/config.js`]);
const cell=Number(config.toString().match(/export const CELL\s*=\s*([\d.]+)/)[1]);
let measurements=0;
const context=vm.createContext({CELL:cell,THREE:{Vector3:class{},Box3:class{
  setFromObject(root){measurements++;if(root.retired)throw Error('Retired root read');Object.assign(this,root.box);return this;}
  isEmpty(){return !this.min;}
}}});
vm.runInContext(bytes.toString().replace(/^import .*;\r?\n/gm,'').replace('export class StoryMission','class StoryMission')+'\nglobalThis.StoryMission=StoryMission;',context);
const small={min:{x:-2,y:8,z:-3},max:{x:2,y:12,z:3}};
const giant={min:{x:-15.25,y:-3,z:-20.25},max:{x:15.25,y:17.5,z:20.25}};
const bb={minX:-30,maxX:30,minY:0,maxY:40,minZ:-40,maxZ:40};
const base={count:209,pos:[0,10,0],bb};
const sequences=[
 {name:'same-root-cache',actions:[{...base,root:'a',box:small},{...base,root:'a',box:giant}]},
 {name:'same-count-root-replaced',actions:[{...base,root:'a',box:small},{...base,root:'b',box:giant},{...base,root:'c',box:small}]},
 {name:'retired-old-root-never-read',actions:[{...base,root:'a',box:small},{...base,root:'b',box:giant,retire:'a'}]},
 {name:'undefined-bounds-become-ready',actions:[{...base,root:'a',box:{}},{...base,root:'a',box:giant}]},
 {name:'no-view-then-ready',actions:[{...base},{...base,root:'a',box:giant}]},
 {name:'view-removed',actions:[{...base,root:'a',box:giant},{...base},{...base,root:'b',box:small}]},
 {name:'count-invalidates',actions:[{...base,root:'a',box:small},{...base,count:210,root:'a',box:giant}]},
 {name:'absent-grid-bounds',actions:[{...base,bb:null},{...base,count:210,root:'a',box:{},bb:null}]},
 {name:'empty-grid-bounds',actions:[{...base,bb:{minX:'Infinity'}}]},
];
for(let i=0;i<24;i++)sequences.push({name:`grid-fallback-${i}`,actions:[{...base,count:i+1,bb:{minX:-i,maxX:i+1,minY:-i%3,maxY:i+4,minZ:-i*2,maxZ:i*2+3}}]});
const probes=[];
for(const [kind,r,up]of [['pickup',6,6],['reach',14,12],['capture',12,7],['scrub',9,6]])
for(const x of [0,8.9999,9,12,16,25.9999,26,33.9999,34,45])
for(const y of [-12,-3,0,10,17.5,30])probes.push({kind,r,up,target:[x,y,0]});
for(const test of sequences){
 measurements=0;let statsCalls=0;const roots={};
 const m=Object.create(context.StoryMission.prototype);
 m.drive={player:{bp:{parts:{size:0},stats:()=>{statsCalls++;return {bb:m.bb};}}}};
 test.expected=[];
 for(const action of test.actions){
  m.drive.player.pos=action.pos;m.drive.player.bp.parts.size=action.count;
  m.bb=action.bb?.minX==='Infinity'?{minX:Infinity}:action.bb;
  if(action.retire)roots[action.retire].retired=true;
  if(action.root){const root=roots[action.root]??={};root.box=action.box;m.drive.visual={root};}else m.drive.visual=null;
  const size=m.carSize();
  test.expected.push({size:{...size},measurements,statsCalls,near:probes.map(p=>m.near(action.pos,p.target,p.r,p.up))});
 }
}
console.log(JSON.stringify({source:{commit:baseline.commit,path:relative,sha256,configSha256:crypto.createHash('sha256').update(config).digest('hex')},cell,probes,sequences}));

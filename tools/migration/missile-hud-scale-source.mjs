import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const sourceHashes={};
for(const name of ['shared/ui/homeScale.js','shared/ui/reticle.js','shared/css/new-ui-reticle.css']) {
 const hash=createHash('sha256').update(fs.readFileSync(path.join(baseline.snapshot,name))).digest('hex');
 if(hash!==baseline.files[name].sha256)throw Error('Frozen source mismatch: '+name);
 sourceHashes[name]=hash;
}
const {reticleScale}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/ui/homeScale.js')));
const {MechReticle}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/ui/reticle.js')));
const cases=[];
for(const [width,height,compact]of [[1600,900,false],[1920,1080,false],[2560,1440,false],
 [1280,720,false],[2000,900,false],[1024,768,false],[1000,560,false],
 [844,390,true],[960,432,true],[960,540,true]]) {
 globalThis.document={documentElement:{hasAttribute:()=>compact}};
 const k=reticleScale(width,height);
 for(const angle of [0,.1])for(const phase of ['search','tracking','locked','reload','firing']) {
  const box=Math.tan(angle)*height/(2*Math.tan(60*Math.PI/360));
  const seek={box,progress:phase==='tracking'?.4:phase==='locked'?1:0,locked:phase==='locked',
   firing:phase==='firing',cooling:phase==='reload',phase:phase==='reload'?'reload':'idle',reload:.3,energyOk:true};
  const host={innerHTML:''};
  MechReticle.prototype._seek.call({k,cx:width/2,cy:height/2,q:()=>host},seek,350);
  cases.push({width,height,compact,angle,phase,k,seek,svg:host.innerHTML});
 }
}
console.log(JSON.stringify({baseline:baseline.commit,sourceHashes,cases}));

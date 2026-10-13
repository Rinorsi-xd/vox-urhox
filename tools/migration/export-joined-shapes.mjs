import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const load=name=>import(pathToFileURL(path.join(baseline.snapshot,'shared',name)));
const {PARTS}=await load('parts/defs.js');
const {exactShapeGeo}=await load('parts/shapes.js');
const {faceMask}=await load('parts/solid.js');
const {DIRS}=await load('core/rotations.js');
const shapes={};
for(const [type,def] of Object.entries(PARTS)){
 if(!def.shape||def.panel||shapes[def.shape])continue;
 const geo=exactShapeGeo(def.shape);
 shapes[def.shape]={position:Array.from(geo.position),normal:Array.from(geo.normal),
  faces:Array.from({length:24},(_,rot)=>DIRS.map(n=>faceMask(type,rot,n)))};
}
const bytes=Buffer.from(JSON.stringify({commit:baseline.commit,dirs:DIRS,shapes}));
const asset='assets/Parts/JoinedShapes.json';
fs.writeFileSync(path.join(root,asset),bytes);
const sources=Object.fromEntries(['shared/parts/shapes.js','shared/parts/polytope.js','shared/parts/solid.js','shared/parts/defs.js','shared/core/rotations.js'].map(p=>[p,baseline.files[p]]));
fs.writeFileSync(path.join(root,'docs/migration/joined-shapes-source.json'),JSON.stringify({commit:baseline.commit,sources,asset,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),shapes:Object.keys(shapes)},null,2));
console.log(JSON.stringify({shapes:Object.keys(shapes).length,bytes:bytes.length}));
